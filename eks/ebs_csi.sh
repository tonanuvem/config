#!/usr/bin/env bash
# =============================================================================
# Instala o driver CSI de EBS como addon do EKS, mostrando o motivo na hora
# quando ele nao fica saudavel.
#
# QUAL E O PAPEL DESTE SCRIPT
# O addon e criado pelo terraform (habilitar_ebs_csi, default true), como todo
# o resto da infraestrutura. O que o terraform NAO faz e dizer por que o addon
# nao fica saudavel: ele so imprime "Still creating..." ate o timeout. O motivo
# fica em health.issues, que so a API do EKS conta - e e isso que este script
# pergunta a cada 10 segundos, junto com o estado dos pods e os logs.
#
# Use "--status" a qualquer momento, inclusive em outro terminal com o
# terraform rodando. A instalacao por aqui serve para quem desligou o addon no
# terraform (habilitar_ebs_csi = false); nao use as duas formas ao mesmo tempo.
#
# Uso:
#   sh ebs_csi.sh              instala e acompanha
#   sh ebs_csi.sh --status     so mostra o estado atual
#   sh ebs_csi.sh --remover    remove o addon
#   ESPERA=600 sh ebs_csi.sh   muda o tempo maximo de espera (default 600s)
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -uo pipefail

cd "$(dirname "$0")" || exit 1

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ADDON="aws-ebs-csi-driver"
ESPERA="${ESPERA:-600}"

ACAO="instalar"
case "${1:-}" in
    --status)        ACAO="status" ;;
    --remover)       ACAO="remover" ;;
    --corrigir-imds) ACAO="imds" ;;
    "")              ;;
    *) echo "Uso: sh ebs_csi.sh [--status|--remover|--corrigir-imds]" >&2; exit 2 ;;
esac

command -v aws >/dev/null 2>&1 || { echo "ERRO: aws cli nao encontrado." >&2; exit 1; }

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi
export AWS_PAGER=""
[ -z "${KUBECONFIG:-}" ] && [ -f "$PWD/files/kube/config" ] && export KUBECONFIG="$PWD/files/kube/config"

# shellcheck source=lib_comum.sh
. ./lib_comum.sh

eks() { aws eks --region "$AWS_REGION" "$@"; }

eks_instancias_running() {
    aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" \
                  "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | tr '\t' '\n'
}

estado() {
    local st
    st=$(eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name "$ADDON" \
        --query 'addon.status' --output text 2>/dev/null | head -1 | tr -d '[:space:]')
    [ -n "$st" ] && printf '%s\n' "$st" || echo "AUSENTE"
}

problemas() {
    eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name "$ADDON" \
        --query 'addon.health.issues' --output json 2>/dev/null || echo "[]"
}

detalhar() {
    # Sem esta checagem, um kubectl quebrado ou sem acesso ao cluster faz todas
    # as consultas abaixo falharem em silencio, e o script afirma "nenhum pod"
    # quando na verdade nao conseguiu olhar. Falso negativo e pior que nada.
    garantir_kubeconfig "$CLUSTER_NAME" "$AWS_REGION"
    case "$?" in
        2)  echo ""
            echo "AVISO: o kubectl desta maquina nao funciona, entao NAO da para"
            echo "       saber o que esta acontecendo dentro do cluster."
            echo "       Conserte e rode de novo:  sh instalar_kubectl.sh"
            return 0 ;;
        3)  echo ""
            echo "AVISO: nao foi possivel falar com o cluster '$CLUSTER_NAME',"
            echo "       nem mesmo apos configurar o kubeconfig. NAO da para"
            echo "       saber o que esta acontecendo dentro dele."
            return 0 ;;
    esac

    echo ""
    echo "--- Pods do driver ---"
    kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-ebs-csi-driver -o wide 2>/dev/null \
        | grep . || echo "(nenhum pod; o addon nem chegou a criar os manifestos)"
    echo ""
    echo "--- Por que os pods nao estao prontos ---"
    kubectl -n kube-system describe pod -l app=ebs-csi-controller 2>/dev/null \
        | sed -n '/^Events:/,$p' | grep -E 'Warning|Failed|Insufficient|taint|Image' | head -8 \
        || echo "(sem eventos)"
    echo ""
    echo "--- Log do container principal ---"
    kubectl -n kube-system logs -l app=ebs-csi-controller -c ebs-plugin --tail=15 2>/dev/null \
        | grep . || echo "(sem logs; o container pode nem ter iniciado)"
}

