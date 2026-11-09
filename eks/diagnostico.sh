#!/usr/bin/env bash
# =============================================================================
# Coleta somente-leitura do estado do cluster, para troubleshooting.
# Nao altera nada.
#
# Uso:
#   sh diagnostico.sh                   tudo
#   sh diagnostico.sh -n dynatrace      foca em um namespace
#   sh diagnostico.sh > diag.txt        salva para analisar depois
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -uo pipefail   # sem -e: uma secao que falha nao aborta o relatorio

cd "$(dirname "$0")" || exit 1

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"
NS=""

case "${1:-}" in
    -n) NS="${2:-}"; [ -n "$NS" ] || { echo "Uso: sh diagnostico.sh [-n namespace]" >&2; exit 2; } ;;
    "") ;;
    *)  echo "Uso: sh diagnostico.sh [-n namespace]" >&2; exit 2 ;;
esac

command -v kubectl >/dev/null 2>&1 || { echo "ERRO: kubectl nao encontrado. Rode: sh instalar_kubectl.sh" >&2; exit 1; }
kubectl version --client >/dev/null 2>&1 || { echo "ERRO: kubectl quebrado. Rode: sh instalar_kubectl.sh" >&2; exit 1; }

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi
export AWS_PAGER=""
[ -z "${KUBECONFIG:-}" ] && [ -f "$PWD/files/kube/config" ] && export KUBECONFIG="$PWD/files/kube/config"

secao() { printf '\n\n========== %s ==========\n' "$1"; }
NS_ARGS=(--all-namespaces); [ -n "$NS" ] && NS_ARGS=(-n "$NS")

secao "1. Nos: capacidade e sistema operacional"
# OS-IMAGE importa: AL2023 usa SELinux, nao AppArmor. Cargas que montam
# /sys/kernel/security/apparmor como hostPath falham nesses nos.
kubectl get nodes -o wide
echo ""
kubectl get nodes -o custom-columns=\
'NO:.metadata.name,INSTANCIA:.metadata.labels.node\.kubernetes\.io/instance-type,'\
'CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory,PODS:.status.allocatable.pods,SO:.status.nodeInfo.osImage'

secao "2. Consumo reservado por no (requests)"
kubectl describe nodes | grep -A6 'Allocated resources' | grep -E 'cpu|memory|Allocated|--' || true

secao "3. Pods que nao estao Running/Succeeded"
kubectl get pods "${NS_ARGS[@]}" \
    --field-selector 'status.phase!=Running,status.phase!=Succeeded' -o wide 2>/dev/null \
    || kubectl get pods "${NS_ARGS[@]}" -o wide

secao "4. Motivo de cada pod pendente"
PENDENTES=$(kubectl get pods "${NS_ARGS[@]}" \
    --field-selector 'status.phase=Pending' \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null)
if [ -z "$PENDENTES" ]; then
    echo "(nenhum pod Pending)"
else
    while read -r ns nome; do
        [ -n "${nome:-}" ] || continue
        echo "--- $ns/$nome"
        kubectl -n "$ns" describe pod "$nome" 2>/dev/null \
            | sed -n '/^Events:/,$p' | tail -12
        echo ""
    done <<< "$PENDENTES"
fi

secao "5. Armazenamento: StorageClasses"
# Sem uma StorageClass default, um PVC sem storageClassName fica Pending para
# sempre, e o scheduler reporta "pod has unbound immediate PersistentVolumeClaims".
kubectl get storageclass -o wide 2>/dev/null || echo "(nenhuma StorageClass)"
echo ""
echo "StorageClass default:"
kubectl get storageclass -o jsonpath=\
'{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' 2>/dev/null \
    | grep . || echo "  NENHUMA -- esta e a causa classica de PVC preso em Pending"

secao "6. Armazenamento: PVCs e PVs"
kubectl get pvc "${NS_ARGS[@]}" 2>/dev/null || echo "(nenhum PVC)"
echo ""
PVCS=$(kubectl get pvc "${NS_ARGS[@]}" \
    -o jsonpath='{range .items[?(@.status.phase=="Pending")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null)
if [ -n "$PVCS" ]; then
    while read -r ns nome; do
        [ -n "${nome:-}" ] || continue
        echo "--- PVC Pending: $ns/$nome"
        kubectl -n "$ns" describe pvc "$nome" 2>/dev/null | sed -n '/^Events:/,$p' | tail -8
    done <<< "$PVCS"
fi
echo ""
kubectl get pv 2>/dev/null | head -20 || true

secao "7. Drivers CSI instalados"
# Em EKS 1.23+ o driver de EBS NAO vem instalado: sem ele, nenhum PVC de disco
# e provisionado.
kubectl get csidrivers 2>/dev/null || echo "(nenhum)"
echo ""
if kubectl get csidrivers 2>/dev/null | grep -q 'ebs.csi.aws.com'; then
    echo "[ok] driver EBS presente"
    kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-ebs-csi-driver 2>/dev/null
else
    echo "[!]  driver EBS AUSENTE (ebs.csi.aws.com)"
    echo "     Sem ele, PVCs de disco ficam Pending e o pod nao agenda."
    echo "     Correcao: habilitar_ebs_csi = true no terraform.tfvars + sh iniciar.sh"
fi

secao "8. Addons do EKS"
aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --output text 2>/dev/null \
    || echo "(nao foi possivel consultar; credenciais?)"

secao "9. DaemonSets e volumes hostPath"
# hostPath que nao existe no no gera FailedMount, por exemplo
# /sys/kernel/security/apparmor em AMIs que nao usam AppArmor.
kubectl get daemonsets "${NS_ARGS[@]}" 2>/dev/null
echo ""
kubectl get daemonsets "${NS_ARGS[@]}" \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\t"}{range .spec.template.spec.volumes[?(@.hostPath)]}{.hostPath.path}{" "}{end}{"\n"}{end}' 2>/dev/null \
    | grep -v '^\s*$' || true

secao "10. Eventos de Warning mais recentes"
kubectl get events "${NS_ARGS[@]}" --field-selector type=Warning \
    --sort-by=.lastTimestamp 2>/dev/null | tail -25 || true

printf '\n\nFim do diagnostico.\n'
