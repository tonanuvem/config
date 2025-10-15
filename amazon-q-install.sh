#!/usr/bin/env bash
set -euo pipefail

LOG="amazon-q-cli_install_$(date +%F_%H-%M-%S).log"
WORKDIR="${TMPDIR:-/tmp}/amazonq_cli.$$"
ZIP="q.zip"

say(){ printf '%s\n' "$*" | tee -a "$LOG"; }

mkdir -p "$WORKDIR"; touch "$LOG"
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

# Detecta glibc com tolerância a erro
GLIBC_VER="$((ldd --version 2>/dev/null | head -n1 | awk '{print $NF}') || true)"
use_musl=0
if [[ -n "${GLIBC_VER:-}" ]]; then
  first="$(printf '%s\n' "$GLIBC_VER" "2.34" | sort -V | head -n1)"
  if [[ "$first" != "2.34" ]]; then use_musl=1; fi
else
  say "⚠️ Não foi possível detectar glibc; adotando variante padrão."
fi

BASE="https://desktop-release.q.us-east-1.amazonaws.com/latest"
if [[ $use_musl -eq 1 ]]; then
  URL="${BASE}/q-${ARCHID}-linux-musl.zip"
  say "🔧 glibc < 2.34 → usando build MUSL"
else
  URL="${BASE}/q-${ARCHID}-linux.zip"
  say "✅ glibc ≥ 2.34 (ou indetectável) → usando build padrão"
fi
say "🌐 URL do pacote: $URL"

cd "$WORKDIR"
# Download
if command -v curl >/dev/null 2>&1; then
  say "⬇️ Baixando com curl..."
  curl --proto '=https' --tlsv1.2 -fL -o "$ZIP" "$URL"
elif command -v wget >/dev/null 2>&1; then
  say "⬇️ Baixando com wget..."
  wget -O "$ZIP" "$URL"
else
  say "❌ Nem curl nem wget encontrados."; exit 1
fi
[[ -s "$ZIP" ]] || { say "❌ Download falhou (arquivo vazio)."; exit 1; }

# Extração
say "📦 Extraindo instalador..."
if command -v unzip >/dev/null 2>&1; then
  unzip -q "$ZIP"
else
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import zipfile; zipfile.ZipFile("q.zip").extractall(".")
PY
  else
    say "❌ Precisa de 'unzip' ou 'python3' para extrair."; exit 1
  fi
fi
[[ -x "./q/install.sh" ]] || { say "❌ ./q/install.sh não encontrado."; exit 1; }

# Instalação user-space e validação
say "⚙️ Instalando Amazon Q CLI (~/.local/bin)..."
bash ./q/install.sh --no-confirm
export PATH="$HOME/.local/bin:$PATH"

say "🔎 q --version:"
q --version || true

say "🩺 q doctor:"
q doctor || true

say "🔐 Para autenticar: q login"
say "💬 Para testar chat: q chat \"Olá, Q!\""
say "ℹ️ Doc oficial (instalação via ZIP): https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-installing-ssh-setup-autocomplete.html"
say "✅ Concluído. Log: $LOG"
``
