#!/bin/sh
# Panorama da fila. Rodar no master: sh ~/fila/status.sh
BASE=$(cd "$(dirname "$0")" && pwd)
PID=$(cat "$BASE/estado/.trava" 2>/dev/null || echo "")
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
  echo "executor: RODANDO (pid $PID)"
else
  echo "executor: PARADO"
fi
echo
printf "%-28s %-9s %s\n" TAREFA ESTADO DURACAO
while IFS= read -r L || [ -n "$L" ]; do
  case "$L" in ''|\#*) continue ;; esac
  ID=$(printf '%s' "$L" | cut -d'|' -f1)
  [ -z "$ID" ] && continue
  if [ -e "$BASE/estado/$ID.ok" ]; then E=ok
  elif [ -e "$BASE/logs/$ID.log" ]; then E=rodando
  else E=pendente; fi
  D=$(grep -h '^### duracao:' "$BASE/logs/$ID.log" 2>/dev/null | tail -1 | cut -d: -f2-)
  printf "%-28s %-9s %s\n" "$ID" "$E" "${D:-}"
done < "$BASE/tarefas.txt"
echo
echo "ultima linha do log em curso:"
ls -t "$BASE/logs"/*.log 2>/dev/null | head -1 | xargs -r tail -2
