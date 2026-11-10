# shellcheck shell=bash
# =============================================================================
# Funcoes compartilhadas pelos scripts do lab.
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

# =============================================================================
# garantir_kubeconfig [cluster] [regiao]
#
# Deixa o kubectl falando com o cluster, configurando o kubeconfig sozinho se
# preciso - em vez de pedir ao usuario um comando que o proprio script tem como
# executar. Escreve em ./files/kube/config, sem tocar no ~/.kube da maquina.
#
# Retorno: 0 = fala com o cluster | 2 = kubectl inutilizavel | 3 = sem acesso
# =============================================================================
garantir_kubeconfig() {
    local cluster="${1:-eksfiap}" regiao="${2:-us-east-1}"

    command -v kubectl >/dev/null 2>&1 || return 2
    kubectl version --client >/dev/null 2>&1 || return 2

    kubectl get --raw /healthz >/dev/null 2>&1 && return 0

    mkdir -p ./files/kube 2>/dev/null && chmod 700 ./files/kube 2>/dev/null
    export KUBECONFIG="$PWD/files/kube/config"
    kubectl get --raw /healthz >/dev/null 2>&1 && return 0

    AWS_PAGER="" aws eks update-kubeconfig --name "$cluster" --region "$regiao" \
        >/dev/null 2>&1 || return 3
    kubectl get --raw /healthz >/dev/null 2>&1 && return 0
    return 3
}
