variable "instance_type" {
  # default     = "t2.micro"
  # default     = "t2.medium"
  default     = "t2.large" # 4	CPUs e 16 GB
  # default     = "t2.xlarge" # 8	CPUs e 32 GB  
}

variable "quantidade" {
  type        = number
  default     = "1"
}

variable "tamanho_disco" {
  type        = number
  default     = "50"
}

variable "ec2_name" {
  type        = string
  default     = "fiap_aluno_code"
}

variable "key_name" {
  type        = string
  default     = "vockey"
}

variable "aws_region" {
  description = "Regiao do AWS Educate padrao."
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
