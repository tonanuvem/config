#!/usr/bin/env bash
# =============================================================================
# Garante uma StorageClass default no cluster (gp3, via driver CSI de EBS).
#
# QUANDO USAR
# Rode somente se "sh diagnostico.sh" apontar "StorageClass default: NENHUMA".
# Um PVC sem storageClassName e sem StorageClass default fica Pending para
# sempre, e o scheduler reporta no pod:
#
#   pod has unbound immediate PersistentVolumeClaims
#
# O EKS normalmente ja cria uma StorageClass "gp2" default. Este script cria
# uma "gp3" (mais rapida e ~20% mais barata que gp2) e a torna a default.
#
# Pre-requisito: driver CSI de EBS instalado (habilitar_ebs_csi = true).
#
# Uso:
#   sh storage.sh            cria gp3 e torna default
#   sh storage.sh --mostrar  so mostra o estado atual
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")" || exit 1

SC_NOME="${SC_NOME:-gp3}"

case "${1:-}" in
    --mostrar) ACAO="mostrar" ;;
    "")        ACAO="aplicar" ;;
    *) echo "Uso: sh storage.sh [--mostrar]" >&2; exit 2 ;;
esac

command -v kubectl >/dev/null 2>&1 || { echo "ERRO: kubectl nao encontrado. Rode: sh instalar_kubectl.sh" >&2; exit 1; }
kubectl version --client >/dev/null 2>&1 || { echo "ERRO: kubectl quebrado. Rode: sh instalar_kubectl.sh" >&2; exit 1; }
[ -z "${KUBECONFIG:-}" ] && [ -f "$PWD/files/kube/config" ] && export KUBECONFIG="$PWD/files/kube/config"

mostrar() {
    echo "StorageClasses:"
    kubectl get storageclass -o wide 2>/dev/null || echo "  (nenhuma)"
    echo ""
    echo -n "Default: "
    kubectl get storageclass -o jsonpath=\
'{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{" "}{end}' 2>/dev/null \
        | grep . || echo "NENHUMA"
    echo ""
}

if [ "$ACAO" = "mostrar" ]; then
    mostrar
    exit 0
fi

echo "=== Antes ==="
mostrar

if ! kubectl get csidrivers 2>/dev/null | grep -q 'ebs.csi.aws.com'; then
    echo "ERRO: driver CSI de EBS (ebs.csi.aws.com) nao esta instalado." >&2
    echo "      Sem ele a StorageClass nao consegue provisionar disco algum." >&2
    echo "      Coloque no terraform.tfvars:  habilitar_ebs_csi = true" >&2
    echo "      e rode:  sh iniciar.sh" >&2
    exit 1
fi

echo "=== Criando a StorageClass '$SC_NOME' ==="
kubectl apply -f - <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${SC_NOME}
provisioner: ebs.csi.aws.com
# WaitForFirstConsumer cria o volume na mesma AZ do no que recebeu o pod.
# Com Immediate o volume pode nascer numa AZ sem vaga e o pod nunca agenda.
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  type: gp3
  encrypted: "true"
YAML

echo ""
echo "=== Tornando '$SC_NOME' a default ==="
# Tira o default das demais, para nao ficar mais de uma marcada.
for sc in $(kubectl get storageclass -o jsonpath=\
'{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{" "}{end}' 2>/dev/null); do
    [ "$sc" = "$SC_NOME" ] && continue
    echo "  removendo default de '$sc'"
    kubectl patch storageclass "$sc" -p \
        '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
done

kubectl patch storageclass "$SC_NOME" -p \
    '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo ""
echo "=== Depois ==="
mostrar

# ---------------------------------------------------------------------------
# PVCs que ja estao Pending: dois casos muito diferentes.
#
#  * storageClassName AUSENTE (null): desde o Kubernetes 1.28 o controlador
#    atribui a default retroativamente, entao o PVC liga sozinho em instantes.
#  * storageClassName = "" (string vazia): significa "nao provisione, so ligue
#    a um PV existente". Esse NAO e atualizado quando surge uma default, e o
#    campo e imutavel - o PVC precisa ser recriado.
# ---------------------------------------------------------------------------
echo "=== PVCs ainda Pending ==="
PENDENTES=$(kubectl get pvc --all-namespaces \
    -o jsonpath='{range .items[?(@.status.phase=="Pending")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null)

if [ -z "$PENDENTES" ]; then
    echo "(nenhum)"
    exit 0
fi

PRECISA_RECRIAR=""
while read -r ns nome; do
    [ -n "${nome:-}" ] || continue
    VALOR=$(kubectl -n "$ns" get pvc "$nome" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
    if [ -n "$VALOR" ]; then
        echo "  $ns/$nome -> classe '$VALOR'; aguarde o provisionamento"
    elif kubectl -n "$ns" get pvc "$nome" -o json 2>/dev/null | grep -q '"storageClassName"'; then
        # A chave existe mas o valor e vazio: foi pedido explicitamente "sem classe".
        echo "  $ns/$nome -> storageClassName=\"\" (PRECISA SER RECRIADO)"
        PRECISA_RECRIAR="$PRECISA_RECRIAR $ns/$nome"
    else
        echo "  $ns/$nome -> sem classe definida; a default sera atribuida sozinha"
    fi
done <<< "$PENDENTES"

if [ -n "$PRECISA_RECRIAR" ]; then
    echo ""
    echo "Os PVCs acima com storageClassName=\"\" nunca recebem a default."
    echo "A StorageClass de um PVC e imutavel, entao eles precisam ser recriados"
    echo "(o StatefulSet dono recria o PVC e o pod em seguida):"
    for item in $PRECISA_RECRIAR; do
        echo "  kubectl -n ${item%%/*} delete pvc ${item##*/}"
    done
    echo ""
    echo "Se o PVC voltar com storageClassName=\"\", quem o define e o template do"
    echo "StatefulSet (no Dynatrace, o volumeClaimTemplate do DynaKube): ajuste la."
else
    echo ""
    echo "Nada a recriar. Acompanhe com:"
    echo "  kubectl get pvc --all-namespaces -w"
fi
