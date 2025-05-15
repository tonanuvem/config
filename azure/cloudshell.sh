#!/bin/bash

# para executar o script, rodar: 
# curl -s -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' https://raw.githubusercontent.com/tonanuvem/config/refs/heads/main/azure/cloudshell.sh | bash

# CONFIG SSH  ----------

# Caminho padrão das chaves
SSH_DIR="$HOME/.ssh"
CHAVE_PRIVADA="$SSH_DIR/id_rsa"
CHAVE_PUBLICA="$CHAVE_PRIVADA.pub"

# Verifica se as chaves já existem
if [[ -f "$CHAVE_PRIVADA" && -f "$CHAVE_PUBLICA" ]]; then
    echo "✅ Chaves SSH já existem:"
    echo " - Privada: $CHAVE_PRIVADA"
    echo " - Pública: $CHAVE_PUBLICA"
else
    echo "🔐 Chaves SSH não encontradas. Gerando novas..."
    
    # Cria o diretório ~/.ssh se não existir
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # Gera nova chave sem senha
    ssh-keygen -t rsa -b 2048 -f "$CHAVE_PRIVADA" -N ""

    if [[ $? -eq 0 ]]; then
        echo "✅ Chaves SSH criadas com sucesso:"
        echo " - Privada: $CHAVE_PRIVADA"
        echo " - Pública: $CHAVE_PUBLICA"
    else
        echo "❌ Erro ao gerar chaves SSH."
        exit 1
    fi
fi

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
else
    echo "A pasta '$PASTA_CONFIG' já existe."
fi

# Entra no diretório ~/enviroment/config
cd "$PASTA_CONFIG" || {
    echo "❌ Erro: não foi possível entrar na pasta '$PASTA_CONFIG'"
    exit 1
}

echo "📁 Agora dentro da pasta: $(pwd)"
