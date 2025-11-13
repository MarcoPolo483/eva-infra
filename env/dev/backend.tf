terraform {
  backend "azurerm" {
    resource_group_name  = "REPLACE-RG"
    storage_account_name = "replacestorageacct"
    container_name       = "tfstate"
    key                  = "eva-infra-dev.tfstate"
  }
}