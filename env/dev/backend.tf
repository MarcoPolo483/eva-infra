terraform {
  backend "azurerm" {
    resource_group_name  = "rg-evada2"
    storage_account_name = "evatfstate123456"
    container_name       = "tfstate"
    key                  = "eva-infra-dev.tfstate"
  }
}