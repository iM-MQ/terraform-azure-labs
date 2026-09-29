output "resource_group_name" {
  description = "The resource group the network is in"
  value       = azurerm_resource_group.lab.name
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.lab.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.lab.address_space
}

output "subnets" {
  description = "Subnet names and their address ranges"
  value = {
    (azurerm_subnet.web.name) = azurerm_subnet.web.address_prefixes[0]
    (azurerm_subnet.app.name) = azurerm_subnet.app.address_prefixes[0]
  }
}

output "web_nsg_name" {
  description = "NSG attached to the web subnet"
  value       = azurerm_network_security_group.web.name
}
