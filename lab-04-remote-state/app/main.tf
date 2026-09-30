# A small resource so the app has something to track in state
resource "azurerm_resource_group" "app" {
  name     = "rg-tflab04-app-uks"
  location = "uksouth"

  tags = {
    environment = "lab"
    project     = "terraform-azure-labs"
    managed_by  = "terraform"
    owner       = "iM-MQ"
    lock_test   = "true"
  }
}