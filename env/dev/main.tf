module "networking" {
  source      = "../modules/networking"
  name_prefix = var.name_prefix
  location    = var.location
}