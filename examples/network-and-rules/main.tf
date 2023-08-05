locals {
  network_name = "my-vpc"
}

module "my_vpc" {
  source = "git::https://github.com/kapetndev/terraform-google-compute.git?ref=v0.1.0"
  name   = local.network_name

  subnets = [
    {
      name          = local.network_name
      description   = "VPC subnetwork in the Hong Kong region"
      ip_cidr_range = "10.170.0.0/20"
      region        = "asia-east2"

      log_config = {
        aggregation_interval = "INTERVAL_10_MIN"
      }
    },
    {
      name          = local.network_name
      description   = "VPC subnetwork in the London region"
      ip_cidr_range = "10.154.0.0/20"
      region        = "europe-west2"

      log_config = {
        aggregation_interval = "INTERVAL_10_MIN"
      }

      secondary_ip_ranges = [
        {
          range_name    = "gke-cluster-pods"
          ip_cidr_range = "10.132.0.0/14"
        },
        {
          range_name    = "gke-cluster-services"
          ip_cidr_range = "10.0.0.0/20"
        },
      ]
    },
  ]

  private_service_connect_ranges = {
    "servicenetworking-googleapis-com" : "10.124.0.0"
  }
}

module "firewall_rules" {
  source  = "git::https://github.com/kapetndev/terraform-google-compute.git//modules/firewall_rules?ref=v0.1.0"
  network = module.my_vpc.name

  # Allow HTTP, HTTPS, and SSH from anywhere.
  default_rules = {
    http_ranges  = ["0.0.0.0/0"]
    https_ranges = ["0.0.0.0/0"]
    ssh_ranges   = ["0.0.0.0/0"]
  }

  egress_rules = {
    "my-vpc-deny-smtp" = {
      ports         = ["25"]
      source_ranges = ["10.170.0.0/20"]
    }
  }

  ingress_rules = {
    "my-vpc-allow-ftp" = {
      allow       = true
      ports       = ["21"]
      target_tags = ["ftp-server"]
    }
    "my-vpc-deny-remote-desktop" = {
      ports              = ["3389"]
      destination_ranges = ["0.0.0.0/0"]
    }
  }
}
