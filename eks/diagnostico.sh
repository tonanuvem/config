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
VIGIAR=0

case "${1:-}" in
    -n) NS="${2:-}"; [ -n "$NS" ] || { echo "Uso: sh diagnostico.sh [-n namespace]" >&2; exit 2; } ;;
    --vigiar) VIGIAR=1 ;;
    "") ;;
    *)  echo "Uso: sh diagnostico.sh [-n namespace | --vigiar]" >&2; exit 2 ;;
esac

# O diagnostico precisa funcionar com o cluster ainda subindo, sem nos e sem
# kubectl - que e justamente quando um "terraform apply" trava. Por isso a
# parte da AWS vem primeiro e o kubectl e opcional.
KUBECTL_OK=1
if ! command -v kubectl >/dev/null 2>&1 || ! kubectl version --client >/dev/null 2>&1; then
    KUBECTL_OK=0
    kubectl() { return 1; }   # faz as secoes do Kubernetes caírem no fallback
fi

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && grep -qi aws_access_key_id ./files/credentials 2>/dev/null; then
    export AWS_SHARED_CREDENTIALS_FILE="$PWD/files/credentials"
fi
export AWS_PAGER=""
[ -z "${KUBECONFIG:-}" ] && [ -f "$PWD/files/kube/config" ] && export KUBECONFIG="$PWD/files/kube/config"

secao() { printf '\n\n========== %s ==========\n' "$1"; }

# -----------------------------------------------------------------------------
# Quando o console termina em "systemd-shutdown ... Powering off" logo apos o
# nodeadm concluir, a maquina nao quebrou: alguem a desligou de fora. O
# CloudTrail diz nominalmente quem - pode ser o proprio ASG, o EKS, ou um
# processo de conformidade da conta (comum em contas de laboratorio, que
# derrubam instancias fora da politica de tipo ou de total de vCPU).
# -----------------------------------------------------------------------------
quem_matou() {
    local inst="$1"
    echo ""
    echo "--- Quem parou/terminou $inst (CloudTrail) ---"
    local ev
    ev=$(aws cloudtrail lookup-events --region "$AWS_REGION" \
        --lookup-attributes "AttributeKey=ResourceName,AttributeValue=$inst" \
        --max-results 15 \
        --query 'Events[?EventName==`TerminateInstances`||EventName==`StopInstances`].[EventTime,EventName,Username]' \
        --output text 2>/dev/null)

    if [ -n "$ev" ]; then
        printf '%s\n' "$ev" | sed 's/^/  /'
        echo ""
        echo "  Se o autor nao for o Auto Scaling nem o EKS, e um processo da"
        echo "  conta derrubando a instancia - tipicamente politica de tipo de"
        echo "  instancia ou de total de vCPU do laboratorio."
    else
        echo "  (nenhum TerminateInstances/StopInstances registrado ainda;"
        echo "   o CloudTrail costuma levar ate 15 minutos para indexar)"
    fi
}


