#!/usr/bin/env bash
# =============================================================================
# Caminho alternativo: cria o cluster EKS somente com a AWS CLI (sem terraform).
# O caminho principal do lab e: sh iniciar.sh
#
# Referencia original:
# https://blog.devgenius.io/how-to-create-eks-cluster-using-aws-cli-60e41111940b
#
# Mudancas em relacao a versao anterior:
#  * a VPC nao tinha Internet Gateway nem route table, e as subnets nao
#    recebiam IP publico. Sem isso os nos nao alcancam o endpoint do EKS nem
#    o ECR e ficam eternamente em "NotReady"/nao registrados. Corrigido.
#  * enable-dns-hostnames habilitado na VPC (exigencia do EKS).
#  * "if [ -f ./awscli/ ]" testava um diretorio com -f, portanto era sempre
#    falso e o mkdir corria mesmo com ambiente antigo existente. Agora usa -d.
#  * as esperas fixas ("for tempo in $(seq 1 100); sleep 5") gastavam 500s e
#    400s mesmo quando o recurso ficava pronto antes. Trocadas por
#    "aws eks wait", que retorna assim que o recurso esta ACTIVE.
#  * recursos recebem a tag Name=$CLUSTER_NAME, para que destruir.sh e
#    delete_vpc.sh consigam encontra-los.
#  * set -euo pipefail e variaveis entre aspas.
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
NODEGROUP_NAME="${NODEGROUP_NAME:-workers_eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"
VPC_CIDR="${VPC_CIDR:-10.6.0.0/16}"
ROLE_NAME="${ROLE_NAME:-LabRole}"
SSH_KEY_NAME="${SSH_KEY_NAME:-vockey}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"
ESTADO="./awscli"

export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

command -v aws >/dev/null 2>&1 || { echo "ERRO: aws cli nao encontrado." >&2; exit 1; }

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi

aws sts get-caller-identity >/dev/null 2>&1 || {
    echo "ERRO: credenciais AWS invalidas ou expiradas. Rode: sh config_credenciais.sh" >&2
    exit 1
}

if [ -d "$ESTADO" ]; then
    echo "Configuracao anterior encontrada em $ESTADO."
    echo "Primeiro destrua o ambiente antigo:  sh awscli_eks_delete.sh"
    exit 1
fi
mkdir -p "$ESTADO"

guardar() { echo "$2" > "$ESTADO/$1.txt"; }

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
VPC_ID=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$CLUSTER_NAME}]" \
    --query Vpc.VpcId --output text)
guardar VPC_ID "$VPC_ID"
echo ""
echo "Criado o VPC : $VPC_ID"

# O EKS exige resolucao de nomes na VPC.
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

# -----------------------------------------------------------------------------
# Subnets (2 AZs, exigencia do EKS)
# -----------------------------------------------------------------------------
mapfile -t AZS < <(aws ec2 describe-availability-zones \
    --filters Name=opt-in-status,Values=opt-in-not-required \
    --query 'AvailabilityZones[].ZoneName' --output text | tr '\t' '\n' | head -2)

SUBNET_IDS=()
for i in 0 1; do
    SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" \
        --cidr-block "10.6.$((i + 1)).0/24" \
        --availability-zone "${AZS[$i]}" \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$CLUSTER_NAME-public-$i},{Key=kubernetes.io/role/elb,Value=1}]" \
        --query Subnet.SubnetId --output text)
    # Sem IP publico os nos nao conseguem sair para a internet.
    aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch
    SUBNET_IDS+=("$SUBNET_ID")
    guardar "SUBNET_$((i + 1))_ID" "$SUBNET_ID"
    echo "Criado o Subnet $((i + 1)) : $SUBNET_ID (${AZS[$i]})"
done

# -----------------------------------------------------------------------------
# Internet Gateway + rota default (nao existiam na versao anterior)
# -----------------------------------------------------------------------------
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$CLUSTER_NAME}]" \
    --query InternetGateway.InternetGatewayId --output text)
