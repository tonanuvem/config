echo ""

terraform init; terraform plan -out main.tfplan; terraform apply -auto-approve main.tfplan 
echo ""
echo "   Aguardando configurações: "
sleep 10
echo "   Salvando a chave privada em arquivo (~/environment/labsuser.pem): "
terraform output -raw private_key_pem > ~/environment/labsuser.pem
chmod 600 ~/environment/labsuser.pem

MASTER=$(terraform output -json ip_externo | jq .[0] | jq .[] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '. | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

# Aguardando Master
export IP=$MASTER
echo "   Aguardando Master com IP = $MASTER: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$MASTER "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao MASTER"

# Aguardando Nodes
for N in $(seq 1 $WORKER_NODES); do
    NODE=$(terraform output -json ip_externo | jq .[$N] | jq .[] | sed 's/"//g')
    echo "   Aguardando Node $N com IP = $NODE: "
    while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$NODE "echo CONECTADONODE" | grep CONECTADONODE | wc -l) != '1' ]; do { printf .; sleep 1; } done
    echo "   Conectado ao Node $N"
done

echo ""
echo "---"
echo "   Realizando ajustes (usando o Ansible): "
sh ajustar.sh

echo ""
echo " Nodes (VMs) iniciados e configurados"
echo ""
echo "   OBS: Caso alguma das tarefas anteriores tenha obtido FAILED, executar: sh ajustar.sh"
echo ""
