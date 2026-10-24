#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Relatório comparativo da bateria tools/perf-ab.ps1 (captures/perf-ab/<data>/report.md).

Entrada: um manifesto JSON gravado pelo perf-ab.ps1:
  {"date": "...", "minutes": 6, "warmup_sec": 180,
   "runs": [{"id": "base", "desc": "...", "run_dir": "captures/runs/...", "outcome": "completed",
             "env": {"KYTY_X": "1"}, "flags": ["--vblank-frequency", "240"]}, ...]}
Reaproveita tools/log_triage.py (triage, frame_summary, SLOW_FRAME_RE); não tem parser próprio de DES_*.

Uso:  python -I tools/perf_ab_report.py manifesto.json --out report.md [--warmup-sec 180]
"""
import argparse
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import log_triage  # noqa: E402

CACHE_RE = re.compile(r'^((?:Vulkan|Static) pipeline cache: .*)$', re.M)
WAVE64_RE = re.compile(r'^(Vulkan compute wave64: .*)$', re.M)
PIPEKEY_RE = re.compile(r'^PIPEKEY (\S+) key=([0-9a-f]+)', re.M)
SPEEDPROBE_RE = re.compile(r'SPEEDPROBE hold_ms=(\d+) wall_s=([\d.,]+) diff=([\d.,]+)')
SPEEDPROBE_FAIL_RE = re.compile(r'(SPEEDPROBE sem captura.*)$', re.M)
MISMATCH_RE = re.compile(r'^READBACK_QUEUE_MISMATCH .*$', re.M)
HITCH_COMPARE_MS = 100.0  # as rodadas têm limiares KYTY_HITCH_LOG_MS diferentes; esta contagem é comparável


def percentile(values, p):
    """Percentil p (0-100) por posição mais próxima, sem interpolar; None se vazio."""
    if not values:
        return None
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, max(0, int(p / 100.0 * (len(ordered) - 1) + 0.5)))]


def fps_stats(fps, warmup_sec):
    """fps = [(t_ms, fps)]; média/p1/p5 depois do aquecimento (cai para tudo se nada sobrar)."""
    used = [v for t, v in fps if t >= warmup_sec * 1000]
    note = ''
    if not used and fps:
        used, note = [v for _, v in fps], 'sem janelas após o aquecimento: usando todas'
    if not used:
        return None
    return dict(windows=len(used), mean=sum(used) / len(used), p1=percentile(used, 1), p5=percentile(used, 5),
                min=min(used), max=max(used), note=note)


def hitch_counts(run_dir):
    """Quadros lentos (SLOW Frame do stdout.txt): total e os de >= HITCH_COMPARE_MS."""
    path = Path(run_dir) / 'stdout.txt'
    if not path.exists():
        return None
    ms = [float(m.group(1)) for line in path.read_text(encoding='utf-8', errors='replace').splitlines()
          if (m := log_triage.SLOW_FRAME_RE.search(line))]
    return dict(count=len(ms), total_ms=sum(ms), worst_ms=max(ms, default=0.0),
                count_100=sum(1 for v in ms if v >= HITCH_COMPARE_MS))


def run_metrics(run_dir, warmup_sec):
    run_dir = Path(run_dir)
    report, _ = log_triage.triage(run_dir)
    out = dict(fps=fps_stats(report['fps'], warmup_sec), hitches=hitch_counts(run_dir),
               crashes=len(report.get('crashes') or []), run=report.get('run') or {})
    windows = [w for w in report['frames'] if w.get('t', 0) >= warmup_sec * 1000]
    out['frame'] = log_triage.frame_summary(windows)
    text = ''
    for name in ('stdout.txt', 'log.txt'):
        p = run_dir / name
        if p.exists():
            text += p.read_text(encoding='utf-8', errors='replace') + '\n'
    # SPEEDPROBE (autopilot.txt, com soak.ps1 -SpeedProbe): o jogo andou quanto em 4 s de relógio (diff entre as imagens).
    probe_path = run_dir / 'autopilot.txt'
    probe_text = probe_path.read_text(encoding='utf-8', errors='replace') if probe_path.exists() else ''
    out['speedprobe'] = [dict(hold_ms=int(h), wall_s=float(w.replace(',', '.')), diff=float(d.replace(',', '.')))
                         for h, w, d in SPEEDPROBE_RE.findall(probe_text)]
    out['speedprobe_failed'] = SPEEDPROBE_FAIL_RE.findall(probe_text)
    # READBACK_QUEUE_MISMATCH: o engine imprime no stdout (que o log.txt pode repetir): conta uma fonte so.
    mismatch_text = ''
    for name in ('stdout.txt', 'log.txt'):
        p = run_dir / name
        if p.exists():
            mismatch_text = p.read_text(encoding='utf-8', errors='replace')
            if 'READBACK_QUEUE_MISMATCH' in mismatch_text or name == 'stdout.txt':
                break
    mismatches = MISMATCH_RE.findall(mismatch_text)
    out['mismatch_count'] = len(mismatches)
    out['mismatch_top'] = mismatches[:3]
    rb_rows = [r for r in report['readback'] if 't' not in r or r['t'] >= warmup_sec * 1000]
    out['readback_lines'] = log_triage.readback_summary(rb_rows)
    out['cache_lines'] = list(dict.fromkeys(CACHE_RE.findall(text)))[:6]
    out['wave64'] = (WAVE64_RE.findall(text) or [None])[0]
    keys = PIPEKEY_RE.findall(text)
    out['pipekey_lines'] = len(keys)
    out['pipekey_distinct'] = len({k for _, k in keys})
    out['write_watch_lines'] = len(re.findall(r'^WRITE-WATCH ', text, re.M))
    out['sync_stack_lines'] = len(re.findall(r'^SYNC-STACK ', text, re.M))
    out['sync_stack_top'] = re.findall(r'^SYNC-STACK .*$', text, re.M)[:3]
    out['write_watch_top'] = re.findall(r'^WRITE-WATCH .*$', text, re.M)[:3]
    # Readback (escopo DES_STAT 'readback', com DES_STATS=1): chamadas e ms por quadro.
    frames = sum(int(c.get('frames', 0)) for c in report['counters'])
    out['readback'] = None
    if frames:
        rows = [s for s in report['stats'] if s.get('name') == 'readback']
        if rows:
            calls, ms = sum(int(s['calls']) for s in rows), sum(float(s['ms']) for s in rows)
            out['readback'] = dict(calls_per_frame=calls / frames, ms_per_frame=ms / frames,
                                   ms_per_call=ms / calls if calls else 0.0)
    return out


def _f(v, fmt='{:.1f}'):
    return '—' if v is None else fmt.format(v)


def render(manifest, warmup_sec):
    runs = manifest['runs']
    rows = []
    for r in runs:
        try:
            m = run_metrics(r['run_dir'], warmup_sec) if r.get('run_dir') else None
        except (OSError, KeyError, ValueError, json.JSONDecodeError) as error:
            m = dict(error=str(error))
        rows.append((r, m))
    L = [f"# Bateria A/B de desempenho {manifest.get('date', '')}\n",
         f"- {len(runs)} execuções de {manifest.get('minutes', '?')} min; estatísticas de fps/DES_FRAME só depois de "
         f"{warmup_sec:.0f} s de log (aquecimento). Save de referência e autopilot em todas.",
         '- Cache do driver: o run.ps1 define KYTY_DRIVER_CACHE_KEY sozinho (sha256 do exe), então todas as rodadas usam o '
         'cache de driver (quente a partir da 2ª com o mesmo exe). C1 = cache FRIO (chave nova aleatória de 64 hex); '
         'C2 = a mesma chave, QUENTE. As outras rodadas não são frias.',
         '- Travadas: `todas` usa o limiar KYTY_HITCH_LOG_MS da própria rodada (A usa 20 ms, as outras 100 ms: '
         'não comparar); `>=100 ms` é comparável entre rodadas. Contagens incluem o carregamento inicial.',
         '']
    L += ['## Comparação\n',
          '| Execução | Resultado | fps médio | p1 | p5 | travadas (todas/total s/pior ms) | >=100 ms | DES_CRASH |',
          '|---|---|---:|---:|---:|---|---:|---:|']
    for r, m in rows:
        if not m or 'error' in m:
            L.append(f"| {r['id']} | {r.get('outcome') or '—'} | — | — | — | {(m or {}).get('error', 'sem execução')} | — | — |")
            continue
        f, h = m['fps'], m['hitches']
        hs = f"{h['count']} / {h['total_ms'] / 1000:.1f} / {h['worst_ms']:.0f}" if h else '—'
        L.append(f"| {r['id']} | {r.get('outcome') or '—'} | {_f(f and f['mean'])} | {_f(f and f['p1'])} | "
                 f"{_f(f and f['p5'])} | {hs} | {h['count_100'] if h else '—'} | {m['crashes']} |")
    L.append('')
    L += ['## Quadros (DES_FRAME)\n']
    if not any(m and m.get('frame') for _, m in rows):
        L += ['Nenhuma linha DES_FRAME nas execuções (engine sem a instrumentação, ou janelas só no aquecimento).', '']
    else:
        L += ['| Execução | vblanks 1 / 2 / 3 / 4+ (%) | p50 ms | p99 ms | readback_wait ms/quadro | sync_reads_guest/quadro | pipeline_static_misses |',
              '|---|---|---:|---:|---:|---:|---:|']
        for r, m in rows:
            fr = m.get('frame') if m else None
            if not fr:
                L.append(f"| {r['id']} | — | — | — | — | — | — |")
                continue
            seen = sum(fr['hist'].values()) or 1
            hist = ' / '.join(f"{100 * fr['hist'][k] / seen:.1f}" for k in ('v1', 'v2', 'v3', 'v4p'))
            L.append(f"| {r['id']} | {hist} | {_f(fr['p50'], '{:.2f}')} | {_f(fr['p99'], '{:.2f}')} | "
                     f"{_f(fr['waits'].get('readback_wait'), '{:.3f}')} | "
                     f"{fr['counts']['sync_reads_guest'] / (fr['frames'] or 1):.1f} | "
                     f"{fr['counts']['pipeline_static_misses']:.0f} |")
        L.append('')
    L += ['## Readback (DES_READBACK, janelas depois do aquecimento)\n']
    if not any(m and (m.get('readback_lines') or m.get('mismatch_count')) for _, m in rows):
        L += ['Nenhuma linha DES_READBACK nas execuções (engine sem a instrumentação, ou nenhuma rodada a usou).', '']
    else:
        L += ['| Execução | prefetch / ativo / queue | acertos (%) | vizinhos | esperas | perdidos | obsoletos | erros | pulados | '
              'leituras guest | guest_read us | sync_reads_guest | async | downloads sínc. | READBACK_QUEUE_MISMATCH |',
              '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
        for r, m in rows:
            rb = m.get('readback_lines') if m else None
            mism = m.get('mismatch_count') if m else None
            if not rb:
                L.append(f"| {r['id']} | — | — | — | — | — | — | — | — | — | — | — | — | — | {'—' if mism is None else mism} |")
                continue
            b, t = rb['boot'] or {}, rb['totals']
            flags = (f"{b.get('prefetch', 0):g} / {b.get('active', 0):g} / {b.get('readback_queue', 0):g}" if b else '—')
            rate = '—' if t['hit_rate'] is None else f"{100 * t['hit_rate']:.1f}%"
            L.append(f"| {r['id']} | {flags} | {t['prefetch_hits']:.0f} ({rate}) | {t['prefetch_neighbors']:.0f} | "
                     f"{t['prefetch_waits']:.0f} | {t['prefetch_lost']:.0f} | {t['prefetch_stale']:.0f} | "
                     f"{t['prefetch_misses']:.0f} | {t['prefetch_skips']:.0f} | {t['guest_reads']:.0f} | "
                     f"{t['guest_read_us']:.1f} | {t['sync_reads_guest']:.0f} | {t['async_readbacks']:.0f} | "
                     f"{t['sync_downloads']:.0f} | {mism} |")
        L.append('')
    L += ['## SpeedProbe (autopilot -SpeedProbe)\n']
    if not any(m and (m.get('speedprobe') or m.get('speedprobe_failed')) for _, m in rows):
        L += ['Nenhuma linha SPEEDPROBE nas execuções.', '']
    else:
        L += ['Segura W por 4 s de relógio; `diff` = média |A-B| por canal (0-255) entre a imagem antes e depois. A mesma '
              'trajetória andando em tempo real dá diffs parecidos; diff bem maior com mais fps = jogo acelerado.', '',
              '| Execução | vblank (flag) | wall_s | diff |', '|---|---|---:|---:|']
        for r, m in rows:
            if not m or 'error' in m:
                continue
            vb = r['flags'][-1] if r.get('flags') else '—'
            for sp in m.get('speedprobe') or []:
                L.append(f"| {r['id']} | {vb} | {sp['wall_s']:.2f} | {sp['diff']:.2f} |")
            for fail in m.get('speedprobe_failed') or []:
                L.append(f"| {r['id']} | {vb} | — | {fail} |")
        L.append('')
    L += ['## Detalhes por execução\n']
    for r, m in rows:
        L.append(f"### {r['id']} — {r.get('desc', '')}")
        L.append(f"- Pasta: `{r.get('run_dir')}` (triage.md ali)")
        if r.get('env'):
            L.append('- Env da rodada: ' + ', '.join(f'`{k}={v}`' for k, v in r['env'].items()))
        if r.get('flags'):
            L.append('- Flags sobrescritas: `' + ' '.join(r['flags']) + '`')
        if not m or 'error' in m:
            L += [f"- Sem métricas: {(m or {}).get('error', 'execução ausente')}", '']
            continue
        if m['fps'] and m['fps']['note']:
            L.append(f"- Aviso: {m['fps']['note']}")
        if m['fps']:
            L.append(f"- fps: {m['fps']['windows']} janelas, min {m['fps']['min']:.1f}, máx {m['fps']['max']:.1f}")
        for line in m['cache_lines']:
            L.append(f"- {line}")
        if m['wave64']:
            L.append(f"- {m['wave64']}")
        if m['pipekey_lines']:
            L.append(f"- PIPEKEY: {m['pipekey_lines']} linhas, {m['pipekey_distinct']} chaves distintas (pipelines fora do cache estático)")
        if m['readback']:
            rb = m['readback']
            L.append(f"- readback (DES_STAT): {rb['calls_per_frame']:.1f} chamadas/quadro, {rb['ms_per_frame']:.2f} ms/quadro, "
                     f"{rb['ms_per_call']:.3f} ms/chamada")
        for sp in m['speedprobe']:
            L.append(f"- SPEEDPROBE: wall_s={sp['wall_s']:.2f} diff={sp['diff']:.2f}")
        if m['mismatch_count']:
            L.append(f"- **READBACK_QUEUE_MISMATCH: {m['mismatch_count']} ocorrências** (primeiras abaixo)")
            for line in m['mismatch_top']:
                L.append(f"  - `{line[:300]}`")
        if m['write_watch_lines'] or m['sync_stack_lines']:
            L.append(f"- WRITE-WATCH {m['write_watch_lines']} linhas, SYNC-STACK {m['sync_stack_lines']} linhas (primeiras abaixo)")
            for line in m['write_watch_top'] + m['sync_stack_top']:
                L.append(f"  - `{line[:300]}`")
        L.append('')
    return '\n'.join(L) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--warmup-sec', type=float, default=None)
    args = parser.parse_args(argv)
    manifest = json.loads(args.manifest.read_text(encoding='utf-8-sig'))
    warmup = args.warmup_sec if args.warmup_sec is not None else float(manifest.get('warmup_sec', 180))
    args.out.write_text(render(manifest, warmup), encoding='utf-8')
    print(args.out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