# -----------------------------------------------------------------------------
# Quando o terraform desiste por timeout mas o EKS termina de criar o addon
# depois, o recurso fica marcado como tainted no estado: o proximo apply
# DESTROI o addon saudavel e o recria do zero, gastando o mesmo tempo de novo.
avisar_taint() {
    grep -q '"aws_eks_addon"' terraform.tfstate 2>/dev/null || return 0
    grep -q '"status": *"tainted"' terraform.tfstate 2>/dev/null || return 0
    echo ""
    echo "ATENCAO: o terraform marcou este addon como tainted (o apply desistiu"
    echo "         antes de o EKS terminar). Se voce rodar 'sh iniciar.sh' assim,"
    echo "         ele vai DESTRUIR este addon saudavel e recria-lo do zero."
    echo ""
    echo "         Limpe a marca antes:"
    echo "           terraform untaint 'aws_eks_addon.ebs_csi[0]'"
}

if [ "$ACAO" = "status" ]; then
    echo "Addon $ADDON: $(estado)"
    [ "$(estado)" = "ACTIVE" ] && avisar_taint
    echo "Problemas de saude:"; problemas
    detalhar
    exit 0
fi

# -----------------------------------------------------------------------------
# Correcao imediata do hop limit do IMDS nos nos que ja existem.
#
# A correcao permanente e imds_hop_limit no terraform, mas ela exige recriar o
# node group. Enquanto isso nao acontece, isto resolve em segundos e sem
# derrubar nada - e precisa ser refeito a cada no novo que o ASG criar.
# -----------------------------------------------------------------------------
if [ "$ACAO" = "imds" ]; then
    IDS=$(eks_instancias_running)
    [ -n "$IDS" ] || { echo "Nenhuma instancia em execucao no cluster '$CLUSTER_NAME'." >&2; exit 1; }

    MUDOU=0
    for i in $IDS; do
        HOP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$i" \
            --query 'Reservations[0].Instances[0].MetadataOptions.HttpPutResponseHopLimit' \
            --output text 2>/dev/null || echo "?")
        if [ "$HOP" = "1" ]; then
            printf '  %s: hop %s -> 2 ... ' "$i" "$HOP"
            if aws ec2 modify-instance-metadata-options --region "$AWS_REGION" \
                --instance-id "$i" --http-put-response-hop-limit 2 \
                --http-endpoint enabled >/dev/null 2>&1; then
                echo "ok"; MUDOU=1
            else
                echo "FALHOU"
            fi
        else
            echo "  $i: hop $HOP (nada a fazer)"
        fi
    done

    if [ "$MUDOU" -eq 1 ]; then
        echo ""
        echo "Reiniciando o ebs-csi-controller para ele tentar de novo ..."
        garantir_kubeconfig "$CLUSTER_NAME" "$AWS_REGION" \
            && kubectl -n kube-system rollout restart deployment/ebs-csi-controller \
            || echo "(nao foi possivel reiniciar pelo kubectl; o pod se recupera sozinho)"
        echo ""
        echo "Acompanhe:  sh ebs_csi.sh --status"
        echo ""
        echo "Lembre: isto vale so para os nos atuais. A correcao permanente e"
        echo "imds_hop_limit = 2 no terraform, que recria o node group."
    fi
    exit 0
