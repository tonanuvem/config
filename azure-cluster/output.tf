output "resource_group_name" {
  value = [for rg in azurerm_resource_group.rg : rg.name]
}

output "virtual_network_name" {
  value = [for vnet in azurerm_virtual_network.fiaplab_network : vnet.name]
}

output "subnet_name" {
  value = [for subnet in azurerm_subnet.fiaplab_subnet : subnet.name]
}

output "linux_virtual_machine_names" {
  value = [for vm in azurerm_linux_virtual_machine.clusterfiaplab_vm : vm.name]
}

output "dns_externo" {
  value = [for ip in azurerm_public_ip.fiaplab_public_ip : ip.fqdn]
}

output "ip_externo" {
  value = [for vm in azurerm_linux_virtual_machine.clusterfiaplab_vm : vm.public_ip_address]
}

output "private_key_pem" {
  value     = azapi_resource_action.ssh_public_key_gen.output.privateKey
  sensitive = true
}

# Outputs adicionais para melhor organização
output "resource_group_locations" {
  value = [for rg in azurerm_resource_group.rg : rg.location]
}

output "complete_infrastructure_info" {
  value = {
    for i in range(var.quantidade) : 
    "region_${i}" => {
      resource_group_name = azurerm_resource_group.rg[i].name
      location           = azurerm_resource_group.rg[i].location
      virtual_network    = azurerm_virtual_network.fiaplab_network[i].name
      subnet            = azurerm_subnet.fiaplab_subnet[i].name
      vm_name           = azurerm_linux_virtual_machine.clusterfiaplab_vm[i].name
      public_ip         = azurerm_linux_virtual_machine.clusterfiaplab_vm[i].public_ip_address
      fqdn              = azurerm_public_ip.fiaplab_public_ip[i].fqdn
    }
  }
}
