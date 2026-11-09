#!/usr/bin/env bash
# =============================================================================
# Remove o ambiente criado por awscli_eks_create.sh.
#
# Mudancas em relacao a versao anterior:
#  * as esperas eram "while describe-nodegroup | grep DELETING ... sleep 1",
#    que falhavam assim que o recurso deixava de existir (o describe passa a
#    retornar erro). Trocadas por "aws eks wait ...-deleted".
#  * "read ERRO" seguido de "[ $ERRO -eq 0 ]" quebrava com o shell script
#    inteiro se o usuario apenas apertasse ENTER. Agora a confirmacao e opcional
#    (-y) e a comparacao esta protegida.
#  * remove tambem Internet Gateway e route table (criados agora pelo create).
#  * regiao e nomes deixaram de ser fixos.
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
NODEGROUP_NAME="${NODEGROUP_NAME:-workers_eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ESTADO="./awscli"

export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

command -v aws >/dev/null 2>&1 || { echo "ERRO: aws cli nao encontrado." >&2; exit 1; }

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi

if [ ! -f "$ESTADO/VPC_ID.txt" ]; then
    echo "ERRO: $ESTADO/VPC_ID.txt nao encontrado." >&2
    echo "      Este script remove apenas o ambiente criado por awscli_eks_create.sh." >&2
    echo "      Para o ambiente criado pelo terraform, use: sh destruir.sh" >&2
    exit 1
fi

ler() { [ -f "$ESTADO/$1.txt" ] && cat "$ESTADO/$1.txt" || echo ""; }

VPC_ID=$(ler VPC_ID)
SUBNET_1_ID=$(ler SUBNET_1_ID)
SUBNET_2_ID=$(ler SUBNET_2_ID)
SECURITYGROUP_ID=$(ler SECURITYGROUP_ID)
IGW_ID=$(ler IGW_ID)
RTB_ID=$(ler RTB_ID)

echo "VPC            : $VPC_ID"
echo "Subnets        : $SUBNET_1_ID $SUBNET_2_ID"
echo "Security group : $SECURITYGROUP_ID"
echo "Internet GW    : $IGW_ID"
echo "Route table    : $RTB_ID"
echo ""

if [ "${1:-}" != "-y" ]; then
    printf "Digite 'sim' para remover tudo acima: "
    read -r RESPOSTA
    [ "${RESPOSTA:-}" = "sim" ] || { echo "Cancelado."; exit 0; }
fi

# -----------------------------------------------------------------------------
echo ""
echo "Excluindo o node group ..."
if aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "$NODEGROUP_NAME" >/dev/null 2>&1; then
    aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "$NODEGROUP_NAME" >/dev/null
    aws eks wait nodegroup-deleted --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "$NODEGROUP_NAME"
fi
echo "  node group removido."

echo "Excluindo o cluster ..."
if aws eks describe-cluster --name "$CLUSTER_NAME" >/dev/null 2>&1; then
    aws eks delete-cluster --name "$CLUSTER_NAME" >/dev/null
    aws eks wait cluster-deleted --name "$CLUSTER_NAME"
fi
echo "  cluster removido."

# Load balancers criados por Service type=LoadBalancer seguram ENIs na subnet.
if [ -n "$VPC_ID" ]; then
    for clb in $(aws elb describe-load-balancers \
            --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" \
            --output text 2>/dev/null || true); do
        echo "  removendo CLB $clb"
        aws elb delete-load-balancer --load-balancer-name "$clb" || true
    done
    for alb in $(aws elbv2 describe-load-balancers \
            --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
            --output text 2>/dev/null || true); do
        echo "  removendo ALB/NLB $alb"
        aws elbv2 delete-load-balancer --load-balancer-arn "$alb" || true
    done
    sleep 20
fi

echo "Excluindo a rede ..."
[ -n "$SECURITYGROUP_ID" ] && aws ec2 delete-security-group --group-id "$SECURITYGROUP_ID" || true
[ -n "$RTB_ID" ] && aws ec2 delete-route-table --route-table-id "$RTB_ID" || true
if [ -n "$IGW_ID" ] && [ -n "$VPC_ID" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" || true
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" || true
fi
[ -n "$SUBNET_1_ID" ] && aws ec2 delete-subnet --subnet-id "$SUBNET_1_ID" || true
[ -n "$SUBNET_2_ID" ] && aws ec2 delete-subnet --subnet-id "$SUBNET_2_ID" || true

if [ -n "$VPC_ID" ] && ! aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null; then
    echo ""
    echo "AVISO: a VPC $VPC_ID nao pode ser removida (ainda ha dependencias)."
    echo "       Limpeza manual: ./delete_vpc.sh --region $AWS_REGION --vpc-id $VPC_ID"
    exit 1
fi

mv "$ESTADO" "./bkp_awscli_$(date "+%Y_%m_%d_%Hh%Mm%S")"
echo ""
echo "Ambiente EKS excluido."
