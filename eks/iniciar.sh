#!/bin/sh
# Cria o cluster EKS do lab. Leva de 12 a 15 minutos.
# Toda a logica esta em preparar.sh (que aceita --plan e --check).
cd "$(dirname "$0")" || exit 1
exec bash ./preparar.sh "$@"
