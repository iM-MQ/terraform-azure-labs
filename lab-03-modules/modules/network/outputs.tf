output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.this.address_space
}

output "subnet_ids" {
  description = "IDs of the web and app subnets"
  value = {
    web = azurerm_subnet.web.id
    app = azurerm_subnet.app.id
  }
}

output "nsg_names" {
  description = "Names of the web and app NSGs"
  value = {
    web = azurerm_network_security_group.web.name
    app = azurerm_network_security_group.app.name
  }
}