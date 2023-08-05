data "google_compute_image" "instance_image" {
  name = "ubuntu-1804-bionic-v20200414"
}

data "google_compute_subnetwork" "europe_west2" {
  name   = "default"
  region = "europe-west2"
}

module "instance" {
  source   = "git::https://github.com/kapetndev/terraform-google-compute.git//modules/gce_instance?ref=v0.1.0"
  hostname = "app.c.my-project.internal"
  name     = "my-instance"
  zone     = "europe-west2-a"

  boot_disk = {
    initialize_params = {
      image = data.google_compute_image.instance_image.self_link
    }
  }

  network_interfaces = [
    { subnetwork = data.google_compute_subnetwork.europe_west2.self_link },
  ]

  tags = [
    "https-server",
    "ssh-server",
  ]
}
