terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-uks"
    storage_account_name = "sttfstatei3llx4"
    container_name       = "tfstate"
    key                  = "lab05-capstone.tfstate"
  }
}