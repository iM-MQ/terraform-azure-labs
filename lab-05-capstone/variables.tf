variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "uksouth"
}

variable "container_image" {
  description = "Asset Register image, pinned to a specific commit"
  type        = string
  default     = "ghcr.io/im-mq/docker-asset-register:208975d0a077290193b93a11e3fedc5ac4d8088a"
}

variable "db_name" {
  description = "Name of the application database"
  type        = string
  default     = "assets"
}

variable "db_admin_username" {
  description = "Administrator username for the PostgreSQL server"
  type        = string
  default     = "assetadmin"
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