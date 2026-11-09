#!/bin/sh
# Configura o kubectl desta maquina (Cloud9 / CloudShell / VM) para o cluster.
# Equivalente a "sh conectar.sh" no modo host, mas sem abrir um shell novo.
set -eu

CLUSTER_NAME="${CLUSTER_NAME:-eksfiap}"
AWS_REGION="${AWS_REGION:-us-east-1}"

export AWS_PAGER=""

aws sts get-caller-identity
aws eks --region "$AWS_REGION" update-kubeconfig --name "$CLUSTER_NAME"
kubectl get nodes
