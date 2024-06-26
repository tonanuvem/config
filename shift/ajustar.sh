# Aguardando:
echo ""
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
#sleep 10

export MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
export QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
export WORKER_NODES=$(expr $QTD_NODES - 1)

# configurar inventario ansible
echo '[masters]' > inv.hosts
echo "master ansible_ssh_host=$MASTER" >> inv.hosts
echo '' >> inv.hosts
echo '[nodes]' >> inv.hosts
#for N in $(seq 0 $WORKER_NODES); do
for N in $(seq 1 $WORKER_NODES); do
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "node$N ansible_ssh_host=$NODE" >> inv.hosts
done

ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem # --extra-vars "checar_Ambiente=sim"
ansible-playbook ~/environment/config/ansible/ansible_hosts.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/k8s_storage_helm_wordpress.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
