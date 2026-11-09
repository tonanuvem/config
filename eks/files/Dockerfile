# =============================================================================
# Imagem com AWS CLI + kubectl usada por kubectl.sh (modo docker).
# Publicada como tonanuvem/kubectl-aws-cli.
#
# ATENCAO: esta versao do Dockerfile ainda NAO foi construida/testada.
# Antes de publicar, rode:
#   docker build -t tonanuvem/kubectl-aws-cli ./files
#   docker run --rm --entrypoint /bin/sh tonanuvem/kubectl-aws-cli \
#       -c 'aws --version && kubectl version --client'
#
# Problemas da versao anterior que esta corrige:
#
# 1) awscli 1.19.21 (marco/2021) + kubectl "stable.txt" (sempre a ultima).
#    A AWS CLI dessa epoca gera kubeconfig com a apiVersion
#    client.authentication.k8s.io/v1alpha1, removida no Kubernetes 1.24.
#    Resultado em qualquer rebuild recente da imagem:
#      error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"
#    Agora: AWS CLI v2 (pacote aws-cli do Alpine) e kubectl com versao fixa.
#
# 2) "pip install awscli" falha no Alpine atual (PEP 668 / ambiente
#    gerenciado externamente). O pacote aws-cli do apk resolve isso.
#
# 3) "apk del py-pip": o pacote no Alpine chama-se py3-pip, entao esse del
#    nunca removia nada (e a camada continuava com o pip instalado).
#
# 4) kubectl baixado de stable.txt deixa a imagem nao reproduzivel e pode
#    ficar mais de uma minor acima do cluster (fora do suporte de skew).
#    Mantenha KUBECTL_VERSION no maximo uma minor acima do EKS do lab.
# =============================================================================

FROM alpine:3.21

# aws-cli v2 vem do repositorio community do Alpine (>= 3.19).
RUN apk add --no-cache \
        aws-cli \
        bash \
        ca-certificates \
        curl \
        git \
        groff \
        less

ARG KUBECTL_VERSION=v1.33.3
RUN curl -fsSLo /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl \
    && kubectl version --client

VOLUME /root/.aws
VOLUME /root/.kube
VOLUME /fiap
WORKDIR /fiap
