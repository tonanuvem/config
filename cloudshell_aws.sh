```bash
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
# CONFIGURAÇÃO DE DIRETÓRIOS
# ------------------------------------------------------------

PASTA_ENV="$HOME/environment"
PASTA_CONFIG="$PASTA_ENV/config"

echo "📁 Verificando diretórios..."

mkdir -p "$PASTA_ENV"

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
# SCRIPTS AUXILIARES
# ------------------------------------------------------------

echo ""
echo "📝 Criando scripts iniciar.sh e destruir.sh..."

cat > "$HOME/iniciar.sh" <<'EOF'
#!/bin/bash

cd ~/environment/config/vm-fiap/

terraform init
terraform plan
terraform apply -auto-approve
EOF

cat > "$HOME/destruir.sh" <<'EOF'
#!/bin/bash

cd ~/environment/config/vm-fiap/

terraform destroy -auto-approve
EOF

chmod +x "$HOME/iniciar.sh"
chmod +x "$HOME/destruir.sh"

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

echo ""
echo "ℹ️ Resize de disco não será executado no AWS CloudShell."
echo ""

# ------------------------------------------------------------
# ANSIBLE
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "        CONFIGURANDO PRÉ-REQUISITOS ANSIBLE"
echo "============================================================"
echo ""

export VM=$(curl -s checkip.amazonaws.com)

echo "IP público detectado:"
echo "$VM"

echo ""

cat > "$PASTA_CONFIG/hosts" <<EOF
[nodes]
cloudshell ansible_connection=local
EOF

export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

echo "Inventário criado:"
echo ""

cat "$PASTA_CONFIG/hosts"

# ------------------------------------------------------------
# ANSIBLE
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "        CONFIGURANDO ANSIBLE"
echo "============================================================"
echo ""

if [ -f "$PASTA_CONFIG/ansible.sh" ]; then

    bash "$PASTA_CONFIG/ansible.sh"

else

    echo "⚠️ ansible.sh não encontrado."

fi

# ------------------------------------------------------------
# FINAL
# ------------------------------------------------------------

echo ""
echo ""
echo "============================================================"
echo "        CLOUDSHELL CONFIGURADO"
echo "============================================================"
echo ""
echo "📁 Config:"
echo "   cd ~/environment/config"
echo ""
echo "🚀 Iniciar Terraform:"
echo "   ~/iniciar.sh"
echo ""
echo "💥 Destruir Terraform:"
echo "   ~/destruir.sh"
echo ""
echo "============================================================"
echo ""
```
