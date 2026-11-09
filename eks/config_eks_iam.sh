#!/usr/bin/env bash
# =============================================================================
# Cria as roles IAM do cluster em uma conta AWS propria.
#
# NAO e necessario no AWS Academy / Learner Lab: lá existe a "LabRole", que ja
# tem todas as policies necessarias, e e o default do main.tf.
#
# Depois de rodar este script, use:
#   CLUSTER_ROLE_NAME=eksFiapClusterRole NODE_ROLE_NAME=eksFiapWorker sh iniciar.sh
# (ou defina cluster_role_name / node_role_name em terraform.tfvars)
#
# Mudancas em relacao a versao anterior:
#  * usava "docker run -d" + varios "docker exec": o container ficava com nome
#    fixo "awscli" e a segunda execucao falhava com "name already in use".
#    Agora e uma unica execucao, e nem exige Docker se a AWS CLI estiver na
#    maquina.
#  * idempotente: se a role ja existe, apenas anexa as policies em vez de
#    abortar com EntityAlreadyExists.
#  * a variavel EXEC era definida e nunca usada; $PWD nao estava entre aspas.
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_ROLE_NAME="${CLUSTER_ROLE_NAME:-eksFiapClusterRole}"
NODE_ROLE_NAME="${NODE_ROLE_NAME:-eksFiapWorker}"
IMAGE="${EKS_IMAGE:-tonanuvem/kubectl-aws-cli}"

if ! grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    sh ./config_credenciais.sh
fi

# ---------------------------------------------------------------------------
# aws() local, ou dentro do container quando a CLI nao esta instalada.
# ---------------------------------------------------------------------------
if command -v aws >/dev/null 2>&1; then
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
        export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
    fi
    export AWS_PAGER=""
    AWSCLI=(aws)
    # Caminho dos JSONs visto por quem executa a CLI.
    IAM_DIR="$PWD/iam"
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    AWSCLI=(docker run --rm
        -v "$PWD/files/credentials:/root/.aws/credentials:ro"
        -v "$PWD/iam:/fiap:ro"
        -w /fiap
        -e AWS_PAGER=
        "$IMAGE" aws)
    # Dentro do container, ./iam esta montado em /fiap (que e o workdir).
    IAM_DIR="/fiap"
else
    echo "ERRO: e preciso ter a AWS CLI instalada ou o Docker em execucao." >&2
    exit 1
fi

echo ""
echo " Configurando ..."
"${AWSCLI[@]}" sts get-caller-identity
echo ""

criar_role() {
    local nome="$1" documento="$2"
    shift 2
    if "${AWSCLI[@]}" iam get-role --role-name "$nome" >/dev/null 2>&1; then
        echo "Role '$nome' ja existe; apenas anexando as policies."
    else
        echo "Criando a role '$nome' ..."
        "${AWSCLI[@]}" iam create-role --role-name "$nome" \
            --assume-role-policy-document "file://$IAM_DIR/$documento" >/dev/null
    fi
    for policy in "$@"; do
        echo "  policy $policy"
        "${AWSCLI[@]}" iam attach-role-policy --role-name "$nome" \
            --policy-arn "arn:aws:iam::aws:policy/$policy"
    done
}

# Role do control plane.
criar_role "$CLUSTER_ROLE_NAME" eksRole.json \
    AmazonEKSClusterPolicy

# Role dos nos workers.
criar_role "$NODE_ROLE_NAME" eksNodeRole.json \
    AmazonEKSWorkerNodePolicy \
    AmazonEKS_CNI_Policy \
    AmazonEC2ContainerRegistryReadOnly

echo ""
echo "Roles criadas. Para usar no lab:"
echo "  CLUSTER_ROLE_NAME=$CLUSTER_ROLE_NAME NODE_ROLE_NAME=$NODE_ROLE_NAME sh iniciar.sh"
