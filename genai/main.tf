provider "aws" {
  region = var.aws_region
}

# VPC do cluster de inferencia distribuida.
resource "aws_vpc" "default" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "genai-vpc"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

# UMA subnet so, de proposito: garante que todos os nos fiquem na mesma AZ.
# Em inferencia distribuida a rede entre nos e o gargalo (285 Mbit/s medidos
# por cima do weave), e trafego entre AZs so pioraria -- e ainda seria cobrado.
#
# A AZ vem fixada da variavel (us-east-1a) porque e uma das quatro que ofertam
# TODOS os tipos do plano, a GPU g6f.large inclusive. Ver variables.tf.
resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.2.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone != "" ? var.availability_zone : null
}

resource "aws_security_group" "default" {
  name        = "genai-security-group"
  description = "Cluster de inferencia distribuida em CPU"
  vpc_id      = aws_vpc.default.id

  # LAB TEMPORARIO - JAMAIS EM PRD
  ingress {
    from_port   = 0
    to_port     = 65353
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 65353
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # ICMP dentro do VPC: o shift e o cluster nao abrem, e isso impede usar ping
  # para diagnosticar a rede entre nos -- justamente o gargalo deste projeto.
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.2.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Sem user_data de proposito: o ../preparar.sh e o script de setup da VM do
# lab (procura ~/environment/labsuser.pem, redimensiona disco, mexe no
# security group do cloud9) e so daria "exit" no cloud-init de um no. Toda a
# configuracao vem do ansible, via ajustar.sh.
resource "aws_instance" "web" {
  count = var.quantidade

  ami                    = lookup(var.aws_amis, var.aws_region)
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile
  vpc_security_group_ids = [aws_security_group.default.id]
  subnet_id              = aws_subnet.default.id

  tags = {
    Name = "${format("%s_%d_%s", "vm", count.index, var.ec2_name)}"
  }

  root_block_device {
    volume_size = var.tamanho_disco
    volume_type = "gp3"
  }

  # Disco de modelos nos indices listados em var.indices_disco_modelos. Os
  # demais levam so rascunho, para nao pagar EBS ocioso -- lembrando que EBS
  # de instancia PARADA continua faturando.
  #
  # Por que LISTA e nao "o ultimo no":
  #
  # a versao anterior dizia "count.index == var.quantidade - 1", isto e, o
  # disco grande ia para o ULTIMO no. Subir "quantidade" de 6 para 7 move o
  # disco grande do indice 5 para o 6 -- e TODO manifest das fases fixa
  # "nodeSelector: node5" com hostPath /models. Num cluster criado de zero
  # com 7 nos, os GGUF cairiam num disco de rascunho de 10 GB e o download
  # falharia. Com lista, acrescentar no e aditivo: indices_disco_modelos
  # = [5, 6] da disco proprio ao novo sem mexer no 5.
  #
  # O QUE ESTE COMENTARIO DIZIA ERRADO ANTES: que mudar volume_size aqui
  # forcaria recriacao da instancia, e portanto que acrescentar um no
  # destruiria os modelos do node5. Conferido contra o estado real com
  # Terraform v1.16.0 e provider aws v6.74.0: NAO forca. Um plan com o
  # indice do disco grande trocado de [5] para [0] -- 10 -> 80 GB num no e
  # 80 -> 10 no outro -- devolve "No changes. Your infrastructure matches
  # the configuration". O provider trata ebs_block_device como computado e
  # ignora divergencia depois que a instancia existe (o bloco esta
  # deprecado na v6 em favor de aws_ebs_volume + aws_volume_attachment).
  #
  # A consequencia pratica inverte o alerta: estes volumes sao de CRIACAO.
  # Nao da para redimensionar o disco de modelos por aqui -- plan nao ve
  # diferenca. Para crescer, ou se usa aws_ebs_volume, ou se recria a
  # instancia de proposito (perdendo o conteudo), ou se da disco a um no novo.
  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = contains(var.indices_disco_modelos, count.index) ? var.tamanho_disco_modelos : var.tamanho_disco_scratch
    volume_type = "gp3"
  }
}
