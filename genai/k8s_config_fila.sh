#!/bin/sh
# Instala a fila de testes no master. Chamado pelo k8s_create_cluster.sh,
# e pode ser rodado sozinho a qualquer momento:
#
#   sh k8s_config_fila.sh
#
# INSTALA, nao dispara. Uma bateria de medicao leva horas e consome o lab
# inteiro; comecar isso sozinho a cada criacao de cluster seria errado. O
# script deixa tudo pronto e imprime o comando para iniciar.
#
# Por que a fila existe: o lab do AWS Academy expira sozinho e ja custou uma
# bateria pela metade. A fila e retomavel (tarefa concluida nao repete),
# aceita tarefa nova enquanto roda, e grava um log por tarefa que o
# consolidar.py transforma em CSV e Markdown.
MASTER=$(terraform output -json ip_externo | jq .[] | jq .[0] | sed 's/"//g')
PEM=~/environment/labsuser.pem
SSH="ssh -o LogLevel=error -oStrictHostKeyChecking=no -i $PEM ec2-user@$MASTER"

echo ""
echo " Instalando a fila de testes no master ($MASTER)"

# A ferramenta da fila vive neste repositorio.
scp -q -o LogLevel=error -oStrictHostKeyChecking=no -i "$PEM" \
    -r "$(dirname "$0")/fila" ec2-user@$MASTER:~/ || {
      echo "   FALHOU ao copiar a fila"; exit 1; }
$SSH 'mkdir -p ~/fila/logs ~/fila/estado; chmod +x ~/fila/*.sh ~/fila/consolidar.py'
echo "   fila/ copiada"

# Os harnesses de medicao e os manifests das fases vivem no OUTRO
# repositorio (k8s-exemplos). A VM do lab e recriada a cada reinicio, entao
# contar com um clone feito a mao nao funciona: busca sozinho.
#
# Quando ja existe, atualiza -- um checkout velho enviaria manifests antigos
# para o master, e a medicao sairia de uma fase que nao e a do repositorio.
# Se o git falhar (sem rede, repositorio privado), avisa em vez de abortar:
# a fila roda qualquer comando, e as fases podem ser copiadas a mao.
REPO=~/environment/k8s-exemplos
EX=$REPO/llm
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" pull --ff-only -q 2>/dev/null \
    && echo "   k8s-exemplos atualizado" \
    || echo "   AVISO: git pull de $REPO falhou; usando o que ja esta na VM"
else
  echo "   clonando k8s-exemplos..."
  git clone -q --depth 1 https://github.com/tonanuvem/k8s-exemplos.git "$REPO" 2>/dev/null \
    && echo "   k8s-exemplos clonado" \
    || echo "   AVISO: clone de k8s-exemplos falhou"
fi

if [ -d "$EX" ]; then
  for F in medir.sh rede.sh concorrencia.sh; do
    [ -f "$EX/$F" ] && scp -q -o LogLevel=error -oStrictHostKeyChecking=no \
      -i "$PEM" "$EX/$F" ec2-user@$MASTER:~/ && echo "   $F copiado"
  done
  for D in "$EX"/fase*; do
    [ -d "$D" ] && scp -q -o LogLevel=error -oStrictHostKeyChecking=no \
      -i "$PEM" -r "$D" ec2-user@$MASTER:~/ && echo "   $(basename "$D")/ copiado"
  done
else
  echo "   AVISO: $EX nao existe nesta VM e o git nao conseguiu trazer."
  echo "          Os harnesses (medir.sh, rede.sh, concorrencia.sh) e os"
  echo "          manifests das fases vem do repositorio k8s-exemplos:"
  echo "            git clone https://github.com/tonanuvem/k8s-exemplos.git $REPO"
  echo "          Depois rodar este script de novo."
fi

echo ""
echo "   Fila instalada. Para iniciar (destacada, sobrevive a queda de SSH):"
echo ""
echo "     ssh -i $PEM ec2-user@$MASTER"
echo "     vi ~/fila/tarefas.txt      # agendar o que rodar"
echo "     setsid nohup sh ~/fila/executar.sh > ~/fila/executor.log 2>&1 < /dev/null &"
echo ""
echo "   Acompanhar:   sh ~/fila/status.sh"
echo "   Consolidar:   python3 ~/fila/consolidar.py"
echo ""
