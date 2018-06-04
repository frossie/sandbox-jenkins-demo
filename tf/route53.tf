resource "aws_route53_record" "jenkins-demo-master" {
  zone_id = "${var.aws_zone_id}"

  name    = "${data.template_file.fqdn.rendered}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.jenkins-demo-master.public_ip}"]
}