module "my_vpc" {
  source = "git::https://github.com/kapetndev/terraform-google-compute.git?ref=v0.1.0"
  name   = "my-vpc"
}
