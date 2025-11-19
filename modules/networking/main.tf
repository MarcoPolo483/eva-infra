variable "name_prefix" {
  description = "Naming prefix (project-environment-region), e.g., eva-dev-cac"
  type        = string
}

variable "location" {
  description = "Azure region, e.g., canadacentral"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "tags" {
  description = "Tags to apply to all networking resources"
  type        = map(string)
  default     = {}
}

# Locals for consistent naming
locals {
  rg_name   = "rg-${var.name_prefix}-net"
  vnet_name = "vnet-${var.name_prefix}-001"

  subnets = {
    app = {
      name           = "snet-app-${var.name_prefix}"
      address_prefix = ["10.0.1.0/24"]
    }
    data = {
      name           = "snet-data-${var.name_prefix}"
      address_prefix = ["10.0.2.0/24"]
    }
    mgmt = {
      name           = "snet-mgmt-${var.name_prefix}"
      address_prefix = ["10.0.3.0/24"]
    }
    pe = {
      name           = "snet-pe-${var.name_prefix}"
      address_prefix = ["10.0.4.0/24"]
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "subnets" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefix
}

# Network Security Groups
resource "azurerm_network_security_group" "nsg_app" {
  name                = "nsg-app-${var.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  # Deny all inbound by default (baseline security)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_data" {
  name                = "nsg-data-${var.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_mgmt" {
  name                = "nsg-mgmt-${var.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG Associations
resource "azurerm_subnet_network_security_group_association" "nsg_assoc_app" {
  subnet_id                 = azurerm_subnet.subnets["app"].id
  network_security_group_id = azurerm_network_security_group.nsg_app.id
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc_data" {
  subnet_id                 = azurerm_subnet.subnets["data"].id
  network_security_group_id = azurerm_network_security_group.nsg_data.id
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc_mgmt" {
  subnet_id                 = azurerm_subnet.subnets["mgmt"].id
  network_security_group_id = azurerm_network_security_group.nsg_mgmt.id
}

# Private DNS Zones for Azure Services
resource "azurerm_private_dns_zone" "pdns_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "pdns_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "pdns_cosmos" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "pdns_search" {
  name                = "privatelink.search.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# Link DNS Zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "pdns_vault_link" {
  name                  = "pdns-vault-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns_vault.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "pdns_blob_link" {
  name                  = "pdns-blob-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns_blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "pdns_cosmos_link" {
  name                  = "pdns-cosmos-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns_cosmos.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "pdns_search_link" {
  name                  = "pdns-search-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns_search.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

# Outputs
output "rg_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.rg.name
}

output "rg_id" {
  description = "Resource group ID"
  value       = azurerm_resource_group.rg.id
}

output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.vnet.name
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value = {
    for k, v in azurerm_subnet.subnets : k => v.id
  }
}

output "subnet_names" {
  description = "Map of subnet keys to names"
  value = {
    for k, v in azurerm_subnet.subnets : k => v.name
  }
}

output "nsg_ids" {
  description = "Map of NSG names to IDs"
  value = {
    app  = azurerm_network_security_group.nsg_app.id
    data = azurerm_network_security_group.nsg_data.id
    mgmt = azurerm_network_security_group.nsg_mgmt.id
  }
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone names to IDs"
  value = {
    vault  = azurerm_private_dns_zone.pdns_vault.id
    blob   = azurerm_private_dns_zone.pdns_blob.id
    cosmos = azurerm_private_dns_zone.pdns_cosmos.id
    search = azurerm_private_dns_zone.pdns_search.id
  }
}