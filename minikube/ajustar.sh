export VM=$(terraform output ip_externo)

# configurar inventario ansible
echo '[nodes]' > hosts
echo "minikube ansible_ssh_host=$VM" >> hosts
echo '' >> hosts

export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_minikube.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
