NODE1=$(terraform output -raw Node_1_ip_externo)
NODE2=$(terraform output -raw Node_2_ip_externo)
NODE3=$(terraform output -raw Node_3_ip_externo)

# Criando arquivos vazios para receber os comandos
> init.sh
> token.sh

# CONFIGURANDO O NODE1 utilizando o DOCKER SWARM INIT:"
### CONFIGURANDO O NODE1 via SSH
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\nNODE 1:\n"
echo ""
echo "   Aguardando configurações: "

echo "sudo docker swarm init" >> init.sh
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE1 'bash -s' < init.sh

# Get Token
TOKEN=$(ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE1 'docker swarm join-token manager | grep docker')
# Remover espacos
TOKEN=`echo $TOKEN | sed 's/ *$//g'`
printf "\n\n"
echo $TOKEN
printf "\n\n"
echo "   TOKEN ACIMA : CLUSTER JOIN"
printf "\n\n"

### CONFIGURANDO OS NODES utilizando o DOCKER SWARM JOIN:

echo "sudo $TOKEN" >> token.sh

# Exemplo:
# docker swarm join --token SWMTKN-1-28amdt0x5r4mbc5092t1w016392emlqv67lyhasph200d6tdhl-41rxupxdsjg9zo00xtdlwon5p 10.1.1.97:2377
printf "\n\n"
echo "CONFIGURANDO OS NODES - JOIN:"

echo "   CONFIGURANDO NODE 2 :  JOIN"
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE2 'bash -s' < token.sh
echo ""
echo "   CONFIGURANDO NODE 3 :  JOIN"
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE3 'bash -s' < token.sh
echo ""

printf "\n\n"
echo "   VERIFICANDO NODES :"
printf "\n\n"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE1 'docker node ls'

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
printf "\n\n"
