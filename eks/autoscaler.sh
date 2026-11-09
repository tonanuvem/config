#!/usr/bin/env bash
# =============================================================================
# Instala (ou remove) o Cluster Autoscaler no cluster EKS do lab.
#
# POR QUE ESTE SCRIPT EXISTE
# O bloco scaling_config { min_size / max_size / desired_size } do terraform
# NAO liga escala automatica: ele so define os limites do Auto Scaling Group.
# Sem um controlador, um pod Pending por falta de memoria fica Pending para
# sempre, mesmo com max_size=4. Quem cria nos e o Cluster Autoscaler, um
# Deployment dentro do cluster - e e ele que este script instala.
#
# PRE-REQUISITOS
#  1. ASG com as tags de descoberta:
#         habilitar_autoscaler = true   (terraform.tfvars) e terraform apply
#  2. A role dos nos (LabRole no AWS Academy) precisa poder chamar
#     autoscaling:DescribeAutoScalingGroups, DescribeAutoScalingInstances,
#     DescribeLaunchConfigurations, DescribeTags, SetDesiredCapacity,
#     TerminateInstanceInAutoScalingGroup e ec2:DescribeInstanceTypes.
#     O script avisa se os logs acusarem falta de permissao.
#
# Uso:
#   sh autoscaler.sh              instala
#   sh autoscaler.sh --remover    remove
#   CA_VERSION=1.37.0 sh autoscaler.sh
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"
REPO_RAW="https://raw.githubusercontent.com/kubernetes/autoscaler"
MANIFESTO_REL="cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml"

ACAO="instalar"
case "${1:-}" in
    --remover) ACAO="remover" ;;
    "")        ;;
    *) echo "Uso: sh autoscaler.sh [--remover]" >&2; exit 2 ;;
esac

command -v kubectl >/dev/null 2>&1 || {
    echo "ERRO: kubectl nao encontrado. Rode: sh instalar_kubectl.sh" >&2
    exit 1
}
kubectl version --client >/dev/null 2>&1 || {
    echo "ERRO: o kubectl desta maquina nao funciona. Rode: sh instalar_kubectl.sh" >&2
    exit 1
}

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi
export AWS_PAGER=""
[ -z "${KUBECONFIG:-}" ] && [ -f "$PWD/files/kube/config" ] && export KUBECONFIG="$PWD/files/kube/config"

if [ "$ACAO" = "remover" ]; then
    kubectl delete deployment cluster-autoscaler -n kube-system --ignore-not-found
    kubectl delete serviceaccount cluster-autoscaler -n kube-system --ignore-not-found
    kubectl delete clusterrole cluster-autoscaler --ignore-not-found
    kubectl delete clusterrolebinding cluster-autoscaler --ignore-not-found
    kubectl delete role cluster-autoscaler -n kube-system --ignore-not-found
    kubectl delete rolebinding cluster-autoscaler -n kube-system --ignore-not-found
    echo "Cluster Autoscaler removido."
    exit 0
fi

# -----------------------------------------------------------------------------
echo "=== 1/4 Versao do Cluster Autoscaler ==="
# -----------------------------------------------------------------------------
# O autoscaler acompanha a minor do cluster: cluster 1.37 -> autoscaler 1.37.x.
MINOR=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
    --query 'cluster.version' --output text 2>/dev/null || echo "")

if [ -z "${CA_VERSION:-}" ]; then
    [ -n "$MINOR" ] && [ "$MINOR" != "None" ] || {
        echo "ERRO: nao foi possivel descobrir a versao do cluster '$CLUSTER_NAME'." >&2
        echo "      Informe explicitamente: CA_VERSION=1.37.0 sh autoscaler.sh" >&2
        exit 1
    }
    echo "Cluster na versao $MINOR; procurando a release correspondente ..."
    # Procura o maior patch publicado para essa minor (tag do repositorio).
    for patch in 9 8 7 6 5 4 3 2 1 0; do
        if curl -fsSL -o /dev/null --max-time 20 \
            "$REPO_RAW/cluster-autoscaler-${MINOR}.${patch}/$MANIFESTO_REL" 2>/dev/null; then
            CA_VERSION="${MINOR}.${patch}"
            break
        fi
    done
    [ -n "${CA_VERSION:-}" ] || {
        echo "ERRO: nenhuma release do Cluster Autoscaler para a minor $MINOR." >&2
        echo "      Veja github.com/kubernetes/autoscaler/releases e use CA_VERSION=..." >&2
        exit 1
    }
fi
echo "Cluster Autoscaler $CA_VERSION"

