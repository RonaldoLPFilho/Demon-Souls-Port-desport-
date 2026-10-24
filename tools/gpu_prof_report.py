#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Ranking agregado do perfil de GPU por shader (KYTY_GPU_PROFILE=1, linhas DES_GPU_PROF).

O engine (desport-prof) escreve, a cada KYTY_GPU_PROFILE_SECONDS, uma linha "DES_GPU_PROF total ..." e as
KYTY_GPU_PROFILE_TOP linhas "DES_GPU_PROF rank=..." mais caras dos quadros amostrados naquele período. Este
script junta todos os períodos de um ou mais logs (ou pastas de captures/runs/<id>/) e gera:
  - totais: quadros amostrados, busy e tempo atribuído por quadro, cobertura (atribuído / busy);
  - ranking por chave (tipo, pipeline, hash do ps/cs, vs, alvo ou grupos);
  - ranking por shader (só o hash: soma alvos, grupos e tipos).
Uma chave fora do top de um período não aparece nele: os valores agregados são um limite inferior (a
coluna "períodos" diz em quantos ela apareceu). Reaproveita log_triage.parse_fields.

Uso:
    python -I tools/gpu_prof_report.py captures/runs/<id> [--out report.md] [--top 25] [--skip-sec 120]
    python -I tools/gpu_prof_report.py stdout.txt --json
