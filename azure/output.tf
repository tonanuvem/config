output "dns_externo" {
  value = azurerm_public_ip.my_terraform_public_ip.fqdn
}

output "ip_externo" {
  value = azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address
}
