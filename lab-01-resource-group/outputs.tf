output "resource_group_name" {
  description = "The name of the resource group created"
  value       = azurerm_resource_group.lab.name
}

output "resource_group_location" {
  description = "The region the resource group is in"
  value       = azurerm_resource_group.lab.location
}
