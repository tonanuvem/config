# Aguardando:
echo ""
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
#sleep 10

# configurar hostnames
terraform output Node_1_ip_externo > hosts &&
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=node1" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
terraform output Node_2_ip_externo > hosts && 
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=node2" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
terraform output Node_3_ip_externo > hosts &&
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=node3" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem

# aplicar configurações
terraform output Node_1_ip_externo > hosts && terraform output Node_2_ip_externo >> hosts && terraform output Node_3_ip_externo >> hosts
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem &&
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem &&
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
