# Networking Module

Terraform module for EVA 2.0 Azure networking infrastructure.

## Resources Created

- **Resource Group**: Networking resources container
- **Virtual Network**: Hub VNet with configurable address space
- **Subnets**: 4 subnets (app, data, mgmt, pe)
- **Network Security Groups**: 3 NSGs with deny-all baseline
- **Private DNS Zones**: 4 zones for Azure services (Key Vault, Blob Storage, Cosmos DB, Search)
- **DNS Zone Links**: VNet associations for private DNS resolution

## Usage

```hcl
module "networking" {
  source = "../../modules/networking"

  name_prefix        = "eva-dev-cac"
  location           = "canadacentral"
  vnet_address_space = ["10.0.0.0/16"]

  tags = {
    environment = "dev"
    project     = "eva"
    owner       = "marco.presta@example.com"
    cost-center = "IT-AI-001"
    managed-by  = "terraform"
  }
}
```

## Inputs

| Name               | Type         | Default          | Description                                |
| ------------------ | ------------ | ---------------- | ------------------------------------------ |
| name_prefix        | string       | -                | Naming prefix (project-environment-region) |
| location           | string       | -                | Azure region                               |
| vnet_address_space | list(string) | ["10.0.0.0/16"]  | VNet address space                         |
| tags               | map(string)  | {}               | Tags for all resources                     |

## Outputs

| Name                 | Description                           |
| -------------------- | ------------------------------------- |
| rg_name              | Resource group name                   |
| rg_id                | Resource group ID                     |
| vnet_id              | Virtual network ID                    |
| vnet_name            | Virtual network name                  |
| subnet_ids           | Map of subnet keys to IDs             |
| subnet_names         | Map of subnet keys to names           |
| nsg_ids              | Map of NSG names to IDs               |
| private_dns_zone_ids | Map of private DNS zone names to IDs  |

## Subnet Layout

| Subnet Name         | Address Prefix | Purpose                          |
| ------------------- | -------------- | -------------------------------- |
| snet-app-*          | 10.0.1.0/24    | Application tier (App Service)   |
| snet-data-*         | 10.0.2.0/24    | Data tier (Cosmos DB, Storage)   |
| snet-mgmt-*         | 10.0.3.0/24    | Management (Key Vault, Monitor)  |
| snet-pe-*           | 10.0.4.0/24    | Private endpoints                |

## Network Security

### Default NSG Rules
- **Baseline**: Deny all inbound traffic (priority 4096)
- **Customization**: Add specific allow rules as needed in environment composition

### Private DNS Zones
- `privatelink.vaultcore.azure.net` - Azure Key Vault
- `privatelink.blob.core.windows.net` - Azure Blob Storage
- `privatelink.documents.azure.com` - Azure Cosmos DB
- `privatelink.search.windows.net` - Azure Cognitive Search

## Example: Adding Allow Rules

```hcl
# In env/dev/main.tf after calling networking module

resource "azurerm_network_security_rule" "allow_https_inbound" {
  name                        = "AllowHTTPSInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = module.networking.rg_name
  network_security_group_name = "nsg-app-eva-dev-cac"
}
```

## Terraform Validation

```powershell
# Format check
terraform fmt -check

# Validate configuration
terraform validate

# Plan (no deployment)
terraform plan
```

## References

- [Azure VNet Documentation](https://learn.microsoft.com/azure/virtual-network/)
- [Azure NSG Best Practices](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Private Endpoint DNS](https://learn.microsoft.com/azure/private-link/private-endpoint-dns)
- [EVA Naming Conventions](../../docs/naming-conventions.md)

---

**Module Version**: 1.0.0  
**Last Updated**: November 19, 2025  
**Maintainer**: EVA Infrastructure Team