# -----------------------------------------------------------------------------
# Modo vigia: quando os nos sobem e nao entram no cluster, a unica evidencia do
# que aconteceu esta dentro da maquina - e ela e destruida pelo ASG poucos
# minutos depois. Este modo espera uma instancia aparecer, mostra como entrar
# nela por SSH e despeja o console assim que a AWS o disponibiliza.
# -----------------------------------------------------------------------------
if [ "$VIGIAR" -eq 1 ]; then
    echo "Vigiando instancias do cluster '$CLUSTER_NAME' em $AWS_REGION."
    echo "Rode isto em paralelo ao 'sh iniciar.sh'. Ctrl-C para sair."
    echo ""

    ESPERA_MAX="${ESPERA_MAX:-1800}"
    INICIO=$SECONDS
    ALVO=""

    while [ $((SECONDS - INICIO)) -lt "$ESPERA_MAX" ]; do
        LINHA=$(aws ec2 describe-instances --region "$AWS_REGION" \
            --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" \
                      "Name=instance-state-name,Values=running" \
            --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,PrivateIpAddress]' \
            --output text 2>/dev/null)

        case "$LINHA" in
            i-*)
                ALVO=$(printf '%s' "$LINHA" | awk '{print $1}')
                IP=$(printf '%s' "$LINHA" | awk '{print $2}')
                echo ""
                echo "Instancia em execucao: $ALVO  (IP publico: $IP)"
                echo ""
                echo "Enquanto ela existe, o caminho mais rico e entrar nela:"
                echo "  ssh -i ~/labsuser.pem ec2-user@$IP"
                echo "  sudo cat /var/log/cloud-init-output.log | tail -50"
                echo "  sudo journalctl -u kubelet --no-pager | tail -50"
                echo ""
                break
                ;;
        esac
        printf '.'
        sleep 15
    done

    if [ -z "$ALVO" ]; then
        echo ""
        echo "Nenhuma instancia em execucao apareceu em ${ESPERA_MAX}s." >&2
        exit 1
    fi

    # -------------------------------------------------------------------------
    # A pergunta decisiva quando o no sobe bem mas o EKS diz "Unhealthy nodes":
    # ele chega a se registrar no cluster? Se aparecer em "kubectl get nodes",
    # o problema e de Ready/condicoes; se nunca aparecer, e de autenticacao -
    # o no nao consegue falar com o API server (access entry / aws-auth).
    # -------------------------------------------------------------------------
    echo ""
    echo "--- Access entry da role dos nos ---"
    # So vale conferir DEPOIS que o node group existe: e na criacao dele que o
    # EKS cria a entry do tipo EC2_LINUX. Consultar antes mostra apenas a role
    # do servico e a do criador do cluster, e nao prova nada.
    NODE_ROLE=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "${NODE_GROUP_NAME:-demo}" --region "$AWS_REGION" \
        --query 'nodegroup.nodeRole' --output text 2>/dev/null || echo "")

    ENTRIES=$(aws eks list-access-entries --cluster-name "$CLUSTER_NAME" \
        --region "$AWS_REGION" --query 'accessEntries[]' --output text 2>/dev/null || echo "")

    echo "  entries existentes:"
    printf '%s\n' "$ENTRIES" | tr '\t' '\n' | grep . | sed 's/^/    /' || echo "    (nenhuma)"

    if [ -z "$NODE_ROLE" ] || [ "$NODE_ROLE" = "None" ]; then
        echo "  (node group ainda nao existe; a entry EC2_LINUX so e criada com ele)"
    elif printf '%s' "$ENTRIES" | grep -qF "$NODE_ROLE"; then
        echo "  [ok]  a role dos nos ($NODE_ROLE) TEM access entry"
        aws eks describe-access-entry --cluster-name "$CLUSTER_NAME" \
            --principal-arn "$NODE_ROLE" --region "$AWS_REGION" \
            --query 'accessEntry.{tipo:type,grupos:kubernetesGroups}' --output json 2>/dev/null \
            | sed 's/^/        /'
    else
        echo "  [!]   a role dos nos ($NODE_ROLE) NAO tem access entry."
        echo "        Sem ela o kubelet nao autentica no API server e o no"
        echo "        nunca se registra. Confira tambem o ConfigMap aws-auth:"
        echo "        kubectl -n kube-system get cm aws-auth -o yaml"
    fi

    if [ "$KUBECTL_OK" -eq 1 ]; then
        aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1 || true
        echo ""
        echo "--- O no se registra no cluster? (kubectl get nodes a cada 20s) ---"
        VISTO=""
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
            NOS=$(kubectl get nodes -o wide 2>&1)
            if printf '%s' "$NOS" | grep -q 'ip-'; then
                printf '%s\n' "$NOS"
                NOME=$(printf '%s' "$NOS" | awk '/^ip-/{print $1; exit}')
                echo ""
                echo "--- Condicoes de $NOME ---"
                kubectl describe node "$NOME" 2>/dev/null \
                    | sed -n '/^Conditions:/,/^Addresses:/p' | head -20
                VISTO="sim"
                break
            fi
            printf '.'
            sleep 20
        done
        if [ -z "$VISTO" ]; then
            echo ""
            echo "NENHUM no se registrou em 4 minutos."
            echo "O no bootou mas nao conseguiu falar com o API server: olhe a"
            echo "access entry do tipo EC2_LINUX para a role dos nos, acima."
        fi
    fi

    echo ""
    echo "Aguardando o console da instancia (pode levar ~4 min) ..."
    while [ $((SECONDS - INICIO)) -lt "$ESPERA_MAX" ]; do
        SAIDA=$(aws ec2 get-console-output --instance-id "$ALVO" --region "$AWS_REGION" \
            --query 'Output' --output text 2>/dev/null)
        if [ -n "$SAIDA" ] && [ "$SAIDA" != "None" ]; then
            echo ""
            echo "========== console de $ALVO =========="
            printf '%s\n' "$SAIDA" | tail -60
            quem_matou "$ALVO"
            exit 0
        fi
        printf '.'
        sleep 20
    done

    echo ""
    echo "O console de $ALVO nao ficou disponivel a tempo." >&2
    echo "Se a instancia ainda existir, tente o SSH mostrado acima." >&2
    exit 1
