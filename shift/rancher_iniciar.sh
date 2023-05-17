terraform init; terraform plan; terraform apply -auto-approve
echo ""
echo " Iniciando configurações: "
RANCHER_SERVER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

# Aguardando Master
export IP=$RANCHER_SERVER
echo "   Aguardando RANCHER_SERVER com IP = $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao RANCHER_SERVER"

# Aguardando Nodes
for N in $(seq 1 $WORKER_NODES); do
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "   Aguardando Node $N com IP = $NODE: "
    while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE "echo CONECTADONODE" | grep CONECTADONODE | wc -l) != '1' ]; do { printf .; sleep 1; } done
    echo "   Conectado ao Node $N"
done

echo ""
echo "---"
echo "   Realizando ajustes (usando o Ansible): "
sh rancher_ajustar.sh

echo ""
echo " Nodes (VMs) iniciados e configurados"
echo ""
echo "   OBS: Caso alguma das tarefas anteriores tenha obtido FAILED, executar: sh rancher_ajustar.sh"
echo ""
