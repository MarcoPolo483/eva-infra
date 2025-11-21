# Output Values for EVA Cosmos DB Module

output "cosmos_account_id" {
  description = "Cosmos DB account resource ID"
  value       = azurerm_cosmosdb_account.eva_cosmos.id
}

output "cosmos_account_name" {
  description = "Cosmos DB account name"
  value       = azurerm_cosmosdb_account.eva_cosmos.name
}

output "cosmos_endpoint" {
  description = "Cosmos DB account endpoint URL"
  value       = azurerm_cosmosdb_account.eva_cosmos.endpoint
}

output "cosmos_primary_key" {
  description = "Cosmos DB account primary key"
  value       = azurerm_cosmosdb_account.eva_cosmos.primary_key
  sensitive   = true
}

output "cosmos_secondary_key" {
  description = "Cosmos DB account secondary key"
  value       = azurerm_cosmosdb_account.eva_cosmos.secondary_key
  sensitive   = true
}

output "cosmos_connection_strings" {
  description = "Cosmos DB account connection strings"
  value       = azurerm_cosmosdb_account.eva_cosmos.connection_strings
  sensitive   = true
}

output "database_name" {
  description = "Main EVA database name"
  value       = azurerm_cosmosdb_sql_database.eva_main_db.name
}

output "containers" {
  description = "Container names and configurations"
  value = {
    documents = {
      name              = azurerm_cosmosdb_sql_container.documents.name
      partition_keys    = azurerm_cosmosdb_sql_container.documents.partition_key_paths
      vector_enabled    = var.enable_vector_search
    }
    conversations = {
      name              = azurerm_cosmosdb_sql_container.conversations.name
      partition_keys    = azurerm_cosmosdb_sql_container.conversations.partition_key_paths
      vector_enabled    = var.enable_vector_search
    }
    user_profiles = {
      name              = azurerm_cosmosdb_sql_container.user_profiles.name
      partition_keys    = azurerm_cosmosdb_sql_container.user_profiles.partition_key_paths
      vector_enabled    = false
    }
    analytics = {
      name              = azurerm_cosmosdb_sql_container.analytics.name
      partition_keys    = azurerm_cosmosdb_sql_container.analytics.partition_key_paths
      vector_enabled    = false
    }
  }
}

output "private_endpoint_id" {
  description = "Private endpoint resource ID (if created)"
  value       = var.is_secure_mode ? azurerm_private_endpoint.cosmos_pe[0].id : null
}

output "private_endpoint_ip" {
  description = "Private endpoint IP address (if created)"
  value       = var.is_secure_mode ? azurerm_private_endpoint.cosmos_pe[0].private_service_connection[0].private_ip_address : null
}

# Key Vault secret references (if Key Vault integration enabled)
output "key_vault_secrets" {
  description = "Key Vault secret references for connection strings"
  value = var.key_vault_id != null ? {
    endpoint_secret_id         = azurerm_key_vault_secret.cosmos_endpoint[0].id
    key_secret_id             = azurerm_key_vault_secret.cosmos_key[0].id
    connection_string_secret_id = azurerm_key_vault_secret.cosmos_connection_string[0].id
  } : null
}

# Configuration for client SDKs
output "client_configuration" {
  description = "Configuration values for Cosmos DB client SDKs"
  value = {
    endpoint                = azurerm_cosmosdb_account.eva_cosmos.endpoint
    database_name          = azurerm_cosmosdb_sql_database.eva_main_db.name
    consistency_level      = var.consistency_level
    vector_search_enabled  = var.enable_vector_search
    vector_dimensions      = var.vector_dimensions
    containers = {
      documents      = "documents"
      conversations  = "conversations"
      user_profiles  = "user_profiles"
      analytics      = "analytics"
    }
    partition_keys = {
      documents      = ["/tenantId", "/documentType"]
      conversations  = ["/tenantId", "/userId"]
      user_profiles  = ["/tenantId"]
      analytics      = ["/tenantId", "/metric_type"]
    }
  }
}

# Monitoring configuration
output "monitoring" {
  description = "Monitoring and diagnostic configuration"
  value = {
    diagnostic_setting_id = var.log_analytics_workspace_id != null ? azurerm_monitor_diagnostic_setting.cosmos_diag[0].id : null
    metrics_enabled      = true
    log_categories = [
      "DataPlaneRequests",
      "MongoRequests", 
      "QueryRuntimeStatistics",
      "PartitionKeyStatistics",
      "PartitionKeyRUConsumption",
      "ControlPlaneRequests"
    ]
  }
}
