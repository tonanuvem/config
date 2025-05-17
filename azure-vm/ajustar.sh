export VM=$(terraform output -raw ip_externo)

# configurar inventario ansible
echo '[nodes]' > hosts
echo "vm-fiap ansible_ssh_host=$VM" >> hosts
echo '' >> hosts

export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --inventory hosts -u ubuntu --key-file ~/environment/labsuser.pem # --extra-vars "checar_Ambiente=sim"
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory hosts -u ubuntu --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory hosts -u ubuntu --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory hosts -u ubuntu --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_dev_java.yml --inventory hosts -u ubuntu --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_code_server_ubuntu.yml --inventory hosts -u ubuntu --key-file ~/environment/labsuser.pem
