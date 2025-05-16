#!/bin/bash

# para executar o script, rodar: 
# curl -s https://raw.githubusercontent.com/tonanuvem/config/refs/heads/main/azure-vm/ssh_config.sh | bash

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