fi

if [ "$ACAO" = "remover" ]; then
    [ "$(estado)" = "AUSENTE" ] && { echo "Addon nao existe."; exit 0; }
    eks delete-addon --cluster-name "$CLUSTER_NAME" --addon-name "$ADDON" >/dev/null
    echo "Removendo ..."
    while [ "$(estado)" != "AUSENTE" ]; do printf '.'; sleep 5; done
    echo ""
    echo "Addon removido."
    exit 0
fi

# -----------------------------------------------------------------------------
# Instalar
# -----------------------------------------------------------------------------
eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.status' --output text 2>/dev/null \
    | grep -q ACTIVE || {
    echo "ERRO: cluster '$CLUSTER_NAME' nao esta ACTIVE em $AWS_REGION." >&2
    echo "      Crie o ambiente primeiro: sh iniciar.sh" >&2
    exit 1
}

ATUAL=$(estado)
if [ "$ATUAL" = "AUSENTE" ]; then
    echo "Criando o addon $ADDON ..."
    ARGS=(--cluster-name "$CLUSTER_NAME" --addon-name "$ADDON" --resolve-conflicts OVERWRITE)
    [ -n "${EBS_CSI_ROLE_ARN:-}" ] && ARGS+=(--service-account-role-arn "$EBS_CSI_ROLE_ARN")
    eks create-addon "${ARGS[@]}" >/dev/null || {
        echo "ERRO: nao foi possivel criar o addon." >&2
        exit 1
    }
elif [ "$ATUAL" = "ACTIVE" ]; then
    echo "Addon ja esta ACTIVE. Nada a fazer."
    avisar_taint
    exit 0
else
    echo "Addon ja existe, em estado $ATUAL. Acompanhando ..."
fi

echo "Acompanhando ate $((ESPERA / 60)) minutos. Os problemas aparecem assim que o EKS os reporta."
echo ""

INICIO=$SECONDS
ULTIMO=""
JA_DETALHOU=0

while [ $((SECONDS - INICIO)) -lt "$ESPERA" ]; do
    ST=$(estado)
    if [ "$ST" != "$ULTIMO" ]; then
        printf '\n[%3ds] estado: %s\n' "$((SECONDS - INICIO))" "$ST"
        ULTIMO="$ST"
    else
        printf '.'
    fi

    case "$ST" in
        ACTIVE)
            echo ""
            echo "Addon ACTIVE em $((SECONDS - INICIO))s."
            avisar_taint
            echo ""
            kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-ebs-csi-driver 2>/dev/null
            echo ""
            echo "Proximo passo: sh storage.sh   (garante uma StorageClass default)"
            exit 0
            ;;
        CREATE_FAILED|DELETE_FAILED)
            echo ""
            echo "ERRO: addon em $ST." >&2
            problemas >&2
            detalhar >&2
            exit 1
            ;;
    esac

    # Problemas de saude aparecem antes de o estado mudar: mostra na primeira vez.
    ISSUES=$(problemas)
    if [ "$JA_DETALHOU" -eq 0 ] && [ -n "$ISSUES" ] && [ "$ISSUES" != "[]" ] && [ "$ISSUES" != "null" ]; then
        echo ""
        echo "=== O EKS reportou problemas de saude ==="
        printf '%s\n' "$ISSUES"
        detalhar
        echo ""
        echo "Continuando a acompanhar (o addon ainda pode se recuperar sozinho) ..."
        JA_DETALHOU=1
    fi

    sleep 10
done

echo ""
echo "ERRO: o addon nao ficou ACTIVE em ${ESPERA}s. Estado final: $(estado)" >&2
problemas >&2
[ "$JA_DETALHOU" -eq 0 ] && detalhar >&2
echo "" >&2
echo "Para remover e tentar de novo:  sh ebs_csi.sh --remover && sh ebs_csi.sh" >&2
exit 1
