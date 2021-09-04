# Aguardando:
echo ""
#sleep 10

MASTER=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_0/) ) { print $1} }')
NODE1=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_1/) ) { print $1} }')
NODE2=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_2/) ) { print $1} }')
NODE3=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_3/) ) { print $1} }')

# configurar hostnames
MASTER > hosts &&
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=master" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
NODE1 > hosts &&
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=node1" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
NODE2 > hosts && 
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=node2" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
NODE3 > hosts &&
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=node3" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem

# aplicar configurações
terraform output Node_1_ip_externo > hosts && terraform output Node_2_ip_externo >> hosts && terraform output Node_3_ip_externo >> hosts
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem &&
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem &&
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
