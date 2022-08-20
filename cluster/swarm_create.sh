#NODE1=$(terraform output Node_1_ip_externo)
MASTER=$(terraform output Node_1_ip_externo)
NODE2=$(terraform output Node_2_ip_externo)
NODE3=$(terraform output Node_3_ip_externo)

# Criando arquivos vazios para receber os comandos
> master.sh
> workers.sh

# CONFIGURANDO O MASTER utilizando o DOCKER SWARM INIT:"
### CONFIGURANDO O MASTER via SSH
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\NODE 1:\n"
echo ""
echo "   Aguardando configurações: "

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

echo "sudo $TOKEN" >> workers.sh

# Exemplo:
# docker swarm join --token SWMTKN-1-28amdt0x5r4mbc5092t1w016392emlqv67lyhasph200d6tdhl-41rxupxdsjg9zo00xtdlwon5p 10.1.1.97:2377
printf "\n\n"
echo "CONFIGURANDO OS NODES - JOIN:"

echo "   CONFIGURANDO NODE 2 :  JOIN"
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE2 'bash -s' < workers.sh
echo ""
echo "   CONFIGURANDO NODE 3 :  JOIN"
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE3 'bash -s' < workers.sh
echo ""

printf "\n\n"
echo "   VERIFICANDO NODES :"
printf "\n\n"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker node ls'

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker node ls'
printf "\n\n"
