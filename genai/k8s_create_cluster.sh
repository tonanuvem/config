# conectar no master e configurar

export DIRETORIO='/home/ec2-user'
# ~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") ) { print } }'

MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
WORKER_NODES=$(expr $QTD_NODES - 1)

# Criando arquivos vazios para receber os comandos
> master.sh
> workers.sh

echo "IPs configurados :"
echo "MASTER = $MASTER"

# CONFIGURANDO O MASTER utilizando o KUBEADM INIT:

echo "Aguardando instalação do KUBEADM."

echo "kubeadm version" >> master.sh
echo "sudo kubeadm config images pull" >> master.sh
# O endpoint do control plane vai no IP PRIVADO, nao no publico.
#
# Com $(curl checkip.amazonaws.com) -- como era aqui e no shift -- o endpoint
# ficava gravado no IP publico, e isso custa o cluster inteiro toda vez que o
# lab encerra a sessao: o Learner Lab para as instancias e as reinicia na
# sessao seguinte, e sem Elastic IP o IP publico vem outro. Ai o endpoint
# gravado no kubeconfig e nos SANs do certificado do apiserver nao batem mais
# com a maquina, e o unico caminho e refazer o kubeadm init. O shift ja esta
# corrigido do mesmo jeito.
#
# O IP privado primario, ao contrario, e preservado atraves de stop/start
# enquanto a instancia existir. Como o fluxo deste lab e "ssh no master e
# roda kubectl la dentro", um endpoint privado atende: o kubectl roda dentro
# do VPC. Quem quiser kubectl de fora usa "ssh -L 6443:localhost:6443".
echo "sudo kubeadm init --control-plane-endpoint \$(hostname -I | awk '{print \$1}'):6443" >> master.sh

### INICIANDO O MASTER via SSH
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < master.sh

#	Configurar o cliente kubectl:
echo "mkdir -p $DIRETORIO/.kube" > master.sh
echo "sudo cp -i /etc/kubernetes/admin.conf $DIRETORIO/.kube/config" >> master.sh
#echo "sudo chown $(id -u):$(id -g) $DIRETORIO/.kube/config" >> master.sh
echo "sudo chown \$(id -u):\$(id -g) $DIRETORIO/.kube/config" >> master.sh

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

### STORAGE: local-path como default
# Nao e compartilhado entre nos -- o volume e local. Para os GGUF, o que vale
# e o /models do no 0 (ver ansible_genai_storage.yml) e o cache no S3.
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER '
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml
  kubectl patch storageclass local-path -p "{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}"
'

### METRICAS
echo ""
echo "   Instalando metrics-server:"
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < k8s_config_metrics.sh

printf "\n\n"
echo "   CONFIGURAÇÕES REALIZADAS. FIM."
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'kubectl get nodes -o wide'
printf "\n\n"
echo "   O master fica com o taint de control-plane: os ranks de inferencia"
echo "   vao nos workers. Um pod por no, senao dois ranks dividem a banda de"
echo "   memoria do mesmo no e a medicao perde o sentido."
printf "\n\n"
