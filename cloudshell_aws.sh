#!/bin/bash

# ============================================================
# AWS CLOUDSHELL - CONFIGURAÇÃO TONANUVEM
#
# Execução:

# curl -s https://raw.githubusercontent.com/tonanuvem/config/refs/heads/main/cloudshell_aws.sh | bash

# ============================================================

set -e

echo ""
echo "============================================================"
echo "        CONFIGURANDO AWS CLOUDSHELL"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# CHAVE SSH labsuser.pem
# ------------------------------------------------------------

# ------------------------------------------------------------
# CONFIGURAÇÃO DE DIRETÓRIOS
# ------------------------------------------------------------

PASTA_ENV="$HOME/environment"
PASTA_CONFIG="$PASTA_ENV/config"

echo "📁 Verificando diretórios..."

mkdir -p "$PASTA_ENV"


echo ""
echo ""
echo "============================================================"
echo "        CONFIGURANDO CHAVE SSH labsuser.pem"
echo "============================================================"
echo ""

printf "\tVERIFICANDO ARQUIVO labsuser.pem:\n\n"

if [ -f "$HOME/labsuser.pem" ]; then

    printf "\t\t✅ ARQUIVO labsuser.pem OK!\n\n"

    cp "$HOME/labsuser.pem" "$PASTA_ENV/labsuser.pem"
    chmod 400 "$PASTA_ENV/labsuser.pem"

    printf "\t\tPermissão configurada: 400\n"
    printf "\t\tArquivo: $PASTA_ENV/labsuser.pem\n\n"

else

    echo ""
    echo "❌ Arquivo labsuser.pem não encontrado!"
    echo ""
    echo "Você deve fazer o upload do arquivo"
    echo "labsuser.pem para o AWS CloudShell."
    echo ""

    exit 1

fi


# ------------------------------------------------------------
# CLONAR CONFIG
# ------------------------------------------------------------

if [ ! -d "$PASTA_CONFIG/.git" ]; then

    echo ""
    echo "📦 Clonando repositório tonanuvem/config..."

    rm -rf "$PASTA_CONFIG"

    git clone \
        https://github.com/tonanuvem/config \
        "$PASTA_CONFIG"

else

    echo ""
    echo "📦 Repositório config já existe."

    cd "$PASTA_CONFIG"

    echo "🔄 Atualizando repositório..."

    git pull --ff-only || true

fi

# ------------------------------------------------------------
# TERRAFORM
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "        CONFIGURANDO TERRAFORM"
echo "============================================================"
echo ""

if command -v terraform >/dev/null 2>&1; then

    echo "✅ Terraform já está instalado."
    echo ""
    terraform --version

else

    echo "⬇️ Terraform não encontrado. Instalando Terraform 1.9.5..."
    echo ""

    TMP_DIR=$(mktemp -d)

    cd "$TMP_DIR"

    curl -fsSL \
      "https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip" \
      -o terraform.zip

    unzip -q terraform.zip

    sudo install -m 0755 terraform /usr/local/bin/terraform

    cd ~

    rm -rf "$TMP_DIR"

    echo ""
    echo "✅ Terraform instalado."
    echo ""

    terraform --version

fi

# ------------------------------------------------------------
# VERIFICAR DISCO
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "        VERIFICANDO DISCO DO CLOUDSHELL"
echo "============================================================"
echo ""

df -h "$HOME"

# echo ""
# echo "ℹ️ Resize de disco não será executado no AWS CloudShell."
# echo ""

# ------------------------------------------------------------
# ANSIBLE
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "        CONFIGURANDO ANSIBLE"
echo "============================================================"
echo ""

export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

if command -v ansible >/dev/null 2>&1; then

    echo "✅ Ansible já está instalado."
    echo ""
    ansible --version

else

    echo "⬇️ Ansible não encontrado. Instalando..."
    echo ""

    python3 -m pip install ansible

    #export PATH="$HOME/.local/bin:$PATH"

    echo ""
    echo "✅ Ansible instalado."
    echo ""

    ansible --version
    rm -rf ~/.cache/pip

fi

# ------------------------------------------------------------
# PRÉ-REQUISITOS ANSIBLE
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "        CONFIGURANDO PRÉ-REQUISITOS ANSIBLE"
echo "============================================================"
echo ""

export VM=$(curl -s checkip.amazonaws.com)

#echo "IP público detectado:"
#echo "$VM"

echo ""

cat > "$PASTA_CONFIG/hosts" <<EOF
[nodes]
cloudshell ansible_connection=local
EOF

echo "Inventário criado:"
echo ""

cat "$PASTA_CONFIG/hosts"

# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "        CLOUDSHELL CONFIGURADO"
echo "============================================================"
echo ""
