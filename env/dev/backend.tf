terraform {
  backend "azurerm" {
    resource_group_name  = "rg-eva-tfstate-cac"
    storage_account_name = "stevatfstatecac"
    container_name       = "tfstate"
    key                  = "eva-dev.terraform.tfstate"
    
    # Use Azure CLI authentication (RBAC)
    # No need for access keys - more secure
    use_azuread_auth     = true
  }
}