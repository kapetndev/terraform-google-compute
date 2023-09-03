locals {
  attached_disks = {
    for disk in var.attached_disks :
    disk.name => disk
  }
}

resource "google_compute_disk" "persistent_disks" {
  for_each    = local.attached_disks
  name        = each.value.name
  description = each.value.description
  project     = var.project_id
  zone        = var.zone
  size        = each.value.size
  image       = each.value.source_type == "image" ? each.value.source : null
  snapshot    = each.value.source_type == "snapshot" ? each.value.source : null
  type        = each.value.options.type

  labels = merge(var.labels, {
    disk_name = each.value.name,
    disk_type = each.value.options.type,
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_instance" "instance" {
  name           = var.name
  description    = var.description
  desired_status = var.running ? "RUNNING" : "TERMINATED"
  project        = var.project_id
  zone           = var.zone
  labels         = var.labels
  metadata       = var.metadata
  hostname       = var.hostname
  machine_type   = var.machine_type
  tags           = var.tags

  # In order to make changes to the service account the instance needs to be in
  # a terminated state. This allows Terraform to stop the instance before
  # applying changes.
  allow_stopping_for_update = true

  dynamic "attached_disk" {
    for_each = local.attached_disks

    content {
      device_name = coalesce(attached_disk.value.device_name, attached_disk.value.name)
      mode        = attached_disk.value.options.mode
      source = (
        attached_disk.value.source_type == "attach"
        ? attached_disk.value.source
        : google_compute_disk.persistent_disks[attached_disk.key].name
      )
    }
  }

  boot_disk {
    auto_delete = var.boot_disk.auto_delete
    source      = var.boot_disk.source

    initialize_params {
      image = var.boot_disk.initialization_params.image
      size  = var.boot_disk.initialization_params.size
      type  = var.boot_disk.initialization_params.type
    }
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces

    content {
      network    = network_interface.value.network
      subnetwork = network_interface.value.subnetwork
      network_ip = network_interface.value.internal_address

      dynamic "access_config" {
        for_each = network_interface.value.external_access ? [""] : []

        content {
          nat_ip = network_interface.value.nat_address
        }
      }
    }
  }

  service_account {
    scopes = setunion([
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ], var.oauth_scopes)
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
  }
}
