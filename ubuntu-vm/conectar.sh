#!/bin/bash

#echo "Em qual NODE você deseja conectar? Digitar ex: 0 ou 1 ou 2 (etc)" 
#read NODENUM

echo "Conectando ..."
echo ""
echo "Atualizando IP..."

# Atualiza apenas o estado local com os dados mais recentes da AWS (sem rodar apply)
terraform refresh > /dev/null

NODENUM=0

# O filtro aceita as tres formas que o ip_externo ja teve: string,
# lista e lista aninhada. Isso importa na transicao -- o state
# existente so passa a devolver a forma nova no proximo apply.
LER_IPS='if type=="string" then . else (.. | strings) end'

mapfile -t IPS < <(
    terraform output -json ip_externo 2>/dev/null |
    jq -r "$LER_IPS" |
    grep -v '^[[:space:]]*$'
)

IP="${IPS[$NODENUM]}"

if [ -z "$IP" ] || [ "$IP" = "null" ]; then
    echo "❌ Erro: Não foi possível obter o IP do Terraform."
    exit 1
fi

echo "Conectando.. IP = $IP"

# 1. Garante que o diretório ~/.aws existe na VM remota antes do SCP
ssh -o LogLevel=error -o StrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@"$IP" "mkdir -p /home/ubuntu/.aws"

# 2. Copia as credenciais AWS para o caminho correto
scp -q -o LogLevel=error -o StrictHostKeyChecking=no -i ~/environment/labsuser.pem ~/environment/credenciais/credentials ubuntu@"$IP":/home/ubuntu/.aws/credentials

# 3. Estabelece a conexão SSH
ssh -o LogLevel=error -o StrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@"$IP"
