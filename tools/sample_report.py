# SPDX-License-Identifier: GPL-2.0-only
"""Relatório de amostragem de CPU (saída do build/sampler/sampler.exe, tools/sampler/).

Para cada thread com CPU relevante: % de um núcleo, funções onde a thread está (folha),
funções presentes na pilha (inclusivo) e o primeiro quadro do engine (que HLE o jogo chamou).
Endereços sem símbolo viram módulo+offset com o mapa de módulos do log.txt da execução.

    python -I tools/sample_report.py samples.json [--log captures/runs/<id>/log.txt] [-o samples.md]
"""

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import log_triage  # noqa: E402

ENGINE_MODULE = 'kyty_emulator'
MIN_CPU_PCT = 5.0
TOP = 8


def label(frame, modules):
    if frame.get('symbol'):
        return f"{frame.get('module') or '?'}!{frame['symbol']}"
    return log_triage.locate(frame['addr'], modules) or f"{frame.get('module') or 'anon'}+{frame['addr']:#x}"


def summarize(data, modules):
    seconds = data['seconds'] or 1.0
    threads = []
    for t in data['threads']:
        leaf, inclusive, engine = Counter(), Counter(), Counter()
        guest = 0
        for stack in t['stacks']:
            if not stack['frames'][0].get('module'):
                guest += stack['count']
            labels = [label(f, modules) for f in stack['frames']]
            leaf[labels[0]] += stack['count']
            for name in set(labels):
                inclusive[name] += stack['count']
            first_engine = next((l for f, l in zip(stack['frames'], labels)
                                 if f.get('module') == ENGINE_MODULE), '(fora do engine)')
            engine[first_engine] += stack['count']
        threads.append(dict(tid=t['tid'], name=t['name'] or '(sem nome)', samples=t['samples'],
                            cpu_pct=100.0 * t['cpu_ms'] / 1000.0 / seconds,
                            guest_pct=100.0 * guest / max(1, t['samples']),
                            leaf=leaf, inclusive=inclusive, engine=engine))
    threads.sort(key=lambda t: -t['cpu_pct'])
    return threads


def render(data, threads):
    busy = [t for t in threads if t['cpu_pct'] >= MIN_CPU_PCT]
    total = sum(t['cpu_pct'] for t in threads)
    L = ['# Amostragem de CPU\n',
         f"- {len(threads)} threads, {data['seconds']:.1f} s a {data['hz']} Hz; CPU total "
         f"{total:.0f}% de um núcleo; {len(busy)} threads acima de {MIN_CPU_PCT:.0f}%\n"]
    engine_tids = [t['tid'] for t in threads if t['guest_pct'] < 10 and t['cpu_pct'] >= 1]
    L.append(f"- Threads do engine (código do jogo < 10% das amostras, CPU ≥ 1%): "
             f"`{','.join(map(str, engine_tids)) or '-'}`\n")
    overall = Counter()
    for t in busy:
        n = t['samples'] or 1
        for name, c in t['engine'].items():
            overall[name] += t['cpu_pct'] * c / n
    L.append('## Onde o tempo vai (primeiro quadro do engine, ponderado pela CPU de cada thread)\n')
    L.append('| Função | % de um núcleo |')
    L.append('|---|---:|')
    L.extend(f'| `{name}` | {pct:.0f} |' for name, pct in overall.most_common(15))
    L.append('')
    for t in busy:
        n = t['samples'] or 1
        L.append(f"## Thread {t['tid']} `{t['name']}` — {t['cpu_pct']:.0f}% ({t['samples']} amostras)\n")
        for title, counter in (('Folha', t['leaf']), ('Primeiro quadro do engine', t['engine']),
                               ('Inclusivo', t['inclusive'])):
            L.append(f'{title}:')
            L.extend(f'- {100.0 * c / n:.0f}% `{name}`' for name, c in counter.most_common(TOP))
            L.append('')
    return '\n'.join(L) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('samples', type=Path)
    parser.add_argument('--log', type=Path, help='log.txt da execução (mapa de módulos do jogo)')
    parser.add_argument('-o', '--output', type=Path, help='padrão: <samples>.md')
    args = parser.parse_args(argv)
    data = json.loads(args.samples.read_text(encoding='utf-8'))
    modules = log_triage.parse_log(args.log)['modules'] if args.log else []
    text = render(data, summarize(data, modules))
    out = args.output or args.samples.with_suffix('.md')
    out.write_text(text, encoding='utf-8')
    print(text[:3000])
    return 0


if __name__ == '__main__':
    sys.exit(main())