fi

NS_ARGS=(--all-namespaces); [ -n "$NS" ] && NS_ARGS=(-n "$NS")

secao "0. Estado na AWS (nao depende do kubectl)"
# Esta secao responde "por que o terraform esta parado": o motivo de um
# cluster, node group ou addon que nao fica pronto esta em health.issues e nas
# scaling activities do ASG, nunca no log do apply.
if command -v aws >/dev/null 2>&1; then
    echo "--- Cluster ---"
    aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
        --query 'cluster.{status:status,versao:version,criado:createdAt}' --output json 2>/dev/null \
        || echo "  (cluster '$CLUSTER_NAME' nao encontrado)"

    echo ""
    echo "--- Node groups ---"
    for ng in $(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" \
            --query 'nodegroups[]' --output text 2>/dev/null); do
        echo "  $ng:"
        aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" \
            --region "$AWS_REGION" \
            --query 'nodegroup.{status:status,tipos:instanceTypes,escala:scalingConfig,problemas:health.issues}' \
            --output json 2>/dev/null | sed 's/^/    /'

        # O erro real de lancamento das instancias (quota de vCPU, tipo de
        # instancia bloqueado, falta de capacidade na AZ) so aparece aqui.
        # NodeCreationFailure aponta as instancias que nao viraram nos. O
        # console output delas e a unica pista do que o bootstrap fez - e ele
        # some quando o EKS termina o rollback, entao e capturado aqui.
        for inst in $(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" \
                --nodegroup-name "$ng" --region "$AWS_REGION" \
                --query 'nodegroup.health.issues[].resourceIds[]' --output text 2>/dev/null); do
            case "$inst" in i-*) ;; *) continue ;; esac
            echo ""
            echo "    --- console da instancia $inst (ultimas linhas) ---"
            aws ec2 get-console-output --instance-id "$inst" --region "$AWS_REGION" \
                --query 'Output' --output text 2>/dev/null \
                | tail -30 | sed 's/^/      /' \
                || echo "      (console indisponivel; a instancia pode ja ter sido removida)"
            quem_matou "$inst"
        done

        ASG=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" \
            --region "$AWS_REGION" --query 'nodegroup.resources.autoScalingGroups[0].name' \
            --output text 2>/dev/null)
        if [ -n "${ASG:-}" ] && [ "$ASG" != "None" ]; then
            echo "    ultimas atividades do ASG $ASG:"
            aws autoscaling describe-scaling-activities --auto-scaling-group-name "$ASG" \
                --region "$AWS_REGION" --max-items 5 \
                --query 'Activities[].{quando:StartTime,status:StatusCode,motivo:StatusMessage}' \
                --output json 2>/dev/null | sed 's/^/      /'
        else
            # Node group em CREATING sem ASG significa que o EKS ainda nao
            # comecou a provisionar as maquinas - problema do lado do EKS, e
            # nao de quota ou de lancamento de instancia (esses so aparecem
            # depois que o ASG existe).
            echo "    ASG AINDA NAO CRIADO: o EKS nao comecou a provisionar."
            echo "    Nesse estado, quota e tipo de instancia nao sao a causa."
            echo ""
            echo "    Role vinculada ao servico (o EKS precisa dela para criar o ASG):"
            if aws iam get-role --role-name AWSServiceRoleForAmazonEKSNodegroup \
                    --query 'Role.RoleName' --output text 2>/dev/null | grep -q .; then
                echo "      [ok]  AWSServiceRoleForAmazonEKSNodegroup existe"
            else
                echo "      [!]   AWSServiceRoleForAmazonEKSNodegroup NAO existe."
                echo "            O EKS a cria sozinho na primeira vez, mas precisa de"
                echo "            iam:CreateServiceLinkedRole - frequentemente negado em"
                echo "            contas de laboratorio."
            fi
            echo ""
            echo "    Launch templates criados pelo EKS:"
            aws ec2 describe-launch-templates --region "$AWS_REGION" \
                --query "LaunchTemplates[?contains(LaunchTemplateName, 'eks-')].LaunchTemplateName" \
                --output text 2>/dev/null | grep . | sed 's/^/      /' || echo "      (nenhum)"
        fi
    done
    [ -z "$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" \
        --query 'nodegroups[]' --output text 2>/dev/null)" ] && echo "  (nenhum node group)"

    echo ""
    echo "--- Auto Scaling Groups com tag do cluster ---"
    aws autoscaling describe-auto-scaling-groups --region "$AWS_REGION" \
        --query "AutoScalingGroups[?contains(to_string(Tags), '$CLUSTER_NAME')].{nome:AutoScalingGroupName,desejado:DesiredCapacity,instancias:length(Instances)}" \
        --output table 2>/dev/null | head -12 || echo "  (nenhum)"

    echo ""
    echo "--- Instancias EC2 do cluster ---"
    aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" \
        --query 'Reservations[].Instances[].{id:InstanceId,tipo:InstanceType,estado:State.Name,az:Placement.AvailabilityZone}' \
        --output table 2>/dev/null | head -20 || echo "  (nenhuma)"
