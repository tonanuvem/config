# conectar no master e configurar

MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

# Criando arquivos vazios para receber os comandos
> master.sh
> workers.sh

# CONFIGURANDO O MASTER utilizando o DOCKER SWARM INIT:"
### CONFIGURANDO O MASTER via SSH
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tMASTER:\n"
echo ""
echo "   Aguardando configurações: "

echo "sudo docker swarm init" >> master.sh
# echo "sudo docker swarm init --advertise-addr eth0:2377" >> master.sh
# echo "sudo docker swarm init --advertise-addr \$(curl checkip.amazonaws.com):2377" >> master.sh

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

echo "sudo $TOKEN" >> workers.sh

# Exemplo:
# docker swarm join --token SWMTKN-1-28amdt0x5r4mbc5092t1w016392emlqv67lyhasph200d6tdhl-41rxupxdsjg9zo00xtdlwon5p 10.1.1.97:2377
printf "\n\n"
echo "CONFIGURANDO OS NODES - JOIN:"

for N in $(seq 1 $WORKER_NODES); do
    printf "\n\n"
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "   CONFIGURANDO NODE $N ($NODE): JOIN"
    ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE 'bash -s' < workers.sh
done

printf "\n\n"
echo "   VERIFICANDO NODES NO MASTER :"
printf "\n\n"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker node ls'

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker node ls'
printf "\n\n"
