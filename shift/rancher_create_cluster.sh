# conectar no master e configurar
# https://rancher.com/adding-custom-nodes-kubernetes-cluster-rancher-2-0-tech-preview-2

MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

> master.sh

# CONFIGURANDO O MASTER utilizando o DOCKER SWARM INIT:"
### CONFIGURANDO O MASTER via SSH
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tMASTER:\n"
echo ""
echo "   Aguardando configurações: "

#echo "sudo docker run --privileged -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher" >> master.sh

ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < rancher_server.sh

# Get Token
DOCKERRUNCMD=$(ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'cat DOCKERRUNCMD')
# Echo command
echo $DOCKERRUNCMD
TOKEN=$DOCKERRUNCMD

#TOKEN=$(ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker swarm join-token manager | grep docker')
# Remover espacos
TOKEN=`echo $TOKEN | sed 's/ *$//g'`
printf "\n\n"
echo $TOKEN
printf "\n\n"
echo "   TOKEN ACIMA : CLUSTER JOIN"
printf "\n\n"

### CONFIGURANDO OS NODES utilizando o DOCKER SWARM JOIN:

echo $TOKEN > workers.sh

printf "\n\n"
echo "CONFIGURANDO OS NODES - JOIN:"

for N in $(seq 1 $WORKER_NODES); do
    printf "\n\n"
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "   CONFIGURANDO NODE $N ($NODE): JOIN"
    ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE 'bash -s' < workers.sh
done

### CONCLUINDO

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
echo "   Acessar Rancher URL = http://fiap.${MASTER}.nip.io"
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'docker node ls'
printf "\n\n"
