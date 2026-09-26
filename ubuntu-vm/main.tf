# Define o provedor AWS onde serão criados os recursos
provider "aws" {
  region = var.aws_region
}

# Descobre a AMI Ubuntu 24.04 mais recente publicada pela Canonical
# (099720109477 e a conta oficial dela). Serve para o output apontar
# quando o pin envelheceu: a troca continua deliberada, nao automatica.
#
# A explicacao completa de pin fixo vs imagem mais recente, e o ciclo
# para atualizar, esta no cabecalho da secao de AMI em variable.tf.
data "aws_ami" "ubuntu_recente" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Quem decide de fato qual imagem sobe. Com a flag em false, que e o
# padrao, usa o ID fixado em aws_amis; com true, a recem-consultada
# acima. O data source sozinho nao troca imagem nenhuma.
locals {
  ami_escolhida = var.usar_ami_mais_recente ? data.aws_ami.ubuntu_recente.id : lookup(var.aws_amis, var.aws_region)
}

# Cria um VPC que receberá as instâncias e recursos
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.prefix_name}-vpc"
  }
}
# Cria um Internet Gateway que possibilita a comunicação da VPC com o mundo externo
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}
# Cria a Regra que permite acesso a Internet de/para o VPC
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}
# Cria uma subrede no VPC que ira receber as instâncias
resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  # Fixa a AZ (como no vm-fiap) para nao correr o risco de a AWS
  # sortear uma zona onde o instance_type nao esteja disponivel.
  availability_zone       = "us-east-1a"
}

# Cria um "security group" para o EC2 visando permitir o acesso Web
resource "aws_security_group" "default" {
  name        = "fiap-ec2-security-group-ec2-instance"
  description = "Grupo de seguranca do EC2"
  vpc_id      = aws_vpc.default.id

  # Acesso TOTAL de qualquer um
  ingress {
    from_port   = 0
    to_port     = 65353
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Acesso de saida para internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  count = var.quantidade # create similar EC2 instances
  
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"
    host = self.public_ip
    # The connection will use the local SSH agent for authentication.
  }
  
  # Define a chave
  key_name  = var.key_name
  
  # Define o nome da VM : "${format("%s_%d_%s", "aluno", count.index, var.ec2_name)}"
  tags = {
    Name = "${var.prefix_name}-${count.index + 1}-${var.ec2_name}"
  }  
  
  # Define tipo da VM (CPU e Memoria)
  instance_type = var.instance_type

  # Disco root.
  #
  # O volume EBS secundario (/dev/xvdb) foi removido: nenhum playbook
  # em config/ansible chegava a formata-lo ou monta-lo, entao eram 50 GB
  # gp3 provisionados e pagos por aluno sem qualquer uso.
  root_block_device {
    volume_size           = var.tamanho_disco
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }
  
  # Versão do Sistema Operacional (Ubuntu)
  ami = local.ami_escolhida

  # Security group to allow HTTP and SSH access
  vpc_security_group_ids = [aws_security_group.default.id]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = aws_subnet.default.id
}