"""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import log_triage  # noqa: E402

PROF_RE = re.compile(r'DES_GPU_PROF (rank=\d+ .*|total .*)$')
TEXT_FIELDS = ('kind', 'pipe', 'hash', 'vs', 'target', 'groups', 'wave')  # nunca números (hashes hex)
LOG_NAMES = ('stdout.txt', 'log.txt')

# Shaders já identificados (docs/agents/knowledge.md; captura uw de 2026-10-24).
KNOWN = {
    'a44e580f4f0cfb2b': 'TAA (cs, saída 2560x1440)',
    '37db6bd367380e9c': 'passada final de saída (ps, compõe a cena no alvo 3840x2160)',
    'a6b124d2b1ba4b7e': 'camada de UI / vídeo de fundo (ps)',
}


def parse_line(line):
    """Uma linha DES_GPU_PROF -> dict (campos de texto preservados como texto), ou None."""
    m = PROF_RE.search(line.rstrip('\r\n'))
    if not m:
        return None
    body = m.group(1)
    rec = log_triage.parse_fields(body)
    for kv in body.split():
        if '=' in kv:
            k, v = kv.split('=', 1)
            if k in TEXT_FIELDS:
                rec[k] = v
    rec['type'] = 'total' if body.startswith('total ') else 'rank'
    return rec


def read_lines(target):
    """Linhas de um arquivo de log ou da pasta de uma execução (stdout.txt, senão log.txt)."""
    path = Path(target)
    if path.is_dir():
        for name in LOG_NAMES:
            if (path / name).exists():
                path = path / name
                break
        else:
            return []
    return path.read_text(encoding='utf-8', errors='replace').splitlines()


def collect(lines, skip_sec=0.0):
    """Períodos {t: {'total': dict|None, 'ranks': [dict]}} com t >= skip_sec*1000, em ordem de t."""
    periods = {}
    for line in lines:
        rec = parse_line(line)
        if rec is None or not isinstance(rec.get('t'), float):
            continue
        t = int(rec['t'])
        if t < skip_sec * 1000:
            continue
        period = periods.setdefault(t, {'total': None, 'ranks': []})
        if rec['type'] == 'total':
            period['total'] = rec
        else:
            period['ranks'].append(rec)
    return dict(sorted(periods.items()))


def shape_of(rec):
    if 'target' in rec:
        return 'target=' + rec['target']
    if 'groups' in rec:
        return 'groups=' + rec['groups']
    return ''


def aggregate(periods):
    """Totais e agregados por chave e por shader."""
    totals = defaultdict(float)
    for period in periods.values():
        total = period['total']
        if total is None:
            continue
        totals['periods'] += 1
        for k in ('frames', 'cbs', 'calls', 'attributed_ms', 'draw_ms', 'dispatch_ms', 'busy_ms', 'span_ms',
                  'dropped', 'lost', 'orphans'):
            v = total.get(k)
            if isinstance(v, float):
                totals[k] += v
    keys = {}
    shaders = {}
    for period in periods.values():
        for rec in period['ranks']:
            if not isinstance(rec.get('gpu_ms'), float):
                continue
            key = (rec.get('kind', '?'), rec.get('pipe', '?'), rec.get('hash', '?'), rec.get('vs', '-'), shape_of(rec))
            entry = keys.setdefault(key, dict(kind=key[0], pipe=key[1], hash=key[2], vs=key[3], shape=key[4],
                                              wave=rec.get('wave', ''), calls=0.0, gpu_ms=0.0, max_us=0.0,
                                              periods=0, best_rank=None))
            calls = rec['calls'] if isinstance(rec.get('calls'), float) else 0.0
            entry['calls'] += calls
            entry['gpu_ms'] += rec['gpu_ms']
            if isinstance(rec.get('max_us'), float):
                entry['max_us'] = max(entry['max_us'], rec['max_us'])
            entry['periods'] += 1
            rank = int(rec['rank']) if isinstance(rec.get('rank'), float) else None
            if rank is not None and (entry['best_rank'] is None or rank < entry['best_rank']):
                entry['best_rank'] = rank
            sh = shaders.setdefault(key[2], dict(hash=key[2], pipes=set(), kinds=set(), shapes=set(), calls=0.0,
                                                 gpu_ms=0.0, wave=set()))
            sh['pipes'].add(key[1])
            sh['kinds'].add(key[0])
            if key[4]:
                sh['shapes'].add(key[4])
            if rec.get('wave'):
                sh['wave'].add(rec['wave'])
            sh['calls'] += calls
            sh['gpu_ms'] += rec['gpu_ms']
    frames = totals.get('frames', 0.0)
    busy = totals.get('busy_ms', 0.0)

    def finish(entry):
        entry['ms_per_frame'] = entry['gpu_ms'] / frames if frames else None
        entry['calls_per_frame'] = entry['calls'] / frames if frames else None
        entry['pct_busy'] = 100.0 * entry['gpu_ms'] / busy if busy else None
        entry['avg_us'] = 1000.0 * entry['gpu_ms'] / entry['calls'] if entry['calls'] else None
        entry['name'] = KNOWN.get(entry['hash'], '')
        return entry

    by_key = sorted((finish(e) for e in keys.values()), key=lambda e: -e['gpu_ms'])
    by_shader = []
    for sh in shaders.values():
        sh = finish(sh)
        for k in ('pipes', 'kinds', 'shapes', 'wave'):
            sh[k] = sorted(sh[k])
        by_shader.append(sh)
    by_shader.sort(key=lambda e: -e['gpu_ms'])
    summary = dict(totals)
    if frames:
        summary['frame_busy_ms'] = busy / frames
        summary['frame_attributed_ms'] = totals.get('attributed_ms', 0.0) / frames
        summary['frame_span_ms'] = totals.get('span_ms', 0.0) / frames
    if busy:
        summary['coverage_pct'] = 100.0 * totals.get('attributed_ms', 0.0) / busy
        listed = sum(e['gpu_ms'] for e in by_key)
        summary['listed_pct'] = 100.0 * listed / busy
    return dict(summary=summary, by_key=by_key, by_shader=by_shader)


def _f(value, fmt='{:.3f}'):
    return '-' if value is None else fmt.format(value)


def render(result, top=25, sources=()):
    s = result['summary']
    out = ['# Perfil de GPU por shader (DES_GPU_PROF)', '']
    if sources:
        out.append('Fontes: ' + ', '.join(f'`{x}`' for x in sources))
        out.append('')
    if not s.get('periods'):
        out.append('Nenhuma linha `DES_GPU_PROF total` encontrada (KYTY_GPU_PROFILE=1 ligado? engine desport-prof?).')
        return '\n'.join(out) + '\n'
    out += [
        f"- Períodos: {int(s['periods'])}; quadros amostrados: {int(s.get('frames', 0))}; "
        f"command buffers: {int(s.get('cbs', 0))}; draws/dispatches medidos: {int(s.get('calls', 0))}",
        f"- Por quadro amostrado: busy {_f(s.get('frame_busy_ms'))} ms, atribuído {_f(s.get('frame_attributed_ms'))} ms, "
        f"vão (1º begin ao último end) {_f(s.get('frame_span_ms'))} ms",
        f"- Cobertura (atribuído / busy): {_f(s.get('coverage_pct'), '{:.1f}')}%; "
        f"listado nos tops (limite inferior): {_f(s.get('listed_pct'), '{:.1f}')}%",
        f"- Draws {_f(s.get('draw_ms'))} ms, dispatches {_f(s.get('dispatch_ms'))} ms; "
        f"sem par de query livre: {int(s.get('dropped', 0))}, perdidos: {int(s.get('lost', 0))}, "
        f"órfãos: {int(s.get('orphans', 0))}",
        '- O quadro amostrado roda serializado pelos timestamps: compare o busy com o DES_GPU_TS normal.',
        '',
        f'## Top {top} por chave', '',
        '| # | ms/quadro | % busy | chamadas/quadro | média µs | máx µs | tipo | pipeline | hash | vs | forma | wave | '
        'períodos | nome |',
        '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|',
    ]
    for i, e in enumerate(result['by_key'][:top], 1):
        out.append(f"| {i} | {_f(e['ms_per_frame'])} | {_f(e['pct_busy'], '{:.1f}')} | "
                   f"{_f(e['calls_per_frame'], '{:.1f}')} | {_f(e['avg_us'], '{:.1f}')} | {e['max_us']:.1f} | "
                   f"{e['kind']} | {e['pipe']} | `{e['hash']}` | `{e['vs']}` | {e['shape']} | {e['wave'] or '-'} | "
                   f"{e['periods']} | {e['name']} |")
    out += ['', f'## Top {top} por shader (soma alvos, grupos e tipos)', '',
            '| # | ms/quadro | % busy | chamadas/quadro | hash | pipelines | tipos | formas | wave | nome |',
            '|---|---|---|---|---|---|---|---|---|---|']
    for i, e in enumerate(result['by_shader'][:top], 1):
        shapes = ', '.join(e['shapes'][:4]) + (f" (+{len(e['shapes']) - 4})" if len(e['shapes']) > 4 else '')
        out.append(f"| {i} | {_f(e['ms_per_frame'])} | {_f(e['pct_busy'], '{:.1f}')} | "
                   f"{_f(e['calls_per_frame'], '{:.1f}')} | `{e['hash']}` | {', '.join(e['pipes'])} | "
                   f"{', '.join(e['kinds'])} | {shapes} | {', '.join(e['wave']) or '-'} | {e['name']} |")
    return '\n'.join(out) + '\n'


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('inputs', nargs='+', help='logs (stdout.txt/log.txt) ou pastas de captures/runs/<id>')
    ap.add_argument('--top', type=int, default=25)
    ap.add_argument('--skip-sec', type=float, default=0.0, help='ignora períodos antes deste tempo (aquecimento)')
    ap.add_argument('--out', help='grava o relatório markdown neste arquivo')
    ap.add_argument('--json', action='store_true', help='imprime o resultado em JSON')
    args = ap.parse_args(argv)
    periods = {}
    offset = 0
    for target in args.inputs:
        # Execuções diferentes podem repetir t: desloca cada uma para não misturar períodos.
        found = collect(read_lines(target), args.skip_sec)
        for t, period in found.items():
            periods[t + offset] = period
        if found:
            offset += max(found) + 1
    result = aggregate(periods)
    if args.json:
        print(json.dumps(result, indent=1, ensure_ascii=False))
        return 0
    text = render(result, args.top, args.inputs)
    if args.out:
        Path(args.out).write_text(text, encoding='utf-8')
    print(text, end='')
    return 0


if __name__ == '__main__':
    sys.exit(main())
