variable "instance_type" { # https://aws.amazon.com/pt/ec2/instance-types/
  # default     = "t2.medium" # 2	CPUs e 4 GB
  default     = "t2.large"    # 2	CPUs e 8 GB
  # default     = "t2.xlarge" # 4	CPUs e 16 GB
  #default     = "t2.2xlarge" # 8	CPUs e 32 GB
}

variable "ec2_name" {
  type        = string
  default     = "fiap_vm_xlarge_4cpus_16gb"
}

variable "key_name" {
  type        = string
  default     = "vockey"
}

variable "aws_region" {
  description = "Regiao do AWS Educate padrao."
  default     = "us-east-1"
}

# Ubuntu 18.04 LTS (x64)
variable "aws_amis" {
  default = {
    us-east-1 = "ami-0c2b8ca1dad447f8a"
  }
}
