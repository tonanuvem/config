#!/bin/bash

#echo "Em qual NODE você deseja conectar? Digitar ex: 0 ou 1 ou 2 (etc)" 
#read NODENUM

echo "Conectando ..."
echo ""
echo "Atualizando IP..."

# Atualiza apenas o estado local com os dados mais recentes da AWS (sem rodar apply)
terraform refresh > /dev/null

NODENUM=0

# Extrai o IP atualizado de forma segura tratando arrays simples ou aninhados
IPS=($(terraform output -json ip_externo 2>/dev/null | jq -r '.[][]'))
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
