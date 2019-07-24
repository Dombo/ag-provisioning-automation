output "loadbalancer_dns_address" {
  value = "${module.elb_http.this_elb_dns_name}"
}
