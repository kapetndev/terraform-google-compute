locals {
  min_master_version = (
    var.kubernetes_version_release_channel != null
    ? data.google_container_engine_versions.supported[0].release_channel_default_version[var.kubernetes_version_release_channel]
    : var.kubernetes_version
  )
}

data "google_container_engine_versions" "supported" {
  count          = var.kubernetes_version_release_channel != null ? 1 : 0
  location       = var.location
  version_prefix = var.kubernetes_version

  # Specify the project in case there is a difference between the project
  # terraform is authenticated with and that of the project the cluster is
  # provisioned.
  project = var.project_id
}

resource "random_id" "cluster_name" {
  byte_length = 4
  prefix      = "${var.name}-"
}

resource "google_container_cluster" "kubernetes_cluster" {
  name            = random_id.cluster_name.hex
  description     = var.description
  resource_labels = var.labels

  # Configures a control plane deployed to either a single zone or region.
  location = var.location

  # Ensure the minimum version of the master. GKE will auto-update the master
  # to new versions, so this does not guarantee the current master version.
  min_master_version = local.min_master_version

  # Set the project, network and subnetwork to those exposed by the respective
  # terraform workspaces. These are managed outside of the terrafrom platform
  # project to separate responsibility.
  project    = var.project_id
  network    = var.network
  subnetwork = var.subnetwork

  # Send all logging and monitoring data to Stackdriver.
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # It is not possible to create a cluster with no node pool defined, but it is
  # desirable to want to only use separately managed node pools. Therefore it
  # is necessary to create the smallest possible default node pool and
  # immediately delete it.
  #
  # This is deliberately not configurable as it is not recommended to use
  # the default node pool.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable intranode visibility to expose pod-to-pod traffic to the VPC for
  # flow logging.
  enable_intranode_visibility = var.enable_intranode_visibility

  # Provide more control over automatic upgrades by specifying a release
  # channel. See
  # https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels
  release_channel {
    channel = var.kubernetes_version_release_channel
  }

  # Configure the cluster addons. The addons listed are all enabled by default
  # when the cluster is created.
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }

    http_load_balancing {
      disabled = false
    }
  }

  # https://cloud.google.com/kubernetes-engine/docs/how-to/alias-ips
  dynamic "ip_allocation_policy" {
    for_each = var.ip_allocation_policy != null ? [""] : []

    content {
      cluster_ipv4_cidr_block       = var.ip_allocation_policy.cluster_ipv4_cidr_block
      cluster_secondary_range_name  = var.ip_allocation_policy.cluster_secondary_range_name
      services_ipv4_cidr_block      = var.ip_allocation_policy.services_ipv4_cidr_block
      services_secondary_range_name = var.ip_allocation_policy.services_secondary_range_name
      stack_type                    = var.ip_allocation_policy.stack_type
    }
  }

  # By default we do not want to issue a client certificate to authenticate to
  # the cluster endpoint. This is because the certificate is not automatically
  # rotated and therefore is a security risk.
  master_auth {
    client_certificate_config {
      issue_client_certificate = var.issue_client_certificate
    }
  }

  dynamic "maintenance_policy" {
    for_each = var.maintenance_policy.recurring_window != null ? [""] : []

    content {
      recurring_window {
        start_time = var.maintenance_policy.recurring_window.start_time
        end_time   = var.maintenance_policy.recurring_window.end_time
        recurrence = var.maintenance_policy.recurring_window.recurrence
      }

      dynamic "maintenance_exclusion" {
        for_each = var.maintenance_policy.exclusions

        content {
          exclusion_name = maintenance_exclusion.value.name
          start_time     = maintenance_exclusion.value.start_time
          end_time       = maintenance_exclusion.value.end_time

          dynamic "exclusion_options" {
            for_each = maintenance_exclusion.value.scope != null ? [""] : []

            content {
              scope = maintenance_exclusion.value.scope
            }
          }
        }
      }
    }
  }

  vertical_pod_autoscaling {
    enabled = var.enable_vertical_pod_autoscaling
  }
}
