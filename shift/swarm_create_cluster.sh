# conectar no master e configurar

# ~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") ) { print } }'
# ~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") ) { print } }'

MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

#MASTER=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_0/) ) { print $1} }')
#NODE1=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_1/) ) { print $1} }')
#NODE2=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_2/) ) { print $1} }')
#NODE3=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_3/) ) { print $1} }')
#echo "IPs configurados :"
#echo "MASTER = $MASTER"
#echo "NODE1 = $NODE1"
#echo "NODE2 = $NODE2"
#echo "NODE3 = $NODE3"

# reset arquivos vazios dos scripts:
> master.sh
#> worker1.sh
#> worker2.sh
#> worker3.sh

# CONFIGURANDO O MASTER utilizando o DOCKER SWARM INIT:"
### CONFIGURANDO O MASTER via SSH
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tMASTER:\n"
echo ""
echo "   Aguardando configurações: "

#echo "while [ \$(ls /usr/local/bin/ | grep docker-compose | wc -l) != '1' ]; do { printf .; sleep 1; } done" >> master.sh
#echo "sudo hostnamectl set-hostname master" >> master.sh
echo "sudo docker swarm init" >> master.sh

ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < master.sh

# Get Token
TOKEN=$(ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker swarm join-token manager | grep docker')
# Remover espacos
TOKEN=`echo $TOKEN | sed 's/ *$//g'`
printf "\n\n"
echo $TOKEN
printf "\n\n"
echo "   TOKEN ACIMA : CLUSTER JOIN"
printf "\n\n"

### CONFIGURANDO OS NODES utilizando o DOCKER SWARM JOIN:

#echo "while [ \$(ls /usr/local/bin/ | grep docker-compose | wc -l) != '1' ]; do { printf .; sleep 1; } done" >> worker1.sh
#echo "while [ \$(ls /usr/local/bin/ | grep docker-compose | wc -l) != '1' ]; do { printf .; sleep 1; } done" >> worker2.sh
#echo "while [ \$(ls /usr/local/bin/ | grep docker-compose | wc -l) != '1' ]; do { printf .; sleep 1; } done" >> worker3.sh
#echo "sudo hostnamectl set-hostname node1" >> worker1.sh
#echo "sudo hostnamectl set-hostname node2" >> worker2.sh
#echo "sudo hostnamectl set-hostname node3" >> worker3.sh
#echo "sudo $TOKEN" >> worker1.sh
#echo "sudo $TOKEN" >> worker2.sh
#echo "sudo $TOKEN" >> worker3.sh
echo "sudo $TOKEN" >> workers.sh

# Exemplo:
# docker swarm join --token SWMTKN-1-28amdt0x5r4mbc5092t1w016392emlqv67lyhasph200d6tdhl-41rxupxdsjg9zo00xtdlwon5p 10.1.1.97:2377
printf "\n\n"
echo "CONFIGURANDO OS NODES - JOIN:"

for N in $(seq 1 $WORKER_NODES); do
    printf "\n\n"
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "   CONFIGURANDO NODE $N ($NODE): KUBEADM JOIN"
    ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE 'bash -s' < workers.sh
done

#printf "\n\n"
#echo "   CONFIGURANDO NODE 1:  JOIN"
#printf "\n\n"
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE1 'bash -s' < worker1.sh
#printf "\n\n"
#echo "   CONFIGURANDO NODE 2: JOIN"
#printf "\n\n"
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE2 'bash -s' < worker2.sh
#printf "\n\n"
#echo "   CONFIGURANDO NODE 3: JOIN"
#printf "\n\n"
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE3 'bash -s' < worker3.sh

printf "\n\n"
echo "   VERIFICANDO NODES NO MASTER :"
printf "\n\n"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker node ls'

### CONFIGURANDO OS VOLUMES 
#printf "\n\n"
#echo "   CONFIGURANDO ETCD no MASTER:"
#printf "\n\n"
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < config_etcd.sh
#printf "\n\n"
#echo "   CONFIGURANDO OS VOLUMES: PORTWORX"
#printf "\n\n"
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < config_volume_portworx.sh
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE1 'bash -s' < config_volume_portworx.sh
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE2 'bash -s' < config_volume_portworx.sh
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE3 'bash -s' < config_volume_portworx.sh

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker node ls'
printf "\n\n"
