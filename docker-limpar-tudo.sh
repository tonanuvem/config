#!/bin/sh

echo "==============================================="
echo " DOCKER RESET TOTAL - LIMPEZA COMPLETA"
echo "==============================================="
echo ""
echo "ATENCAO: Isso vai apagar TODOS os containers,"
echo "imagens, volumes, networks e cache do Docker."
echo ""
echo "Digite SIM para continuar:"
read CONFIRMA

if [ "$CONFIRMA" != "SIM" ]; then
  echo "Operacao cancelada."
  exit 1
fi

echo ""
echo "STATUS ANTES DA LIMPEZA"
echo "-----------------------------------------------"
docker system df
echo ""

echo "1) Parando todos os containers..."
CONTAINERS=$(docker ps -aq)
if [ -n "$CONTAINERS" ]; then
  docker stop $CONTAINERS
  echo "Containers parados."
else
  echo "Nenhum container para parar."
fi
echo ""

echo "2) Removendo todos os containers..."
if [ -n "$CONTAINERS" ]; then
  docker rm $CONTAINERS
  echo "Containers removidos."
else
  echo "Nenhum container para remover."
fi
echo ""

echo "3) Removendo todas as imagens..."
IMAGES=$(docker images -aq)
if [ -n "$IMAGES" ]; then
  docker rmi -f $IMAGES
  echo "Imagens removidas."
else
  echo "Nenhuma imagem para remover."
fi
echo ""

echo "4) Removendo todos os volumes..."
VOLUMES=$(docker volume ls -q)
if [ -n "$VOLUMES" ]; then
  docker volume rm $VOLUMES
  echo "Volumes removidos."
else
  echo "Nenhum volume para remover."
fi
echo ""

echo "5) Removendo todas as networks customizadas..."
NETWORKS=$(docker network ls --filter type=custom -q)
if [ -n "$NETWORKS" ]; then
  docker network rm $NETWORKS
  echo "Networks removidas."
else
  echo "Nenhuma network customizada para remover."
fi
echo ""

echo "6) Limpando cache e recursos orfaos..."
docker system prune -a --volumes -f
echo "Limpeza final concluida."
echo ""

echo "STATUS APOS LIMPEZA"
echo "-----------------------------------------------"
docker system df
echo ""

echo "Docker foi completamente limpo."
echo "==============================================="
