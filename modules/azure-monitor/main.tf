terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Variables
variable "name_prefix" {
  description = "Prefix for naming resources (e.g., eva-dev)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for monitoring resources"
  type        = string
}

variable "retention_in_days" {
  description = "Log Analytics workspace retention period (days)"
  type        = number
  default     = 30
}

variable "action_group_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID for diagnostic settings (optional)"
  type        = string
  default     = null
}

variable "vnet_id" {
  description = "Virtual Network resource ID for diagnostic settings (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Locals
locals {
  law_name     = "law-${var.name_prefix}-001"
  appi_name    = "appi-${var.name_prefix}-001"
  ag_name      = "ag-${var.name_prefix}-alerts-001"
  alert_prefix = "alert-${var.name_prefix}"
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = local.law_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = local.appi_name
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = var.tags
}

# Action Group for Alerts
resource "azurerm_monitor_action_group" "main" {
  name                = local.ag_name
  resource_group_name = var.resource_group_name
  short_name          = "eva-alerts"

  email_receiver {
    name          = "platform-team"
    email_address = var.action_group_email
  }

  tags = var.tags
}

# Diagnostic Settings for Key Vault (if provided)
resource "azurerm_monitor_diagnostic_setting" "kv" {
  count                      = var.key_vault_id != null ? 1 : 0
  name                       = "diag-kv-to-law"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for Virtual Network (if provided)
resource "azurerm_monitor_diagnostic_setting" "vnet" {
  count                      = var.vnet_id != null ? 1 : 0
  name                       = "diag-vnet-to-law"
  target_resource_id         = var.vnet_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "VMProtectionAlerts"
  }

  metric {
    category = "AllMetrics"
  }
}

# Alert: Key Vault Access Failures
resource "azurerm_monitor_metric_alert" "kv_access_failures" {
  count               = var.key_vault_id != null ? 1 : 0
  name                = "${local.alert_prefix}-kv-access-failures"
  resource_group_name = var.resource_group_name
  scopes              = [var.key_vault_id]
  description         = "Alert when Key Vault access failures exceed threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.KeyVault/vaults"
    metric_name      = "ServiceApiResult"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5

    dimension {
      name     = "StatusCode"
      operator = "Include"
      values   = ["403", "429"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = var.tags
}

# Alert: High NSG Deny Rate
# Note: NSG flow logs would need to be configured separately for detailed metrics
# This is a placeholder for demonstrating alert structure
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "nsg_deny_rate" {
  count                = var.vnet_id != null ? 1 : 0
  name                 = "${local.alert_prefix}-nsg-deny-rate"
  resource_group_name  = var.resource_group_name
  location             = var.location
  scopes               = [azurerm_log_analytics_workspace.main.id]
  description          = "Alert on high NSG deny rate indicating potential attack"
  severity             = 3
  window_duration      = "PT15M"
  evaluation_frequency = "PT5M"

  criteria {
    query = <<-QUERY
      AzureNetworkAnalytics_CL
      | where SubType_s == "FlowLog" and FlowStatus_s == "D"
      | summarize DenyCount = count() by bin(TimeGenerated, 5m)
      | where DenyCount > 100
    QUERY

    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }

  tags = var.tags
}

# Outputs
output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_workspace_id" {
  description = "Log Analytics workspace ID (GUID for ingestion)"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "log_analytics_primary_shared_key" {
  description = "Log Analytics workspace primary shared key"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "application_insights_id" {
  description = "Application Insights resource ID"
  value       = azurerm_application_insights.main.id
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "action_group_id" {
  description = "Action group resource ID"
  value       = azurerm_monitor_action_group.main.id
}
