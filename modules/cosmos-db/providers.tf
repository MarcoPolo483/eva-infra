# Terraform Requirements for EVA Cosmos DB Module

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.80.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">=1.9.0"
    }
  }
}

# Data sources for existing resources
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "cosmos_rg" {
  name = var.resource_group_name
}
