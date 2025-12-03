# Azure Cosmos DB Module for EVA 2.0 Enterprise Platform
# Implements advanced AI-optimized Cosmos DB with vector search and HPK

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0"
    }
  }
}

locals {
  cosmos_name = "${var.name_prefix}-cosmos-${var.environment}"
  tags = merge(var.tags, {
    Module      = "cosmos-db"
    Environment = var.environment
    Purpose     = "eva-ai-platform"
  })
}

# Cosmos DB Account with vector search and AI optimizations
resource "azurerm_cosmosdb_account" "eva_cosmos" {
  name                = local.cosmos_name
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  # Consistency policy optimized for AI workloads
  consistency_policy {
    consistency_level       = var.consistency_level
    max_interval_in_seconds = var.max_interval_in_seconds
    max_staleness_prefix    = var.max_staleness_prefix
  }

  # Geo-replication configuration
  geo_location {
    location          = var.location
    failover_priority = 0
  }

  dynamic "geo_location" {
    for_each = var.additional_geo_locations
    content {
      location          = geo_location.value.location
      failover_priority = geo_location.value.failover_priority
    }
  }

  # AI and vector search capabilities
  capabilities {
    name = "EnableServerless"
  }

  capabilities {
    name = "EnableNoSQLVectorSearch"
  }

  # Advanced security settings
  public_network_access_enabled         = !var.is_secure_mode
  network_acl_bypass_for_azure_services = true

  dynamic "ip_range_filter" {
    for_each = var.allowed_ip_ranges
    content {
      ip_range_filter = ip_range_filter.value
    }
  }

  # Backup configuration
  backup {
    type                = "Periodic"
    interval_in_minutes = var.backup_interval_minutes
    retention_in_hours  = var.backup_retention_hours
    storage_redundancy  = var.backup_storage_redundancy
  }

  tags = local.tags
}

# Main EVA database for all collections
resource "azurerm_cosmosdb_sql_database" "eva_main_db" {
  name                = "eva-platform"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.eva_cosmos.name

  # Shared throughput for cost optimization
  dynamic "autoscale_settings" {
    for_each = var.enable_autoscale ? [1] : []
    content {
      max_throughput = var.max_throughput_ru
    }
  }
}

# Document processing container with vector search
resource "azurerm_cosmosdb_sql_container" "documents" {
  name                = "documents"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.eva_cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.eva_main_db.name

  # Hierarchical Partition Key for tenant isolation
  partition_key_paths = ["/tenantId", "/documentType"]

  # Vector indexing policy for AI search
  indexing_policy {
    indexing_mode = "consistent"

    # Include paths for efficient queries
    included_path {
      path = "/*"
    }

    # Exclude large vectors from automatic indexing
    excluded_path {
      path = "/embedding/*"
    }
    excluded_path {
      path = "/content_vectors/*"
    }

    # Spatial indexes for location-based queries
    dynamic "spatial_index" {
      for_each = var.enable_spatial_indexing ? [1] : []
      content {
        path  = "/location/*"
        types = ["Point", "Polygon"]
      }
    }

    # Composite indexes for common query patterns
    composite_index {
      index {
        path  = "/tenantId"
        order = "ascending"
      }
      index {
        path  = "/documentType"
        order = "ascending"
      }
      index {
        path  = "/created_at"
        order = "descending"
      }
    }

    composite_index {
      index {
        path  = "/tenantId"
        order = "ascending"
      }
      index {
        path  = "/status"
        order = "ascending"
      }
      index {
        path  = "/updated_at"
        order = "descending"
      }
    }
  }

  # Vector embedding configuration
  dynamic "vector_embedding_policy" {
    for_each = var.enable_vector_search ? [1] : []
    content {
      vector_embedding {
        path              = "/content_vector"
        data_type         = "float32"
        dimensions        = var.vector_dimensions
        distance_function = var.vector_distance_function
      }
      vector_embedding {
        path              = "/title_vector"
        data_type         = "float32"
        dimensions        = var.vector_dimensions
        distance_function = var.vector_distance_function
      }
    }
  }

  # Time-to-live for document lifecycle
  default_ttl = var.document_ttl_seconds

  # Unique key constraints
  unique_key {
    paths = ["/tenantId", "/file_path"]
  }
}

