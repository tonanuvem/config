# Aguardando:
echo "Ajustando configurações:"
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
#sleep 10

export QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
export WORKER_NODES=$(expr $QTD_NODES - 1)

# configurar inventario ansible
echo '[nodes]' > inv.hosts

for N in $(seq 0 $WORKER_NODES); do
    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "node$N ansible_ssh_host=$NODE" >> inv.hosts
done

### AJUSTANDO via SSH
echo ""
echo "AJUSTANDO via SSH o NODE $NODE"
echo ""
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE 'bash -s' < 'mkdir ~/environment/'
ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE 'bash -s' < 'git clone https://github.com/tonanuvem/config'

#ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --inventory inv.hosts -u ubuntu --key-file ~/environment/labsuser.pem
#ansible-playbook ~/environment/config/ansible/ansible_hosts.yml --inventory inv.hosts -u ubuntu --key-file ~/environment/labsuser.pem
#ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory inv.hosts -u ubuntu --key-file ~/environment/labsuser.pem
#ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory inv.hosts -u ubuntu --key-file ~/environment/labsuser.pem
#ansible-galaxy collection install community.general
#ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory inv.hosts -u ubuntu --key-file ~/environment/labsuser.pem
#ansible-playbook ~/environment/config/ansible/ansible_microk8s.yml --inventory inv.hosts -u ubuntu --key-file ~/environment/labsuser.pem
