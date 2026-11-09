# =============================================================================
# Variaveis do lab EKS
#
# Os valores default reproduzem o comportamento original do lab (cluster
# "eksfiap", 2 nos t3.medium em us-east-1), portanto "terraform apply" sem
# nenhum -var continua funcionando como antes.
# Para customizar, crie um arquivo terraform.tfvars (ja ignorado pelo git).
# =============================================================================

variable "aws_region" {
  description = "Regiao AWS onde o cluster sera criado."
  type        = string
  default     = "us-east-1"
}

variable "cluster-name" {
  description = "Nome do cluster EKS."
  type        = string
  default     = "eksfiap"
}

variable "cluster_version" {
  description = <<-EOT
    Versao do Kubernetes do cluster (ex: "1.33"). Deixe null para usar a
    versao default do EKS no momento da criacao - isso evita que o lab pare
    de funcionar quando uma versao sai do suporte padrao da AWS.
  EOT
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------

variable "cluster_role_name" {
  description = <<-EOT
    Nome da role IAM usada pelo control plane. No AWS Academy / Learner Lab a
    role pronta e a "LabRole" (ja contem AmazonEKSClusterPolicy). Em uma conta
    propria, use a role criada por config_eks_iam.sh (eksFiapClusterRole).
  EOT
  type        = string
  default     = "LabRole"
}

variable "node_role_name" {
  description = <<-EOT
    Nome da role IAM usada pelos nos workers. Precisa das policies
    AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy e
    AmazonEC2ContainerRegistryReadOnly (a LabRole ja as possui).
  EOT
  type        = string
  default     = "LabRole"
}

variable "extra_admin_role_names" {
  description = <<-EOT
    Roles IAM adicionais (apenas o nome, nao o ARN) que receberao acesso de
    administrador no cluster via EKS Access Entry. Util quando o professor
    cria o cluster e os alunos acessam com outra role.

    ATENCAO: nao inclua aqui a role usada como node_role_name - o EKS cria
    automaticamente um access entry do tipo EC2_LINUX para ela e o terraform
    falharia com ResourceInUseException.
  EOT
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Rede
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR da VPC do lab."
  type        = string
  default     = "10.5.0.0/16"
}

variable "subnet_count" {
  description = "Quantidade de subnets publicas (minimo 2, exigencia do EKS)."
  type        = number
  default     = 2

  validation {
    condition     = var.subnet_count >= 2
    error_message = "O EKS exige subnets em pelo menos 2 Availability Zones."
  }
}

variable "cluster_ingress_cidrs" {
  description = <<-EOT
    CIDRs liberados no security group do cluster.

    O default "0.0.0.0/0" mantem o comportamento original do lab (tudo aberto),
    o que e pratico em sala de aula mas NAO deve ser usado fora de um lab.
    Para restringir, informe por exemplo ["203.0.113.10/32"].
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "endpoint_private_access" {
  description = "Habilita o endpoint privado do API server (acesso de dentro da VPC)."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Habilita o endpoint publico do API server (necessario para kubectl de fora da VPC)."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Node group
# -----------------------------------------------------------------------------

variable "node_group_name" {
  description = "Nome do managed node group."
  type        = string
  default     = "demo"
}

variable "node_instance_types" {
  description = "Tipos de instancia dos nos workers."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_ami_type" {
  description = <<-EOT
    AMI dos nos. AL2023_x86_64_STANDARD e a familia atual; AL2_x86_64 (Amazon
    Linux 2) esta em fim de vida no EKS.
  EOT
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_capacity_type" {
  description = "ON_DEMAND ou SPOT. SPOT reduz bastante o custo do lab."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type deve ser ON_DEMAND ou SPOT."
  }
}

variable "node_disk_size" {
  description = "Tamanho do disco (GiB) de cada no."
  type        = number
  default     = 20
}

variable "node_desired_size" {
  description = "Quantidade desejada de nos workers."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Quantidade minima de nos workers."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Quantidade maxima de nos workers."
  type        = number
  default     = 4
}

variable "node_ssh_key_name" {
  description = <<-EOT
    Nome do key pair EC2 para acesso SSH aos nos ("vockey" no AWS Academy).
    Use "" para criar o node group sem acesso SSH - o lab funciona sem isso e
    evita o erro de apply quando o key pair nao existe na conta.

    ATENCAO: habilitar SSH sem preencher node_ssh_source_security_group_ids faz
    o EKS liberar a porta 22 para 0.0.0.0/0.
  EOT
  type        = string
  default     = "vockey"
}

variable "node_ssh_source_security_group_ids" {
  description = "Security groups autorizados a abrir SSH nos nos. Vazio = 0.0.0.0/0."
  type        = list(string)
  default     = []
}
