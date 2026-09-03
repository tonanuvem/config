terraform init -backend-config="bucket=tfstate-cloudshell-$(aws sts get-caller-identity --query Account --output text)"
terraform plan; terraform apply -auto-approve
echo ""
echo " Iniciando configurações: "

# Aguardando Nodes
# O filtro aceita as tres formas que o ip_externo ja teve: string,
# lista e lista aninhada. Isso importa na transicao -- o state
# existente so passa a devolver a forma nova no proximo apply.
LER_IPS='if type=="string" then . else (.. | strings) end'

mapfile -t IPS < <(
    terraform output -json ip_externo 2>/dev/null |
    jq -r "$LER_IPS" |
    grep -v '^[[:space:]]*$'
)

export QTD_NODES=${#IPS[@]}

if [ "$QTD_NODES" -eq 0 ]; then
    echo ""
    echo "❌ Nenhum IP encontrado no output do Terraform."
    echo ""
    exit 1
fi

export WORKER_NODES=$((QTD_NODES - 1))

for N in $(seq 0 $WORKER_NODES); do
    IP="${IPS[$N]}"

    echo "   Aguardando Node $N com $IP: "
    while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$IP "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { printf "."; sleep 1; } done
    echo "   Conectado ao $IP, verificando ajustes: "
done

# bash, nao sh: o ajustar.sh usa arrays e mapfile.
bash ajustar.sh

echo ""
echo " Ambiente iniciado e configurado"
