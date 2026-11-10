#!/usr/bin/env bash
# =============================================================================
# Instala/reinstala o kubectl nesta maquina, na versao do cluster EKS.
#
# Util quando o kubectl da VM esta quebrado. Sintoma tipico:
#   /usr/local/bin/kubectl: line 1: syntax error near unexpected token `<'
#   ... <Error><Code>NoSuchKey</Code> ... kubernetes-release/release/vX.Y.Z ...
#
# Isso acontece quando o kubectl foi baixado do bucket legado
# storage.googleapis.com/kubernetes-release, congelado na v1.31.0: para
# qualquer versao a partir da v1.32.0 ele responde 404, e um curl sem --fail
# grava o XML de erro no lugar do binario.
#
# Uso:
#   sh instalar_kubectl.sh                 # versao compativel com o cluster
#   KUBECTL_VERSION=v1.37.2 sh instalar_kubectl.sh
#   DESTINO=~/bin sh instalar_kubectl.sh   # sem sudo
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"
DESTINO="${DESTINO:-/usr/local/bin}"
ARCH="${ARCH:-amd64}"

# ---------------------------------------------------------------------------
# Versao do kubectl (ver lib_comum.sh): explicita > a do cluster > stable.
# ---------------------------------------------------------------------------
if [ -z "${KUBECTL_VERSION:-}" ] \
    && [ -z "${AWS_ACCESS_KEY_ID:-}" ] \
    && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi

# shellcheck source=lib_comum.sh
. ./lib_comum.sh
KUBECTL_VERSION=$(resolver_kubectl_version "$CLUSTER_NAME" "$AWS_REGION")

echo "Instalando kubectl $KUBECTL_VERSION em $DESTINO ..."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# -f/--fail e o que impede o 404 de ser gravado como se fosse o binario.
curl -fsSL -o "$TMP/kubectl" \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"

# Confere o checksum publicado antes de instalar.
if curl -fsSL -o "$TMP/kubectl.sha256" \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256"; then
    echo "$(cat "$TMP/kubectl.sha256")  $TMP/kubectl" | sha256sum --check --quiet
    echo "Checksum conferido."
else
    echo "AVISO: checksum nao disponivel; seguindo sem conferir."
fi

chmod +x "$TMP/kubectl"

# Confere que o binario responde ANTES de sobrescrever o que ja existe.
"$TMP/kubectl" version --client >/dev/null

if [ -w "$DESTINO" ]; then
    install -m 0755 "$TMP/kubectl" "$DESTINO/kubectl"
else
    sudo install -o root -g root -m 0755 "$TMP/kubectl" "$DESTINO/kubectl"
fi

echo ""
hash -r 2>/dev/null || true
"$DESTINO/kubectl" version --client

# ---------------------------------------------------------------------------
# O mesmo download quebrado que corrompia o kubectl corrompia tambem o kubeadm
# e o kubelet, instalados lado a lado pelo ansible_k8s.yml. Sintoma no systemd:
#   kubelet.service: Failed to execute /usr/local/bin/kubelet: Exec format error
# seguido de um laco de reinicio sem fim (restart counter nas centenas).
# ---------------------------------------------------------------------------
CORROMPIDOS=""
for bin in kubeadm kubelet; do
    for dir in /usr/local/bin /usr/bin; do
        alvo="$dir/$bin"
        [ -f "$alvo" ] || continue
        if head -c 1 "$alvo" 2>/dev/null | grep -q '<'; then
            CORROMPIDOS="$CORROMPIDOS $alvo"
        fi
    done
done

if [ -n "$CORROMPIDOS" ]; then
    echo ""
    echo "AVISO: estes arquivos tambem sao paginas de erro, nao binarios:"
    for c in $CORROMPIDOS; do echo "  $c"; done
    echo ""
    echo "Vieram do mesmo download quebrado. Para instala-los corretamente:"
    for c in $CORROMPIDOS; do
        nome=$(basename "$c")
        echo "  sudo curl -fsSL -o $c https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/$nome && sudo chmod +x $c"
    done
    if systemctl is-active --quiet kubelet 2>/dev/null \
        || systemctl is-enabled --quiet kubelet 2>/dev/null; then
        echo ""
        echo "O kubelet.service esta em laco de reinicio nesta maquina. Em um lab"
        echo "de EKS ele nao serve para nada (os nos ficam na AWS); so e usado nos"
        echo "labs de cluster proprio com kubeadm. Para parar o laco:"
        echo "  sudo systemctl disable --now kubelet"
    fi
fi

echo ""
echo "kubectl instalado. Proximo passo: sh conectar.sh"
