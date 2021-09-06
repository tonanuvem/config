# Aguardando:
echo ""
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
#sleep 10

export MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
export QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
export WORKER_NODES=$(expr $QTD_NODES - 1)
#NODE1=$(terraform output -json ip_externo | jq .[] | jq .[1])
#NODE2=$(terraform output -json ip_externo | jq .[] | jq .[2])
#NODE3=$(terraform output -json ip_externo | jq .[] | jq .[3])
#MASTER=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_0/) ) { print $1} }')
#NODE1=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_1/) ) { print $1} }')
#NODE2=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_2/) ) { print $1} }')
#NODE3=$(~/environment/ip | awk -Fv '{ if ( !($1 ~  "None") && (/vm_3/) ) { print $1} }')

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

# configurar hostnames
#echo $MASTER > hosts &&
#echo " Ajustando hostname do "
#ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=master" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
#for N in $(seq 1 $WORKER_NODES); do
#    echo " Ajustando hostname do NODE $N"
#    NODE=$(terraform output -json ip_externo | jq .[] | jq .[$N]) 
#    echo $NODE > hosts
#    ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=worker$N" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
#done

#echo $NODE1 > hosts &&
#ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=worker1" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
#echo $NODE2 > hosts && 
#ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=worker2" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
#echo $NODE3 > hosts &&
#ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --extra-vars "nome=worker3" --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem

# aplicar configurações
#printf  "$MASTER\n$NODE1\n$NODE2\n$NODE3" > hosts
terraform output -json ip_externo | jq .[0] | jq .[] > hosts
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_hosts.yml --inventory inv.hosts -u ec2-user --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem &&
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem &&
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory hosts -u ec2-user --key-file ~/environment/labsuser.pem
