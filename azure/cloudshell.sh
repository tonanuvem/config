#!/bin/bash

# para executar o script, rodar: curl -s gh/cloudshell.sh | bash

# Caminho da pasta
PASTA_ENV="enviroment"
PASTA_CONFIG="$PASTA_ENV/config"

# Verifica se a pasta 'enviroment' existe
if [ ! -d "$PASTA_ENV" ]; then
    echo "Criando pasta '$PASTA_ENV'..."
    mkdir -p "$PASTA_ENV"
fi

# Verifica se a pasta 'config' existe dentro de 'enviroment'
if [ ! -d "$PASTA_CONFIG" ]; then
    echo "Clonando repositório na pasta '$PASTA_ENV'..."
    git clone https://github.com/tonanuvem/config "$PASTA_CONFIG"
else
    echo "A pasta '$PASTA_CONFIG' já existe."
fi
