variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-tflab01-uks"
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "uksouth"
}
