terraform {
  backend "azurerm" {
    resource_group_name  = "eva-infra-tfstate-rg"
    storage_account_name = "evainfratfstate"
    container_name       = "tfstate"
    key                  = "eva-infra-dev.tfstate"
  }
}
