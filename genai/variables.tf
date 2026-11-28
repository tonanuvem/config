# Tipo de instancia.
#
# O teto do AWS Academy e ".large" -- todo xlarge recebe explicit deny
# (validado por dry-run; ver k8s-exemplos/llm/AWSACADEMY-RESTRICOES.md).
# TODO tipo permitido tem 2 vCPU, entao capacidade de CPU so cresce por
# numero de nos. A escolha e, portanto, por RAM e por rede:
#
#   r5.large    2 vCPU  16,0 GiB  Up to 10 Gbps   <- default: mais RAM
#   m6i.large   2 vCPU   8,0 GiB  Up to 12,5 Gbps    equilibrio
#   c5n.large   2 vCPU   5,25 GiB Up to 25 Gbps      melhor rede (teste de TP)
#   t2.large    2 vCPU   8,0 GiB  Low to Moderate    NAO usar: burstavel
#
# Por que nao t2.large, usado no shift: e burstavel. Sao ~40 min de CPU
# plena e depois cai para 60% de baseline, o que destroi a reprodutibilidade
# de qualquer benchmark longo.
variable "instance_type" {
  type    = string
  default = "r5.large"
}

# 1 master + 5 workers.
#
# Fase A do plano: 4 workers viram ranks de inferencia (4 = 2^2, exigencia do
# distributed-llama) e 1 worker hospeda n8n, LangGraph e Prometheus, fora dos
# ranks para nao contaminar a medicao.
#
# O limite da conta e 9 instancias somando TODOS os labs, e a VM do code-server
# ja ocupa 1. Com 6 aqui, o total fica em 7 e sobra folga.
variable "quantidade" {
  type    = number
  default = 6
}

# Disco raiz: SO, kubelet, containerd e imagens.
# O cluster atual usa 4,3 GB de 50, entao 40 e folgado mesmo com imagens de
# inferencia. Lembrar que EBS de instancia PARADA continua faturando.
variable "tamanho_disco" {
  type    = number
  default = 40
}

# Tamanho do volume de modelos (/dev/xvdb).
#
# Em llama.cpp RPC, distributed-llama e prima.cpp o arquivo do modelo vive no
# no raiz; os workers recebem os tensores pela rede. Entao nao faz sentido
# pagar disco grande em todos. O raiz e o node5 -- o no de aplicacao, fora dos
# 4 ranks medidos -- e nao o no 0, que e o master e fica com o taint de
# control-plane. Ver o comentario do ebs_block_device no main.tf.
#
# 80 GB acomodam o maior modelo do plano, gpt-oss-120b (conferido no HF:
# 63.387.346.208 bytes = 59,03 GiB), e ficam abaixo do teto de 100 GB por
# volume do lab.
#
# Mas 80 GB NAO acomodam o gpt-oss junto com os demais: o node5 ja guarda
# ~47 GB entre os GGUF do Qwen3-30B-A3B, Qwen3-8B, gemma-4-12B e o .m do
# distributed-llama. Dai a opcao de dar disco proprio a um no novo, via
# indices_disco_modelos, em vez de apagar o que ja foi medido.
variable "tamanho_disco_modelos" {
  type    = number
  default = 80
}

# Quais nos levam o volume de modelos. LISTA, nao "o ultimo no": com "o
# ultimo", subir quantidade moveria o disco grande para o no novo, e os
# manifests das fases fixam node5 -- ver o comentario do ebs_block_device no
# main.tf, que tambem registra o que foi medido sobre redimensionar volume.
#
# [5] = so o node5, que e o no de aplicacao (n8n, LangGraph, coordenador).
# Para o gpt-oss-120b (59,03 GiB), que precisa de 5 ranks mais um coordenador
# com disco proprio, subir quantidade para 7 e usar [5, 6].
variable "indices_disco_modelos" {
  type    = list(number)
  default = [5]
}

# Volume de rascunho dos demais nos.
# Subir este valor se for testar prima.cpp, que pode querer o arquivo local.
variable "tamanho_disco_scratch" {
  type    = number
  default = 10
}

variable "ec2_name" {
  type    = string
  default = "genai"
}

# Instance profile pre-criado pelo AWS Academy. Anexar e permitido; criar role
# nao e. Da aos nos acesso a S3 (cache dos GGUF entre sessoes) e, de quebra,
# credenciais que se renovam sozinhas pelo metadata -- as credenciais copiadas
# a mao expiram no meio do trabalho.
variable "instance_profile" {
  type    = string
  default = "LabInstanceProfile"
}

variable "key_name" {
  type    = string
  default = "vockey"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Amazon Linux 2023. O Amazon Linux 2 nao serve: tem Python 3.7, e o
# ansible-core 2.19+ exige 3.8+ no no gerenciado.
variable "aws_amis" {
  default = {
    us-east-1 = "ami-0820d0c589175bc01" # amazon linux 2023 (2023.12.20261102 - kernel 6.1)
  }
}

# AZ da subnet. Fixada de proposito, em vez de deixar a AWS escolher.
#
# Matriz levantada na conta (describe-instance-type-offerings):
#
#   tipo          1a   1b   1c   1d   1e   1f
#   r5.large      sim  sim  sim  sim  -    sim
#   m6i.large     sim  sim  sim  sim  -    sim
#   c5n.large     sim  sim  sim  sim  -    sim
#   t3.large      sim  sim  sim  sim  -    sim
#   t2.large      sim  sim  sim  sim  sim  sim
#   g6f.large     sim  sim  sim  sim  -    -     <- a GPU
#
# Duas razoes para fixar em 1a:
#
# 1. E a 1f que o shift pegou por sorte, e e a unica das modernas que NAO
#    oferta g6f.large. Em 1a o no de GPU pode entrar na MESMA subnet do
#    cluster -- sem trafego entre AZs, que seria cobrado e mais lento.
# 2. Deixar em branco permite cair em us-east-1e, que so oferta t2.large.
#    O apply funcionaria e o tipo escolhido falharia, por capacidade.
#
# 1b, 1c e 1d servem igualmente bem se 1a ficar sem capacidade.
variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}
