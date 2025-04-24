variable "instance_type" {
  # default     = "t2.micro"
  # default     = "t2.medium"
  default     = "t2.large"
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
    # us-east-1 = "ami-0e8a34246278c21e4" # amazon linux 2 (v. 202311 - end of support)
    us-east-1 = "ami-08a0d1e16fc3f61ea"   # amazon linux 2023 (v. 2003.4 20240611)
  }
}