# -----------------------------------------------------------------------------
echo ""
echo "=== 2/4 Tags de descoberta no ASG ==="
# -----------------------------------------------------------------------------
ASG=$(aws autoscaling describe-auto-scaling-groups --region "$AWS_REGION" \
    --query "AutoScalingGroups[?contains(Tags[?Key=='eks:cluster-name'].Value, '$CLUSTER_NAME')].AutoScalingGroupName | [0]" \
    --output text 2>/dev/null || echo "None")

if [ "$ASG" = "None" ] || [ -z "$ASG" ]; then
    echo "AVISO: nao foi possivel localizar o ASG do cluster para conferir as tags."
else
    echo "ASG: $ASG"
    FALTANDO=""
    for tag in "k8s.io/cluster-autoscaler/enabled" "k8s.io/cluster-autoscaler/$CLUSTER_NAME"; do
        if aws autoscaling describe-tags --region "$AWS_REGION" \
            --filters "Name=auto-scaling-group,Values=$ASG" "Name=key,Values=$tag" \
            --query 'Tags[0].Key' --output text 2>/dev/null | grep -q "$tag"; then
            echo "  [ok]  $tag"
        else
            echo "  [!]   $tag AUSENTE"
            FALTANDO="sim"
        fi
    done
    if [ -n "$FALTANDO" ]; then
        echo ""
        echo "ERRO: sem essas tags o autoscaler nao enxerga o node group." >&2
        echo "      Coloque no terraform.tfvars:  habilitar_autoscaler = true" >&2
        echo "      e rode:  sh iniciar.sh" >&2
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
echo ""
echo "=== 3/4 Aplicando o manifesto oficial ==="
# -----------------------------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL --max-time 60 -o "$TMP/ca.yaml" \
    "$REPO_RAW/cluster-autoscaler-${CA_VERSION}/$MANIFESTO_REL"

# O exemplo oficial traz um placeholder de nome de cluster e uma imagem antiga
# (a v1.32.1 continua fixada mesmo nas tags mais novas), entao os dois sao
# ajustados aqui.
sed -i "s|<YOUR CLUSTER NAME>|$CLUSTER_NAME|g" "$TMP/ca.yaml"
sed -i "s|image: registry.k8s.io/autoscaling/cluster-autoscaler:.*|image: registry.k8s.io/autoscaling/cluster-autoscaler:v${CA_VERSION}|" "$TMP/ca.yaml"

grep -q "$CLUSTER_NAME" "$TMP/ca.yaml" || {
    echo "ERRO: o manifesto nao ficou com o nome do cluster; abortando." >&2
    exit 1
}
echo "Imagem: $(grep -o 'registry.k8s.io/autoscaling/cluster-autoscaler:[^ ]*' "$TMP/ca.yaml" | head -1)"

kubectl apply -f "$TMP/ca.yaml"

# Evita que o proprio autoscaler seja despejado ao compactar nos.
kubectl -n kube-system annotate deployment cluster-autoscaler \
    cluster-autoscaler.kubernetes.io/safe-to-evict=false --overwrite

# -----------------------------------------------------------------------------
echo ""
echo "=== 4/4 Verificando ==="
# -----------------------------------------------------------------------------
if kubectl -n kube-system rollout status deployment/cluster-autoscaler --timeout=180s; then
    echo ""
    LOGS=$(kubectl -n kube-system logs deployment/cluster-autoscaler --tail=200 2>/dev/null || echo "")
    if printf '%s' "$LOGS" | grep -qiE 'AccessDenied|UnauthorizedOperation|is not authorized'; then
        echo "AVISO: o autoscaler subiu mas a role dos nos nao tem permissao de autoscaling:" >&2
        printf '%s\n' "$LOGS" | grep -iE 'AccessDenied|UnauthorizedOperation|is not authorized' | head -3 | sed 's/^/        /' >&2
        echo "       Adicione as permissoes listadas no topo deste script a role dos nos." >&2
        exit 1
    fi
    echo "Cluster Autoscaler ativo."
    echo "Acompanhe com:  kubectl -n kube-system logs -f deployment/cluster-autoscaler"
else
    echo ""
    echo "ERRO: o Deployment nao ficou pronto." >&2
    kubectl -n kube-system get pods -l app=cluster-autoscaler >&2
    kubectl -n kube-system describe pod -l app=cluster-autoscaler 2>/dev/null \
        | grep -iE 'Image|Failed|Error|Warning' | head -10 >&2
    echo "" >&2
    echo "       Se for ImagePullBackOff, a tag v$CA_VERSION pode nao existir." >&2
    echo "       Tente outra: CA_VERSION=<versao> sh autoscaler.sh" >&2
    exit 1
fi
