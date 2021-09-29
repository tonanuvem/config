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
  default     = "20"
}

variable "ec2_name" {
  type        = string
  default     = "fiap_ubuntuvm_medium_2cpus_4gb"
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
    us-east-1 = "ami-0c2b8ca1dad447f8a"
  }
}
