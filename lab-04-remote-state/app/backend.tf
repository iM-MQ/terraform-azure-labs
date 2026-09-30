terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-uks"
    storage_account_name = "sttfstate6791if"
    container_name       = "tfstate"
    key                  = "lab04-app.tfstate"
  }
}