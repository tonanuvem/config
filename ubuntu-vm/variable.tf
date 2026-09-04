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

# ============================================================
# AMI: pin fixo vs imagem mais recente
#
# Uma AMI tem ID imutavel. A Canonical publica uma AMI NOVA, com ID
# novo, toda vez que reconstroi a imagem do Ubuntu 24.04 -- mesmo sendo
# a "mesma" versao. Dai as duas posturas possiveis:
#
#   com pin  (o que este lab usa): o ID fica escrito no codigo, em
#            aws_amis mais abaixo. Todo aluno sobe exatamente a mesma
#            imagem, hoje e daqui a tres meses. Previsivel, mas
#            envelhece.
#
#   sem pin  (most_recent = true): sempre a mais nova. Fresca, mas a
#            imagem muda sozinha -- um aluno na terca pode pegar uma
#            diferente da de quinta, e um build ruim da Canonical
#            quebraria a turma inteira sem ninguem ter mexido em nada.
#
# Para sala de aula o pin e o certo. O risco dele e ninguem perceber que
# envelheceu, e e por isso que existem as outras duas pecas:
#
#   main.tf    data.aws_ami.ubuntu_recente consulta qual e a mais nova
#              (so consulta, nao troca nada), e locals.ami_escolhida
#              decide entre ela e o pin conforme a flag abaixo.
#   output.tf  ami_em_uso, ami_mais_recente_disponivel e ami_status
#              avisam quando os dois divergiram.
#
# Ciclo para atualizar a imagem:
#
#   1. rode normal; o output ami_status avisa se o pin ficou para tras
#   2. export TF_VAR_usar_ami_mais_recente=true && terraform apply
#      -- testa a imagem nova sem editar arquivo nenhum
#   3. aprovada, promova o ID em aws_amis e rode
#      unset TF_VAR_usar_ami_mais_recente
#
# A flag e um bool comum do Terraform, entao aceita a forma
# TF_VAR_<nome> como variavel de ambiente. Sem o unset do passo 3 voce
# continua flutuando na mais recente, e o pin deixa de valer.
# ============================================================

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
