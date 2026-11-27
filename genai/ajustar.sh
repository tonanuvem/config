# Aguardando:
echo ""
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
export ANSIBLE_HOST_KEY_CHECKING=false

export MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
export QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
export WORKER_NODES=$(expr $QTD_NODES - 1)

# configurar inventario ansible
echo '[masters]' > inv.hosts
echo "master ansible_ssh_host=$MASTER" >> inv.hosts
echo '' >> inv.hosts
echo '[nodes]' >> inv.hosts
for N in $(seq 1 $WORKER_NODES); do
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "node$N ansible_ssh_host=$NODE" >> inv.hosts
done

ANS="ansible-playbook --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem"
BASE=~/environment/config/ansible

$ANS $BASE/ansible_hostname.yml
$ANS $BASE/ansible_hosts.yml
$ANS $BASE/ansible_utils.yml
$ANS $BASE/ansible_docker.yml
$ANS $BASE/ansible_k8s.yml

# Especifico deste lab: formata e monta /dev/xvdb em /models, e afrouxa os
# buffers de TCP. O k8s_storage_helm_wordpress.yml do shift NAO entra aqui --
# e do lab de volumes, nao tem nada a ver com inferencia.
$ANS $BASE/ansible_genai_storage.yml