guardar IGW_ID "$IGW_ID"
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
echo "Criado o Internet Gateway : $IGW_ID"

RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$CLUSTER_NAME}]" \
    --query RouteTable.RouteTableId --output text)
guardar RTB_ID "$RTB_ID"
aws ec2 create-route --route-table-id "$RTB_ID" \
    --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null

for SUBNET_ID in "${SUBNET_IDS[@]}"; do
    ASSOC_ID=$(aws ec2 associate-route-table --route-table-id "$RTB_ID" \
        --subnet-id "$SUBNET_ID" --query AssociationId --output text)
    echo "Rota associada a $SUBNET_ID ($ASSOC_ID)"
done

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------
SECURITYGROUP_ID=$(aws ec2 create-security-group \
    --group-name "eks-sg-node-group-$CLUSTER_NAME" \
    --description "EKS Node Group" --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$CLUSTER_NAME}]" \
    --query GroupId --output text)
guardar SECURITYGROUP_ID "$SECURITYGROUP_ID"

# Lab: tudo liberado. Em uso real, restrinja para o seu IP.
aws ec2 authorize-security-group-ingress --group-id "$SECURITYGROUP_ID" \
    --protocol "all" --cidr "0.0.0.0/0" >/dev/null

echo ""
echo "Criadas as regras de firewall : $SECURITYGROUP_ID"

# -----------------------------------------------------------------------------
# Cluster EKS
# -----------------------------------------------------------------------------
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo ""
echo "Role ARN do Lab : $ROLE_ARN"
echo ""

aws eks create-cluster --name "$CLUSTER_NAME" --role-arn "$ROLE_ARN" \
    --resources-vpc-config "subnetIds=${SUBNET_IDS[0]},${SUBNET_IDS[1]},securityGroupIds=$SECURITYGROUP_ID" \
    --access-config 'authenticationMode=API_AND_CONFIG_MAP,bootstrapClusterCreatorAdminPermissions=true' \
    >/dev/null

echo "Aguardando a criacao do Cluster EKS (tipico: 9 a 11 minutos) ..."
INICIO=$SECONDS
aws eks wait cluster-active --name "$CLUSTER_NAME"
echo "   Cluster criado em $((SECONDS - INICIO))s."
echo ""
echo "   Masters estao criados. Agora vamos criar os Workers..."
echo ""

# -----------------------------------------------------------------------------
# Node group
# -----------------------------------------------------------------------------
REMOTE_ACCESS=()
if aws ec2 describe-key-pairs --key-names "$SSH_KEY_NAME" >/dev/null 2>&1; then
    REMOTE_ACCESS=(--remote-access "ec2SshKey=$SSH_KEY_NAME,sourceSecurityGroups=$SECURITYGROUP_ID")
else
    echo "AVISO: key pair '$SSH_KEY_NAME' nao existe; node group sem acesso SSH."
fi

aws eks create-nodegroup --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODEGROUP_NAME" \
    --scaling-config minSize=1,maxSize=4,desiredSize=2 \
    --subnets "${SUBNET_IDS[@]}" \
    --instance-types "$INSTANCE_TYPE" \
    --node-role "$ROLE_ARN" \
    "${REMOTE_ACCESS[@]+"${REMOTE_ACCESS[@]}"}" \
    >/dev/null

echo "Aguardando a criacao dos Workers (tipico: 3 a 5 minutos) ..."
INICIO=$SECONDS
aws eks wait nodegroup-active --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODEGROUP_NAME"
echo "   Nodes Workers criados em $((SECONDS - INICIO))s."

# -----------------------------------------------------------------------------
# kubeconfig
# -----------------------------------------------------------------------------
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

if command -v kubectl >/dev/null 2>&1; then
    kubectl cluster-info
    kubectl get nodes
else
    echo "kubectl nao encontrado nesta maquina. Use: sh conectar.sh"
fi
