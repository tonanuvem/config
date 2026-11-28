#!/bin/sh
# Executor de fila de testes. Roda no master, destacado, e sobrevive a queda
# de SSH. Uma tarefa por vez -- duas baterias simultaneas contaminariam as duas.
#
#   setsid nohup sh ~/fila/executar.sh > ~/fila/executor.log 2>&1 < /dev/null &
#
# Propriedades que importam num lab que expira sozinho:
#
# RETOMAVEL  cada tarefa que termina bem deixa um marcador em estado/<id>.ok.
#            Se o lab cair no meio, basta relancar: as concluidas sao puladas
#            e a que morreu recomeca. Nada de refazer 2 h de medicao.
#
# APPEND     o tarefas.txt e relido a CADA iteracao, entao da para acrescentar
#            tarefas com o executor rodando. Linhas novas entram no fim.
#
# UM LOG     por tarefa, em logs/<id>.log, com inicio, fim e duracao. O
#            consolidar.py le esses logs e monta a tabela.
#
# TRAVA      um unico executor por vez, senao dois disparariam medicoes
#            concorrentes sem querer.
#
# Formato do tarefas.txt:  <id>|<comando>
# Linhas em branco e comecando com # sao ignoradas.
set -u
BASE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$BASE/logs" "$BASE/estado"
TRAVA="$BASE/estado/.trava"

if [ -e "$TRAVA" ]; then
  PID=$(cat "$TRAVA" 2>/dev/null || echo "")
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "ja existe um executor rodando (pid $PID). Saindo."; exit 1
  fi
  echo "trava orfa de pid $PID -- assumindo."
fi
echo $$ > "$TRAVA"
trap 'rm -f "$TRAVA"' EXIT

echo "executor iniciado em $(date -Is)"

while :; do
  PROXIMA=""
  # Rele o arquivo a cada volta, para aceitar tarefas acrescentadas em voo.
  while IFS= read -r LINHA || [ -n "$LINHA" ]; do
    case "$LINHA" in ''|\#*) continue ;; esac
    ID=$(printf '%s' "$LINHA" | cut -d'|' -f1)
    CMD=$(printf '%s' "$LINHA" | cut -d'|' -f2-)
    [ -z "$ID" ] && continue
    if [ ! -e "$BASE/estado/$ID.ok" ]; then
      PROXIMA="$ID"; PROXIMO_CMD="$CMD"; break
    fi
  done < "$BASE/tarefas.txt"

  if [ -z "$PROXIMA" ]; then
    echo "fila vazia em $(date -Is). Nada pendente."
    # Nao sai: fica esperando tarefa nova, que e o ponto de poder agendar
    # mais sem relancar o executor. Para encerrar, apagar o estado/.trava
    # e matar o processo, ou criar estado/.parar.
    [ -e "$BASE/estado/.parar" ] && { echo "pedido de parada. Encerrando."; exit 0; }
    sleep 120
    continue
  fi

  LOG="$BASE/logs/$PROXIMA.log"
  echo "== $(date -Is) INICIANDO $PROXIMA"
  {
    echo "### tarefa: $PROXIMA"
    echo "### comando: $PROXIMO_CMD"
    echo "### inicio: $(date -Is)"
    echo
  } > "$LOG"

  T0=$(date +%s)
  if sh -c "$PROXIMO_CMD" >> "$LOG" 2>&1; then
    RES=ok
  else
    RES=falhou
  fi
  T1=$(date +%s)

  {
    echo
    echo "### fim: $(date -Is)"
    echo "### duracao: $(( (T1 - T0) / 60 )) min $(( (T1 - T0) % 60 )) s"
    echo "### resultado: $RES"
  } >> "$LOG"

  if [ "$RES" = ok ]; then
    touch "$BASE/estado/$PROXIMA.ok"
    echo "== $(date -Is) OK $PROXIMA ($(( (T1 - T0) / 60 )) min)"
  else
    # Falha NAO marca .ok, entao um relancamento tenta de novo. Mas nao
    # trava a fila: registra e segue, senao uma tarefa ruim congela tudo.
    touch "$BASE/estado/$PROXIMA.falhou"
    echo "== $(date -Is) FALHOU $PROXIMA -- ver $LOG"
    # Para nao repetir eternamente na mesma volta, marca como .ok se ja
    # falhou tres vezes.
    N=$(cat "$BASE/estado/$PROXIMA.tentativas" 2>/dev/null || echo 0)
    N=$((N + 1)); echo "$N" > "$BASE/estado/$PROXIMA.tentativas"
    [ "$N" -ge 3 ] && { touch "$BASE/estado/$PROXIMA.ok"; echo "   3 tentativas, desistindo de $PROXIMA"; }
  fi
done
