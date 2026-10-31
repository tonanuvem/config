#!/bin/bash
# Substituto moderno e Open Source do Portworx (k8s_config_volume_portworx.sh / k8s_criar_volume_portworx.sh)
# Utiliza o Longhorn (CNCF) para replicação de volumes entre os Worker Nodes usando o disco extra (/dev/xvdb).

set -e

LONGHORN_VERSION="v1.13.0"

preparar_node_storage() {
  echo "=== Configurando pré-requisitos (iSCSI / NFS) e disco /dev/xvdb em $(hostname) ==="
  lsblk

  # Instala iscsi-initiator-utils e nfs-utils (Amazon Linux / RedHat ou Ubuntu / Debian)
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y iscsi-initiator-utils nfs-utils >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y iscsi-initiator-utils nfs-utils >/dev/null
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq open-iscsi nfs-common >/dev/null
  fi

  sudo modprobe iscsi_tcp || true
  sudo systemctl enable --now iscsid

  # Monta o disco dedicado /dev/xvdb em /var/lib/longhorn se existir e ainda não estiver montado
  sudo mkdir -p /var/lib/longhorn
  if [ -b /dev/xvdb ] && ! mountpoint -q /var/lib/longhorn; then
    if ! sudo blkid /dev/xvdb >/dev/null 2>&1; then
      echo "Formatando /dev/xvdb como ext4..."
      sudo mkfs.ext4 -F /dev/xvdb >/dev/null
    fi
    sudo mount /dev/xvdb /var/lib/longhorn
    if ! grep -q "/var/lib/longhorn" /etc/fstab; then
      echo "/dev/xvdb /var/lib/longhorn ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab >/dev/null
    fi
    echo "Disco /dev/xvdb montado em /var/lib/longhorn:"
    df -h /var/lib/longhorn
  fi
}

instalar_longhorn_no_master() {
  local LONGHORN_VER="$1"

  WORKER_NODES=$(kubectl get nodes --no-headers | grep -v "control-plane" | wc -l)
  QTD_NODES=$(kubectl get nodes --no-headers | wc -l)

  echo "Verificando se todos os $QTD_NODES nodes estão com status Ready: "
  while [ "$(kubectl get nodes --no-headers | grep -w Ready | wc -l)" != "$QTD_NODES" ]; do
    printf "."
    sleep 1
  done
  echo " OK!"

  # Instalador oficial de pré-requisitos iSCSI como fallback via DaemonSet
  kubectl apply -f "https://raw.githubusercontent.com/longhorn/longhorn/${LONGHORN_VER}/deploy/prerequisite/longhorn-iscsi-installation.yaml"

  echo ""
  echo "Aplicando manifesto do Longhorn (${LONGHORN_VER})..."
  kubectl apply -f "https://raw.githubusercontent.com/longhorn/longhorn/${LONGHORN_VER}/deploy/longhorn.yaml"

  echo ""
  echo "Aguardando pods do Longhorn em longhorn-system iniciarem (geralmente 1 a 2 min): "
  while [ "$(kubectl get pods -n longhorn-system -l app=longhorn-manager --no-headers 2>/dev/null | grep -w Running | wc -l)" != "$QTD_NODES" ]; do
    printf "."
    sleep 2
  done
  echo " OK!"

  echo "Aguardando Longhorn UI ficar Ready: "
  kubectl rollout status deployment/longhorn-ui -n longhorn-system --timeout=180s

  # Define a StorageClass 'longhorn' como default (desmarcando local-path caso esteja como default)
  if kubectl get storageclass local-path >/dev/null 2>&1; then
    kubectl patch storageclass local-path \
      -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || true
  fi
  kubectl patch storageclass longhorn \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

  # Expõe o Dashboard do Longhorn (longhorn-frontend) via NodePort
  kubectl patch svc longhorn-frontend -n longhorn-system \
    -p '{"spec": {"type": "NodePort"}}'

  echo ""
  echo "StorageClasses configuradas:"
  kubectl get storageclass

  echo ""
  echo "Pods em longhorn-system:"
  kubectl get pods -n longhorn-system -o wide

  INGRESS_HOST=$(curl -s checkip.amazonaws.com)
  LONGHORN_PORT=$(kubectl get svc longhorn-frontend -n longhorn-system -o jsonpath='{.spec.ports[0].nodePort}')

  echo ""
  echo "========================================"
  echo "   GERENCIADOR DE VOLUMES LONGHORN ATIVO"
  echo "========================================"
  echo ""
  echo "Acessar Longhorn Dashboard UI:"
  echo "http://$INGRESS_HOST:$LONGHORN_PORT"
  echo ""
}

# Se executado a partir da pasta do Terraform (controller), prepara todos os nós via SSH e instala no Master.
# Se executado diretamente dentro do Master (onde kubectl já funciona), roda localmente.
if [ -f "main.tf" ] && command -v terraform >/dev/null 2>&1 && [ -f "terraform.tfstate" ]; then
  MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
  QTD_NODES=$(terraform output -json ip_externo | jq '.[] | length')
  WORKER_NODES=$(expr $QTD_NODES - 1)

  printf "\n\n"
  echo "   CONFIGURANDO OS VOLUMES REPLICADOS: LONGHORN (${LONGHORN_VERSION})"
  printf "\n\n"

  for N in $(seq 0 $WORKER_NODES); do
    NODE_IP=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "-> Preparando Node $N ($NODE_IP)..."
    ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$NODE_IP \
      "$(typeset -f preparar_node_storage); preparar_node_storage"
  done

  echo ""
  echo "-> Instalando Longhorn no Master ($MASTER)..."
  ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER \
    "$(typeset -f instalar_longhorn_no_master); instalar_longhorn_no_master '$LONGHORN_VERSION'"

  # Configura o cron para detectar rapidamente falha nos nodes (drain/uncordon)
  if [ -f "k8s_config_cron.sh" ]; then
    echo "-> Configurando Cron de monitoramento de Nodes no Master..."
    ssh -oStrictHostKeyChecking=no -i ~/environment/labsuser.pem ec2-user@$MASTER 'bash -s' < k8s_config_cron.sh
  fi
else
  preparar_node_storage
  instalar_longhorn_no_master "$LONGHORN_VERSION"
fi
