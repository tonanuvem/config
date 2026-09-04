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

# ============================================================
# HEARTBEAT
#
# O Ansible nao imprime nada durante uma task longa, entao "lento" e
# "morto" ficam indistinguiveis. Foi o que custou mais tempo aqui: o
# openjdk/maven baixando e o dpkg desempacotando 80+ pacotes pareciam
# um travamento identico ao do mirror quebrado. Este amostrador roda em
# paralelo a cada etapa e mostra o que o no esta realmente fazendo.
# ============================================================

HB_PID=""

heartbeat_inicia() {

    local NODE="$1"
    local ETAPA="$2"

    (
        while true; do

            sleep 30

            INFO=$(ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" '
                if pgrep -x apt-get >/dev/null 2>&1; then
                    PROC=apt-get
                elif pgrep -x dpkg >/dev/null 2>&1; then
                    PROC=dpkg
                else
                    PROC=-
                fi
                BAIXANDO=$(sudo du -sb /var/cache/apt/archives/partial 2>/dev/null | cut -f1)
                ULTIMO=$(sudo tail -n 1 /var/log/apt/term.log 2>/dev/null | tr -d "\r" | cut -c1-70)
                echo "proc=$PROC baixado=${BAIXANDO:-0}B | $ULTIMO"
            ' 2>/dev/null)

            [ -n "$INFO" ] && echo "      ⏱  [$ETAPA] $INFO"

        done
    ) &

    HB_PID=$!
}

heartbeat_para() {

    [ -n "$HB_PID" ] || return 0

    kill "$HB_PID" 2>/dev/null
    wait "$HB_PID" 2>/dev/null

    HB_PID=""
}

# Sem isto um Ctrl+C deixaria o amostrador orfao rodando em background.
trap 'heartbeat_para; exit 130' INT TERM

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
    ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" 'bash -s' <<'REMOTO' \
        || falhar "Boot de $NODE nao concluiu no prazo (lock do apt preso)."
# Os dois tetos abaixo sao o ponto: uma espera sem limite apenas troca
# "apt travado" por "ajustar.sh travado", que e exatamente o defeito que
# viemos corrigir. A versao anterior prometia "Timeout" na mensagem de
# erro mas tinha um while infinito.
timeout 600 cloud-init status --wait >/dev/null 2>&1 || true

N=0

while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; do

    N=$((N + 1))

    if [ "$N" -gt 120 ]; then
        echo "   ❌ lock do apt/dpkg nao liberou em 10 min"
        exit 1
    fi

    # Um sinal de vida a cada minuto, para a espera nao parecer travamento.
    if [ $((N % 12)) -eq 0 ]; then
        echo "   ... ainda aguardando o lock do apt ($((N * 5))s)"
    fi

    sleep 5
done
REMOTO

    # O mirror do apt e escolhido testando cada candidato, nao fixado:
    # fixar um so trocaria um ponto unico de falha por outro. O teste de
    # aceitacao e o proprio apt-get update sob limite de parede, porque
    # sondar por fora nao reproduz o defeito -- o mirror regional chegou
    # a passar num curl pequeno e travar no update completo em seguida.
    echo "Escolhendo mirror do apt em $NODE..."
    ssh "${SSH_OPTS[@]}" -i "$CHAVE" ubuntu@"$NODE" 'bash -s' <<'REMOTO' \
        || falhar "Não foi possível preparar o apt (mirror/listas) em $NODE."
set -u

# Um Ctrl+C no CloudShell mata o Ansible, mas nao o apt-get que ficou
# rodando no no. Esse zumbi nao segura o lock do dpkg (entao passa pela
# espera acima), mas briga com o rm das listas mais abaixo. Limpamos
# restos antes de comecar.
#
# -x casa o nome exato do processo. Com -f o padrao casaria a linha de
# comando deste proprio script -- que roda como bash -c com o texto
# inteiro -- e o script se mataria.
sudo pkill -9 -x apt-get 2>/dev/null || true
sudo pkill -9 -x http 2>/dev/null || true
sudo pkill -9 -x store 2>/dev/null || true
sudo pkill -9 -x gpgv 2>/dev/null || true
sleep 1

# Ordem definida por observacao, nao por teoria: o us-east-1.ec2 travou
# o apt-get update de forma reproduzivel a partir desta VPC (Ign: nos
# indices e stall ate o limite de parede), enquanto o archive.ubuntu.com
# baixou 15 MB em 0,35s. O regional seria o mais rapido e sem egress
# quando saudavel, entao fica como ultimo recurso em vez de sair da
# lista -- mas nao vale gastar 2 min de cada execucao tentando ele
# primeiro.
MIRRORS="
http://archive.ubuntu.com/ubuntu
http://br.archive.ubuntu.com/ubuntu
http://us-east-1.ec2.archive.ubuntu.com/ubuntu
"

# Acquire::Timeout sozinho nao protege. Observado no no travado: o
# metodo http ficava em CLOSE-WAIT (servidor fechou, apt nunca
# percebeu) com a transferencia parada de vez -- o du de
# /var/lib/apt/lists/partial nao mexia um byte em 53s. Nesse estado o
# apt nao esta esperando um read que expira, entao o timeout dele nunca
# dispara; so um limite de parede (timeout -k) corta.
printf 'Acquire::http::Timeout "20";\nAcquire::https::Timeout "20";\nAcquire::Retries "3";\n' \
    | sudo tee /etc/apt/apt.conf.d/99fiap-timeout >/dev/null

# O teste de aceitacao do mirror e o proprio apt-get update, nao uma
# sondagem por fora: o mirror regional ja passou num curl pequeno e
# travou no update completo logo em seguida. Se o update nao terminar
# no prazo, o mirror cai e tentamos o proximo.
#
# Limpar /var/lib/apt/lists a cada tentativa importa duas vezes: descarta
# indices parciais do mirror anterior e, como os playbooks usam
# cache_valid_time, garante que eles nao reaproveitem um cache furado
# (o que dava "held broken packages" em pacotes que existem).
ESCOLHIDO=""

for M in $MIRRORS; do
    echo "   Testando mirror: $M"

    sudo sed -i -E "s#http://[^ ]*archive\.ubuntu\.com/ubuntu#$M#g" \
        /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list 2>/dev/null || true

    sudo rm -rf /var/lib/apt/lists/*

    if sudo timeout -k 10 120 apt-get update -qq; then
        ESCOLHIDO="$M"
        echo "   ✅ mirror OK (apt-get update concluido): $M"
        break
    fi

    echo "   ⚠️  mirror travou ou falhou no update: $M"
done

if [ -z "$ESCOLHIDO" ]; then
    echo "   ❌ nenhum mirror concluiu o apt-get update"
    exit 1
fi
REMOTO

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

    # Amostra sempre o primeiro no: e suficiente para diferenciar uma
    # etapa lenta de uma travada, sem multiplicar SSH por node.
    heartbeat_inicia "${IPS[0]}" "$NOME"

    "$ANSIBLE_PLAYBOOK" "$ARQUIVO" \
        --inventory "$INV" \
        -u ubuntu \
        --key-file ~/environment/labsuser.pem

    RC=$?

    heartbeat_para

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
