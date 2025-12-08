variable "name_prefix" { type = string }
variable "location"    { type = string }

resource "azurerm_resource_group" "rg" {
  name     = "${var.name_prefix}-rg-net"
  location = var.location
}

output "rg_name" { value = azurerm_resource_group.rg.name }