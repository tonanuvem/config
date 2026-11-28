#!/bin/sh
# Acrescenta UM no ao cluster que ja esta no ar, sem derrubar nada.
#
#   sh no_extra.sh
#
# Existe porque o caminho obvio e destrutivo: o k8s_create_cluster.sh roda
# "kubeadm init" no master, isto e, refaz o cluster do zero. Rodar aquilo
# para ganhar um no apagaria todo o estado -- e neste projeto estado e
# medicao, modelo baixado e banco do n8n.
#
# O caminho correto e incremental:
#
#   1. terraform apply -- aditivo, se o disco do no novo vier de
#      indices_disco_modelos. Conferido: "1 to add, 0 to change, 0 to
#      destroy".
#   2. ansible SO no no novo, com --limit. Isto NAO e preciosismo: o
#      ansible_docker.yml tem uma tarefa "Restartar o Docker service" sem
#      condicao, entao rodar nos nos antigos reiniciaria o containerd e
#      mataria os pods de inferencia no meio da medicao.
#   3. kubeadm join com token novo, gerado no master.
#
# O ansible_hosts.yml fica DE FORA de proposito: ele monta /etc/hosts a
# partir de hostvars de TODOS os hosts do inventario, e com --limit os
# outros nao tem fatos coletados, entao ele falha. /etc/hosts e conveniencia
# aqui -- o Kubernetes e o weave trabalham por IP, e os workers de
# inferencia se acham por Service DNS. Para alinhar /etc/hosts em todos,
# rodar "sh ajustar.sh" quando NAO houver medicao em curso.
set -e
export ANSIBLE_PYTHON_INTERPRETER=auto_silent
export ANSIBLE_DEPRECATION_WARNINGS=false
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
export ANSIBLE_HOST_KEY_CHECKING=false
PEM=~/environment/labsuser.pem
BASE=~/environment/config/ansible

echo "== 1. terraform apply (aditivo)"
terraform apply -auto-approve

MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
QTD=$(terraform output -json ip_externo | jq '.[] | length')
ULTIMO=$(expr $QTD - 1)
NOVO=$(terraform output -json ip_externo | jq .[] | jq .[$ULTIMO] | sed 's/"//g')
echo "   master = $MASTER / no novo = node$ULTIMO ($NOVO)"

echo "== 2. inventario"
{
  echo '[masters]'
  echo "master ansible_ssh_host=$MASTER"
  echo ''
  echo '[nodes]'
  N=1
  while [ $N -le $ULTIMO ]; do
    IP=$(terraform output -json ip_externo | jq .[] | jq .[$N] | sed 's/"//g')
    echo "node$N ansible_ssh_host=$IP"
    N=$(expr $N + 1)
  done
} > inv.hosts

echo "== 3. ansible SO em node$ULTIMO"
ANS="ansible-playbook --inventory inv.hosts -u ec2-user --key-file $PEM --limit node$ULTIMO"
$ANS $BASE/ansible_hostname.yml
$ANS $BASE/ansible_utils.yml
$ANS $BASE/ansible_docker.yml
$ANS $BASE/ansible_k8s.yml
$ANS $BASE/ansible_genai_storage.yml

echo "== 4. kubeadm join"
TOKEN=$(ssh -oStrictHostKeyChecking=no -i $PEM ec2-user@$MASTER 'sudo kubeadm token create --print-join-command')
ssh -oStrictHostKeyChecking=no -i $PEM ec2-user@$NOVO "sudo $TOKEN"

echo ""
ssh -oStrictHostKeyChecking=no -i $PEM ec2-user@$MASTER 'kubectl get nodes -o wide'
echo ""
echo "   Se o no novo tem disco de modelos, conferir a montagem:"
echo "     ssh -i $PEM ec2-user@$NOVO 'df -h /models'"
