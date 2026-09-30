output "resource_group_name" {
  description = "Resource group holding the state storage account"
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Storage account holding Terraform state"
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Container holding the state files"
  value       = azurerm_storage_container.state.name
}