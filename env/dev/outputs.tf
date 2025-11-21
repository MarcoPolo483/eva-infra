# EVA 2.0 Development Environment Outputs

# Networking Outputs
output "vnet_id" {
  description = "Virtual network ID"
  value       = module.networking.vnet_id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = module.networking.private_subnet_id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.networking.public_subnet_id
}

# Key Vault Outputs
output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = module.key_vault.key_vault_id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.key_vault.key_vault_name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.key_vault_uri
}

output "managed_identity_id" {
  description = "User-assigned managed identity ID"
  value       = module.key_vault.managed_identity_id
}

output "managed_identity_client_id" {
  description = "User-assigned managed identity client ID"
  value       = module.key_vault.managed_identity_client_id
}

# Monitoring Outputs
output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = module.monitoring.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  value       = module.monitoring.log_analytics_workspace_name
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = module.monitoring.application_insights_instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.monitoring.application_insights_connection_string
  sensitive   = true
}

# Cosmos DB Outputs
output "cosmos_account_id" {
  description = "Cosmos DB account resource ID"
  value       = module.cosmos_db.cosmos_account_id
}

output "cosmos_account_name" {
  description = "Cosmos DB account name"
  value       = module.cosmos_db.cosmos_account_name
}

output "cosmos_endpoint" {
  description = "Cosmos DB account endpoint URL"
  value       = module.cosmos_db.cosmos_endpoint
}

output "cosmos_database_name" {
  description = "Cosmos DB database name"
  value       = module.cosmos_db.database_name
}

output "cosmos_containers" {
  description = "Cosmos DB container configurations"
  value       = module.cosmos_db.containers
}

output "cosmos_client_configuration" {
  description = "Configuration for Cosmos DB clients"
  value       = module.cosmos_db.client_configuration
}

# Environment Configuration for Applications
output "eva_environment_config" {
  description = "Complete environment configuration for EVA applications"
  value = {
    # Basic Configuration
    environment         = var.environment
    location           = var.location
    resource_group_name = var.resource_group_name
    
    # Authentication & Security
    key_vault_url = module.key_vault.key_vault_uri
    managed_identity_client_id = module.key_vault.managed_identity_client_id
    is_secure_mode = var.is_secure_mode
    
    # Cosmos DB
    cosmos_endpoint = module.cosmos_db.cosmos_endpoint
    cosmos_database_name = module.cosmos_db.database_name
    cosmos_containers = module.cosmos_db.containers
    
    # Monitoring
    log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
    application_insights_connection_string = module.monitoring.application_insights_connection_string
    
    # Networking
    vnet_id = module.networking.vnet_id
    private_subnet_id = module.networking.private_subnet_id
  }
  sensitive = true
}
