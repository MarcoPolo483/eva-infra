# Terraform State Management Configuration

This document describes the remote state backend configuration for EVA 2.0 infrastructure.

## Backend: Azure Storage

Terraform state is stored in Azure Storage Account with the following configuration:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-eva-tfstate-cac"
    storage_account_name = "stevatfstatecac"
    container_name       = "tfstate"
    key                  = "eva-dev.terraform.tfstate"
  }
}
```

## Prerequisites

Before running `terraform init`, ensure:

1. **Azure Storage Account exists**: `stevatfstatecac`
   - Resource Group: `rg-eva-tfstate-cac`
   - Location: Canada Central
   - Redundancy: LRS (Locally Redundant Storage)
   - Versioning: Enabled
   - Soft Delete: Enabled (90-day retention)

2. **Blob Container exists**: `tfstate`
   - Public access: Disabled (private)

3. **Azure CLI authenticated**:
   ```powershell
   az login
   az account set --subscription "<subscription-id>"
   ```

4. **RBAC permissions** on storage account:
   - `Storage Blob Data Contributor` (minimum)

## Initialize Remote State

```powershell
cd env/dev
terraform init
```

## State Locking

Azure Storage uses **lease-based locking** automatically:
- Lock timeout: 20 minutes
- Force unlock (emergency only):
  ```powershell
  terraform force-unlock <lock-id>
  ```

## State Encryption

- **At Rest**: Azure Storage encryption (Microsoft-managed keys)
- **In Transit**: HTTPS only (enforced by storage account policy)

## Backup & Recovery

### Automatic Versioning
- Enabled on blob container
- Retains previous versions for 90 days
- Access via Azure Portal or Azure CLI

### Manual Backup (Before Major Changes)
```powershell
# Download current state
az storage blob download \
  --account-name stevatfstatecac \
  --container-name tfstate \
  --name eva-dev.terraform.tfstate \
  --file backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').tfstate
```

### Restore from Backup
```powershell
# Upload backup to restore
az storage blob upload \
  --account-name stevatfstatecac \
  --container-name tfstate \
  --name eva-dev.terraform.tfstate \
  --file backup-20251119-153000.tfstate \
  --overwrite
```

## Troubleshooting

### Error: "Failed to get existing workspaces"
**Cause**: Authentication failure or missing permissions  
**Fix**:
```powershell
az login
az account set --subscription "<subscription-id>"
```

### Error: "Error locking state: state blob is already locked"
**Cause**: Previous operation didn't complete (crash, timeout)  
**Fix**:
1. Wait 20 minutes for automatic lock release
2. OR force unlock (use with caution):
   ```powershell
   terraform force-unlock <lock-id>
   ```

### Error: "container does not exist"
**Cause**: Blob container not created  
**Fix**:
```powershell
az storage container create \
  --name tfstate \
  --account-name stevatfstatecac \
  --auth-mode login
```

## Security Best Practices

1. **Never commit state files** to git (`.tfstate` files are in `.gitignore`)
2. **Use RBAC** instead of storage account keys
3. **Enable soft delete** for accidental deletion protection
4. **Audit access** via Azure Monitor diagnostic logs
5. **Separate state files** per environment (dev, stg, prd)

## State File Naming Convention

```
<project>-<environment>.terraform.tfstate
```

Examples:
- `eva-dev.terraform.tfstate`
- `eva-stg.terraform.tfstate`
- `eva-prd.terraform.tfstate`

## Migration (If Needed)

To migrate from local to remote state:

```powershell
# 1. Configure backend in backend.tf
# 2. Run terraform init with -migrate-state flag
terraform init -migrate-state

# 3. Verify migration
terraform state list
```

## References

- [Azure Backend Documentation](https://www.terraform.io/language/settings/backends/azurerm)
- [State Locking](https://www.terraform.io/language/state/locking)
- [Azure Storage Best Practices](https://learn.microsoft.com/azure/storage/common/storage-best-practices)
