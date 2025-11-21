# Input Variables for EVA Cosmos DB Module

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Cosmos DB Configuration
variable "consistency_level" {
  description = "Cosmos DB consistency level"
  type        = string
  default     = "Session"
  validation {
    condition = contains([
      "BoundedStaleness",
      "Eventual", 
      "Session",
      "Strong",
      "ConsistentPrefix"
    ], var.consistency_level)
    error_message = "Consistency level must be one of: BoundedStaleness, Eventual, Session, Strong, ConsistentPrefix."
  }
}

variable "max_interval_in_seconds" {
  description = "Max lag time for BoundedStaleness consistency"
  type        = number
  default     = 300
}

variable "max_staleness_prefix" {
  description = "Max stale requests for BoundedStaleness consistency"
  type        = number
  default     = 100000
}

variable "additional_geo_locations" {
  description = "Additional geo-replication locations"
  type = list(object({
    location          = string
    failover_priority = number
  }))
  default = []
}

# Security Configuration  
variable "is_secure_mode" {
  description = "Enable private endpoints and enhanced security"
  type        = bool
  default     = false
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access Cosmos DB"
  type        = list(string)
  default     = []
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint (required if is_secure_mode = true)"
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs for private endpoint"
  type        = list(string)
  default     = []
}

# Performance Configuration
variable "enable_autoscale" {
  description = "Enable autoscale for throughput"
  type        = bool
  default     = true
}

variable "max_throughput_ru" {
  description = "Maximum RU/s for autoscale"
  type        = number
  default     = 4000
}

# Vector Search Configuration
variable "enable_vector_search" {
  description = "Enable vector search capabilities"
  type        = bool
  default     = true
}

variable "vector_dimensions" {
  description = "Vector dimensions for embeddings"
  type        = number
  default     = 1536 # OpenAI ada-002 dimensions
}

variable "vector_distance_function" {
  description = "Distance function for vector search"
  type        = string
  default     = "cosine"
  validation {
    condition = contains([
      "cosine",
      "dotproduct", 
      "euclidean"
    ], var.vector_distance_function)
    error_message = "Distance function must be one of: cosine, dotproduct, euclidean."
  }
}

variable "enable_spatial_indexing" {
  description = "Enable spatial indexing for location-based queries"
  type        = bool
  default     = false
}

# Data Retention Configuration
variable "document_ttl_seconds" {
  description = "TTL for documents in seconds (null = no TTL)"
  type        = number
  default     = null
}

variable "conversation_ttl_seconds" {
  description = "TTL for conversations in seconds (default: 90 days)"
  type        = number
  default     = 7776000 # 90 days
}

# Backup Configuration
variable "backup_interval_minutes" {
  description = "Backup interval in minutes"
  type        = number
  default     = 240 # 4 hours
}

variable "backup_retention_hours" {
  description = "Backup retention in hours"
  type        = number
  default     = 720 # 30 days
}

variable "backup_storage_redundancy" {
  description = "Backup storage redundancy"
  type        = string
  default     = "Geo"
  validation {
    condition = contains([
      "Geo",
      "Local",
      "Zone"
    ], var.backup_storage_redundancy)
    error_message = "Backup storage redundancy must be one of: Geo, Local, Zone."
  }
}

# Integration Configuration
variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
  default     = null
}

variable "key_vault_id" {
  description = "Key Vault ID for storing connection strings"
  type        = string
  default     = null
}

variable "managed_identity_principal_ids" {
  description = "Principal IDs of managed identities to grant access"
  type        = list(string)
  default     = []
}
