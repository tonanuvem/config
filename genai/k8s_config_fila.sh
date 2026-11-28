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
# repositorio (k8s-exemplos). Copia se estiver presente na VM; senao avisa,
# em vez de falhar -- a fila funciona com qualquer comando.
EX=~/environment/k8s-exemplos/llm
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
  echo "   AVISO: $EX nao existe nesta VM."
  echo "          Os harnesses (medir.sh, rede.sh, concorrencia.sh) e os"
  echo "          manifests das fases vem do repositorio k8s-exemplos:"
  echo "            git clone https://github.com/tonanuvem/k8s-exemplos.git ~/environment/k8s-exemplos"
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
