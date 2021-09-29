terraform init; terraform plan; terraform apply -auto-approve
echo ""
echo " Iniciando configurações: "

# Aguardando Nodes
export QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')

for N in $(seq 0 $QTD_NODES); do
    IP=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    
    echo "   Aguardando Node $N com $IP: "
    while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { echo .; sleep 1; } done
    echo "   Conectado ao $IP, verificando ajustes: "
done

sh ajustar.sh

echo ""
echo " Cluster iniciado e configurado"
