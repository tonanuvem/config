#!/usr/bin/env bash
# =============================================================================
# Abre um shell com o kubectl ja apontado para o cluster EKS do lab.
#
# Chamado por conectar.sh.
#
# Dois modos (variavel MODO=auto|host|docker):
#   host   - usa o aws/kubectl instalados na maquina (CloudShell, Cloud9, VM)
#   docker - usa a imagem tonanuvem/kubectl-aws-cli
#   auto   - host se aws+kubectl existirem, senao docker (default)
#
# Mudancas em relacao a versao anterior:
#  * nao usa mais "docker run -d" + "docker exec": o container antigo ficava
#    rodando depois que o shell era fechado e a segunda execucao falhava com
#    "The container name /kubectl is already in use";
#  * monta apenas o arquivo de credenciais (antes a pasta ./files inteira
#    virava /root/.aws) e persiste o kubeconfig em ./files/kube;
#  * confere se o cluster existe antes de tentar conectar;
#  * modo host, que dispensa o Docker e nao depende da imagem do Docker Hub.
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"
MODO="${MODO:-auto}"
IMAGE_PUBLICADA="${EKS_IMAGE_PUBLICADA:-tonanuvem/kubectl-aws-cli}"
IMAGE_LOCAL="${IMAGE_LOCAL:-eks-lab/kubectl-aws-cli:local}"
# EKS_IMAGE continua tendo prioridade, para quem quer apontar uma imagem propria.
IMAGE="${EKS_IMAGE:-}"
CONTAINER="${EKS_CONTAINER:-kubectl}"

CRED="./files/credentials"
KUBEDIR="$PWD/files/kube"

# -----------------------------------------------------------------------------
# Credenciais
# -----------------------------------------------------------------------------
if ! grep -qi aws_access_key_id "$CRED" 2>/dev/null; then
    echo "Credenciais nao encontradas em $CRED."
    sh ./config_credenciais.sh
fi

mkdir -p "$KUBEDIR"
chmod 700 "$KUBEDIR"

# -----------------------------------------------------------------------------
# Escolha do modo
# -----------------------------------------------------------------------------
if [ "$MODO" = "auto" ]; then
    if command -v aws >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1; then
        MODO="host"
    else
        MODO="docker"
    fi
fi

echo ""
echo "Cluster : $CLUSTER_NAME"
echo "Regiao  : $AWS_REGION"
echo "Modo    : $MODO"
echo ""

# Mensagem de boas-vindas mostrada dentro do shell.
AJUDA='
=====================================================================
 Shell conectado ao cluster EKS. Comandos uteis:
   kubectl get nodes
   kubectl get pods -A
   kubectl create deployment nginx --image=nginx
   kubectl expose deployment nginx --type=LoadBalancer --port=80
 Digite "exit" para sair.
=====================================================================
'

# -----------------------------------------------------------------------------
if [ "$MODO" = "host" ]; then
# -----------------------------------------------------------------------------
    for cmd in aws kubectl; do
        command -v "$cmd" >/dev/null 2>&1 || {
            echo "ERRO: '$cmd' nao encontrado. Use MODO=docker sh conectar.sh" >&2
            exit 1
        }
    done

    if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
        export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
    fi
    export AWS_DEFAULT_REGION="$AWS_REGION"
    export AWS_PAGER=""
    # Nao mexe no ~/.kube/config do usuario.
    export KUBECONFIG="$KUBEDIR/config"

    if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
            --query 'cluster.status' --output text 2>/dev/null | grep -q ACTIVE; then
        echo "ERRO: cluster '$CLUSTER_NAME' nao esta ACTIVE em $AWS_REGION." >&2
        echo "      Crie o ambiente primeiro: sh iniciar.sh" >&2
        exit 1
    fi

    aws eks --region "$AWS_REGION" update-kubeconfig --name "$CLUSTER_NAME"

    echo ""
    echo "Cluster endpoint:"
    aws eks --region "$AWS_REGION" describe-cluster --name "$CLUSTER_NAME" \
        --query "cluster.endpoint" --output text

    echo ""
    kubectl get nodes || echo "(os nos podem levar alguns minutos para aparecer)"

    printf '%s' "$AJUDA"
    exec bash -i

