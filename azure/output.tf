output "dns_externo" {
  value = azurerm_public_ip.fiaplab_public_ip.fqdn
}

output "ip_externo" {
  value = azurerm_linux_virtual_machine.fiaplab_vm.public_ip_address
}

output "private_key_pem" {
  value     = azapi_resource_action.ssh_public_key_gen.output.privateKey
  sensitive = true
}
