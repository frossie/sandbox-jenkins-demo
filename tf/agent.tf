module "agent" {
  source = "./modules/agent"

  name                = "agent"
  k8s_namespace       = "${kubernetes_namespace.jenkins.metadata.0.name}"
  agent_storage_class = "${local.k8s_storage_class}"
  agent_volume_size   = "${var.jenkins_agent_volume_size}"
  agent_user          = "${local.jenkins_agent_user}"
  agent_pass          = "${local.jenkins_agent_pass}"
  master_url          = "https://${local.master_alias}"
  agent_replicas      = "${var.jenkins_agent_replicas}"
  agent_labels        = ["docker"]
  agent_executors     = "${var.jenkins_agent_executors}"
  env_name            = "${var.env_name}"
}
