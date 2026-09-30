output "resource_group_name" {
  description = "Resource group holding both networks"
  value       = azurerm_resource_group.lab.name
}

output "dev_network" {
  description = "Summary of the dev network"
  value = {
    vnet          = module.network_dev.vnet_name
    address_space = module.network_dev.address_space
    nsgs          = module.network_dev.nsg_names
  }
}

output "test_network" {
  description = "Summary of the test network"
  value = {
    vnet          = module.network_test.vnet_name
    address_space = module.network_test.address_space
    nsgs          = module.network_test.nsg_names
  }
}