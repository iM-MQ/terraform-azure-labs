# Random ending for names that must be unique across Azure
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Resource group for the whole application
resource "azurerm_resource_group" "app" {
  name     = "rg-tflab05-uks"
  location = var.location
  tags     = var.tags
}