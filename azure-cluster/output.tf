output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "virtual_network_name" {
  value = azurerm_virtual_network.fiaplab_network.name
}

output "subnet_name" {
  value = azurerm_subnet.fiaplab_subnet.name
}

output "linux_virtual_machine_names" {
  value = [for s in azurerm_linux_virtual_machine.clusterfiaplab_vm : s.name[*]]
}

output "dns_externo" {
  value = [for ip in azurerm_public_ip.fiaplab_public_ip : ip.fqdn]
}

output "ip_externo" {
  #value = azurerm_linux_virtual_machine.fiaplab_vm.public_ip_address
  value = [for s in azurerm_linux_virtual_machine.clusterfiaplab_vm : s.public_ip_address[*]]
}

output "private_key_pem" {
  value     = azapi_resource_action.ssh_public_key_gen.output.privateKey
  sensitive = true
}
