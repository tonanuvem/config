# shellcheck shell=bash
# =============================================================================
# Funcao compartilhada por instalar_kubectl.sh e build_imagem.sh.
# Nao e executavel: use "source ./lib_versao.sh".
#
# O kubectl precisa estar a no maximo uma minor de distancia do cluster
# (skew suportado pelo Kubernetes). Fixar uma versao no codigo envelhece e
# silenciosamente sai do skew - foi o que aconteceu com o lab quando o EKS
# passou a criar clusters 1.37 e a imagem tinha kubectl 1.33.
# =============================================================================

# resolver_kubectl_version [cluster] [regiao]
# Ordem: $KUBECTL_VERSION > versao do cluster EKS > stable.txt
resolver_kubectl_version() {
    local cluster="${1:-eksfiap}" regiao="${2:-us-east-1}" minor versao

    if [ -n "${KUBECTL_VERSION:-}" ]; then
        printf '%s\n' "$KUBECTL_VERSION"
        return 0
    fi

    if command -v aws >/dev/null 2>&1; then
        minor=$(AWS_PAGER="" aws eks describe-cluster --name "$cluster" \
            --region "$regiao" --query 'cluster.version' --output text 2>/dev/null || echo "")
        if [ -n "$minor" ] && [ "$minor" != "None" ]; then
            echo "Cluster '$cluster' esta na versao $minor." >&2
            versao=$(curl -fsSL "https://dl.k8s.io/release/stable-${minor}.txt" 2>/dev/null || echo "")
            if [ -n "$versao" ]; then
                printf '%s\n' "$versao"
                return 0
            fi
            echo "AVISO: nao ha release publicada para a minor $minor." >&2
        fi
    fi

    echo "Usando a versao stable do kubectl." >&2
    versao=$(curl -fsSL https://dl.k8s.io/release/stable.txt 2>/dev/null || echo "")
    if [ -z "$versao" ]; then
        echo "ERRO: nao foi possivel descobrir a versao do kubectl." >&2
        echo "      Informe explicitamente: KUBECTL_VERSION=v1.37.2 ..." >&2
        return 1
    fi
    printf '%s\n' "$versao"
}
