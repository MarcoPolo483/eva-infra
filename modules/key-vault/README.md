# Key Vault Module

This module creates an Azure Key Vault with private endpoint connectivity, RBAC authorization, and diagnostic logging.

## Features

- **Private Endpoint**: Zero public exposure, accessed via private DNS zone
- **RBAC Authorization**: Azure AD-based access control (no access policies)
- **Soft Delete**: 90-day retention with purge protection enabled
- **Audit Logging**: Diagnostic settings send audit logs to Log Analytics
- **Network Security**: Default deny with Azure Services bypass

## Resources Created

- `azurerm_key_vault` - Key Vault instance (Standard SKU)
- `azurerm_private_endpoint` - Private endpoint for VNet connectivity
- `azurerm_monitor_diagnostic_setting` - Audit and metrics logging
- `azurerm_role_assignment` - Key Vault Administrator role for deploying principal

## Usage

```hcl
module "key_vault" {
  source = "../../modules/key-vault"

  name_prefix                = "eva-dev"
  location                   = "canadacentral"
  resource_group_name        = module.networking.rg_name
  subnet_id                  = module.networking.subnet_ids["pe"]
  private_dns_zone_id        = module.networking.private_dns_zone_ids["vault"]
  log_analytics_workspace_id = module.azure_monitor.log_analytics_workspace_id
  tenant_id                  = data.azurerm_client_config.current.tenant_id

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
| `subnet_id` | Subnet ID for private endpoint | string | - | yes |
| `private_dns_zone_id` | Private DNS zone ID (privatelink.vaultcore.azure.net) | string | - | yes |
| `log_analytics_workspace_id` | Log Analytics workspace ID | string | null | no |
| `tenant_id` | Azure AD tenant ID | string | - | yes |
| `tags` | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| `key_vault_id` | Key Vault resource ID |
| `key_vault_name` | Key Vault name |
| `key_vault_uri` | Key Vault URI (e.g., https://kv-eva-dev-001.vault.azure.net/) |
| `private_endpoint_id` | Private endpoint resource ID |
| `private_endpoint_ip` | Private IP address of the endpoint |

## Security Baseline

### RBAC Roles
- **Key Vault Administrator**: Full control (assigned to deployment principal)
- **Key Vault Secrets User**: Read secrets only (assign to application identities)
- **Key Vault Crypto Officer**: Manage keys and certificates

### Network Access
- Public network access: **Disabled**
- Private endpoint: **Required** (connected to `snet-pe` subnet)
- Network ACLs: Default **Deny**, Azure Services **Bypass**

### Audit Logging
Captured events:
- All secret/key/certificate access (`AuditEvent` log)
- Azure Policy evaluations (`AzurePolicyEvaluationDetails` log)
- Metrics: Request latency, availability, saturation (`AllMetrics`)

## Example: Grant Application Access

```hcl
# Grant eva-api app identity access to secrets
resource "azurerm_role_assignment" "api_secrets" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eva_api.principal_id
}
```

## Validation

```bash
# Format and validate
terraform fmt
terraform validate

# Plan with dev environment
terraform -chdir=env/dev plan -out=plan.tfplan

# Check Key Vault endpoint resolves privately
nslookup kv-eva-dev-001.vault.azure.net
```

## References

- [Azure Key Vault Best Practices](https://learn.microsoft.com/azure/key-vault/general/best-practices)
- [Private Endpoints for Key Vault](https://learn.microsoft.com/azure/key-vault/general/private-link-service)
- [Key Vault RBAC Guide](https://learn.microsoft.com/azure/key-vault/general/rbac-guide)
- [EVA Naming Conventions](../../docs/naming-conventions.md)
