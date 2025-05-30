#!/bin/bash

# para executar o script, rodar: 
# curl -s https://raw.githubusercontent.com/tonanuvem/config/refs/heads/main/cloudshell.sh | bash && cd ~/environment/config

# CONFIG provider ----------
#	Configurar Azure para usar os serviços Compute e ContainerService:

az provider register --namespace Microsoft.Compute && az provider register --namespace Microsoft.ContainerService

# CONFIG environment ----------

# Caminho da pasta
PASTA_ENV="$HOME/environment"
PASTA_CONFIG="$PASTA_ENV/config"

# Verifica se a pasta 'environment' existe
if [ ! -d "$PASTA_ENV" ]; then
    echo "Criando pasta '$PASTA_ENV'..."
    mkdir -p "$PASTA_ENV"
fi

# Verifica se a pasta 'config' existe dentro de 'environment'
if [ ! -d "$PASTA_CONFIG" ]; then
    echo "Clonando repositório na pasta '$PASTA_ENV'..."
    git clone https://github.com/tonanuvem/config "$PASTA_CONFIG"
    echo -e 'cd ~/environment/config/azure-vm/ && sh ligar.sh' > ~/ligar.sh 
    echo -e 'cd ~/environment/config/azure-vm/ && sh suspender.sh' > ~/suspender.sh
else
    echo "A pasta '$PASTA_CONFIG' já existe."
fi

# Entrar no diretório ~/enviroment/config
echo ""
echo ""
echo "📁  Pasta configurada. "
echo "                        cd ~/environment/config"
echo ""
