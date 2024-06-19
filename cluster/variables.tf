variable "hostname" {
  type = map
  default = {
    # master   = "master"
    node1    = "node1"
    node2    = "node2"
    node3    = "node3"   
  }
}

variable "ec2_name" {
  type = map
  default = {
    node1     = "clusterfiap_node1_medium_2cpus_4gb"
    node2     = "clusterfiap_node2_medium_2cpus_4gb"
    node3     = "clusterfiap_node3_medium_2cpus_4gb"
  }
}

variable "instance_type" {
  # default     = "t2.micro"
  # default     = "t2.medium"
  default     = "t2.large" # 4	CPUs e 16 GB
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
    us-east-1 = "ami-0e8a34246278c21e4" # amazon linux 2 (v. 202311 - end of support)
    # us-east-1 = "ami-08a0d1e16fc3f61ea"   # amazon linux 2023 (v. 2003.4 20240611)
  }
}
