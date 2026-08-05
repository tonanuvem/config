#!/bin/bash

set -e

COMPOSE_FILE="chrome-Neko-docker-compose.yml"

echo ">>> Verificando container em execução..."
# Adicionado -f $COMPOSE_FILE antes do comando ps
if [ "$(docker compose -f $COMPOSE_FILE ps -q 2>/dev/null)" ]; then
  echo ">>> Container rodando, parando..."
  # Adicionado -f $COMPOSE_FILE antes do comando down
  docker compose -f $COMPOSE_FILE down
  echo ">>> Container parado."
fi

echo ""
echo ">>> Verificando diretórios em /opt/neko..."
if [ ! -d "/opt/neko/profile" ] || [ ! -d "/opt/neko/downloads" ]; then
  echo ">>> Criando diretórios..."
  sudo mkdir -p /opt/neko/profile /opt/neko/downloads
  echo ">>> Ajustando permissões..."
  sudo chown -R $(id -u):$(id -g) /opt/neko
else
  echo ">>> Diretórios já existem, pulando."
fi

echo ""
echo "Qual IP usar para WebRTC?"
echo "  1) IP local Wi-Fi ($(hostname -I | awk '{print $1}'))"
echo "  2) IP Tailscale   ($(tailscale ip -4 2>/dev/null || echo 'não disponível'))"
echo "  3) Digitar manualmente"
echo ""
read -p "Escolha [1/2/3]: " OPCAO

case $OPCAO in
  1)
    NAT_IP=$(hostname -I | awk '{print $1}')
    ;;
  2)
    NAT_IP=$(tailscale ip -4 2>/dev/null)
    if [ -z "$NAT_IP" ]; then
      echo "ERRO: Tailscale não encontrado ou sem IP disponível."
      exit 1
    fi
    ;;
  3)
    read -p "Digite o IP: " NAT_IP
    ;;
  *)
    echo "Opção inválida."
    exit 1
    ;;
esac

echo ""
echo ">>> Usando IP: $NAT_IP"
export NEKO_WEBRTC_NAT1TO1="$NAT_IP"

echo ">>> Subindo container neko..."
# Corrigida a ordem: -f vem ANTES do up
docker compose -f $COMPOSE_FILE up -d

echo ""
echo ">>> Concluído! Acesse: http://$NAT_IP:8000"
