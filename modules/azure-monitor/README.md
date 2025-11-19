# Azure Monitor Module

This module creates a centralized observability stack for EVA 2.0, including Log Analytics workspace, Application Insights, diagnostic settings, and baseline alerts.

## Features

- **Log Analytics Workspace**: Centralized log aggregation with configurable retention
- **Application Insights**: APM for web apps and APIs (workspace-based)
- **Diagnostic Settings**: Auto-configure logging for Key Vault and VNet
- **Action Group**: Email notifications for platform alerts
- **Baseline Alerts**: Key Vault access failures, NSG deny rate

## Resources Created

- `azurerm_log_analytics_workspace` - Log aggregation (PerGB2018 SKU)
- `azurerm_application_insights` - Application performance monitoring
- `azurerm_monitor_action_group` - Alert notification channel
- `azurerm_monitor_diagnostic_setting` - Key Vault and VNet logging
- `azurerm_monitor_metric_alert` - Key Vault access failure alert
- `azurerm_monitor_scheduled_query_rules_alert_v2` - NSG deny rate alert

## Usage

```hcl
module "azure_monitor" {
  source = "../../modules/azure-monitor"

  name_prefix           = "eva-dev"
  location              = "canadacentral"
  resource_group_name   = module.networking.rg_name
  retention_in_days     = 30
  action_group_email    = "platform-team@example.com"
  key_vault_id          = module.key_vault.key_vault_id
  vnet_id               = module.networking.vnet_id

  tags = {
    environment = "dev"
    project     = "eva"
    owner       = "platform-team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name_prefix` | Prefix for naming (e.g., eva-dev) | string | - | yes |
| `location` | Azure region | string | - | yes |
| `resource_group_name` | Resource group name | string | - | yes |
| `retention_in_days` | Log Analytics retention period | number | 30 | no |
| `action_group_email` | Email for alert notifications | string | - | yes |
| `key_vault_id` | Key Vault resource ID (optional) | string | null | no |
| `vnet_id` | Virtual Network resource ID (optional) | string | null | no |
| `tags` | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| `log_analytics_workspace_id` | Log Analytics workspace resource ID |
| `log_analytics_workspace_name` | Log Analytics workspace name |
| `log_analytics_workspace_workspace_id` | Workspace ID (GUID for ingestion API) |
| `log_analytics_primary_shared_key` | Workspace shared key (sensitive) |
| `application_insights_id` | Application Insights resource ID |
| `application_insights_instrumentation_key` | Instrumentation key (sensitive) |
| `application_insights_connection_string` | Connection string (sensitive) |
| `action_group_id` | Action group resource ID |

## Baseline Alerts

### Key Vault Access Failures
- **Severity**: 2 (Warning)
- **Threshold**: >5 failures (403/429 status codes) in 15 minutes
- **Frequency**: Check every 5 minutes
- **Action**: Email notification to action group

### NSG Deny Rate
- **Severity**: 3 (Informational)
- **Threshold**: >100 denied flows per 5-minute window
- **Frequency**: Check every 5 minutes
- **Action**: Email notification to action group
- **Note**: Requires NSG flow logs configured separately

## Diagnostic Settings

When `key_vault_id` and `vnet_id` are provided, the module automatically configures:

**Key Vault**:
- `AuditEvent` logs (all secret/key/certificate access)
- `AzurePolicyEvaluationDetails` logs
- `AllMetrics` metrics

**Virtual Network**:
- `VMProtectionAlerts` logs
- `AllMetrics` metrics

## Example: Query Logs

```bash
# Install Azure CLI Log Analytics extension
az extension add --name log-analytics

# Query Key Vault audit logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where ResourceType == 'VAULTS' | take 10"

# Query Application Insights traces
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AppTraces | where TimeGenerated > ago(1h) | take 10"
```

## Example: Add Custom Alert

```hcl
# Alert on high API latency
resource "azurerm_monitor_metric_alert" "api_latency" {
  name                = "alert-eva-dev-api-latency"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when API P95 latency exceeds 300ms"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 300
  }

  action {
    action_group_id = module.azure_monitor.action_group_id
  }
}
```

## Validation

```bash
# Format and validate
terraform fmt
terraform validate

# Plan with dev environment
terraform -chdir=env/dev plan -out=plan.tfplan

# Query workspace after deployment
az monitor log-analytics workspace show \
  --resource-group rg-eva-dev-net \
  --workspace-name law-eva-dev-001
```

## References

- [Azure Monitor Best Practices](https://learn.microsoft.com/azure/azure-monitor/best-practices)
- [Log Analytics Workspace Design](https://learn.microsoft.com/azure/azure-monitor/logs/workspace-design)
- [Application Insights Overview](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Alert Rules](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-overview)
- [EVA Naming Conventions](../../docs/naming-conventions.md)
