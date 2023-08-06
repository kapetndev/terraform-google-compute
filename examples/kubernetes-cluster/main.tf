locals {
  network = "my-vpc"
}

data "google_compute_network" "my_vpc" {
  name = local.network
}

data "google_compute_subnetwork" "my_vpc_europe_west2" {
  name   = local.network
  region = "europe-west2"
}

module "kubernetes_cluster" {
  source                        = "git::https://github.com/kapetndev/terraform-google-compute.git//modules/gke_cluster?ref = v0.1.0"
  cluster_secondary_range_name  = "gke-cluster-pods"
  kubernetes_version            = "1.24.12-gke.500"
  location                      = data.google_compute_subnetwork.my_vpc_europe_west2.region
  name                          = "my-cluster"
  network                       = data.google_compute_network.my_vpc.id
  services_secondary_range_name = "gke-cluster-services"
  subnetwork                    = data.google_compute_subnetwork.my_vpc_europe_west2.id
}

module "kubernetes_cluster_node_pool_production" {
  source    = "git::https://github.com/kapetndev/terraform-google-compute.git//modules/gke_node_pool?ref=v0.1.0"
  cluster   = module.kubernetes_cluster.name
  location  = module.kubernetes_cluster.location
  pool_name = "my-pool"
}
