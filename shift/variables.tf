variable "instance_type" {
  # default     = "t2.micro"
  # default     = "t2.medium"
  default     = "t2.large" # 2	CPUs e 8 GB
  # default     = "t2.xlarge" # 4	CPUs e 16 GB  
}

variable "quantidade" {
  type        = number
  default     = "4"
}

variable "tamanho_disco" {
  type        = number
  default     = "50"
}

variable "ec2_name" {
  type        = string
  default     = "fiap_vm_k8s"
}

variable "key_name" {
  type        = string
  default     = "vockey"
}

variable "aws_region" {
  description = "Regiao do AWS Educate padrao."
  default     = "us-east-1"
}

# Amazon Linux 2
# Amazon Linux 2
variable "aws_amis" {
  default = {
    # us-east-1 = "ami-0c2b8ca1dad447f8a" # amazon linux 1
    # us-east-1 = "ami-0e8a34246278c21e4" # amazon linux 2 (v. 202311 - end of support)
    us-east-1 = "ami-08a0d1e16fc3f61ea"   # amazon linux 2023 (v. 2003.4 20240611)
  }
}

# Usado para definir a chave com base na chave publica
/*
variable "public_key_path" {
  default     = "public_key.pem"
#  description = <<DESCRIPTION
#Verificar a saida do comando: ssh-keygen -y -f ./vockey.pem
#Exemplo: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41"
#DESCRIPTION
}
*/
