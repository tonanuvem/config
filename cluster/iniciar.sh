terraform init; terraform plan; terraform apply -auto-approve
echo ""
echo " Iniciando configurações: "
# Aguardando Node1
export IP=$(terraform output Node_1_ip_externo)
echo "   Aguardando Node1 com $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
# Aguardando Node2
export IP=$(terraform output Node_2_ip_externo)
echo "   Aguardando Node2 com $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO2" | grep CONECTADO2 | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
# Aguardando Node3
export IP=$(terraform output Node_3_ip_externo)
echo "   Aguardando Node3 com $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO3" | grep CONECTADO3 | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
sh ajustar.sh
#sh config-node1.sh
#sh config-node2.sh
#sh config-node3.sh
echo ""
echo " Cluster iniciado e configurado"
