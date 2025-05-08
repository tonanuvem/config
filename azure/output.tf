output "vm_public_ip" {
  value = azurerm_linux_virtual_machine.vm.public_ip_address
  description = "Endereço IP público da VM (se configurado)"
}
