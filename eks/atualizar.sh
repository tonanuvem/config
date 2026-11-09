#!/usr/bin/env bash
# =============================================================================
# Atualiza o repositorio (git pull) preservando as credenciais locais.
#
# Por que isso existe:
# as versoes antigas dos scripts escreviam dentro de arquivos versionados
# (o "sed -i" em main.tf e as credenciais em files/credentials). Na segunda
# execucao do lab, o "git pull" do passo 1 falhava com:
#
#   error: Your local changes to the following files would be overwritten
#          by merge: eks/main.tf
#
# Este script descarta apenas essas alteracoes geradas por script, guarda e
# devolve as credenciais, e faz o pull.
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

cd "$(dirname "$0")"

git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "ERRO: esta pasta nao e um clone git." >&2
    exit 1
}

BACKUP=""
if [ -s ./files/credentials ]; then
    BACKUP=$(mktemp)
    cp ./files/credentials "$BACKUP"
    chmod 600 "$BACKUP"
    echo "Credenciais guardadas temporariamente."
fi

restaurar() {
    if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
        mkdir -p ./files
        cp "$BACKUP" ./files/credentials
        chmod 600 ./files/credentials
        rm -f "$BACKUP"
        echo "Credenciais restauradas em ./files/credentials."
    fi
}
trap restaurar EXIT

# Arquivos que os scripts antigos modificavam. So estes sao descartados.
for arquivo in main.tf files/credentials; do
    if git ls-files --error-unmatch "$arquivo" >/dev/null 2>&1 \
        && ! git diff --quiet -- "$arquivo" 2>/dev/null; then
        echo "Descartando alteracoes locais em $arquivo (geradas por script)."
        git checkout -- "$arquivo"
    fi
done

RAMO=$(git rev-parse --abbrev-ref HEAD)
echo ""
echo "Atualizando o ramo '$RAMO' ..."
git pull origin "$RAMO"

# Restaura agora (e nao no trap) para a mensagem final ficar por ultimo.
trap - EXIT
restaurar

echo ""
echo "Repositorio atualizado. Proximo passo: sh config_credenciais.sh"
