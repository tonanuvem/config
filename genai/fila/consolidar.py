#!/usr/bin/env python3
"""Consolida os logs da fila em CSV e Markdown.

E o "script Python para consolidar em CSV/Markdown" que o item 4 dos
entregaveis pede. Le logs/*.log, extrai as medicoes e escreve:

    resultados.csv       uma linha por execucao, para planilha
    resultados.md        tabelas agrupadas, para colar no relatorio

Nao inventa nada: o que nao aparece no log sai vazio. Logs parciais (lab que
expirou no meio) entram com o que tiverem.

    python3 ~/fila/consolidar.py
"""
import csv
import glob
import os
import re
import sys
from collections import defaultdict

BASE = os.path.dirname(os.path.abspath(__file__))

# Saida do medir.sh
RE_MOTOR = re.compile(r'^(motor\S*)\s+(\S+)\s+(\S*)\s*$')
RE_PROMPT = re.compile(r'^prompt:\s+(\S+)(?:\s+\(alvo\s+(\d+)\))?\s+--\s+(\d+)\s+tokens')
# "raciocinio" so aparece na saida do medir.sh; as linhas "req:" do
# concorrencia.sh trazem ttft/tps/tokens sem ele. Opcional nos dois, senao as
# latencias POR REQUISICAO sob concorrencia -- que e o que cada usuario espera
# -- ficariam de fora da consolidacao.
RE_MEDIDA = re.compile(
    r'ttft=([\d.]+)s\s+tps=([\d.]+)\s+tokens=(\d+)'
    r'(?:\s+raciocinio=(\d+))?'
    r'(?:\s+prefill=(\d+)\s+ms/token)?')
# Saida do concorrencia.sh
RE_NIVEL = re.compile(r'^===\s+(\d+)\s+requisicao')
RE_AGREG = re.compile(
    r'parede=([\d.]+)s\s+tokens=(\d+)\s+VAZAO AGREGADA=([\d.]+)\s+tok/s\s+\((\d+)/(\d+)\s+ok\)')
# Saida do rede.sh
RE_ENA = re.compile(r'^\s*(bw_\w+_allowance_exceeded|pps_allowance_exceeded):\s+(\d+)')
RE_DUR = re.compile(r'^### duracao:\s+(.*)$')
RE_RES = re.compile(r'^### resultado:\s+(\S+)')


def ler_log(caminho):
    """Devolve (linhas_de_medida, linhas_de_concorrencia, contadores_ena, meta)."""
    tarefa = os.path.basename(caminho)[:-4]
    medidas, concorrencia, ena = [], [], []
    meta = {'tarefa': tarefa, 'duracao': '', 'resultado': ''}
    motor = fase = ''
    tipo = alvo = tokens_prompt = ''
    nivel = ''

    for linha in open(caminho, errors='replace'):
        linha = linha.rstrip('\n')

        m = RE_DUR.match(linha)
        if m:
            meta['duracao'] = m.group(1).strip(); continue
        m = RE_RES.match(linha)
        if m:
            meta['resultado'] = m.group(1); continue

        m = RE_MOTOR.match(linha)
        if m:
            motor, _no, fase = m.group(1), m.group(2), m.group(3)
            continue
        m = RE_PROMPT.match(linha)
        if m:
            tipo, alvo, tokens_prompt = m.group(1), m.group(2) or '', m.group(3)
            continue
        m = RE_NIVEL.match(linha)
        if m:
            nivel = m.group(1); continue

        m = RE_MEDIDA.search(linha)
        if m:
            medidas.append({
                'tarefa': tarefa, 'motor': motor, 'fase': fase,
                'prompt': tipo, 'alvo': alvo, 'prompt_tokens': tokens_prompt,
                'ttft_s': m.group(1), 'tps': m.group(2),
                'tokens_saida': m.group(3), 'tokens_raciocinio': m.group(4) or '',
                'prefill_ms_token': m.group(5) or '',
                'concorrencia': nivel or '1',
            })
            continue
        m = RE_AGREG.search(linha)
        if m:
            concorrencia.append({
                'tarefa': tarefa, 'motor': motor, 'fase': fase,
                'concorrencia': nivel,
                'parede_s': m.group(1), 'tokens_total': m.group(2),
                'vazao_agregada_tps': m.group(3),
                'ok': m.group(4), 'pedidas': m.group(5),
            })
            continue
        m = RE_ENA.match(linha)
        if m:
            ena.append({'tarefa': tarefa, 'contador': m.group(1), 'valor': m.group(2)})

    return medidas, concorrencia, ena, meta


def tabela_md(titulo, colunas, rotulos, linhas):
    if not linhas:
        return ''
    out = ['## ' + titulo, '', '| ' + ' | '.join(rotulos) + ' |',
           '| ' + ' | '.join(['---'] * len(rotulos)) + ' |']
    for l in linhas:
        out.append('| ' + ' | '.join(str(l.get(c, '')) for c in colunas) + ' |')
    return '\n'.join(out) + '\n'


def main():
    logs = sorted(glob.glob(os.path.join(BASE, 'logs', '*.log')))
    if not logs:
        print('nenhum log em', os.path.join(BASE, 'logs')); return 1

    medidas, concorrencia, ena, metas = [], [], [], []
    for c in logs:
        a, b, e, m = ler_log(c)
        medidas += a; concorrencia += b; ena += e; metas.append(m)

    cols_m = ['tarefa', 'fase', 'prompt', 'prompt_tokens', 'concorrencia',
              'ttft_s', 'prefill_ms_token', 'tps', 'tokens_saida',
              'tokens_raciocinio', 'motor']
    with open(os.path.join(BASE, 'resultados.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols_m, extrasaction='ignore')
        w.writeheader(); w.writerows(medidas)

    partes = ['# Resultados consolidados', '',
              'Gerado por `fila/consolidar.py` a partir de `fila/logs/*.log`.',
              'Campo vazio = nao apareceu no log.', '']
    partes.append(tabela_md(
        'Medicoes (uma linha por execucao)',
        cols_m,
        ['tarefa', 'fase', 'prompt', 'tok prompt', 'conc',
         'TTFT s', 'prefill ms/tok', 'tok/s', 'tok saida', 'tok racioc.', 'motor'],
        medidas))
    partes.append(tabela_md(
        'Concorrencia (vazao agregada)',
        ['tarefa', 'fase', 'concorrencia', 'parede_s', 'tokens_total',
         'vazao_agregada_tps', 'ok', 'pedidas'],
        ['tarefa', 'fase', 'simultaneas', 'parede s', 'tokens',
         'vazao agregada tok/s', 'ok', 'pedidas'],
        concorrencia))
    partes.append(tabela_md(
        'Contadores de estouro de banda (Nitro/ENA)',
        ['tarefa', 'contador', 'valor'], ['tarefa', 'contador', 'valor'], ena))
    partes.append(tabela_md(
        'Execucao da fila',
        ['tarefa', 'duracao', 'resultado'], ['tarefa', 'duracao', 'resultado'],
        metas))

    md = '\n'.join(p for p in partes if p)
    with open(os.path.join(BASE, 'resultados.md'), 'w') as f:
        f.write(md)

    print('medicoes:', len(medidas), '| concorrencia:', len(concorrencia),
          '| contadores:', len(ena))
    print('escrito:', os.path.join(BASE, 'resultados.csv'))
    print('escrito:', os.path.join(BASE, 'resultados.md'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
