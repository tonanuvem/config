# conectar no master e configurar
# https://rancher.com/adding-custom-nodes-kubernetes-cluster-rancher-2-0-tech-preview-2

RANCHER_SERVER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

### CONFIGURANDO via SSH
printf "\n\n xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \n"
printf "\n\n\tRANCHER_SERVER:\n"
echo ""
echo "   Aguardando configurações: "

ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$RANCHER_SERVER 'bash -s' < rancher_config_credenciais.sh

ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$RANCHER_SERVER 'bash -s' < rancher_config_cli_create.sh

# Get Token
DOCKERRUNCMD=$(ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$RANCHER_SERVER 'cat JOINTOKEN')
# Echo command
echo $DOCKERRUNCMD

# Remover espacos
# TOKEN=$DOCKERRUNCMD
# TOKEN=`echo $TOKEN | sed 's/ *$//g'`
echo $DOCKERRUNCMD > rancher_join_token.sh

# Ajustar Server:
sed -i 's|--server|--server https://fiap.'$RANCHER_SERVER'.nip.io |' rancher_join_token.sh
#sed -i 's|sudo docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run rancher/rancher-agent:v2.7.3 --server|curl --insecure -fL https://fiap.34.227.89.181.nip.io/system-agent-install.sh; sudo  sh -s - --server https://fiap.'$RANCHER_SERVER'.nip.io --label "cattle.io/os=linux" |' rancher_join_token.sh
printf "\n\n"
echo "   TOKEN ABAIXO : CLUSTER JOIN"
cat rancher_join_token.sh
printf "\n\n"

### CONFIGURANDO OS NODES :

printf "\n\n"
echo "CONFIGURANDO OS NODES - JOIN:"

for N in $(seq 1 $WORKER_NODES); do
    printf "\n\n"
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "   CONFIGURANDO NODE $N ($NODE): JOIN"
    ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE 'bash -s' < rancher_join_token.sh
done

### CONCLUINDO

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
echo "   Acessar Rancher URL = http://fiap.${RANCHER_SERVER}.nip.io"
echo ""
echo "   Username : admin"
echo "   Senha    : fiapfiapfiap"
#echo "   Senha de Bootstrap:"
echo ""
#ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$RANCHER_SERVER 'docker logs rancherserver 2>&1 | grep "Bootstrap Password:"'
printf "\n\n"
