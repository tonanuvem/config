variable "instance_type" {
  # default     = "t2.micro"
  # default     = "t2.medium"
  default     = "t2.large" # 2	CPUs e 8 GB
  # default     = "t2.xlarge" # 4	CPUs e 16 GB  
  # default     = "t2.2xlarge" # 8	CPUs e 32 GB  
}

variable "quantidade" {
  type    = number
  default = 1

  validation {
    condition     = var.quantidade >= 1
    error_message = "A quantidade deve ser maior ou igual a 1."
  }
}

variable "tamanho_disco" {
  type    = number
  default = 50

  validation {
    condition     = var.tamanho_disco >= 8
    error_message = "O tamanho do disco deve ser de pelo menos 8 GiB."
  }
}

variable "prefix_name" {
  type        = string
  default     = "fiaplab"
}

variable "ec2_name" {
  type        = string
  default     = "aluno"
}

variable "key_name" {
  type        = string
  default     = "vockey"
  # default     = "chave-fiaplab-vm"
}

variable "aws_region" {
  type        = string
  description = "Região AWS onde os recursos serão criados."
  default     = "us-east-1"
}

# Ubuntu
variable "aws_amis" {
  default = {
    us-east-1 = "ami-0e86e20dae9224db8" # Ubuntu Server 24.04 LTS (HVM),EBS General Purpose (SSD) Volume Type. 
    # us-east-1 = "ami-00bd2fe1439631665" # Uso anterior
    # us-east-1 = "ami-0bf6b162dbe07782b" # ubuntu do cloud9 (precisaria rodar cloud-init para configurar)
  }
}
