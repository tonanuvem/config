#!/bin/bash

# ============================================================
# CONFIGURAÇÕES
# ============================================================

export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

cd ~/environment/config/ubuntu-vm || exit 1

# ============================================================
# LOCALIZAR ANSIBLE
# ============================================================

ANSIBLE_PLAYBOOK="$(command -v ansible-playbook 2>/dev/null || true)"

if [ -z "$ANSIBLE_PLAYBOOK" ]; then

    if [ -x "/tmp/fiap/ansible_venv/bin/ansible-playbook" ]; then
        ANSIBLE_PLAYBOOK="/tmp/fiap/ansible_venv/bin/ansible-playbook"
    else
        echo ""
        echo "❌ ansible-playbook não encontrado!"
        echo ""
        echo "Verifique a instalação do Ansible no CloudShell."
        exit 1
    fi

fi

echo ""
echo "ANSIBLE:"
echo "$ANSIBLE_PLAYBOOK"
echo ""

# ============================================================
# OBTENDO NODES
# ============================================================

# Achata o array (mesmo que venha bidimensional [["IP"]]) para obter todos os IPs
IPS=($(terraform output -json ip_externo | jq -r '.[][]'))
QTD_NODES=${#IPS[@]}

if [ "$QTD_NODES" -eq 0 ]; then
    echo "❌ Erro: Nenhum IP encontrado no output do Terraform."
    exit 1
fi

WORKER_NODES=$((QTD_NODES - 1))

echo "Quantidade de Nodes: $QTD_NODES"
echo ""

# ============================================================
# INVENTÁRIO ANSIBLE
# ============================================================

echo '[nodes]' > inv.hosts

for N in $(seq 0 "$WORKER_NODES"); do
    NODE="${IPS[$N]}"
    echo "node$N ansible_ssh_host=$NODE" >> inv.hosts
done

echo "Inventário:"
cat inv.hosts
echo ""

# ============================================================
# SCP
# ============================================================

echo ""
echo "============================================================"
echo "        COPIANDO ARQUIVOS PARA A EC2"
echo "============================================================"
echo ""

for N in $(seq 0 "$WORKER_NODES"); do
    NODE="${IPS[$N]}"

    echo "Copiando arquivos para $NODE..."

    # Cria diretórios necessários
    ssh -o StrictHostKeyChecking=no \
        -i ~/environment/labsuser.pem \
        ubuntu@"$NODE" \
        "mkdir -p /home/ubuntu/environment /home/ubuntu/.aws"

    # Copia SOMENTE config
    scp -q \
        -i ~/environment/labsuser.pem \
        -r ~/environment/config \
        ubuntu@"$NODE":/home/ubuntu/environment/

    # Copia credenciais AWS
    scp -q \
        -i ~/environment/labsuser.pem \
        ~/environment/credenciais/credentials \
        ubuntu@"$NODE":/home/ubuntu/.aws/credentials

    echo "✅ Arquivos copiados para $NODE"
    echo ""

    echo "Copiando labsuser.pem para $NODE..."

    # Garante que o diretório exista
    ssh -o StrictHostKeyChecking=no \
        -i ~/environment/labsuser.pem \
        ubuntu@"$NODE" \
        "mkdir -p /home/ubuntu/environment"

    # Remove eventual chave antiga que esteja protegida
    ssh -o StrictHostKeyChecking=no \
        -i ~/environment/labsuser.pem \
        ubuntu@"$NODE" \
        "rm -f /home/ubuntu/environment/labsuser.pem"

    # Copia somente o PEM
    scp \
        -i ~/environment/labsuser.pem \
        ~/environment/labsuser.pem \
        ubuntu@"$NODE":/home/ubuntu/environment/labsuser.pem

    # Ajusta permissão
    ssh -o StrictHostKeyChecking=no \
        -i ~/environment/labsuser.pem \
        ubuntu@"$NODE" \
        "chmod 400 /home/ubuntu/environment/labsuser.pem"

    echo "✅ labsuser.pem copiado para $NODE"
    echo ""
done

# ============================================================
# ANSIBLE
# ============================================================

echo ""
echo "============================================================"
echo "        AJUSTANDO VIA ANSIBLE"
echo "============================================================"
echo ""

"$ANSIBLE_PLAYBOOK" ~/environment/config/ansible/ansible_hostname.yml \
    --inventory inv.hosts \
    -u ubuntu \
    --key-file ~/environment/labsuser.pem

"$ANSIBLE_PLAYBOOK" ~/environment/config/ansible/ansible_desligamento.yml \
    --inventory inv.hosts \
    -u ubuntu \
    --key-file ~/environment/labsuser.pem

"$ANSIBLE_PLAYBOOK" ~/environment/config/ansible/ansible_utils.yml \
    --inventory inv.hosts \
    -u ubuntu \
    --key-file ~/environment/labsuser.pem

"$ANSIBLE_PLAYBOOK" ~/environment/config/ansible/ansible_docker.yml \
    --inventory inv.hosts \
    -u ubuntu \
    --key-file ~/environment/labsuser.pem

"$ANSIBLE_PLAYBOOK" ~/environment/config/ansible/ansible_k8s.yml \
    --inventory inv.hosts \
    -u ubuntu \
    --key-file ~/environment/labsuser.pem

"$ANSIBLE_PLAYBOOK" ~/environment/config/ansible/ansible_dev_java.yml \
    --inventory inv.hosts \
    -u ubuntu \
    --key-file ~/environment/labsuser.pem

"$ANSIBLE_PLAYBOOK" ~/environment/config/ansible/ansible_code_server_ubuntu.yml \
    --inventory inv.hosts \
    -u ubuntu \
    --key-file ~/environment/labsuser.pem

echo ""
echo "============================================================"
echo "        ✅ LAB CONFIGURADO"
echo "============================================================"
echo ""
