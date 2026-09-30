# Values used in more than one place
locals {
  location = "uksouth"

  common_tags = {
    project    = "terraform-azure-labs"
    managed_by = "terraform"
    owner      = "iM-MQ"
  }
}

# Resource group for both networks
resource "azurerm_resource_group" "lab" {
  name     = "rg-tflab03-uks"
  location = local.location
  tags     = local.common_tags
}

# Dev network, built from the module
module "network_dev" {
  source = "./modules/network"

  name_prefix         = "dev"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.20.0.0/16"]
  web_subnet_prefix   = "10.20.1.0/24"
  app_subnet_prefix   = "10.20.2.0/24"
  tags                = merge(local.common_tags, { environment = "dev" })
}

# Test network, built from the same module
module "network_test" {
  source = "./modules/network"

  name_prefix         = "test"
  location            = local.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.30.0.0/16"]
  web_subnet_prefix   = "10.30.1.0/24"
  app_subnet_prefix   = "10.30.2.0/24"
  tags                = merge(local.common_tags, { environment = "test" })
}