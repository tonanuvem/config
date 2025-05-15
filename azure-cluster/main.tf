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
  name     = "fiap"
  location = var.resource_group_location
}

# Create virtual network
resource "azurerm_virtual_network" "fiaplab_network" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "fiaplab_subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.fiaplab_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

#resource "azurerm_public_ip" "test" {
#  name                = "publicIPForLB"
#  location            = azurerm_resource_group.rg.location
#  resource_group_name = azurerm_resource_group.rg.name
#  allocation_method   = "Static"
#}

#resource "azurerm_lb" "test" {
#  name                = "loadBalancer"
#  location            = azurerm_resource_group.rg.location
#  resource_group_name = azurerm_resource_group.rg.name

#  frontend_ip_configuration {
#    name                 = "publicIPAddress"
#    public_ip_address_id = azurerm_public_ip.test.id
#  }
#}

#resource "azurerm_lb_backend_address_pool" "test" {
#  loadbalancer_id = azurerm_lb.test.id
#  name            = "BackEndAddressPool"
#}

# Create public IPs
resource "azurerm_public_ip" "fiaplab_public_ip" {
  count               = var.quantidade
  name                = "var.public_ip_name${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "fiaplab_nsg" {
  name                = var.nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

# Create network interface
resource "azurerm_network_interface" "fiaplab_nic" {
  count               = var.quantidade
  name                = "clusternic${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "clusterfiaplab_nic_configuration"
    subnet_id                     = azurerm_subnet.fiaplab_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.fiaplab_public_ip[count.index].id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "fiaplab_sg_association" {
  network_interface_id      = azurerm_network_interface.fiaplab_nic.id
  network_security_group_id = azurerm_network_security_group.fiaplab_nsg.id
}

resource "azurerm_availability_set" "avset" {
  name                         = "avset"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_linux_virtual_machine" "clusterfiaplab_vm" {
  count                 = var.quantidade
  name                  = "var.vm_name${count.index}"
  location              = azurerm_resource_group.rg.location
  availability_set_id   = azurerm_availability_set.avset.id
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.fiaplab_nic[count.index].id]
  size                  = var.vm_size

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

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
    name                 = "myosdisk${count.index}"
  }

  computer_name  = "var.vm_name${count.index}"
  admin_username = var.username
}

resource "azurerm_managed_disk" "fiaplab_disk" {
  count                = var.quantidade
  name                 = "datadisk_existing_${count.index}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
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
