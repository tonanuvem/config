variable "vm_size" {
  description = "Tipo de instancia"
  type        = string
  default     = "Standard_B2ms"
  # default     = "Standard_DS1_v2"
}

variable "shutdown" {
  description = "Horário diário para desligar a VM no formato HHMM (ex: 0300 para 03h da manhã) para economizar os créditos"
  type        = string
  default     = "0300"
}

variable "resource_group_name_prefix" {
  description = "Prefixo para o nome do grupo de recursos"
  type        = string
  default     = "fiapvm"
}

variable "resource_group_location" {
  description = "Localização para o grupo de recursos"
  type        = string
  default     = "East US"
}

variable "vnet_name" {
  description = "Nome da rede virtual"
  type        = string
  default     = "fiaplab-vnet"
}

variable "subnet_name" {
  description = "Nome da sub-rede"
  type        = string
  default     = "fiaplab-subnet"
}

variable "public_ip_name" {
  description = "Nome do IP público"
  type        = string
  default     = "fiaplab-public-ip"
}

variable "nsg_name" {
  description = "Nome do Network Security Group"
  type        = string
  default     = "fiaplab-nsg"
}

variable "nic_name" {
  description = "Nome da interface de rede"
  type        = string
  default     = "fiaplab-nic"
}

variable "storage_account_prefix" {
  description = "Prefixo para o nome da conta de armazenamento"
  type        = string
  default     = "fiapstorage"
}

variable "disk_name" {
  type        = string
  default     = "fiaplab-disk"
}

variable "vm_name" {
  description = "Nome da máquina virtual"
  type        = string
  default     = "fiaplab-vm"
}

variable "username" {
  description = "Nome de usuário para a VM"
  type        = string
  default     = "ubuntu"
}

variable "senha" {
  description = "Senha do usuário administrador da VM, por exemplo = P@ssword1234!"
  type        = string
  default     = "P@ssword1234!"
  sensitive   = true
}
