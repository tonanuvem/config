#!/usr/bin/env bash
# =============================================================================
# Cria o cluster EKS do lab com terraform.
#
# Chamado por iniciar.sh. Tempo tipico: 12 a 15 minutos
#   control plane ~9-11 min  +  node group ~3-5 min
#
# Uso:
#   sh preparar.sh              cria o ambiente
#   sh preparar.sh --plan       apenas mostra o que seria criado
#   sh preparar.sh --check      apenas roda as verificacoes previas
#
# Mudancas em relacao a versao anterior:
#  * nao usa mais "sed -i" em main.tf (isso sujava o repositorio e fazia o
#    "git pull" do passo 1 falhar na segunda vez que o lab era executado);
#  * verificacoes previas (credenciais, role IAM, key pair, cluster existente)
#    antes do apply, para nao descobrir o erro depois de 10 minutos;
#  * nao roda mais "terraform plan" antes do apply (era trabalho duplicado);
#  * aborta no primeiro erro, em vez de seguir ate o apply.
# =============================================================================

# Permite ser chamado como "sh preparar.sh" sem perder os recursos do bash.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

MODO="apply"
case "${1:-}" in
    --plan)  MODO="plan" ;;
    --check) MODO="check" ;;
    "")      ;;
    *)
        echo "Uso: sh preparar.sh [--plan|--check]" >&2
        exit 2
        ;;
esac

TF_ARGS=()
AVISOS=()

# As variaveis de ambiente abaixo sao repassadas ao terraform SO quando o
# usuario as define explicitamente. Assim um terraform.tfvars continua valendo
# para quem nao usa variavel de ambiente, e as verificacoes previas deste
# script nunca divergem do que o terraform vai criar (antes, CLUSTER_NAME=x
# mudava as checagens mas o terraform criava "eksfiap" de qualquer forma).
[ -n "${CLUSTER_NAME+x}" ] && TF_ARGS+=(-var "cluster-name=$CLUSTER_NAME")
[ -n "${AWS_REGION+x}" ] && TF_ARGS+=(-var "aws_region=$AWS_REGION")
[ -n "${CLUSTER_ROLE_NAME+x}" ] && TF_ARGS+=(-var "cluster_role_name=$CLUSTER_ROLE_NAME")
[ -n "${NODE_ROLE_NAME+x}" ] && TF_ARGS+=(-var "node_role_name=$NODE_ROLE_NAME")
[ -n "${SSH_KEY_NAME+x}" ] && TF_ARGS+=(-var "node_ssh_key_name=$SSH_KEY_NAME")

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"
SSH_KEY_NAME="${SSH_KEY_NAME:-vockey}"
CLUSTER_ROLE_NAME="${CLUSTER_ROLE_NAME:-LabRole}"

titulo() { printf '\n=== %s ===\n' "$1"; }
ok()     { printf '  [ok]   %s\n' "$1"; }
aviso()  { printf '  [!]    %s\n' "$1"; AVISOS+=("$1"); }
erro()   { printf '  [ERRO] %s\n' "$1" >&2; }

# -----------------------------------------------------------------------------
titulo "1/5 Ferramentas necessarias"
# -----------------------------------------------------------------------------
FALTANDO=0

if command -v aws >/dev/null 2>&1; then
    ok "aws cli: $(aws --version 2>&1 | head -1)"
else
    erro "aws cli nao encontrado. Instale a AWS CLI v2 antes de continuar."
    FALTANDO=1
fi

if command -v terraform >/dev/null 2>&1; then
    ok "terraform: $(terraform version -json 2>/dev/null \
        | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p' \
        | head -1 || terraform version | head -1)"
else
    erro "terraform nao encontrado. Instale com: sh ../terraform.sh"
    FALTANDO=1
fi

[ "$FALTANDO" -eq 0 ] || exit 1

# -----------------------------------------------------------------------------
titulo "2/5 Credenciais AWS"
# -----------------------------------------------------------------------------
# config_credenciais.sh grava em ./files/credentials. Antes esse arquivo era
# usado apenas pelo container do kubectl, e o terraform dependia de um
# ~/.aws/credentials configurado a parte - o que fazia "sh iniciar.sh" falhar
# logo depois de "sh config_credenciais.sh". Aqui as duas pontas sao ligadas,
# sem alterar o ~/.aws do usuario.
if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
    ok "usando ./files/credentials"
