variable "aws_zone_id" {
  description = "route53 Hosted Zone ID to manage DNS records in."
}

# note that the production name is `jenkins-prod` for backwards compatiblity
variable "env_name" {
  description = "Name of deployment environment."
}

variable "service_name" {
  description = "service / unqualifed hostname"
  default     = "ci"
}

variable "domain_name" {
  description = "DNS domain name to use when creating route53 records."
}

variable "group_name" {
  description = "select group specific configuration."
}

variable "master_fqdn" {
  description = "FQDN jenkins will respond to. If empty (default), it is generated from the env_name, service_name, and domain_name. This is useful to configure jenkins to respond to a DNS alias."
  default     = ""
}

variable "worker_instance_type" {
  default = "c5.2xlarge"
}

variable "worker_root_volume_size" {
  default = "100"
}

variable "jenkins_agent_volume_size" {
  description = "Persistent volume for agent -- must include a unit postfix. Eg., Gi."
}

variable "jenkins_agent_user" {
  description = "username to access jenkins master."
}

variable "jenkins_agent_pass" {
  description = "password to access jenkins master."
}

variable "jenkins_agent_replicas" {
  description = "number of jenkins agents to create."
}

variable "jenkins_agent_executors" {
  description = "number of executors per agent."
  default     = "1"
}

variable "tls_crt_path" {
  description = "wildcard tls certificate."
}

variable "tls_key_path" {
  description = "wildcard tls private key."
}

variable "dns_enable" {
  description = "create route53 dns records."
  default     = false
}

variable "prometheus_github_org" {
  description = "limit access to prometheus dashboard to members of this org"
}

variable "prometheus_client_id" {
  description = "github oauth client id"
}

variable "prometheus_client_secret" {
  description = "github oauth client secret"
}

data "vault_generic_secret" "grafana_oauth" {
  path = "${local.vault_root}/grafana_oauth"
}

variable "grafana_oauth_client_id" {
  description = "github oauth Client ID for grafana"
  default     = ""
}

variable "grafana_oauth_client_secret" {
  description = "github oauth Client Secret for grafana."
  default     = ""
}

variable "grafana_oauth_team_ids" {
  description = "github team id (integer value treated as string)"
  default     = "1936535"
}

resource "random_string" "grafana_admin_pass" {
  length = 20

  keepers = {
    host = "${module.eks.cluster_endpoint}"
  }
}

locals {
  # remove "<env>-" prefix for production
  dns_prefix = "${replace("${var.env_name}-", "jenkins-prod-", "")}"

  master_fqdn  = "${local.dns_prefix}${var.service_name}.${var.domain_name}"
  master_alias = "${var.master_fqdn != "" ? var.master_fqdn : local.master_fqdn}"

  k8s_cluster_name = "${var.service_name}-${var.env_name}"

  dns_suffix                       = "${local.master_fqdn}"
  tiller_k8s_namespace             = "tiller"
  nginx_ingress_k8s_namespace      = "nginx-ingress"
  prometheus_k8s_namespace         = "monitoring"
  metrics_server_k8s_namespace     = "metrics-server"
  cluster_autoscaler_k8s_namespace = "cluster-autoscaler"
  tls_crt                          = "${file(var.tls_crt_path)}"
  tls_key                          = "${file(var.tls_key_path)}"

  vault_root = "secret/dm/square/jenkins/${var.env_name}"

  grafana_oauth               = "${data.vault_generic_secret.grafana_oauth.data}"
  grafana_oauth_client_id     = "${var.grafana_oauth_client_id != "" ? var.grafana_oauth_client_id : local.grafana_oauth["client_id"]}"
  grafana_oauth_client_secret = "${var.grafana_oauth_client_secret != "" ? var.grafana_oauth_client_secret : local.grafana_oauth["client_secret"]}"

  grafana_admin_pass = "${random_string.grafana_admin_pass.result}"
  grafana_admin_user = "admin"
}
