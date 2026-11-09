#!/bin/sh
# Abre um shell com o kubectl apontado para o cluster EKS do lab.
# Toda a logica esta em kubectl.sh (MODO=auto|host|docker).
cd "$(dirname "$0")" || exit 1
exec bash ./kubectl.sh "$@"