elif [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
    ok "usando as credenciais do ambiente (AWS_ACCESS_KEY_ID)"
else
    aviso "./files/credentials vazio; usando a configuracao default da AWS CLI"
fi

export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

if ! IDENTIDADE=$(aws sts get-caller-identity --output json 2>&1); then
    erro "as credenciais AWS nao sao validas ou expiraram."
    printf '%s\n' "$IDENTIDADE" | sed 's/^/         /' >&2
    erro "rode novamente: sh config_credenciais.sh"
    exit 1
fi

ACCOUNT=$(printf '%s' "$IDENTIDADE" | sed -n 's/.*"Account": *"\([^"]*\)".*/\1/p')
ARN=$(printf '%s' "$IDENTIDADE" | sed -n 's/.*"Arn": *"\([^"]*\)".*/\1/p')
ok "conta $ACCOUNT"
ok "identidade $ARN"
ok "regiao $AWS_REGION"

# -----------------------------------------------------------------------------
titulo "3/5 Pre-requisitos na conta"
# -----------------------------------------------------------------------------
# Role do cluster: o terraform tambem valida isso, mas aqui a mensagem e clara.
if aws iam get-role --role-name "$CLUSTER_ROLE_NAME" >/dev/null 2>&1; then
    ok "role IAM '$CLUSTER_ROLE_NAME' encontrada"
else
    erro "role IAM '$CLUSTER_ROLE_NAME' nao encontrada nesta conta."
    erro "No AWS Academy ela se chama LabRole. Em conta propria, crie as roles"
    erro "com: sh config_eks_iam.sh  e depois rode:"
    erro "  CLUSTER_ROLE_NAME=eksFiapClusterRole sh preparar.sh"
    exit 1
fi

# Key pair do SSH: sem essa checagem o apply falhava SO depois de o control
# plane ficar pronto (~11 minutos perdidos).
if [ -n "$SSH_KEY_NAME" ]; then
    if aws ec2 describe-key-pairs --key-names "$SSH_KEY_NAME" >/dev/null 2>&1; then
        ok "key pair EC2 '$SSH_KEY_NAME' encontrado"
    else
        aviso "key pair '$SSH_KEY_NAME' nao existe: o node group sera criado sem SSH"
        # -var repetido: o terraform usa a ultima ocorrencia.
        TF_ARGS+=(-var "node_ssh_key_name=")
    fi
fi

# Cluster homonimo criado fora do terraform (ex: por awscli_eks_create.sh).
if aws eks describe-cluster --name "$CLUSTER_NAME" >/dev/null 2>&1; then
    if [ -f terraform.tfstate ] && grep -q '"aws_eks_cluster"' terraform.tfstate 2>/dev/null; then
        ok "cluster '$CLUSTER_NAME' ja existe e esta no estado do terraform"
    else
        erro "ja existe um cluster '$CLUSTER_NAME' nesta conta, fora do estado"
        erro "do terraform. Destrua o ambiente antigo antes de continuar:"
        erro "  sh destruir.sh          (se foi criado por este terraform)"
        erro "  sh awscli_eks_delete.sh (se foi criado via AWS CLI)"
        exit 1
    fi
fi

# main.tf alterado por versoes antigas do script (o antigo "sed -i").
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git diff --quiet -- main.tf 2>/dev/null; then
        aviso "main.tf esta modificado localmente (provavelmente pelo 'sed' da"
        aviso "versao antiga). Para voltar ao arquivo do repositorio: sh atualizar.sh"
    fi
fi

if [ "$MODO" = "check" ]; then
    titulo "Verificacoes concluidas"
    exit 0
fi

# -----------------------------------------------------------------------------
titulo "4/5 terraform init"
# -----------------------------------------------------------------------------
terraform init -input=false

# -----------------------------------------------------------------------------
if [ "$MODO" = "plan" ]; then
    titulo "5/5 terraform plan"
    terraform plan -input=false "${TF_ARGS[@]+"${TF_ARGS[@]}"}"
    exit 0
fi

titulo "5/5 terraform apply"
# -----------------------------------------------------------------------------
echo "Criando o cluster '$CLUSTER_NAME' em $AWS_REGION."
echo "Tempo estimado: 12 a 15 minutos (control plane + workers)."
echo "Nao interrompa: um apply cancelado deixa recursos orfaos na conta."
echo ""

INICIO=$SECONDS

terraform apply -auto-approve -input=false "${TF_ARGS[@]+"${TF_ARGS[@]}"}"

DURACAO=$((SECONDS - INICIO))

titulo "Ambiente criado em $((DURACAO / 60))m$((DURACAO % 60))s"

if [ "${#AVISOS[@]}" -gt 0 ]; then
    echo ""
    echo "Avisos desta execucao:"
    printf '  - %s\n' "${AVISOS[@]}"
fi

echo ""
echo "Proximo passo:  sh conectar.sh"
echo "Para destruir:  sh destruir.sh"
