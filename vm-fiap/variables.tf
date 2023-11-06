variable "instance_type" {
  # default     = "t2.micro"
  default     = "t2.medium"
}

variable "volume_size" {
  default     = 30
}

variable "ec2_name" {
  type        = string
  default     = "fiap_vm_medium_2cpus_4gb"
}

variable "key_name" {
  type        = string
  default     = "vockey"
}

variable "aws_region" {
  description = "Regiao do AWS Educate padrao."
  default     = "us-east-1"
}

variable "aws_amis" {
  default = {
    # us-east-1 = "ami-0c2b8ca1dad447f8a" # amazon linux 1
    us-east-1 = "ami-0e8a34246278c21e4" # amazon linux 2 (v. 202311)
  }
}
