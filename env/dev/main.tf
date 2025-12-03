module "networking" {
  source      = "../../modules/networking"
  name_prefix = var.name_prefix
  location    = var.location
}

# Placeholder outputs - modules not yet implemented
# module "key_vault" - To be added
# module "monitoring" - To be added  
# module "cosmos_db" - To be added
