output "app_url" {
  description = "Public web address of the Asset Register"
  value       = "https://${azurerm_container_app.web.ingress[0].fqdn}"
}

output "database_server" {
  description = "PostgreSQL server address"
  value       = azurerm_postgresql_flexible_server.db.fqdn
}

output "resource_group_name" {
  description = "Resource group holding the application"
  value       = azurerm_resource_group.app.name
}
