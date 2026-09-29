variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-tflab02-uks"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "web_subnet_prefix" {
  description = "Address range for the web subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "app_subnet_prefix" {
  description = "Address range for the app subnet"
  type        = string
  default     = "10.10.2.0/24"
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default = {
    environment = "lab"
    project     = "terraform-azure-labs"
    managed_by  = "terraform"
    owner       = "iM-MQ"
  }
}
