# Random ending so the storage account name is unique across Azure
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Resource group for Terraform state
resource "azurerm_resource_group" "state" {
  name     = "rg-tfstate-uks"
  location = "uksouth"

  tags = {
    project    = "terraform-azure-labs"
    managed_by = "terraform"
    purpose    = "terraform-state"
  }
}

# Storage account to hold the state files
resource "azurerm_storage_account" "state" {
  name                            = "sttfstate${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = azurerm_resource_group.state.tags
}

# Private container inside the storage account
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
