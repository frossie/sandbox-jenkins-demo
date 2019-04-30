locals {
  agent_fsroot     = "/j"
  docker_host_name = "localhost"
  docker_host_port = "2375"
  docker_tuple     = "${local.docker_host_name}:${local.docker_host_port}"
  docker_host      = "tcp://${local.docker_tuple}"
  jmx_host         = "localhost"
  jmx_port         = "8080"
  jmx_tuple        = "${local.jmx_host}:${local.jmx_port}"
  app_version      = "1.0.0"
}

resource "kubernetes_secret" "jenkins_agent" {
  metadata {
    namespace = "${var.k8s_namespace}"
    name      = "${var.name}"

    labels {
      "app.kubernetes.io/name"       = "${var.name}"
      "app.kubernetes.io/instance"   = "${var.env_name}"
      "app.kubernetes.io/version"    = "${local.app_version}"
      "app.kubernetes.io/component"  = "agent"
      "app.kubernetes.io/part-of"    = "jenkins"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data {
    JSWARM_USERNAME = "${var.agent_user}"
    JSWARM_PASSWORD = "${var.agent_pass}"
  }
}

# headless service required by statefulset
resource "kubernetes_service" "jenkins_agent" {
  metadata {
    namespace = "${var.k8s_namespace}"
    name      = "${var.name}"

    labels {
      "app.kubernetes.io/name"       = "${var.name}"
      "app.kubernetes.io/instance"   = "${var.env_name}"
      "app.kubernetes.io/version"    = "${local.app_version}"
      "app.kubernetes.io/component"  = "agent"
      "app.kubernetes.io/part-of"    = "jenkins"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    selector {
      "app.kubernetes.io/name"      = "${var.name}"
      "app.kubernetes.io/instance"  = "${var.env_name}"
      "app.kubernetes.io/version"   = "${local.app_version}"
      "app.kubernetes.io/component" = "agent"
      "app.kubernetes.io/part-of"   = "jenkins"
    }

    cluster_ip = "None"
  }
}

resource "kubernetes_stateful_set" "jenkins_agent" {
  metadata {
    namespace = "${var.k8s_namespace}"
    name      = "${var.name}"

    labels {
      "app.kubernetes.io/name"       = "${var.name}"
      "app.kubernetes.io/instance"   = "${var.env_name}"
      "app.kubernetes.io/version"    = "${local.app_version}"
      "app.kubernetes.io/component"  = "agent"
      "app.kubernetes.io/part-of"    = "jenkins"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    pod_management_policy  = "Parallel"
    replicas               = "${var.agent_replicas}"
    revision_history_limit = 10

    selector {
      match_labels {
        "app.kubernetes.io/name"      = "${var.name}"
        "app.kubernetes.io/instance"  = "${var.env_name}"
        "app.kubernetes.io/version"   = "${local.app_version}"
        "app.kubernetes.io/component" = "agent"
        "app.kubernetes.io/part-of"   = "jenkins"
      }
    }

    service_name = "${kubernetes_service.jenkins_agent.metadata.0.name}"

    update_strategy {
      type = "RollingUpdate"

      #rolling_update {
      #  max_surge       = "${ceil(var.replicas * 1.5)}"
      #  max_unavailable = "${floor(var.replicas * 0.5)}"
      #}
    }

    template {
      metadata {
        labels {
          "app.kubernetes.io/name"       = "${var.name}"
          "app.kubernetes.io/instance"   = "${var.env_name}"
          "app.kubernetes.io/version"    = "${local.app_version}"
          "app.kubernetes.io/component"  = "agent"
          "app.kubernetes.io/part-of"    = "jenkins"
          "app.kubernetes.io/managed-by" = "terraform"
        }
      }

      spec {
        security_context {
          run_as_user = "${var.agent_uid}"
          fs_group    = "${var.agent_gid}"

          # k8s 1.14+
          #run_as_group = "${var.agent_gid}"
        }

        container {
          name              = "dind"
          image             = "${var.dind_image}"
          image_pull_policy = "Always"
          command           = ["/usr/local/bin/dockerd"]
          args              = ["--host=${local.docker_host}"]

          security_context {
            privileged = true
          }

          env {
            name  = "DOCKER_HOST"
            value = "${local.docker_host}"
          }

          volume_mount {
            name       = "docker-graph-storage"
            mount_path = "/var/lib/docker"
          }

          volume_mount {
            name       = "ws"
            mount_path = "${local.agent_fsroot}"
          }

          resources {
            limits {
              cpu    = "8"
              memory = "12Gi"
            }

            requests {
              cpu    = "6"
              memory = "12Gi"
            }
          }

          liveness_probe {
            exec {
              command = [
                "wget",
                "--spider",
                "-q",
                "http://${local.docker_tuple}/_ping",
              ]
            }

            initial_delay_seconds = "5"
            timeout_seconds       = "1"
            period_seconds        = "5"
            failure_threshold     = "2"
          }

          readiness_probe {
            exec {
              command = [
                "wget",
                "--spider",
                "-q",
                "http://${local.docker_tuple}/_ping",
              ]
            }

            initial_delay_seconds = "5"
            timeout_seconds       = "1"
            period_seconds        = "5"
            failure_threshold     = "2"
          }
        } # container

        container {
          name              = "swarm"
          image             = "${var.swarm_image}"
          image_pull_policy = "Always"

          liveness_probe {
            exec {
              command = [
                "wget",
                "--spider",
                "-q",
                "http://${local.jmx_tuple}/metrics",
              ]
            }

            initial_delay_seconds = "5"
            timeout_seconds       = "1"
            period_seconds        = "5"
            failure_threshold     = "2"
          }

          readiness_probe {
            exec {
              command = [
                "wget",
                "--spider",
                "-q",
                "http://${local.jmx_tuple}/metrics",
              ]
            }

            initial_delay_seconds = "5"
            timeout_seconds       = "1"
            period_seconds        = "5"
            failure_threshold     = "2"
          }

          resources {
            limits {
              cpu    = "2"
              memory = "3Gi"
            }

            requests {
              cpu    = "1"
              memory = "2Gi"
            }
          }

          env = [
            {
              name  = "DOCKER_HOST"
              value = "${local.docker_host}"
            },
            {
              name  = "JSWARM_MASTER_URL"
              value = "${var.master_url}"
            },
            {
              name  = "JSWARM_MODE"
              value = "${var.agent_mode}"
            },
            {
              name  = "JSWARM_LABELS"
              value = "${join(" ", var.agent_labels)}"
            },
            {
              name  = "JSWARM_EXECUTORS"
              value = "${var.agent_executors}"
            },
            {
              name = "JSWARM_AGENT_NAME"

              value_from {
                field_ref {
                  field_path = "metadata.name"
                }
              }
            },
            {
              name  = "JSWARM_DISABLE_CLIENTS_UNIQUE_ID"
              value = "true"
            },
            {
              name  = "JSWARM_DELETE_EXISTING_CLIENTS"
              value = "true"
            },
            {
              name = "JSWARM_USERNAME"

              value_from {
                secret_key_ref {
                  name = "${kubernetes_secret.jenkins_agent.metadata.0.name}"
                  key  = "JSWARM_USERNAME"
                }
              }
            },
            {
              name = "JSWARM_PASSWORD"

              value_from {
                secret_key_ref {
                  name = "${kubernetes_secret.jenkins_agent.metadata.0.name}"
                  key  = "JSWARM_PASSWORD"
                }
              }
            },
          ]

          volume_mount {
            name       = "ws"
            mount_path = "${local.agent_fsroot}"
          }
        } # container

        init_container {
          name              = "mount-chown"
          image             = "alpine:3.9"
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c", "chown ${var.agent_uid}:${var.agent_gid} ${local.agent_fsroot} && chmod 6700 ${local.agent_fsroot}"]

          volume_mount {
            name       = "ws"
            mount_path = "${local.agent_fsroot}"
          }

          security_context {
            run_as_user = "0"
          }
        }

        volume {
          name      = "docker-graph-storage"
          empty_dir = {}
        }
      } # spec
    } # template

    volume_claim_template {
      metadata {
        name = "ws"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "${var.agent_storage_class}"

        resources {
          requests {
            storage = "${var.agent_volume_size}"
          }
        }
      }
    }
  } # spec
}
