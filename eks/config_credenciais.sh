#!/bin/sh
# =============================================================================
# Le as credenciais da AWS coladas pelo usuario e grava em ./files/credentials
#
# Esse arquivo e usado:
#  * pelo container do kubectl (kubectl.sh monta ./files em /root/.aws);
#  * pelo preparar.sh, via AWS_SHARED_CREDENTIALS_FILE, para que o terraform
#    use as mesmas credenciais sem precisar mexer em ~/.aws/credentials.
#
# O arquivo NAO e versionado (ver .gitignore na raiz do repositorio).
# =============================================================================

set -eu

cd "$(dirname "$0")"

DEST="./files/credentials"
mkdir -p ./files

echo "Cole suas credenciais da AWS e pressione ENTER 2 vezes:"
echo "(formato esperado: o bloco [default] do AWS Academy / Learner Lab)"
echo ""

CRED=$(sed '/^$/q')

# ---------------------------------------------------------------------------
# Validacao: evita seguir adiante com um arquivo vazio ou colado pela metade,
# que antes so dava erro varios minutos depois, dentro do terraform.
# ---------------------------------------------------------------------------
if [ -z "$(printf '%s' "$CRED" | tr -d '[:space:]')" ]; then
    echo "ERRO: nada foi colado. Rode novamente: sh config_credenciais.sh" >&2
    exit 1
fi

if ! printf '%s\n' "$CRED" | grep -qi 'aws_access_key_id'; then
    echo "ERRO: o texto colado nao contem 'aws_access_key_id'." >&2
    echo "      Copie o bloco completo de credenciais e tente novamente." >&2
    exit 1
fi

if ! printf '%s\n' "$CRED" | grep -qi 'aws_secret_access_key'; then
    echo "ERRO: o texto colado nao contem 'aws_secret_access_key'." >&2
    echo "      Copie o bloco completo de credenciais e tente novamente." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Grava com permissao restrita (antes ficava legivel para todo mundo).
# ---------------------------------------------------------------------------
OLD_UMASK=$(umask)
umask 077

if printf '%s\n' "$CRED" | grep -q '^[[:space:]]*\['; then
    printf '%s\n' "$CRED" > "$DEST"
else
    # Sem o cabecalho de profile o arquivo e invalido para a AWS CLI.
    { echo "[default]"; printf '%s\n' "$CRED"; } > "$DEST"
fi

umask "$OLD_UMASK"
chmod 600 "$DEST"

KEY_ID=$(grep -i '^[[:space:]]*aws_access_key_id' "$DEST" \
    | head -1 | sed 's/.*=[[:space:]]*//' | tr -d "\"' \r")

echo ""
echo "Credenciais gravadas em $DEST (permissao 600)."
echo "Access Key ID: ...$(printf '%s' "$KEY_ID" | tail -c 5)"

if ! grep -qi 'aws_session_token' "$DEST"; then
    echo ""
    echo "AVISO: nao ha 'aws_session_token'. No AWS Academy as credenciais sao"
    echo "       temporarias e sempre incluem o token; sem ele o acesso falha."
fi

echo ""
echo "Proximo passo: sh iniciar.sh"
