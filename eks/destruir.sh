#!/usr/bin/env bash
# =============================================================================
# Destroi o ambiente EKS do lab.
#
# Uso:
#   sh destruir.sh        pede confirmacao
#   sh destruir.sh -y     nao pede confirmacao
#
# Mudancas em relacao a versao anterior:
#  * a ordem foi invertida. Antes a VPC era apagada por fora (delete_vpc.sh)
#    e SO DEPOIS rodava "terraform destroy" - o estado do terraform ficava
#    apontando para recursos que nao existiam mais, e o destroy terminava com
#    erro ou deixava lixo no tfstate. Agora: terraform destroy primeiro e, so
#    se a VPC sobreviver, a limpeza manual entra como plano B.
#  * remove antes os Load Balancers criados pelo Kubernetes (Service
#    type=LoadBalancer). Eles seguram ENIs na subnet e sao a causa mais comum
#    de "DependencyViolation" ao apagar a VPC. O delete_vpc.sh trata apenas
#    elbv2 (ALB/NLB); um Service type=LoadBalancer no EKS cria, por default,
#    um Classic Load Balancer, que ficava para tras.
#  * regiao e nome do cluster deixaram de ser fixos no script.
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

TF_ARGS=()
[ -n "${CLUSTER_NAME+x}" ] && TF_ARGS+=(-var "cluster-name=$CLUSTER_NAME")
[ -n "${AWS_REGION+x}" ] && TF_ARGS+=(-var "aws_region=$AWS_REGION")

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"

CONFIRMAR=1
[ "${1:-}" = "-y" ] && CONFIRMAR=0

command -v aws >/dev/null 2>&1 || { echo "ERRO: aws cli nao encontrado." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "ERRO: terraform nao encontrado." >&2; exit 1; }

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

aws sts get-caller-identity >/dev/null 2>&1 || {
    echo "ERRO: credenciais AWS invalidas ou expiradas." >&2
    echo "      Rode: sh config_credenciais.sh" >&2
    exit 1
}

if [ "$CONFIRMAR" -eq 1 ]; then
    echo "Isto vai APAGAR o cluster '$CLUSTER_NAME' e a VPC do lab em $AWS_REGION."
    printf "Digite 'sim' para continuar: "
    read -r RESPOSTA
    [ "$RESPOSTA" = "sim" ] || { echo "Cancelado."; exit 0; }
fi

EKS_VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=$CLUSTER_NAME" \
    --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "None")

echo ""
echo "VPC do lab: $EKS_VPC_ID"

# -----------------------------------------------------------------------------
echo ""
echo "=== 1/3 Removendo Load Balancers criados pelo Kubernetes ==="
# -----------------------------------------------------------------------------
if [ "$EKS_VPC_ID" != "None" ] && [ -n "$EKS_VPC_ID" ]; then
    # Classic Load Balancers (default de Service type=LoadBalancer no EKS).
    for clb in $(aws elb describe-load-balancers \
            --query "LoadBalancerDescriptions[?VPCId=='$EKS_VPC_ID'].LoadBalancerName" \
            --output text 2>/dev/null || true); do
        echo "  removendo CLB $clb"
        aws elb delete-load-balancer --load-balancer-name "$clb" || true
    done

    # ALB / NLB.
    for alb in $(aws elbv2 describe-load-balancers \
            --query "LoadBalancers[?VpcId=='$EKS_VPC_ID'].LoadBalancerArn" \
            --output text 2>/dev/null || true); do
        echo "  removendo ALB/NLB $alb"
        aws elbv2 delete-load-balancer --load-balancer-arn "$alb" || true
    done

    # As ENIs do load balancer levam alguns segundos para desaparecer.
    echo "  aguardando a liberacao das interfaces de rede ..."
    sleep 20
else
    echo "  nenhuma VPC com a tag Name=$CLUSTER_NAME encontrada; seguindo."
fi

# -----------------------------------------------------------------------------
echo ""
echo "=== 2/3 terraform destroy ==="
# -----------------------------------------------------------------------------
terraform init -input=false >/dev/null
if terraform destroy -auto-approve -input=false "${TF_ARGS[@]+"${TF_ARGS[@]}"}"; then
    DESTROY_OK=1
else
    DESTROY_OK=0
    echo ""
    echo "AVISO: o terraform destroy falhou. Tentando a limpeza manual da VPC."
fi

# -----------------------------------------------------------------------------
echo ""
echo "=== 3/3 Verificacao final ==="
# -----------------------------------------------------------------------------
EKS_VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=$CLUSTER_NAME" \
    --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "None")

if [ "$EKS_VPC_ID" != "None" ] && [ -n "$EKS_VPC_ID" ]; then
    echo "A VPC $EKS_VPC_ID ainda existe. Rodando a limpeza manual."
    echo "(delete_vpc.sh - https://github.com/lianghong/delete_vpc)"
    chmod +x delete_vpc.sh
    ./delete_vpc.sh --region "$AWS_REGION" --vpc-id "$EKS_VPC_ID" --non-interactive || true

    # Realinha o estado do terraform depois da remocao por fora.
    terraform destroy -auto-approve -input=false "${TF_ARGS[@]+"${TF_ARGS[@]}"}" || true
else
    echo "Nenhuma VPC do lab restante."
fi

echo ""
if [ "$DESTROY_OK" -eq 1 ]; then
    echo "Ambiente destruido."
else
    echo "Ambiente destruido com avisos: confira no console da AWS se sobrou"
    echo "algum recurso (EKS, EC2, Load Balancer, Elastic IP, VPC)."
fi
