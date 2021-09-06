# Criar e Configurar Portworx

MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')

printf "\n\n"
echo "   CONFIGURANDO OS VOLUMES: PORTWORX"
printf "\n\n"
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < k8s_config_volume_portworx.sh
# Cron para detectar rapidamente falha nos nodes
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < k8s_config_cron.sh
# configurar um Storage Class default no cluster
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'kubectl create -f https://tonanuvem.github.io/k8s-exemplos/storageclass_default_portworx.yaml'
