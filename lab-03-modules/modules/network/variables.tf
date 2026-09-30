variable "name_prefix" {
  description = "Short name for this network, used in resource names (e.g. dev, test)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.name_prefix))
    error_message = "name_prefix must be 2 to 10 lowercase letters or numbers, e.g. dev or test."
  }
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to put the network in"
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.address_space : can(cidrnetmask(cidr))])
    error_message = "Every address_space entry must be a valid CIDR range, e.g. 10.20.0.0/16."
  }
}

variable "web_subnet_prefix" {
  description = "Address range for the web subnet"
  type        = string
}

variable "app_subnet_prefix" {
  description = "Address range for the app subnet"
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
