# conectar no master e configurar

export DIRETORIO='/home/ec2-user'
# ~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") ) { print } }'

MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

echo "IPs configurados :"
echo "MASTER = $MASTER"
> master.sh

# CONFIGURANDO O MASTER utilizando o KUBEADM INIT:

echo "Aguardando instalação do KUBEADM."

echo "kubeadm version" >> master.sh
echo "sudo kubeadm config images pull" >> master.sh
echo "sudo kubeadm init --control-plane-endpoint \$(curl checkip.amazonaws.com):6443" >> master.sh

### INICIANDO O MASTER via SSH
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < master.sh

#	Configurar o cliente kubectl:
echo "mkdir -p $DIRETORIO/.kube" > master.sh
echo "sudo cp -i /etc/kubernetes/admin.conf $DIRETORIO/.kube/config" >> master.sh
echo "sudo chown $(id -u):$(id -g) $DIRETORIO/.kube/config" >> master.sh

### CONFIGURANDO O MASTER via SSH
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < master.sh
# Get Token
TOKEN=$(ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'sudo kubeadm token create --print-join-command')
printf "\n\n"
echo $TOKEN
printf "\n\n"
echo "   TOKEN ACIMA : KUBEADM JOIN"
printf "\n\n"
echo "Master do Cluster foi inicializado. Agora vamos configurar a rede do cluster."
# Configurar a rede do cluster:
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < k8s_config_network_weave.sh

### CONFIGURANDO OS NODES utilizando o KUBEADM JOIN:

# Exemplo:
# kubeadm join 10.0.1.169:6443 --token fdwf9o.om0jvrom7uv3eeg4 \
#    --discovery-token-ca-cert-hash sha256:46abcfc7e371878b78f1071a7e396a3b1f1e851cbec76e65f0030d3f73411fd1
printf "\n\n"
echo "CONFIGURANDO OS NODES utilizando o KUBEADM JOIN:"

echo "sudo $TOKEN" > workers.sh

for N in $(seq 1 $WORKER_NODES); do
    printf "\n\n"
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "   CONFIGURANDO NODE $N ($NODE): KUBEADM JOIN"
    ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE 'bash -s' < workers.sh
done

echo "   VERIFICANDO NODES NO MASTER :"
printf "\n\n"
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'kubectl get nodes'

### CONFIGURANDO OS VOLUMES 
#sh k8s_criar_volume_portworx.sh

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'kubectl get nodes'
printf "\n\n"
