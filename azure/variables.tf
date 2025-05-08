variable "location" {
  type        = string
  default     = "East US"
  description = "Localização do grupo de recursos."
}

variable "username" {
  type        = string
  description = "Nome de usuário para a conta local na nova VM."
  default     = "azureuser"
}
