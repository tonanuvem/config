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
# O inventario e gravado fora do clone deste repositorio quando o
# fiaplab.sh informa FIAPLAB_INVENTORY (aponta para /tmp/fiap/inventory).
# O default preserva o comportamento antigo para quem roda o script
# direto, na mao.
INV="${FIAPLAB_INVENTORY:-inv.hosts}"

mkdir -p "$(dirname "$INV")"

echo '[masters]' > "$INV"
echo "master ansible_ssh_host=$MASTER" >> "$INV"
echo '' >> "$INV"
echo '[nodes]' >> "$INV"

for N in $(seq 1 $WORKER_NODES); do
    NODE=$(terraform output -json ip_externo | jq -r ".[$N]")
    echo "node$N ansible_ssh_host=$NODE" >> "$INV"
    echo "   Worker Node $N: $NODE"
done

echo ""
echo "   Inventário gerado ($INV):"
cat "$INV"
echo ""

echo "   Executando playbooks Ansible..."

echo "   1 - Configurando hostnames..."
ansible-playbook ~/environment/config/ansible/ansible_hostname.yml --inventory "$INV" -u $user --key-file ~/environment/labsuser.pem

echo "   2 - Configurando hosts..."
ansible-playbook ~/environment/config/ansible/ansible_hosts.yml --inventory "$INV" -u $user --key-file ~/environment/labsuser.pem

echo "   3 - Instalando utilitários..."
ansible-playbook ~/environment/config/ansible/ansible_utils.yml --inventory "$INV" -u $user --key-file ~/environment/labsuser.pem

echo "   4 - Instalando Docker..."
ansible-playbook ~/environment/config/ansible/ansible_docker.yml --inventory "$INV" -u $user --key-file ~/environment/labsuser.pem

echo "   5 - Configurando Kubernetes..."
ansible-playbook ~/environment/config/ansible/ansible_k8s_azure_vm.yml --inventory "$INV" -u $user --key-file ~/environment/labsuser.pem

echo "   6 - Configurando storage, Helm..."
ansible-playbook ~/environment/config/ansible/k8s_storage_helm_wordpress.yml --inventory "$INV" -u $user --key-file ~/environment/labsuser.pem

echo "   7 - Configurando VSCode Server e Azure CLI..."
ansible-playbook ~/environment/config/ansible/ansible_code_server_ubuntu.yml --inventory "$INV" -u ubuntu --key-file ~/environment/labsuser.pem
ansible-playbook ~/environment/config/ansible/ansible_azure_cli.yml --inventory "$INV" -u ubuntu --key-file ~/environment/labsuser.pem

echo ""
echo "   Configuração concluída!"
