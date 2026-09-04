variable "instance_type" {
  # default     = "t2.micro"
  # default     = "t2.medium"
  default     = "t2.large" # 2	CPUs e 8 GB
  # default     = "t2.xlarge" # 4	CPUs e 16 GB  
  # default     = "t2.2xlarge" # 8	CPUs e 32 GB  
}

variable "quantidade" {
  type    = number
  default = 1

  validation {
    condition     = var.quantidade >= 1
    error_message = "A quantidade deve ser maior ou igual a 1."
  }
}

variable "tamanho_disco" {
  type    = number
  default = 50

  validation {
    condition     = var.tamanho_disco >= 8
    error_message = "O tamanho do disco deve ser de pelo menos 8 GiB."
  }
}

variable "prefix_name" {
  type        = string
  default     = "fiaplab"
}

variable "ec2_name" {
  type        = string
  default     = "aluno"
}

variable "key_name" {
  type        = string
  default     = "vockey"
  # default     = "chave-fiaplab-vm"
}

variable "aws_region" {
  type        = string
  description = "Região AWS onde os recursos serão criados."
  default     = "us-east-1"
}

# Por padrao o lab usa a AMI fixada em aws_amis, para que a imagem nao
# mude sob os alunos no meio do semestre. Ligue esta flag apenas para
# validar uma imagem nova antes de promover o pin abaixo.
variable "usar_ami_mais_recente" {
  type        = bool
  default     = false
  description = "Usa a AMI Ubuntu 24.04 mais recente da Canonical em vez do ID fixado em aws_amis."
}

# Ubuntu
#
# O ID e fixado de proposito, para a imagem nao mudar sob os alunos no
# meio do semestre -- mas ele envelhece, e isso custa tempo: uma imagem
# antiga chega com pacotes base desatualizados, e o apt precisa baixar
# a diferenca em toda execucao. Medido em 2026-09-04: trocar uma imagem
# de meses atras por uma do dia derrubou o lab de 223s para 198s.
#
# A hipotese inicial era outra -- que o unattended-upgrades do primeiro
# boot fosse segurar o lock do apt -- mas isso nunca se manifestou em
# nenhuma das medicoes. O custo real e o volume de download.
#
# O output "ami_mais_recente_disponivel" avisa quando este pin ficou
# para tras; a flag usar_ami_mais_recente permite validar a nova antes
# de promover o ID aqui.
variable "aws_amis" {
  default = {
    # Promovido em 2026-09-04 apos medicao: o lab inteiro caiu de 223s
    # para 198s so trocando a imagem. O ganho ficou todo nas tasks que
    # instalam pacotes base do Ubuntu -- utils -16s e pre-reqs do docker
    # -5s -- porque numa imagem recente eles ja estao atualizados e o apt
    # baixa menos. Traz kernel 7.0.0-1012-aws no lugar do 6.8.0-1012-aws.
    us-east-1 = "ami-025d99823a4caad37" # Ubuntu Server 24.04 LTS, build de 2026-09-04
    # us-east-1 = "ami-0e86e20dae9224db8" # Uso anterior, build antigo: ~25s mais lento
    # us-east-1 = "ami-00bd2fe1439631665" # Uso anterior
    # us-east-1 = "ami-0bf6b162dbe07782b" # ubuntu do cloud9 (precisaria rodar cloud-init para configurar)
  }
}
