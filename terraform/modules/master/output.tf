output alb_dns_name {
  value = "${aws_alb.controller.dns_name}"
}