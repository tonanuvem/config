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

  # Disco de modelos no ULTIMO no (node5), nao no no 0.
  #
  # Nos tres engines que entraram no plano (llama.cpp RPC, distributed-llama,
  # prima.cpp) e o no RAIZ que carrega o arquivo do modelo; os workers recebem
  # os tensores pela rede e quase nao usam disco. Ate ai a versao anterior
  # estava certa -- o erro era onde: o indice 0 e o MASTER, que fica com o
  # taint de control-plane e portanto nunca roda o pod coordenador. O disco
  # estava no unico no que nao podia usa-lo.
  #
  # O node5 (indice quantidade-1) e o no de aplicacao do plano, de proposito
  # fora dos 4 ranks de inferencia (node1..node4) para que n8n e LangGraph nao
  # contaminem a medicao. Pelo mesmo motivo ele e o lugar do coordenador: o I/O
  # de disco, a tokenizacao e o sampling do raiz ficam fora dos nos medidos.
  # E n8n/LangGraph precisam de volume persistente de qualquer forma, que cai
  # neste mesmo disco em vez de pedir outro.
  #
  # Assim nao e preciso NFS: o llama-server roda no node5 com os GGUF locais e
  # aponta --rpc para node1..node4. NFS fica em reserva para o caso do
  # prima.cpp exigir o arquivo em cada no -- e ai exporta deste disco.
  #
  # Os demais levam so rascunho, para nao pagar EBS ocioso em 5 nos --
  # lembrando que EBS de instancia parada continua faturando.
  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = count.index == var.quantidade - 1 ? var.tamanho_disco_modelos : var.tamanho_disco_scratch
    volume_type = "gp3"
  }
}