# Conversation and chat history container
resource "azurerm_cosmosdb_sql_container" "conversations" {
  name                = "conversations"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.eva_cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.eva_main_db.name

  partition_key_paths = ["/tenantId", "/userId"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/message_vectors/*"
    }

    composite_index {
      index {
        path  = "/tenantId"
        order = "ascending"
      }
      index {
        path  = "/userId"
        order = "ascending"
      }
      index {
        path  = "/created_at"
        order = "descending"
      }
    }
  }

  # Vector embeddings for semantic conversation search
  dynamic "vector_embedding_policy" {
    for_each = var.enable_vector_search ? [1] : []
    content {
      vector_embedding {
        path              = "/message_vector"
        data_type         = "float32"
        dimensions        = var.vector_dimensions
        distance_function = var.vector_distance_function
      }
    }
  }

  # Conversation retention policy
  default_ttl = var.conversation_ttl_seconds

  unique_key {
    paths = ["/conversation_id"]
  }
}

# User profiles and preferences container
resource "azurerm_cosmosdb_sql_container" "user_profiles" {
  name                = "user_profiles"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.eva_cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.eva_main_db.name

  partition_key_paths = ["/tenantId"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    composite_index {
      index {
        path  = "/tenantId"
        order = "ascending"
      }
      index {
        path  = "/role"
        order = "ascending"
      }
      index {
        path  = "/last_activity"
        order = "descending"
      }
    }
  }

  unique_key {
    paths = ["/user_id"]
  }
}

# Analytics and metrics container
resource "azurerm_cosmosdb_sql_container" "analytics" {
  name                = "analytics"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.eva_cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.eva_main_db.name

  partition_key_paths = ["/tenantId", "/metric_type"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    composite_index {
      index {
        path  = "/tenantId"
        order = "ascending"
      }
      index {
        path  = "/metric_type"
        order = "ascending"
      }
      index {
        path  = "/timestamp"
        order = "descending"
      }
    }
  }

  # Analytics data retention (1 year)
  default_ttl = 31536000
}

# Vector search indexes (requires REST API calls after deployment)
resource "azapi_resource" "vector_search_index" {
  count     = var.enable_vector_search ? 1 : 0
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/vectorIndex@2024-05-15"
  name      = "content-vector-index"
  parent_id = azurerm_cosmosdb_sql_container.documents.id

  body = jsonencode({
    properties = {
      vectorIndexes = [
        {
          path = "/content_vector"
          type = "quantizedFlat"
        },
        {
          path = "/title_vector"
          type = "quantizedFlat"
        }
      ]
    }
  })

  depends_on = [azurerm_cosmosdb_sql_container.documents]
}

# Private endpoint for secure access
resource "azurerm_private_endpoint" "cosmos_pe" {
  count               = var.is_secure_mode ? 1 : 0
  name                = "${local.cosmos_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${local.cosmos_name}-psc"
    private_connection_resource_id = azurerm_cosmosdb_account.eva_cosmos.id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name                 = "cosmos-dns-zone-group"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  tags = local.tags
}

# Diagnostic settings for monitoring
resource "azurerm_monitor_diagnostic_setting" "cosmos_diag" {
  count                      = var.log_analytics_workspace_id != null ? 1 : 0
  name                       = "${local.cosmos_name}-diag"
  target_resource_id         = azurerm_cosmosdb_account.eva_cosmos.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Data plane logs
  enabled_log {
    category = "DataPlaneRequests"
  }

  enabled_log {
    category = "MongoRequests"
  }

  enabled_log {
    category = "QueryRuntimeStatistics"
  }

  enabled_log {
    category = "PartitionKeyStatistics"
  }

  enabled_log {
    category = "PartitionKeyRUConsumption"
  }

  enabled_log {
    category = "ControlPlaneRequests"
  } # Metrics
  metric {
    category = "Requests"
  }

  metric {
    category = "AllMetrics"
  }
}

# RBAC assignments for managed identities
resource "azurerm_role_assignment" "cosmos_data_contributor" {
  count                = length(var.managed_identity_principal_ids)
  scope                = azurerm_cosmosdb_account.eva_cosmos.id
  role_definition_name = "Cosmos DB Built-in Data Contributor"
  principal_id         = var.managed_identity_principal_ids[count.index]
}

# Key Vault secrets for connection strings (if Key Vault provided)
resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  count        = var.key_vault_id != null ? 1 : 0
  name         = "${local.cosmos_name}-endpoint"
  value        = azurerm_cosmosdb_account.eva_cosmos.endpoint
  key_vault_id = var.key_vault_id
  tags         = local.tags
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  count        = var.key_vault_id != null ? 1 : 0
  name         = "${local.cosmos_name}-key"
  value        = azurerm_cosmosdb_account.eva_cosmos.primary_key
  key_vault_id = var.key_vault_id
  tags         = local.tags
}

resource "azurerm_key_vault_secret" "cosmos_connection_string" {
  count        = var.key_vault_id != null ? 1 : 0
  name         = "${local.cosmos_name}-connection-string"
  value        = azurerm_cosmosdb_account.eva_cosmos.connection_strings[0]
  key_vault_id = var.key_vault_id
  tags         = local.tags
}
