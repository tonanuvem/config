# Fila de testes no master

Para não ficar disparando medição a mão. O executor roda destacado no master,
uma tarefa por vez, e sobrevive a queda de SSH.

## Subir

A fila é instalada **automaticamente** pelo `k8s_create_cluster.sh`, no fim da
criação do cluster. Para instalar sozinha a qualquer momento, de dentro de
`genai/`:

```bash
sh k8s_config_fila.sh
```

Ela **instala e não dispara**: uma bateria de medição leva horas e consome o
lab inteiro, então começar isso sozinho a cada criação de cluster seria errado.
Para iniciar, no master:

```bash
vi ~/fila/tarefas.txt
setsid nohup sh ~/fila/executar.sh > ~/fila/executor.log 2>&1 < /dev/null &
```

Os harnesses de medição (`medir.sh`, `rede.sh`, `concorrencia.sh`) e os
manifests das fases vivem no repositório `k8s-exemplos`. O
`k8s_config_fila.sh` os copia se encontrar `~/environment/k8s-exemplos/llm`
na VM, e avisa em vez de falhar se não encontrar — a fila roda qualquer
comando, não depende deles.

## Acompanhar

```bash
sh ~/fila/status.sh
```

```
executor: RODANDO (pid 31452)

TAREFA                       ESTADO    DURACAO
00-aguardar-corrente         ok         61 min 12 s
10-concorrencia-pp           rodando
20-concorrencia-pp-1slot     pendente
```

## Consolidar

```bash
python3 ~/fila/consolidar.py     # escreve resultados.csv e resultados.md
```

É o consolidador que o item 4 dos entregáveis pede. Lê `logs/*.log`, extrai
TTFT, tok/s, prefill por token, vazão agregada sob concorrência e os
contadores de estouro de banda do Nitro. Campo vazio quer dizer que não
apareceu no log — não preenche nada por conta.

## Por que ela tem as propriedades que tem

O lab do AWS Academy **expira sozinho** e já nos custou uma bateria pela
metade. Então:

- **Retomável.** Tarefa que termina bem deixa `estado/<id>.ok` e não repete.
  Depois de um stop/start, relançar o executor continua de onde parou — nada
  de refazer duas horas de medição.
- **Aceita tarefa nova em voo.** O `tarefas.txt` é relido a cada volta, então
  dá para acrescentar linhas com o executor rodando, que é o ponto de
  "agendar mais testes" sem derrubar nada.
- **Não congela numa tarefa ruim.** Falha é registrada e a fila segue; três
  falhas na mesma tarefa e ela é desistida, para não girar em falso.
- **Uma por vez, com trava.** Duas baterias simultâneas contaminariam as duas,
  e a trava impede dois executores por acidente.
- **Um log por tarefa**, com início, fim e duração, que é o que o
  `consolidar.py` lê.

## Encerrar

```bash
touch ~/fila/estado/.parar     # sai quando a fila esvaziar
```

Sem isso o executor fica esperando tarefa nova em vez de morrer — de
propósito, para que agendar mais seja só editar o `tarefas.txt`.
