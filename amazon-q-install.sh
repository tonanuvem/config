#!/usr/bin/env bash
set -euxo pipefail

LOG="amazon-q-install_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOG") 2>&1

# URL oficial do pacote .deb mais recente
URL="${URL:-https://desktop-release.q.us-east-1.amazonaws.com/latest/amazon-q.deb}"
# Caminho do arquivo .deb que será baixado (no diretório atual)
DEB="${DEB:-amazon-q.deb}"

export DEBIAN_FRONTEND=noninteractive

# Mantém sudo ativo (não falha se não tiver sudo)
sudo -v || true

# Info do SO
if [[ -r /etc/os-release ]]; then
  . /etc/os-release || true
fi

echo "🌐 Garantindo 'wget' e certificados…"
if ! command -v wget >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y wget ca-certificates
fi

echo "⬇️  Baixando Amazon Q Desktop: $URL"
# Opções de robustez em redes instáveis
WGET_OPTS=(--retry-connrefused --waitretry=2 --tries=5 --timeout=30 --show-progress -O "$DEB")
wget "${WGET_OPTS[@]}" "$URL"

# Verificações básicas do artefato baixado
if [[ ! -s "$DEB" ]]; then
  echo "❌ Download falhou: arquivo vazio ou inexistente: $DEB"
  exit 1
fi
if ! dpkg-deb --info "$DEB" >/dev/null 2>&1; then
  echo "❌ O arquivo baixado não parece um .deb válido: $DEB"
  exit 1
fi

echo "🧩 Atualizando índices de pacotes…"
sudo apt-get update -y

# Em alguns Ubuntu, libayatana-appindicator3-1 fica no 'universe'
ensure_universe_repo() {
  if [[ "${ID:-}" == "ubuntu" ]]; then
    if ! apt-cache show libayatana-appindicator3-1 >/dev/null 2>&1; then
      echo "ℹ️ Habilitando repositório 'universe' (Ubuntu)…"
      if ! command -v add-apt-repository >/dev/null 2>&1; then
        sudo apt-get install -y software-properties-common
      fi
      sudo add-apt-repository -y universe || true
      sudo apt-get update -y
    fi
  fi
}

ensure_universe_repo

# Dependências primárias exigidas pelo .deb
deps=(libayatana-appindicator3-1 libwebkit2gtk-4.1-0 libgtk-3-0)

# Fallbacks possíveis para distros/versões diferentes
declare -A fallbacks
# WebKitGTK: alguns releases têm 4.0-37/49/4 em vez de 4.1-0
fallbacks[libwebkit2gtk-4.1-0]="libwebkit2gtk-4.0-37 libwebkit2gtk-4.0-49 libwebkit2gtk-4.0-4"
# GTK3: em versões recentes pode ser sufixo t64
fallbacks[libgtk-3-0]="libgtk-3-0t64"

install_one() {
  local pkg="$1"

  # Se pacote existir no índice, tenta instalar
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    if sudo apt-get install -y -V -o Dpkg::Use-Pty=0 "$pkg"; then
      return 0
    fi
  fi

  # Tenta fallbacks, se configurados
  if [[ -n "${fallbacks[$pkg]:-}" ]]; then
    for alt in ${fallbacks[$pkg]}; do
      if apt-cache show "$alt" >/dev/null 2>&1; then
        echo "⚠️ Tentando alternativa para '$pkg': '$alt'"
        if sudo apt-get install -y -V -o Dpkg::Use-Pty=0 "$alt"; then
          return 0
        fi
      fi
    done
  fi
  echo "⚠️ Não foi possível instalar '$pkg' (nem alternativas)."
  return 1
}

echo "🧩 Instalando dependências…"
for p in "${deps[@]}"; do
  install_one "$p" || true
done

echo "🧩 Correção de pacotes quebrados (se houver)…"
sudo apt-get -f install -y -V -o Dpkg::Use-Pty=0 || true

echo "📦 Instalando o pacote .deb: $DEB"
if ! sudo dpkg -i "$DEB"; then
  echo "🔁 Ajustando dependências e tentando novamente…"
  sudo apt-get -f install -y
  sudo dpkg -i "$DEB"
fi
echo "🔎 Verificando status final do pacote…"
if dpkg -s amazon-q >/dev/null 2>&1; then
  dpkg -s amazon-q | awk -F': ' '/^(Status|Version):/{print}'
  echo "✅ Instalação concluída com sucesso."
  echo "🗂️ Log salvo em: $LOG"
else
  echo "❌ O pacote 'amazon-q' não foi configurado corretamente."
  echo "   Consulte o log detalhado: $LOG"
  exit 2
fi
