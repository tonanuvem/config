#!/bin/bash

# Obtém a quantidade de nodes disponíveis
TOTAL_NODES=$(terraform output -json ip_externo | jq 'length')

if [ -n "$1" ]; then
    NODENUM="$1"
else
    # Caso não tenha sido passado, solicita ao usuário
    if [ "$TOTAL_NODES" -eq 1 ]; then
        echo "Em qual NODE você deseja conectar? Digitar: 1"
    else
        echo "Em qual NODE você deseja conectar? Digitar: de 1 até $TOTAL_NODES"
    fi
    read NODENUM
fi

# Valida se o número está dentro do range válido
if [[ ! "$NODENUM" =~ ^[0-9]+$ ]] || [ "$NODENUM" -lt 1 ] || [ "$NODENUM" -gt "$TOTAL_NODES" ]; then
    echo "Erro: Número inválido. Digite um número de 1 até $TOTAL_NODES"
    exit 1
fi

# Obtém o IP usando o índice correto
NODE=$(terraform output -json ip_externo | jq --argjson idx "$NODENUM" -r '.[$idx]')

echo "Conectando no NODE $NODENUM.. IP = $NODE"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$NODE
