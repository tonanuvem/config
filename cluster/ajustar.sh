# Aguardando:
echo ""
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
#sleep 10
# Aguardando Node1
export IP=$(terraform output Node_1_ip_externo)
echo "   Aguardando configurações do $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO1" | grep CONECTADO1 | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
# Aguardando Node2
export IP=$(terraform output Node_2_ip_externo)
echo "   Aguardando configurações do $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO2" | grep CONECTADO2 | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "
# Aguardando Node3
export IP=$(terraform output Node_3_ip_externo)
echo "   Aguardando configurações do $IP: "
while [ $(ssh -q -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$IP "echo CONECTADO3" | grep CONECTADO3 | wc -l) != '1' ]; do { printf .; sleep 1; } done
echo "   Conectado ao $IP, verificando ajustes: "

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
