# =============================================================================
# Lab EKS - FIAP
#
# Mudancas em relacao a versao anterior:
#  * o Account ID deixou de ser fixo no arquivo. Havia um ARN com o numero da
#    conta de origem, reescrito por um "sed -i" em preparar.sh - o que sujava
#    o repositorio e quebrava o "git pull". Agora as roles sao resolvidas por
#    data source.
#  * enable_dns_hostnames reativado (o EKS precisa de DNS na VPC).
#  * subnets com a tag kubernetes.io/role/elb, necessaria para Service
#    type=LoadBalancer funcionar.
#  * access_config com bootstrap do criador como admin, resolvendo o erro
#    "You must be logged in to the server (Unauthorized)".
#  * removidos o aws_lb "lb_eks" e os aws_network_interface "eni_eks": nao
#    eram usados por nada, custavam dinheiro e travavam a exclusao da VPC.
# =============================================================================

terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Fixado na linha 5.x: a 6.x tem breaking changes que quebrariam o lab.
      version = "~> 5.100"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.cluster-name
      ManagedBy = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Dados da conta / IAM
# -----------------------------------------------------------------------------

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

# Filtra Local Zones / Wavelength, que nao suportam EKS.
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Falha no inicio do apply (e nao depois de 10 minutos) caso a role nao exista.
data "aws_iam_role" "cluster" {
  name = var.cluster_role_name
}

data "aws_iam_role" "node" {
  name = var.node_role_name
}

# -----------------------------------------------------------------------------
# VPC
#  * VPC
#  * Subnets publicas (uma por AZ)
#  * Internet Gateway
#  * Route Table
# -----------------------------------------------------------------------------

resource "aws_vpc" "demo" {
  cidr_block = var.vpc_cidr

  # Obrigatorio para o EKS: sem resolucao de nomes os nos nao registram no
  # cluster e o endpoint privado nao resolve.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                                        = var.cluster-name
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "demo" {
  count = var.subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.demo.id

  tags = {
    Name                                        = "${var.cluster-name}-public-${count.index}"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
    # Permite que o EKS/controller descubra estas subnets ao criar
    # Service type=LoadBalancer e Ingress publicos.
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id

  tags = {
    Name = var.cluster-name
  }
}

resource "aws_route_table" "demo" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  tags = {
    Name = var.cluster-name
  }
}

resource "aws_route_table_association" "demo" {
  count = var.subnet_count

  subnet_id      = aws_subnet.demo[count.index].id
  route_table_id = aws_route_table.demo.id
}

# -----------------------------------------------------------------------------
# Security Group do control plane
#
# O default (cluster_ingress_cidrs = 0.0.0.0/0) mantem o comportamento original
# do lab. Em qualquer uso que nao seja sala de aula, restrinja a variavel.
# -----------------------------------------------------------------------------

resource "aws_security_group" "eksfiap" {
  name        = var.cluster-name
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.demo.id

  ingress {
    description = "Acesso de entrada ao cluster (lab)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.cluster_ingress_cidrs
  }

  egress {
    description = "Saida liberada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.cluster-name
  }
}

# -----------------------------------------------------------------------------
# Cluster EKS (control plane) - ~9 a 11 minutos
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "eksfiap" {
  name     = var.cluster-name
  role_arn = data.aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    security_group_ids      = [aws_security_group.eksfiap.id]
    subnet_ids              = aws_subnet.demo[*].id
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }

  # Quem roda o "terraform apply" ja entra no cluster como administrador.
  # Sem isso aparece o classico:
  #   error: You must be logged in to the server (Unauthorized)
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name = var.cluster-name
  }

  # Garante que a rota de saida existe antes de o EKS provisionar as ENIs.
  depends_on = [
    aws_route_table_association.demo,
  ]
}

# Acesso de administrador para roles adicionais (opcional).
resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.extra_admin_role_names)

  cluster_name  = aws_eks_cluster.eksfiap.name
  principal_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${each.value}"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = aws_eks_access_entry.admin

  cluster_name  = aws_eks_cluster.eksfiap.name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# -----------------------------------------------------------------------------
