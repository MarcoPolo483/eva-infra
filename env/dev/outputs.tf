output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.networking.vnet_id
}

output "private_subnet_id" {
  description = "Private Subnet ID"
  value       = module.networking.private_subnet_id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = module.networking.public_subnet_id
}

# Outputs for not-yet-implemented modules commented out
# output "key_vault_id" - module.key_vault
# output "monitoring" - module.monitoring
# output "cosmos_db" - module.cosmos_db
