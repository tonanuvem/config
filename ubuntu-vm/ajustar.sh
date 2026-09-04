#!/bin/bash

# ============================================================
# CONFIGURAÇÕES
# ============================================================

export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

# VM de lab e efemera e reaproveita IPs: sem isto o Ansible aborta
# com "Host key verification failed" por chave antiga no known_hosts.
export ANSIBLE_HOST_KEY_CHECKING=false

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

# O filtro aceita as tres formas que o ip_externo ja teve: string,
# lista e lista aninhada. Isso importa na transicao -- o state
# existente so passa a devolver a forma nova no proximo apply.
LER_IPS='if type=="string" then . else (.. | strings) end'

mapfile -t IPS < <(
    terraform output -json ip_externo 2>/dev/null |
    jq -r "$LER_IPS" |
    grep -v '^[[:space:]]*$'
)

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

# O inventario e gravado fora do clone deste repositorio quando o
# fiaplab.sh informa FIAPLAB_INVENTORY (aponta para /tmp/fiap/inventory).
# O default preserva o comportamento antigo para quem roda o script
# direto, na mao.
INV="${FIAPLAB_INVENTORY:-inv.hosts}"

mkdir -p "$(dirname "$INV")"

echo '[nodes]' > "$INV"

for N in $(seq 0 "$WORKER_NODES"); do
    NODE="${IPS[$N]}"
    echo "node$N ansible_ssh_host=$NODE" >> "$INV"
done

echo "Inventário:"
cat "$INV"
echo ""

# ============================================================
# SCP
#
# Cada ssh/scp tem o codigo de retorno verificado: sem isso, uma
# falha ao copiar credenciais ou a chave so aparecia muito depois,
# como um erro incompreensivel no meio de um playbook.
# ============================================================

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=error)
CHAVE="$HOME/environment/labsuser.pem"
CREDENCIAIS="$HOME/environment/credenciais/credentials"

if [ ! -f "$CHAVE" ]; then
    echo "❌ Chave SSH não encontrada: $CHAVE"
    exit 1
fi

if [ ! -f "$CREDENCIAIS" ]; then
    echo "❌ Credenciais AWS não encontradas: $CREDENCIAIS"
    exit 1
fi

echo ""
echo "============================================================"
echo "        COPIANDO ARQUIVOS PARA A EC2"
echo "============================================================"
echo ""

falhar() {
    echo ""
    echo "❌ $1"
    echo ""
    exit 1
}

