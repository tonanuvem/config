#!/usr/bin/env bash
set -euo pipefail

# ========= Config =========
LOG="amazon-q-cli_install_$(date +%F_%H-%M-%S).log"
WORKDIR="${TMPDIR:-/tmp}/amazonq_cli.$$"
ZIP="q.zip"

# ========= Funções utilitárias =========
say() { printf '%s\n' "$*" | tee -a "$LOG"; }

# Cria diretório de trabalho e log
mkdir -p "$WORKDIR"
touch "$LOG"

say "📄 Log: $LOG"
say "📂 Workdir: $WORKDIR"

# Detecta arquitetura
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCHID="x86_64" ;;
  aarch64|arm64) ARCHID="aarch64" ;;
  *) say "❌ Arquitetura não suportada: $ARCH"; exit 1 ;;
esac
say "🧭 Arquitetura detectada: $ARCHID"

# Detecta glibc (>= 2.34 usa 'standard'; menor usa 'musl')
GLIBC_VER=""
if command -v ldd >/dev/null 2>&1; then
  # Extrai a última “palavra” da 1ª linha: normalmente a versão da glibc
  GLIBC_VER="$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')"
  # fallback se formato diferente
  if ! [[ "$GLIBC_VER" =~ ^[0-9]+\.[0-9]+ ]]; then
    GLIBC_VER="$(ldd --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+' | head -n1 || true)"
  fi
fi
use_musl=0
if [[ -n "${GLIBC_VER:-}" ]]; then
  # Compara versões com sort -V
  first="$(printf '%s\n' "$GLIBC_VER" "2.34" | sort -V | head -n1)"
  if [[ "$first" != "2.34" ]]; then
    # GLIBC_VER < 2.34
    use_musl=1
  fi
else
  say "⚠️ Não foi possível detectar glibc; adotando variante padrão."
fi

# Monta URL oficial (documentação AWS)
BASE="https://desktop-release.q.us-east-1.amazonaws.com/latest"
if [[ $use_musl -eq 1 ]]; then
  URL="${BASE}/q-${ARCHID}-linux-musl.zip"
  say "🔧 glibc < 2.34 detectada → usando build MUSL"
else
  URL="${BASE}/q-${ARCHID}-linux.zip"
  say "✅ glibc ≥ 2.34 (ou indetectável) → usando build padrão"
fi
say "🌐 URL do pacote: $URL"

# Baixa com curl ou wget
cd "$WORKDIR"
if command -v curl >/dev/null 2>&1; then
  say "⬇️ Baixando com curl..."
  curl --proto '=https' --tlsv1.2 -fL -o "$ZIP" "$URL"
elif command -v wget >/dev/null 2>&1; then
  say "⬇️ Baixando com wget..."
  wget -O "$ZIP" "$URL"
else
  say "❌ Nem curl nem wget disponíveis."
  exit 1
fi

# Verificação básica
if [[ ! -s "$ZIP" ]]; then
  say "❌ Download falhou (arquivo vazio): $ZIP"
  exit 1
fi
# Descompacta (usa unzip ou fallback em Python)
say "📦 Extraindo instalador..."
if command -v unzip >/dev/null 2>&1; then
  unzip -q "$ZIP"
else
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import zipfile, sys
zipfile.ZipFile("q.zip").extractall(".")
PY
  else
    say "❌ Precisa de 'unzip' ou 'python3' para extrair."
    exit 1
  fi
fi

# Executa instalador (não interativo)
if [[ ! -x "./q/install.sh" ]]; then
  say "❌ Arquivo ./q/install.sh não encontrado após extração."
  exit 1
fi

say "⚙️  Instalando Amazon Q CLI no diretório do usuário (~/.local/bin)..."
bash ./q/install.sh --no-confirm

# Garante PATH nesta sessão
export PATH="$HOME/.local/bin:$PATH"

# Verificações pós-instalação
say "🔎 Verificando versão:"
if ! command -v q >/dev/null 2>&1; then
  say "⚠️ 'q' não está no PATH desta sessão. Adicione manualmente:"
  say "    export PATH=\"\$HOME/.local/bin:\$PATH\""
else
  q --version || true
fi

say "🩺 Executando 'q doctor' (diagnóstico rápido):"
q doctor || true

say "🔐 Para autenticar, rode: q login"
say "💬 Para conversar: q chat \"Olá, Q!\""
say "⚙️ Configurações: q settings all  |  Inline suggestions (zsh): q inline enable"

# Notas sobre SSH (opcional)
cat <<'SSH_NOTES' | tee -a "$LOG"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 Integração SSH (opcional; requer root no servidor remoto)
- No servidor remoto, edite /etc/ssh/sshd_config e adicione:
    AcceptEnv Q_SET_PARENT
    AllowStreamLocalForwarding yes
  Reinicie o sshd e reconecte via SSH. Em seguida:
    q login
    q doctor
Referência: docs AWS (SSH remoto).
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SSH_NOTES

say "✅ Concluído. Log salvo em: $LOG"
