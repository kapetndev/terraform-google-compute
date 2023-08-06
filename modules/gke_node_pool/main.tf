resource "random_id" "node_pool_name" {
  byte_length = 4
  prefix      = "${var.name}-"
}

resource "google_container_node_pool" "container_optimised_node_pool" {
  name    = random_id.node_pool_name.hex
  project = var.project_id
  cluster = var.cluster

  # Depending on the value location either places all nodes in a single zone
  # (zonal) or spread them across the zones within a single region (regional).
  location = var.location

  # Overrides the cluster setting on a per-node-pool basis.
  max_pods_per_node = var.max_pods_per_node

  # The min and max number of nodes (per-zone) to scale to.
  dynamic "autoscaling" {
    for_each = var.autoscaling != null ? [""] : []

    content {
      min_node_count = var.autoscaling.min_node_count
      max_node_count = var.autoscaling.max_node_count
    }
  }

  # Fix broken nodes automatically and keep them updated with the control
  # plane. Setting auto_upgrade to true (default) requires operators to pay
  # extra attention to the release notes of the cluster's version to ensure
  # that the cluster and its nodes are kept up to date and do not break any
  # applications running on the cluster.
  dynamic "management" {
    for_each = var.management != null ? [""] : []

    content {
      auto_repair  = var.management.auto_repair
      auto_upgrade = var.management.auto_upgrade
    }
  }

  node_config {
    disk_size_gb = var.node_config.disk_size
    disk_type    = var.node_config.disk_type
    image_type   = var.node_config.image_type
    labels       = var.node_config.labels
    machine_type = var.node_config.machine_type

    metadata = merge({
      # Explicitly remove GCE legacy metadata API endpoint to prevent most SSRF
      # bugs in apps running on pods inside the cluster from giving attackers a
      # path to pull the GKE metadata/bootstrapping credentials.
      disable-legacy-endpoints = "true"

      # Set metadata on the VM to supply more entropy.
      google-compute-enable-virtio-rng = "true"
    }, var.node_config.metadata)

    # Use the default/minimal oauth scopes to help restrict the permissions to
    # only those needed for GCR and stackdriver logging/monitoring/tracing
    # needs.
    oauth_scopes = setunion([
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ], var.node_config.oauth_scopes)

    # Configure shielded instance options. The options below are deliberately
    # not configurable as they are provided as a minimum baseline for security.
    shielded_instance_config {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
    }
  }

  dynamic "upgrade_settings" {
    for_each = var.upgrade_settings != null ? [""] : []

    content {
      max_surge       = var.upgrade_settings.max_surge
      max_unavailable = var.upgrade_settings.max_unavailable
    }
  }
}
