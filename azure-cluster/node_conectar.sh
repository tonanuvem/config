#!/bin/bash

if [ -n "$1" ]; then
    NODENUM="$1"
else
    # Caso não tenha sido passado, solicita ao usuário
    echo "Em qual NODE você deseja conectar? Digitar: 1 ou 2"
    read NODENUM
fi

# Obtém o IP usando o índice correto (passando a variável para jq)
NODE=$(terraform output -json ip_externo | jq -r ".[$INDEX]")

echo "Conectando.. IP = $NODE"
ssh -o LogLevel=error -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ubuntu@$NODE