# -----------------------------------------------------------------------------
else
# -----------------------------------------------------------------------------
    command -v docker >/dev/null 2>&1 || {
        echo "ERRO: docker nao encontrado e aws/kubectl tambem nao." >&2
        echo "      Instale o Docker ou a AWS CLI + kubectl." >&2
        exit 1
    }

    docker info >/dev/null 2>&1 || {
        echo "ERRO: o daemon do Docker nao esta acessivel." >&2
        echo "      Verifique 'sudo systemctl start docker' e as permissoes do usuario." >&2
        exit 1
    }

    # -------------------------------------------------------------------------
    # Escolha da imagem.
    #
    # A imagem publicada foi construida com awscli 1.19.21 (2021), que gera
    # kubeconfig com a apiVersion client.authentication.k8s.io/v1alpha1,
    # removida no Kubernetes 1.24. Corrigir o files/Dockerfile nao muda nada
    # para quem baixa a imagem publicada, por isso aqui a imagem construida
    # localmente (build_imagem.sh) tem preferencia, e um pull que falha cai
    # para o build local em vez de simplesmente abortar.
    # -------------------------------------------------------------------------
    construir_local() {
        echo "Construindo a imagem local $IMAGE_LOCAL (uma vez; leva ~1 min) ..."
        bash ./build_imagem.sh
        IMAGE="$IMAGE_LOCAL"
    }

    if [ -n "$IMAGE" ]; then
        # Imagem indicada explicitamente pelo usuario.
        docker image inspect "$IMAGE" >/dev/null 2>&1 || {
            echo "Baixando a imagem $IMAGE ..."
            docker pull "$IMAGE"
        }
    elif [ "${EKS_BUILD:-0}" = "1" ]; then
        construir_local
    elif docker image inspect "$IMAGE_LOCAL" >/dev/null 2>&1; then
        IMAGE="$IMAGE_LOCAL"
        echo "Usando a imagem local $IMAGE_LOCAL."
    elif docker image inspect "$IMAGE_PUBLICADA" >/dev/null 2>&1; then
        IMAGE="$IMAGE_PUBLICADA"
    else
        echo "Baixando a imagem $IMAGE_PUBLICADA ..."
        if docker pull "$IMAGE_PUBLICADA"; then
            IMAGE="$IMAGE_PUBLICADA"
        else
            echo ""
            echo "AVISO: nao foi possivel baixar $IMAGE_PUBLICADA."
            construir_local
        fi
    fi

    echo "Imagem  : $IMAGE"

    # Remove sobras de execucoes anteriores (causa do "name already in use").
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

    BOOTSTRAP=$(cat <<'INNER'
set -e
echo "Versoes dentro do container:"
aws --version 2>&1 | head -1
kubectl version --client 2>/dev/null | head -2 || true
echo ""
if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
        --query 'cluster.status' --output text 2>/dev/null | grep -q ACTIVE; then
    echo "ERRO: cluster '$CLUSTER_NAME' nao esta ACTIVE em $AWS_REGION." >&2
    echo "      Crie o ambiente primeiro: sh iniciar.sh" >&2
    exit 1
fi
aws eks --region "$AWS_REGION" update-kubeconfig --name "$CLUSTER_NAME"
echo ""
echo "Cluster endpoint:"
aws eks --region "$AWS_REGION" describe-cluster --name "$CLUSTER_NAME" \
    --query "cluster.endpoint" --output text
echo ""
kubectl get nodes || echo "(os nos podem levar alguns minutos para aparecer)"
printf '%s' "$AJUDA"
exec /bin/sh
INNER
    )

    echo " Conectando ..."
    # Uma unica execucao interativa: ao sair, o container e removido.
    docker run -ti --rm --name "$CONTAINER" \
        -v "$PWD/files/credentials:/root/.aws/credentials:ro" \
        -v "$KUBEDIR:/root/.kube" \
        -v "$PWD:/fiap" \
        -w /fiap \
        -e CLUSTER_NAME="$CLUSTER_NAME" \
        -e AWS_REGION="$AWS_REGION" \
        -e AWS_DEFAULT_REGION="$AWS_REGION" \
        -e AWS_PAGER="" \
        -e AJUDA="$AJUDA" \
        --entrypoint /bin/sh \
        "$IMAGE" -c "$BOOTSTRAP"
fi
