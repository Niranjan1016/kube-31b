output alb_dns_name {
  value = "${aws_alb.controller.dns_name}"
}

output master_ip {
  value = "${aws_instance.master.public_ip}"
}