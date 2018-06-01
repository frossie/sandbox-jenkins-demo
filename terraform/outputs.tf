output "JENKINS_IP" {
  value = "${aws_eip.jenkins-demo-master.public_ip}"
}

output "JENKINS_FQDN" {
  value = "${aws_route53_record.jenkins-demo-master.fqdn}"
}

output "SUBNET_ID" {
  value = "${aws_subnet.jenkins-demo.id}"
}

output "SECURITY_GROUP_ID_SSH" {
  value = "${aws_security_group.jenkins-demo-ssh.id}"
}

output "SECURITY_GROUP_ID_HTTP" {
  value = "${aws_security_group.jenkins-demo-http.id}"
}

output "SECURITY_GROUP_ID_AGENTPORT" {
  value = "${aws_security_group.jenkins-demo-agentport.id}"
}

output "SECURITY_GROUP_ID_INTERNAL" {
  value = "${aws_security_group.jenkins-demo-internal.id}"
}

output "AWS_DEFAULT_REGION" {
  value = "${var.aws_default_region}"
}

output "ENV_NAME" {
  value = "${var.env_name}"
}

output "DOMAIN_NAME" {
  value = "${var.domain_name}"
}
