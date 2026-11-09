#!/usr/bin/env bash
# =============================================================================
# Constroi localmente a imagem com AWS CLI + kubectl a partir de ./files.
#
# Por que existe:
# o kubectl.sh (modo docker) usava a imagem publicada tonanuvem/kubectl-aws-cli,
# que foi construida com awscli 1.19.21 (2021). Corrigir o files/Dockerfile nao
# muda nada para quem baixa a imagem publicada - e preciso reconstruir. Este
# script faz isso sem depender da Docker Hub nem de credencial de push.
#
# Uso:
#   sh build_imagem.sh                      # tag local (eks-lab/kubectl-aws-cli:local)
#   sh build_imagem.sh -t meuuser/minhaimg  # outra tag, para depois publicar
#   KUBECTL_VERSION=v1.32.5 sh build_imagem.sh
#
# Depois do build, "sh conectar.sh" usa a imagem local automaticamente.
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

IMAGE_LOCAL="${IMAGE_LOCAL:-eks-lab/kubectl-aws-cli:local}"
CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"

TAG="$IMAGE_LOCAL"
if [ "${1:-}" = "-t" ]; then
    [ -n "${2:-}" ] || { echo "Uso: sh build_imagem.sh [-t tag]" >&2; exit 2; }
    TAG="$2"
elif [ -n "${1:-}" ]; then
    echo "Uso: sh build_imagem.sh [-t tag]" >&2
    exit 2
fi

command -v docker >/dev/null 2>&1 || {
    echo "ERRO: docker nao encontrado." >&2
    exit 1
}
docker info >/dev/null 2>&1 || {
    echo "ERRO: o daemon do Docker nao esta acessivel." >&2
    echo "      Verifique 'sudo systemctl start docker' e as permissoes do usuario." >&2
    exit 1
}

# Versao do kubectl pela do cluster, nao fixa no codigo: um pino envelhece e
# sai do skew suportado (o lab chegou a ter kubectl 1.33 com cluster 1.37).
if [ -z "${KUBECTL_VERSION:-}" ] \
    && [ -z "${AWS_ACCESS_KEY_ID:-}" ] \
    && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi

# shellcheck source=lib_versao.sh
. ./lib_versao.sh
KUBECTL_VERSION=$(resolver_kubectl_version "$CLUSTER_NAME" "$AWS_REGION")

echo "Construindo $TAG (kubectl $KUBECTL_VERSION) a partir de ./files ..."
echo ""

docker build \
    --build-arg "KUBECTL_VERSION=$KUBECTL_VERSION" \
    -t "$TAG" \
    ./files

# ---------------------------------------------------------------------------
# Verificacao: o problema que motivou a mudanca do Dockerfile era justamente
# uma imagem que construia e so falhava em uso (AWS CLI antiga gerando
# kubeconfig com apiVersion v1alpha1). Entao o build nao termina sem conferir
# as duas ferramentas.
# ---------------------------------------------------------------------------
echo ""
echo "Verificando a imagem ..."
docker run --rm --entrypoint /bin/sh "$TAG" -c '
    set -e
    aws --version
    kubectl version --client
' || {
    echo "" >&2
    echo "ERRO: a imagem foi construida mas aws/kubectl nao respondem nela." >&2
    exit 1
}

echo ""
echo "Imagem $TAG pronta."
if [ "$TAG" = "$IMAGE_LOCAL" ]; then
    echo "O 'sh conectar.sh' vai usar esta imagem local automaticamente."
else
    echo "Para publicar:  docker push $TAG"
fi
