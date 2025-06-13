terraform {
  required_version = ">=0.12"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  count    = var.quantidade
  name     = "${var.resource_group_name_prefix}-${count.index}"
  location = var.resource_group_locations[count.index]
}

resource "azurerm_virtual_network" "fiaplab_network" {
  count               = var.quantidade
  name                = "${var.vnet_name}-${count.index}"
  address_space       = ["10.${count.index}.0.0/16"]  # Corrigido: usa 10.X.0.0/16
  location            = var.resource_group_locations[count.index]
  resource_group_name = azurerm_resource_group.rg[count.index].name
}

resource "azurerm_subnet" "fiaplab_subnet" {
  count                = var.quantidade
  name                 = "${var.subnet_name}-${count.index}"
  resource_group_name  = azurerm_resource_group.rg[count.index].name
  virtual_network_name = azurerm_virtual_network.fiaplab_network[count.index].name
  address_prefixes     = ["10.${count.index}.0.0/24"]  # Corrigido: usa 10.X.0.0/24
}

resource "azurerm_public_ip" "fiaplab_public_ip" {
  count               = var.quantidade
  name                = "public_ip_${count.index}"
  location            = var.resource_group_locations[count.index]
  resource_group_name = azurerm_resource_group.rg[count.index].name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "fiaplab_nsg" {
  count               = var.quantidade
  name                = "${var.nsg_name}-${count.index}"
  location            = var.resource_group_locations[count.index]
  resource_group_name = azurerm_resource_group.rg[count.index].name

  security_rule {
    name                       = "Liberar_acesso"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "fiaplab_nic" {
  count               = var.quantidade
  name                = "clusternic${count.index}"
  location            = var.resource_group_locations[count.index]
  resource_group_name = azurerm_resource_group.rg[count.index].name

  ip_configuration {
    name                          = "clusterfiaplab_nic_configuration"
    subnet_id                     = azurerm_subnet.fiaplab_subnet[count.index].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.fiaplab_public_ip[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "fiaplab_sg_association" {
  count                     = var.quantidade
  network_interface_id      = azurerm_network_interface.fiaplab_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.fiaplab_nsg[count.index].id
}

resource "azurerm_availability_set" "avset" {
  count                        = var.quantidade
  name                         = "avset-${count.index}"
  location                     = var.resource_group_locations[count.index]
  resource_group_name          = azurerm_resource_group.rg[count.index].name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_linux_virtual_machine" "clusterfiaplab_vm" {
  count                 = var.quantidade
  name                  = "${format("%s_%d_%s", "vm", count.index, var.vm_name)}"
  location              = var.resource_group_locations[count.index]
  availability_set_id   = azurerm_availability_set.avset[count.index].id
  resource_group_name   = azurerm_resource_group.rg[count.index].name
  network_interface_ids = [azurerm_network_interface.fiaplab_nic[count.index].id]
  size                  = var.vm_size

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.username
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "disco_so_${count.index}"
  }

  computer_name  = "${var.vm_name}-${count.index}"
  admin_username = var.username
}

resource "azurerm_managed_disk" "fiaplab_disk" {
  count                = var.quantidade
  name                 = "disco_dados_${count.index}"
  location             = var.resource_group_locations[count.index]
  resource_group_name  = azurerm_resource_group.rg[count.index].name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1024"
}

resource "azurerm_virtual_machine_data_disk_attachment" "fiaplab_disk_att" {
  count              = var.quantidade
  managed_disk_id    = azurerm_managed_disk.fiaplab_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.clusterfiaplab_vm[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "auto_shutdown" {
  count              = var.quantidade
  virtual_machine_id = azurerm_linux_virtual_machine.clusterfiaplab_vm[count.index].id

  location              = var.resource_group_locations[count.index]
  enabled               = true
  daily_recurrence_time = var.shutdown
  timezone              = "E. South America Standard Time"

  notification_settings {
    enabled = false
  }
}
