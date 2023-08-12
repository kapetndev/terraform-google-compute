resource "google_compute_global_address" "private_ip_allocations" {
  for_each      = var.private_service_connect_ranges
  address       = split("/", each.value.address)[0]
  address_type  = "INTERNAL"
  name          = each.key
  network       = google_compute_network.network.id
  prefix_length = split("/", each.value.address)[1]
  project       = var.project_id
  purpose       = "VPC_PEERING"
}

resource "google_service_networking_connection" "service_networking_connection" {
  count   = length(var.private_service_connect_ranges) != 0 ? 1 : 0
  network = google_compute_network.network.id
  service = "servicenetworking.googleapis.com"

  reserved_peering_ranges = [
    for _, addr in google_compute_global_address.private_ip_allocations :
    addr.name
  ]
}