for N in $(seq 0 "$WORKER_NODES"); do

    NODE="${IPS[$N]}"

    echo "Sincronizando repositório Git em $NODE..."

    ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" \
        "mkdir -p /home/ubuntu/environment /home/ubuntu/.aws" \
        || falhar "Não foi possível conectar em $NODE."

    # VM efemera recem-criada: nos primeiros minutos de boot o cloud-init,
    # o apt-daily e o unattended-upgrades seguram o lock do apt/dpkg. Sem
    # esperar, o primeiro "apt install" dos playbooks (utils, docker) fica
    # travado repetindo em silencio. Aqui bloqueamos ate o boot concluir e
    # o lock ser liberado -- e o que o ambiente do Cloud9 nao precisa por
    # ja estar ligado ha tempo.
    echo "Aguardando cloud-init/unattended-upgrades liberar o apt em $NODE..."
    ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" \
        "cloud-init status --wait >/dev/null 2>&1 || true; \
         while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 5; done" \
        || falhar "Timeout aguardando o boot de $NODE."

    # O mirror regional us-east-1.ec2.archive.ubuntu.com as vezes deixa a
    # conexao ESTABELECIDA mas para de enviar dados no meio do download; sem
    # timeout o apt fica pendurado indefinidamente. Aqui damos timeout curto
    # + retries para o apt abortar a conexao morta e re-tentar, em vez de
    # travar todo o ajustar.sh.
    printf 'Acquire::http::Timeout "20";\nAcquire::https::Timeout "20";\nAcquire::Retries "3";\n' | \
        ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" \
            "sudo tee /etc/apt/apt.conf.d/99fiap-timeout >/dev/null" \
        || falhar "Não foi possível configurar timeout do apt em $NODE."

    ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" \
        "if [ -d '/home/ubuntu/environment/config/.git' ]; then
            cd /home/ubuntu/environment/config && git pull --ff-only;
         else
            git clone https://github.com/tonanuvem/config /home/ubuntu/environment/config;
         fi" \
        || falhar "Não foi possível sincronizar o repositório config em $NODE."

    scp -q "${SSH_OPTS[@]}" -i "$CHAVE" \
        "$CREDENCIAIS" \
        ubuntu@"$NODE":/home/ubuntu/.aws/credentials \
        || falhar "Não foi possível copiar as credenciais AWS para $NODE."

    ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" \
        "chmod 600 /home/ubuntu/.aws/credentials" \
        || falhar "Não foi possível proteger as credenciais em $NODE."

    echo "✅ Repositório e credenciais atualizados em $NODE"
    echo ""

    echo "Copiando labsuser.pem para $NODE..."

    # Garante permissao de escrita no arquivo antigo antes de sobrescrever.
    ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" \
        "test -f /home/ubuntu/environment/labsuser.pem && chmod 600 /home/ubuntu/environment/labsuser.pem || true"

    scp -q "${SSH_OPTS[@]}" -i "$CHAVE" \
        "$CHAVE" \
        ubuntu@"$NODE":/home/ubuntu/environment/labsuser.pem \
        || falhar "Não foi possível copiar a chave SSH para $NODE."

    ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" \
        "chmod 400 /home/ubuntu/environment/labsuser.pem" \
        || falhar "Não foi possível proteger a chave SSH em $NODE."

    echo "✅ labsuser.pem copiado com sucesso para $NODE"
    echo ""
done

# ============================================================
# ANSIBLE
#
# Os playbooks rodam em sequencia e cada um tem o codigo de retorno
# verificado. Antes, os 7 eram invocados soltos e o exit code do
# script era apenas o do ultimo (code_server): uma falha em k8s ou
# docker passava como sucesso para o criar.sh.
# ============================================================

PLAYBOOKS=(
    hostname
    desligamento
    utils
    docker
    k8s
    dev_java
    code_server_ubuntu
)

TOTAL="${#PLAYBOOKS[@]}"

echo ""
echo "============================================================"
echo "        AJUSTANDO VIA ANSIBLE ($TOTAL etapas)"
echo "============================================================"
echo ""

for I in "${!PLAYBOOKS[@]}"; do

    NOME="${PLAYBOOKS[$I]}"
    ARQUIVO="$HOME/environment/config/ansible/ansible_${NOME}.yml"

    echo "------------------------------------------------------------"
    echo " Etapa $((I + 1))/$TOTAL : $NOME"
    echo "------------------------------------------------------------"

    if [ ! -f "$ARQUIVO" ]; then
        echo ""
        echo "❌ Playbook não encontrado:"
        echo "   $ARQUIVO"
        echo ""
        exit 1
    fi

    "$ANSIBLE_PLAYBOOK" "$ARQUIVO" \
        --inventory "$INV" \
        -u ubuntu \
        --key-file ~/environment/labsuser.pem

    RC=$?

    if [ "$RC" -ne 0 ]; then
        echo ""
        echo "============================================================"
        echo " ❌ FALHA NA ETAPA: $NOME"
        echo "============================================================"
        echo ""
        echo "As etapas anteriores foram aplicadas, mas a configuração"
        echo "está incompleta. O code-server pode não estar disponível."
        echo ""
        echo "Para tentar novamente, execute no menu:"
        echo "   1) Criar infraestrutura"
        echo ""
        exit "$RC"
    fi

    echo ""
done

echo ""
echo "============================================================"
echo "        ✅ LAB CONFIGURADO"
echo "============================================================"
echo ""
