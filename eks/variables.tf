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
  description = <<-EOT
    Tipos de instancia dos nos workers.

    t3.large (2 vCPU / 8 GiB) e o default porque t3.medium (4 GiB, ~3 GiB
    alocaveis depois do overhead do kubelet e dos DaemonSets) nao comporta
    stacks de observabilidade como o Dynatrace: os pods ficam Pending com
    "Insufficient memory".

    Prefira t3.large a t2.large: mesma CPU e memoria, geracao mais nova e
    cerca de 10% mais barata (us-east-1: ~US$ 0,0832/h contra ~US$ 0,0928/h).
  EOT
  type        = list(string)
  default     = ["t3.large"]
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
  description = <<-EOT
    Quantidade desejada de nos workers.

    O default e 2 porque **3 nao funciona no AWS Academy**. Com 3 x t3.large,
    um processo automatizado da propria conta (que aparece no CloudTrail como
    um principal "sysNNNNNNN", nem AutoScaling nem EKS) termina cada instancia
    poucos segundos depois de ela subir. O ASG relanca, o processo mata de
    novo, e o node group morre com NodeCreationFailure depois de ~35 minutos.
    Com 2 x t3.large o mesmo codigo sobe normalmente.

    Tecnicamente 3 seria melhor - com a stack do Dynatrace a CPU chegava a 77%
    de requests em um dos nos, e um StatefulSet de 3 replicas com anti-afinidade
    precisa de 3 dominios de falha. Onde a conta permitir, use 3.
  EOT
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Quantidade minima de nos workers."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Quantidade maxima de nos workers."
  type        = number
  default     = 4
}

variable "habilitar_ebs_csi" {
  description = <<-EOT
    Instala o addon aws-ebs-csi-driver no cluster.

    A partir do EKS 1.23 o provisionador de EBS saiu do Kubernetes e virou um
    driver CSI que NAO vem instalado. Sem ele, qualquer PVC de disco fica
    Pending e o pod nao agenda, com a mensagem:

      pod has unbound immediate PersistentVolumeClaims

    Isso atinge qualquer StatefulSet (Dynatrace ActiveGate, bancos de dados,
    Prometheus...), por isso o default e true e o addon fica no terraform,
    junto com o resto da infraestrutura.

    O addon e o ultimo recurso a ser criado (depends_on do node group), entao,
    se ele falhar, o cluster e os workers ja estao prontos - e o
    ebs_csi_timeout limita a espera, em vez dos 20 minutos default do provider.
    Nesse caso, diagnostique com "sh ebs_csi.sh --status".

    Use false para tirar o addon do apply, por exemplo quando ele esta
    impedindo uma turma de comecar; ai instale depois com "sh ebs_csi.sh".
    Nao use as duas formas ao mesmo tempo: com o addon ja criado pelo script,
    o terraform falha com ResourceInUseException.

    A role dos nos precisa poder criar e anexar volumes EBS (a LabRole do AWS
    Academy ja pode). Em conta propria, use IRSA e informe
    ebs_csi_service_account_role_arn.
  EOT
  type        = bool
  default     = true
}

variable "ebs_csi_timeout" {
  description = <<-EOT
    Tempo maximo de espera do terraform pelo addon do EBS.

    O default do provider e 20 minutos, durante os quais o apply so imprime
    "Still creating..." - o motivo real fica em health.issues, que o terraform
    nao mostra. Oito minutos ja e bem mais do que os 1 a 2 minutos de uma
    instalacao normal, e falha cedo o suficiente para nao perder uma aula.
  EOT
  type        = string
  default     = "8m"
}

variable "ebs_csi_service_account_role_arn" {
  description = <<-EOT
    ARN da role IAM (IRSA) para a service account do driver EBS. Deixe null
    para o driver usar as permissoes da role dos nos - que e o caso do AWS
    Academy, onde nao ha IRSA configurado.
  EOT
  type        = string
  default     = null
}

variable "habilitar_autoscaler" {
  description = <<-EOT
    Marca o Auto Scaling Group do node group com as tags que o Cluster
    Autoscaler usa para descobri-lo.

    ATENCAO: isto sozinho NAO escala nada. scaling_config (min/max/desired)
    apenas define os limites do ASG; nada cria nos quando um pod fica Pending.
    Para ter escala automatica de verdade e preciso tambem instalar o Cluster
    Autoscaler no cluster:

        sh autoscaler.sh

    Com o autoscaler ativo, o desired_size passa a ser controlado por ele. Um
    "terraform apply" posterior devolve o valor de node_desired_size, e o
    autoscaler torna a subir os nos se houver pods Pending.
  EOT
  type        = bool
  default     = false
}

variable "node_group_timeout" {
  description = <<-EOT
    Tempo maximo de espera do terraform pelo node group.

    O default do provider e 60 minutos. Um node group cujos nos nao conseguem
    entrar no cluster (quota de vCPU estourada, tipo de instancia bloqueado,
    falta de capacidade na AZ, rede sem saida) fica "Still creating..." esse
    tempo todo sem dizer nada - o motivo fica em health.issues e nas scaling
    activities do Auto Scaling Group, que o terraform nao mostra.

    25 minutos ja e bem mais que os 3 a 5 de uma criacao normal.
    Diagnostique com "sh diagnostico.sh".
  EOT
  type        = string
  default     = "25m"
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
