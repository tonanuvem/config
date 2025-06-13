#!/bin/bash

# Aguardando:
echo ""
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

# Corrigido: extraindo IPs da nova estrutura do output
MASTER=$(terraform output -json ip_externo | jq -r '.[0]')
QTD_NODES=$(terraform output -json ip_externo | jq '. | length')
WORKER_NODES=$(expr $QTD_NODES - 1)
user=ubuntu

echo "   Debug - Configurando inventário com:"
echo "   Master: $MASTER"
echo "   Quantidade total de nodes: $QTD_NODES"
echo "   Worker nodes: $WORKER_NODES"

# configurar inventario ansible
echo '[masters]' > inv.hosts
echo "master ansible_ssh_host=$MASTER" >> inv.hosts
echo '' >> inv.hosts
echo '[nodes]' >> inv.hosts

for N in $(seq 1 $WORKER_NODES); do
    NODE=$(terraform output -json ip_externo | jq -r ".[$N]")
    echo "node$N ansible_ssh_host=$NODE" >> inv.hosts
    echo "   Worker Node $N: $NODE"
done

echo ""
echo "   Inventário gerado (inv.hosts):"
cat inv.hosts
echo ""

echo "   Executando playbooks Ansible..."

echo "   1/6 - Configurando hostnames..."
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --inventory inv.hosts -u $user --key-file ~/environment/labsuser.pem

echo "   2/6 - Configurando hosts..."
ansible-playbook ~/environment/config/ansible/ansible_hosts.yml --inventory inv.hosts -u $user --key-file ~/environment/labsuser.pem

echo "   3/6 - Instalando utilitários..."
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory inv.hosts -u $user --key-file ~/environment/labsuser.pem

echo "   4/6 - Instalando Docker..."
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory inv.hosts -u $user --key-file ~/environment/labsuser.pem

echo "   5/6 - Configurando Kubernetes..."
ansible-playbook ~/environment/config/ansible/ansible_k8s.yml --inventory inv.hosts -u $user --key-file ~/environment/labsuser.pem

echo "   6/6 - Configurando storage, Helm e WordPress..."
ansible-playbook ~/environment/config/ansible/k8s_storage_helm_wordpress.yml --inventory inv.hosts -u $user --key-file ~/environment/labsuser.pem

echo ""
echo "   Configuração concluída!"
