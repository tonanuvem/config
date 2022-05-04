terraform init; terraform plan; terraform apply -auto-approve
echo ""
echo " Iniciando configurações: "
MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

# Aguardando Master
export IP=$MASTER
echo "   Aguardando Master com $MASTER: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { echo .; sleep 1; } done
echo "   Conectado ao MASTER com IP = $MASTER"

# Aguardando Nodes
for N in $(seq 1 $WORKER_NODES); do
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "   Aguardando Node $N: "
    while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE "echo CONECTADONODE" | grep CONECTADONODE | wc -l) != '1' ]; do { echo .; sleep 1; } done
    echo "   Conectado ao Node $N com IP = $NODE"
done

echo "   Realizando ajustes (usando o Ansible): "
sh ajustar.sh

echo ""
echo " Nodes (VMs) iniciados e configurados"