else
    echo "(aws cli nao encontrado)"
fi

if [ "$KUBECTL_OK" -eq 0 ]; then
    printf '\n\nAVISO: kubectl indisponivel nesta maquina; as secoes do Kubernetes\n'
    printf '       abaixo ficarao vazias. Para instalar: sh instalar_kubectl.sh\n'
fi

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

secao "8. Addons do EKS: status e problemas de saude"
# Um addon preso em CREATING (o terraform fica em "Still creating...") quase
# sempre tem a explicacao em health.issues, e nao no log do terraform.
ADDONS=$(aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" \
    --query 'addons[]' --output text 2>/dev/null || echo "")

if [ -z "$ADDONS" ]; then
    echo "(nenhum addon gerenciado; coredns/kube-proxy/vpc-cni rodam auto-gerenciados)"
else
    for addon in $ADDONS; do
        echo "--- $addon"
        aws eks describe-addon --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" \
            --addon-name "$addon" \
            --query 'addon.{status:status,versao:addonVersion,role:serviceAccountRoleArn,problemas:health.issues}' \
            --output json 2>/dev/null || echo "  (nao foi possivel consultar)"
    done
fi

echo ""
echo "Pods do driver de EBS:"
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-ebs-csi-driver -o wide 2>/dev/null \
    | grep . || echo "  (nenhum)"
echo ""
kubectl -n kube-system get events --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null \
    | grep -i 'ebs-csi' | tail -10 || true

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
