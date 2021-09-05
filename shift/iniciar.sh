terraform init; terraform plan; terraform apply -auto-approve
echo ""
echo " Iniciando configurações: "
MASTER=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_0/) ) { print $1} }')
NODE1=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_1/) ) { print $1} }')
NODE2=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_2/) ) { print $1} }')
NODE3=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_3/) ) { print $1} }')
echo "IPs configurados :"
echo "MASTER = $MASTER"
echo "NODE1 = $NODE1"
echo "NODE2 = $NODE2"
echo "NODE3 = $NODE3"

# Aguardando Master
export IP=$MASTER
echo "   Aguardando Node1 com $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { echo .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
# Aguardando Node1
export IP=$NODE1
echo "   Aguardando Node1 com $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { echo .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
# Aguardando Node2
export IP=$NODE2
echo "   Aguardando Node2 com $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO2" | grep CONECTADO2 | wc -l) != '1' ]; do { echo .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
# Aguardando Node3
export IP=$NODE3
echo "   Aguardando Node3 com $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO3" | grep CONECTADO3 | wc -l) != '1' ]; do { echo .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "

sh ajustar.sh

echo ""
echo " Cluster iniciado e configurado"