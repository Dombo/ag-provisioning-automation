# What and how?

Prepared for the A&G Snr. DevOps interview test.

An exercise in configuration management and provisioning to satisfy the below criterion.

Be sure to read over and understand [What do you need to get started?](#what-do-you-need-to-get-started) before proceeding to [Running the example](#running-the-example)

A docker container offers a portable execution environment, bound into the container are 
your AWS credentials and SSH pubkey (neither are persisted). Terraform is executed from the 
container, it stands up the resources listed in [Resources Deployed](#resources-deployed).

Ansible is packaged and inserted into the userdata to run on boot. The config management that
Ansible completes sets up nginx to satisfy the rest of the challenge.

## Resources Deployed

    * ASG
    * LaunchConfig
        * AMI sourcing
        * SSH key loading
        * Injecting provisioning utility payload
    * ELB
    * VPC
    * Subnet
    * SecurityGroup

# What do you need to get started?

* Docker (preferably a *nix host - windows incompatibilities not tested)
* SSH public key located at ~/.ssh/id_rsa
* AWS credentials located at ~/.aws/*
    * If the location of either are non-standard you'll need to override the variables accordingly (main.tf & variables.tf)
* Set your desired region & profile to use for AWS API authentication through terraform.tfvars

# Running the example

Standing up

```bash
> docker build -t terraformer .
> docker run -it --rm -v $(cd -P "./data" && pwd):/data -v $HOME/.aws:/root/.aws:ro -v $HOME/.ssh:/root.ssh:ro terraformer version
> docker run -it --rm -v $(cd -P "./data" && pwd):/data -v $HOME/.aws:/root/.aws:ro -v $HOME/.ssh:/root.ssh:ro terraformer init
> docker run -it --rm -v $(cd -P "./data" && pwd):/data -v $HOME/.aws:/root/.aws:ro -v $HOME/.ssh:/root.ssh:ro terraformer apply

```

Tearing down

```bash
> docker run -it --rm -v $(cd -P "./data" && pwd):/data -v $HOME/.aws:/root/.aws:ro -v $HOME/.ssh:/root.ssh:ro terraformer destroy
```

# Housekeeping / Troubleshooting


## Provided Criterion

The goal:

    Through a scripting language of your choice, provision a web server that prints a simple html index page that displays the EC2 instance ID of the web server that is responding to the request.

Requirements:

    Must run on AWS.
    Share on a VCS of your choice. (e.g GitHub, BitBucket)
    Must be able to run your script in my own AWS account.
    Must be able to create with a one line command and delete with a one line command.
    Include requirements/packages/dependencies (e.g. Ansible version, Boto version) in readme form.

Bonus challenge:

    Try adding some sort of load balancing in to the mix and make your solution highly available.

Some tips to help:

    There are heaps of NGINX and Apache hello world web pages out there you can "borrow"
    Load balancing can mean many things, DNS round robin, ELB's, ALB's etc.
    Remember to keep security in mind when you're handling AWS API keys.

----

Notes 

# Alternate examples

* Build an AMI to save on spin up time
* Load balance at the DNS layer if you don't require multi-AZ resiliency / cost footprint declines