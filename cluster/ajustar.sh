# Aguardando:
echo ""
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
#sleep 10

# configurar inventario ansible
echo '' > inv.hosts
echo '[nodes]' >> inv.hosts
NODE1=$(terraform output -raw Node_1_ip_externo)
echo "node1 ansible_ssh_host=$NODE1" >> inv.hosts
NODE2=$(terraform output -raw Node_2_ip_externo)
echo "node2 ansible_ssh_host=$NODE2" >> inv.hosts
NODE3=$(terraform output -raw Node_3_ip_externo)
echo "node3 ansible_ssh_host=$NODE3" >> inv.hosts

# aplicar configurações
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem # --extra-vars "checar_Ambiente=sim"
ansible-playbook ~/environment/config/ansible/ansible_hosts.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/k8s_storage_helm_wordpress.yml  --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
