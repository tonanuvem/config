#!/usr/bin/env bash
# =============================================================================
# Instala o driver CSI de EBS como addon do EKS, mostrando o motivo na hora
# quando ele nao fica saudavel.
#
# POR QUE FORA DO TERRAFORM
# O terraform espera o addon chegar a ACTIVE e nao mostra mais nada enquanto
# isso: sao ate 20 minutos de "Still creating..." e, no fim, o apply inteiro
# falha. O motivo real fica em health.issues, que so a API do EKS conta.
# Este script pergunta isso a cada 10 segundos e imprime assim que aparece,
# entao um problema vira diagnostico em ~1 minuto em vez de 20.
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
    --status)  ACAO="status" ;;
    --remover) ACAO="remover" ;;
    "")        ;;
    *) echo "Uso: sh ebs_csi.sh [--status|--remover]" >&2; exit 2 ;;
esac

command -v aws >/dev/null 2>&1 || { echo "ERRO: aws cli nao encontrado." >&2; exit 1; }

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi
export AWS_PAGER=""
[ -z "${KUBECONFIG:-}" ] && [ -f "$PWD/files/kube/config" ] && export KUBECONFIG="$PWD/files/kube/config"

eks() { aws eks --region "$AWS_REGION" "$@"; }

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
if [ "$ACAO" = "status" ]; then
    echo "Addon $ADDON: $(estado)"
    echo "Problemas de saude:"; problemas
    detalhar
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