# Workers (managed node group) - ~3 a 5 minutos
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Launch template dos nos
#
# Existe por um motivo so: ajustar o IMDS. Um managed node group sem launch
# template usa o default da AMI, e com AL2023 esse default bloqueia o acesso de
# pods comuns ao IMDS do no (ver imds_hop_limit). Sem isso o ebs-csi-controller
# nao consegue credenciais e fica em CrashLoopBackOff.
#
# Ao usar launch template, o EKS nao aceita no node group os argumentos
# disk_size e remote_access: eles passam a ser definidos aqui.
# -----------------------------------------------------------------------------
resource "aws_launch_template" "demo" {
  name_prefix = "${var.cluster-name}-"
  description = "Nos do ${var.cluster-name}"

  key_name = var.node_ssh_key_name == "" ? null : var.node_ssh_key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = var.imds_hop_limit
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.cluster-name}-worker"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "demo" {
  cluster_name    = aws_eks_cluster.eksfiap.name
  node_group_name = var.node_group_name
  node_role_arn   = data.aws_iam_role.node.arn
  subnet_ids      = aws_subnet.demo[*].id

  ami_type       = var.node_ami_type
  instance_types = var.node_instance_types
  capacity_type  = var.node_capacity_type

  # disk_size e remote_access vivem no launch template (o EKS nao aceita os
  # dois lugares ao mesmo tempo).
  launch_template {
    id      = aws_launch_template.demo.id
    version = aws_launch_template.demo.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "${var.cluster-name}-workers"
  }

  # Sem isto o provider espera 60 minutos so imprimindo "Still creating...".
  # Quando os nos nao conseguem entrar no cluster, o motivo esta em
  # health.issues e nas scaling activities do ASG: "sh diagnostico.sh".
  timeouts {
    create = var.node_group_timeout
    update = var.node_group_timeout
    delete = var.node_group_timeout
  }
}

# -----------------------------------------------------------------------------
# Driver CSI de EBS
#
# Desde o EKS 1.23 o provisionador de EBS deixou de fazer parte do Kubernetes e
# virou um driver CSI, que nao vem instalado. Sem ele qualquer PVC de disco
# fica Pending e o pod nao agenda:
#
#   0/2 nodes are available: pod has unbound immediate PersistentVolumeClaims
#
# Depende do node group: o driver roda nos nos, entao nao adianta instalar o
# addon antes de existir no onde agendar os pods dele.
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "ebs_csi" {
  count = var.habilitar_ebs_csi ? 1 : 0

  cluster_name             = aws_eks_cluster.eksfiap.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.ebs_csi_service_account_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Sem isto o provider espera 20 minutos so imprimindo "Still creating...".
  timeouts {
    create = var.ebs_csi_timeout
    update = var.ebs_csi_timeout
    delete = var.ebs_csi_timeout
  }

  # Ultimo recurso do apply: se o addon falhar, o cluster e os workers ja
  # estao prontos e so ele precisa de atencao.
  depends_on = [aws_eks_node_group.demo]

  tags = {
    Name = "${var.cluster-name}-ebs-csi"
  }
}

# -----------------------------------------------------------------------------
# Tags de descoberta do Cluster Autoscaler
#
# As tags definidas em aws_eks_node_group.tags ficam no node group e NAO sao
# propagadas para o Auto Scaling Group criado por tras dele. O autoscaler
# procura ASGs por tag (--node-group-auto-discovery=asg:tag=...), entao elas
# precisam ser aplicadas no proprio ASG, com aws_autoscaling_group_tag.
#
# Isto apenas torna o node group visivel ao autoscaler. Quem escala e o
# Deployment do Cluster Autoscaler, instalado por "sh autoscaler.sh".
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group_tag" "autoscaler" {
  for_each = var.habilitar_autoscaler ? {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster-name}" = "owned"
  } : {}

  autoscaling_group_name = aws_eks_node_group.demo.resources[0].autoscaling_groups[0].name

  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = false
  }
}
