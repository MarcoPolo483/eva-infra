config {
  module = false
}

plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "azurerm_resource_group_location" {
  enabled = true
}

rule "azurerm_unused_variable" {
  enabled = true
}
