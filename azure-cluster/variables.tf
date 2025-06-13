variable "quantidade" {
  type        = number
  default     = 3
  description = "Quantidade de VMs a serem criadas. Há limites de CPUs nas regiões listadas em resource_group_locations."
}

variable "resource_group_locations" {
  type        = list(string)
  description = "Lista de regiões da Azure onde os recursos serão criados"
  default     = [
    #"southcentralus",
    "westus"
    "eastus2",
    "westus2"
  ]
}

variable "shutdown" {
  description = "Horário diário para desligar a VM no formato HHMM (ex: 0300 para 03h da manhã)"
  type        = string
  default     = "0300"
}

variable "vm_size" {
  description = "Tipo de instância"
  type        = string
  default     = "Standard_B2s"
  #default     = "Standard_D2s_v6"
}

variable "vm_name" {
  description = "Nome base da máquina virtual"
  type        = string
  default     = "fiap-vm-k8s"
}

variable "resource_group_name_prefix" {
  description = "Prefixo para o nome do grupo de recursos"
  type        = string
  default     = "fiapcluster"
}

variable "vnet_name" {
  description = "Nome base da rede virtual"
  type        = string
  default     = "clusterlab-vnet"
}

variable "subnet_name" {
  description = "Nome base da sub-rede"
  type        = string
  default     = "clusterlab-subnet"
}

variable "public_ip_name" {
  description = "Nome base do IP público"
  type        = string
  default     = "clusterlab-public-ip"
}

variable "nsg_name" {
  description = "Nome base do Network Security Group"
  type        = string
  default     = "clusterlab-nsg"
}

variable "nic_name" {
  description = "Nome base da interface de rede"
  type        = string
  default     = "clusterlab-nic"
}

variable "storage_account_prefix" {
  description = "Prefixo para o nome da conta de armazenamento"
  type        = string
  default     = "clusterlabdiag"
}

variable "username" {
  description = "Nome de usuário para a VM"
  type        = string
  default     = "ubuntu"
}

variable "senha" {
  description = "Senha do usuário administrador da VM"
  type        = string
  default     = "P@ssword1234!"
  sensitive   = true
}
