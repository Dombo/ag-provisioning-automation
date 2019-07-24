/*
* Credentials
*   A note on the challenges of persistent credentials
*     * passing them as environment variables leaves them in logs
*     * putting them in files under VCS is obviously a no go
*     * passing them via the profile mechanism is reasonable (still not great)
*     * ideally passing a role to assume and using a bastion account pattern would be employed
*       * in this case I am binding them in using a readonly volume, the contents of volumes
*         do not make it into layers so we don't have a concern here (this is just dev btw)
*/
provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}

/*
* Data Providers
*/
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = "${module.vpc.vpc_id}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

locals {
  common_tags = {
    Terraform   = "true"
    Environment = "dev"
    Owner       = "dombo"
    Project     = "ag-provisioning-automation"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.67"

  name = "vpc"
  cidr = "10.0.0.0/16"

  azs = [
    "${data.aws_availability_zones.available.names[0]}",
    "${data.aws_availability_zones.available.names[1]}",
  ]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = "${concat(list(local.common_tags))}"
}

module "web_service_loadbalancer_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.17"

  name        = "web-service-loadbalancer"
  description = "Security group for web-service with HTTP:80 publicly open"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "web-service inbound web traffic"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "web-service outbound web traffic"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = "${concat(list(local.common_tags))}"
}

module "web_service_instance_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "2.17"

  name        = "web-service-instances"
  description = "Security group for web-service with HTTP:80 publicly open"
  vpc_id      = "${module.vpc.vpc_id}"

  computed_ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "web-service loadbalancer routed ingress web traffic"
      source_security_group_id = "${module.web_service_loadbalancer_sg.this_security_group_id}"
    },
  ]

  number_of_computed_ingress_with_source_security_group_id = 1

  computed_egress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "web-service loadbalancer routed egress web traffic"
      source_security_group_id = "${module.web_service_loadbalancer_sg.this_security_group_id}"
    },
  ]

  number_of_computed_egress_with_source_security_group_id = 1

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "web-service inbound SSH traffic"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "web-service outbound SSH traffic"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "web-service outbound HTTP traffic"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "web-service outbound HTTPS traffic"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = "${concat(list(local.common_tags))}"
}

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "1.4.1"

  name = "elb"

  subnets         = "${module.vpc.public_subnets}"
  security_groups = ["${module.web_service_loadbalancer_sg.this_security_group_id}"]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = [
    {
      target              = "HTTP:80/"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]

  tags = "${concat(list(local.common_tags))}"
}

// TODO (improvement) Run local-exec to create a keypair & have the public_key_filename variable fallback to it

resource "aws_key_pair" "deployer" {
  key_name   = "deployers-key"
  public_key = "${file("/root/.ssh/${var.public_key_filename}")}"
}

resource "null_resource" "prepare_bootstrap" {
  provisioner "local-exec" {
    command = "./shell/prepare.sh ./ansible > ./shell/bootstrap.sh"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

data "template_file" "bootstrap_system_configuration" {
  template = "${file("${path.module}/shell/bootstrap.sh")}"

  depends_on = ["null_resource.prepare_bootstrap"]
}

data "template_cloudinit_config" "bootstrap_config" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.bootstrap_system_configuration.rendered}"
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "2.10"

  name = "web-service"

  # Launch configuration
  lc_name = "web-service-lc-${uuid()}"

  image_id        = "${data.aws_ami.ubuntu.id}"
  instance_type   = "t2.small"
  security_groups = ["${module.web_service_instance_sg.this_security_group_id}"]

  key_name = "${aws_key_pair.deployer.key_name}"

  user_data = "${data.template_cloudinit_config.bootstrap_config.rendered}"

  root_block_device = [
    {
      volume_size = "8"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name = "web-service-asg-${uuid()}"

  //    I've left room to deploy this in a private subnet as would be considered general best practice
  vpc_zone_identifier = ["${module.vpc.private_subnets[0]}", "${module.vpc.private_subnets[1]}"]

  //  vpc_zone_identifier       = ["${module.vpc.public_subnets[0]}", "${module.vpc.public_subnets[1]}"]
  //  associate_public_ip_address = true // For debugging purposes only - advise a bastion & private sub deployment usually
  load_balancers = ["${module.elb_http.this_elb_id}"]

  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 3
  desired_capacity          = 2
  wait_for_capacity_timeout = 0

  tags_as_map = "${concat(list(local.common_tags))}"
}
