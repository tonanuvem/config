#!/usr/bin/env bash
set -euo pipefail

WORKDIR="$(mktemp -d)"
ZIP="q.zip"

echo "📂 Workdir: $WORKDIR"
cd "$WORKDIR"

# Detecta arquitetura
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCHID="x86_64" ;;
  aarch64|arm64) ARCHID="aarch64" ;;
  *) echo "❌ Arquitetura não suportada: $ARCH"; exit 1 ;;
esac
echo "🧭 Arquitetura: $ARCHID"

# Detecta glibc (fallback para musl)
GLIBC_VER="$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}' || true)"
use_musl=0
if [[ -n "$GLIBC_VER" ]]; then
  first="$(printf '%s\n' "$GLIBC_VER" "2.34" | sort -V | head -n1)"
  [[ "$first" != "2.34" ]] && use_musl=1
fi

BASE="https://desktop-release.q.us-east-1.amazonaws.com/latest"
URL="$BASE/q-${ARCHID}-linux.zip"
[[ $use_musl -eq 1 ]] && URL="$BASE/q-${ARCHID}-linux-musl.zip"

echo "🌐 Baixando: $URL"
curl -fsSL -o "$ZIP" "$URL"

echo "📦 Extraindo..."
if command -v unzip >/dev/null; then
  unzip -q "$ZIP"
else
  python3 - <<'PY'
import zipfile; zipfile.ZipFile("q.zip").extractall(".")
PY
fi

echo "⚙️ Instalando Amazon Q CLI (~/.local/bin)..."
bash ./q/install.sh --no-confirm
export PATH="$HOME/.local/bin:$PATH"



echo "⚙️ Aplicando Configurações do Amazon Q CLI..."
AGENTS_DIR="$HOME/.aws/amazonq/cli-agents"
mkdir -p "$AGENTS_DIR"

# Agente lab-fiap: máximo de usabilidade com poucos guard-rails
cat > "$AGENTS_DIR/lab-fiap.json" <<'JSON'
{
  "name": "lab-fiap",
  "description": "Agente para laboratório: todas as ferramentas pré-aprovadas; bash com mínimos bloqueios.",
  "tools": [
    "execute_bash",
    "fs_read",
    "fs_write",
    "introspect",
    "report_issue",
    "use_aws"
  ],
  "allowedTools": [
    "execute_bash",
    "fs_read",
    "fs_write",
    "introspect",
    "report_issue",
    "use_aws"
  ],
  "toolsSettings": {
    "execute_bash": {
      "allowReadOnly": true,
      "deniedCommands": [
        "\\Arm\\s+-rf\\s+/(\\s|$).*\\z",
        "\\Add\\s+if=/dev/.*\\z",
        "\\Amkfs\\..*\\z",
        "\\A(sudo\\s+)?shred\\b.*\\z",
        "\\A(sudo\\s+)?dd\\s+of=/dev/.*\\z",
        "\\A(sudo\\s+)?(shutdown|reboot)\\b.*\\z"
      ]
    }
  }
}
JSON

echo "✅ Agente criado: $AGENTS_DIR/lab-fiap.json"

# Torna o agente o padrão (não requer login)
q settings chat.defaultAgent lab-fiap

# Usabilidade do CLI
q inline enable                         # sugestões inline (ghost text)
q theme system                          # tema do dropdown segue o sistema
q settings autocomplete.disable false   # garante dropdown de autocomplete ligado

# Experimentos (os que têm chave em q settings)
q settings chat.enableKnowledge true    # persistência de contexto (/knowledge)
q settings chat.enableTangentMode true  # checkpoints de conversa (/tangent)

# Integração SSH local (cliente). Servidor remoto ainda precisa de ajuste em sshd_config (root).
q integrations install ssh || true


echo "🔎 Versão:"
q --version || true
# echo "🩺 Diagnóstico:"
# q doctor || true

echo "✅ Instalação concluída!"
echo "  Próximos passos:"
echo "  - Autenticar com comando: q login"
echo "  - Conversar com comando: q chat"
echo ""
