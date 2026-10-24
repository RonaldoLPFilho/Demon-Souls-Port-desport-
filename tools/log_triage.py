#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Relatório curto de uma execução do KytyPS5 (PLAN.md §6 Fase 2, tarefa 4).

Lê uma pasta de captures/runs/<id>/ (log.txt, run.json, memory.csv, calls.json) ou só um log, e
produz um resumo no stdout e em <pasta>/triage.md:
  - resultado da execução (run.json) e último marco DES_MILESTONE;
  - parada do engine (bloco "--- Error ---") ou exceção do host, com módulo + offset;
  - imports ausentes efetivamente chamados ("Unresolved import stub called"), com o status do
    docs/IMPORTS.md (out/nid_status.json) quando disponível;
  - mensagens de validação Vulkan agrupadas; avisos repetidos com contagem;
  - memória: pico e crescimento por minuto após o aquecimento (PA-001);
  - rastreamento de chamadas (calls.json): funções chamadas, as mais frequentes e as que nunca
    foram chamadas.

Uso:
    python tools/log_triage.py captures/runs/<id>
    python tools/log_triage.py captures/runs/<id>/log.txt --no-write
"""
import argparse
from collections import Counter
import csv
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
MEM_SLOPE_SKIP_SEC = 120.0  # DES_MEM: a inclinação só usa amostras depois dos 2 primeiros minutos
WARMUP_SEC = 30.0           # memória: ignora o carregamento inicial ao medir a inclinação
GROWTH_ALERT_MB_PER_MIN = 5.0
TOP = 10

MILESTONE_RE = re.compile(r'^DES_MILESTONE (\S+) t=(\d+)(?: (.*))?$')
FPS_RE = re.compile(r'^DES_FPS t=(\d+) fps=([\d.]+)$')
SLOW_CALL_RE = re.compile(r'^DES_SLOW (.*)$')
MEM_RE = re.compile(r'^DES_MEM t=(\d+) name=(\S+) bytes=(\d+) count=(\d+)$')
CRASH_RE = re.compile(r'^DES_CRASH (.*)$')
STATS_RE = re.compile(r'^(DES_COUNTERS|DES_STAT|DES_STAT_ADDR) (.*)$')
LOADING_RE = re.compile(r'^Loading: (.+)$')
BASE_RE = re.compile(r'^base_vaddr\s*=\s*0x([0-9a-fA-F]+)')
SIZE_RE = re.compile(r'^mapped_size\s*=\s*0x([0-9a-fA-F]+)')
STUB_CALL_RE = re.compile(r'^Unresolved import stub called \[\d+\]: .*?symbol=(\S+)')
STUB_LINK_RE = re.compile(r'^Relocate: unresolved \S+ import patched to stub')
VULKAN_RE = re.compile(r'^\[Vulkan\]\[([A-Z])\]\[(\d+)\]: (.*)$')
HOST_EXC_RE = re.compile(r'Unhandled host exception: .*?pc=0x([0-9a-fA-F]+).*?address=0x([0-9a-fA-F]+)')
WARNING_RE = re.compile(r'(^warning:|\bignoring\b|\bnot implemented\b|\bunsupported\b)', re.I)


def normalize(line):
    line = re.sub(r'0x[0-9a-fA-F]+', 'N', line)
    return re.sub(r'\d+', 'N', line).strip()


def parse_crash(text):
    """DES_CRASH: pares chave=valor separados por espaço; message="..." vai até o fim da linha."""
    message = ''
    if ' message="' in text:
        text, message = text.split(' message="', 1)
        message = message.rstrip().rstrip('"')
    fields = dict(kv.split('=', 1) for kv in text.split() if '=' in kv)
    fields['message'] = message
    return fields


def parse_log(path):
    text = path.read_text(encoding='utf-8', errors='replace')
    lines = text.splitlines()
    report = dict(lines=len(lines), milestones=[], fps=[], slow_calls=[], counters=[], stats=[], stat_addrs=[], mem_samples=[], crashes=[], modules=[], error=None, host_exception=None,
                  stub_calls={}, stubbed_at_link=0, vulkan={}, warnings={})
    pending_module = None
    for i, line in enumerate(lines):
        if m := MILESTONE_RE.match(line):
            report['milestones'].append(dict(name=m.group(1), t_ms=int(m.group(2)), detail=m.group(3) or ''))
        elif m := FPS_RE.match(line):
            report['fps'].append((int(m.group(1)), float(m.group(2))))
        elif m := SLOW_CALL_RE.match(line):
            report['slow_calls'].append(dict(kv.split('=', 1) for kv in m.group(1).split() if '=' in kv))
        elif m := CRASH_RE.match(line):
            report['crashes'].append(parse_crash(m.group(1)))
        elif m := MEM_RE.match(line):
            report['mem_samples'].append((int(m.group(1)), m.group(2), int(m.group(3)), int(m.group(4))))
        elif m := STATS_RE.match(line):
            fields = dict(kv.split('=', 1) for kv in m.group(2).split() if '=' in kv)
            key = {'DES_COUNTERS': 'counters', 'DES_STAT': 'stats', 'DES_STAT_ADDR': 'stat_addrs'}[m.group(1)]
            report[key].append(fields)
        elif m := LOADING_RE.match(line):
            pending_module = dict(path=m.group(1).replace('\\', '/'), base=None, size=None)
            report['modules'].append(pending_module)
        elif pending_module and (m := BASE_RE.match(line)):
            pending_module['base'] = int(m.group(1), 16)
        elif pending_module and (m := SIZE_RE.match(line)):
            pending_module['size'] = int(m.group(1), 16)
            pending_module = None
        elif line.strip() == '--- Error ---':
            body = [l.strip() for l in lines[i + 1:i + 6] if l.strip()]
            where = next((l for l in body if l.startswith('in ')), None)
            report['error'] = dict(message=body[0] if body else '', where=where[3:] if where else None)
        elif m := STUB_CALL_RE.match(line):
            report['stub_calls'][m.group(1)] = report['stub_calls'].get(m.group(1), 0) + 1
        elif STUB_LINK_RE.match(line):
            report['stubbed_at_link'] += 1
        elif m := VULKAN_RE.match(line):
            key = (m.group(1), m.group(2), normalize(m.group(3))[:160])
            report['vulkan'][key] = report['vulkan'].get(key, 0) + 1
        elif WARNING_RE.search(line) and not line.startswith(('\t', ' ')):
            key = normalize(line)[:200]
            report['warnings'][key] = report['warnings'].get(key, 0) + 1
        if m := HOST_EXC_RE.search(line):
            report['host_exception'] = dict(pc=int(m.group(1), 16), address=int(m.group(2), 16))
    return report


def locate(address, modules):
    for m in modules:
        if m['base'] is not None and m['size'] and m['base'] <= address < m['base'] + m['size']:
            return f"{Path(m['path']).name}+{address - m['base']:#x}"
    return None


def mem_by_category(samples):
    """DES_MEM (t_ms, nome, bytes, contagem) -> por categoria: valor inicial, final, pico e inclinação.

    A inclinação (MB/min) é a reta de mínimos quadrados das amostras depois de MEM_SLOPE_SKIP_SEC;
    None se houver menos de 3 amostras nessa faixa ou menos de 1 minuto entre elas.
    """
    by_name = {}
    for t_ms, name, size, count in sorted(samples, key=lambda x: x[0]):
        by_name.setdefault(name, []).append((t_ms, size, count))
    out = {}
    for name, rows in by_name.items():
        late = [(t / 60000.0, b / 1048576.0) for t, b, _ in rows if t >= MEM_SLOPE_SKIP_SEC * 1000]
        slope = None
        if len(late) >= 3 and late[-1][0] - late[0][0] >= 1.0:
            n = len(late)
            mean_t = sum(t for t, _ in late) / n
            mean_v = sum(v for _, v in late) / n
            den = sum((t - mean_t) ** 2 for t, _ in late)
            slope = sum((t - mean_t) * (v - mean_v) for t, v in late) / den if den else None
        out[name] = dict(first_mb=rows[0][1] / 1048576.0, last_mb=rows[-1][1] / 1048576.0,
                         peak_mb=max(b for _, b, _ in rows) / 1048576.0, slope_mb_per_min=slope,
                         last_count=rows[-1][2], samples=len(rows))
    return out


def memory_summary(path):
    if not path.exists():
        return None
    samples = []
    with path.open(encoding='utf-8') as f:
        for row in csv.DictReader(f):
            try:
                samples.append((float(row['t_sec']), float(row['private_mb']), float(row['working_set_mb'])))
            except (KeyError, ValueError):
                continue
    if not samples:
        return None
    steady = [s for s in samples if s[0] >= WARMUP_SEC]
    slope = None
    if len(steady) >= 10:
        n = len(steady)
        mean_t = sum(s[0] for s in steady) / n
        mean_m = sum(s[1] for s in steady) / n
        var = sum((s[0] - mean_t) ** 2 for s in steady)
        if var > 0:
            slope = 60.0 * sum((s[0] - mean_t) * (s[1] - mean_m) for s in steady) / var
    return dict(samples=len(samples), duration_sec=samples[-1][0],
                peak_private_mb=max(s[1] for s in samples), peak_working_set_mb=max(s[2] for s in samples),
                last_private_mb=samples[-1][1], growth_mb_per_min=slope,
                alert=slope is not None and slope > GROWTH_ALERT_MB_PER_MIN)


def calls_summary(path):
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding='utf-8'))
    entries = data.get('entries', [])
    called = [e for e in entries if e.get('count')]
    return dict(elapsed_ms=data.get('elapsed_ms'), imports=len(entries), called=len(called),
                total_calls=sum(e['count'] for e in called),
                top=sorted(called, key=lambda e: -e['count'])[:TOP],
                first=sorted(called, key=lambda e: (e['first_ms'] is None, e['first_ms'] or 0))[:TOP])


GAME_TIMING = re.compile(r'\[MSG-Init\] (?:(.+?) took ([\d.]+)(m?s)|(Finished Initialization|Starting main loop): ([\d.]+)s)')
GAME_ERROR = re.compile(r'\[[\d:.]+ ERROR-(\w+)\] (.*)')


def game_log_summary(run_dir):
    """Tempos de inicialização e erros do log do próprio jogo (game_logs/, vindo de /hostapp/logs)."""
    logs = sorted((run_dir / 'game_logs').glob('*.log'))
    if not logs:
        return None
    timings, errors = {}, Counter()
    for path in logs:
        for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
            m = GAME_TIMING.search(line)
            if m and m.group(1):
                sec = float(m.group(2)) / (1000.0 if m.group(3) == 'ms' else 1.0)
                timings.setdefault(m.group(1), sec)
            elif m:
                timings.setdefault(m.group(4), float(m.group(5)))
            e = GAME_ERROR.search(line)
            if e:
                errors[f'{e.group(1)}: {e.group(2)}'] += 1
    return dict(files=[p.name for p in logs], timings=timings, errors=errors)


SLOW_FRAME_RE = re.compile(r'SLOW Frame ([\d.]+) ms(.*)$')


def hitch_summary(run_dir):
    """Quadros lentos do engine FrameGen ("SLOW Frame <ms> ms ... compile=<ms>" no stdout.txt)."""
    path = run_dir / 'stdout.txt'
    if not path.exists():
        return None
    frames = []
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        m = SLOW_FRAME_RE.search(line)
        if not m:
            continue
        fields = dict(kv.split('=', 1) for kv in m.group(2).split() if '=' in kv)
        try:
            compile_ms = float(fields.get('compile', 0))
        except ValueError:
            compile_ms = 0.0
        frames.append((float(m.group(1)), compile_ms))
    if not frames:
        return None
    total = sum(f for f, _ in frames)
    compiling = [f for f, c in frames if c >= 0.5 * f]
    return dict(count=len(frames), total_ms=total, worst_ms=max(f for f, _ in frames),
                over_500=sum(1 for f, _ in frames if f >= 500), over_1000=sum(1 for f, _ in frames if f >= 1000),
                compile_count=len(compiling), compile_ms=sum(compiling))


def load_status():
    path = ROOT / 'out' / 'nid_status.json'
    if not path.exists():
        return {}
    rows = json.loads(path.read_text(encoding='utf-8')).get('rows', [])
    return {r['nid']: r for r in rows}


def triage(target):
    target = Path(target)
    run_dir = target if target.is_dir() else target.parent
    log = target / 'log.txt' if target.is_dir() else target
    if not log.exists():
        raise FileNotFoundError(f'{log} não existe')
    run = None
    if (run_dir / 'run.json').exists():
        run = json.loads((run_dir / 'run.json').read_text(encoding='utf-8-sig'))
    report = parse_log(log)
    # Linhas DES_* também vão para o stdout (o engine desport-fg as emite nos dois): com o log em
    # Silent só o stdout.txt as tem. Junta sem duplicar.
    stdout = run_dir / 'stdout.txt'
    if stdout.exists():
        extra = parse_log(stdout)
        seen = {m['name'] for m in report['milestones']}
        report['milestones'] += [m for m in extra['milestones'] if m['name'] not in seen]
        report['milestones'].sort(key=lambda m: m['t_ms'])
        for key in ('fps', 'slow_calls', 'counters', 'stats', 'stat_addrs', 'mem_samples', 'crashes'):
            if not report[key]:
                report[key] = extra[key]
    report['run'] = run
    report['memory'] = memory_summary(run_dir / 'memory.csv')
    report['mem_categories'] = mem_by_category(report['mem_samples'])
    report['dumps'] = sorted(p.name for p in run_dir.glob('*.dmp'))
    report['calls'] = calls_summary(run_dir / 'calls.json')
    report['game_log'] = game_log_summary(run_dir)
    report['hitches'] = hitch_summary(run_dir)
    if report['host_exception']:
        report['host_exception']['where'] = locate(report['host_exception']['pc'], report['modules'])
    status = load_status()
    if report['calls']:
        # Funções de módulos nativos (ex.: libc.prx) não têm nome no engine; usa o verificado.
        for entry in report['calls']['top'] + report['calls']['first']:
            if not entry.get('function'):
                entry['function'] = (status.get(entry['nid']) or {}).get('name') or ''
    report['stub_call_rows'] = []
    for symbol, count in sorted(report['stub_calls'].items(), key=lambda kv: -kv[1]):
        nid = re.split(r'[\[#]', symbol)[0]
        row = status.get(nid, {})
        report['stub_call_rows'].append(dict(symbol=symbol, nid=nid, count=count,
                                             library=row.get('library'), name=row.get('name')))
    return report, run_dir


def load_scenario(name, path=ROOT / 'tests' / 'regression' / 'scenarios.toml'):
    import tomllib
    scenarios = tomllib.loads(path.read_text(encoding='utf-8'))
    if name not in scenarios:
        raise KeyError(f'cenário desconhecido: {name} (há: {", ".join(scenarios)})')
    return scenarios[name]


def evaluate(report, scenario):
    """Lista de falhas do cenário (vazia = passou)."""
    failures = []
    seen = {m['name']: m['t_ms'] for m in report['milestones']}
    for name in scenario.get('expect_milestones', []):
        if name not in seen:
            failures.append(f'marco ausente: {name}')
    deadline = scenario.get('deadline_ms')
    if deadline is not None:
        late = [n for n in scenario.get('expect_milestones', []) if n in seen and seen[n] > deadline]
        failures += [f'marco {n} em {seen[n]} ms (limite {deadline} ms)' for n in late]
    if not scenario.get('allow_engine_stop', False) and report['error']:
        failures.append(f"parada do engine: {report['error']['message']}")
    if report['host_exception']:
        failures.append('exceção do host')
    run = report.get('run') or {}
    if run.get('result') == 'crashed_or_error' and not scenario.get('allow_engine_stop', False):
        failures.append(f"processo terminou com código {run.get('exit_code')}")
    limit = scenario.get('max_vulkan_errors')
    if limit is not None:
        errors = sum(n for k, n in report['vulkan'].items() if k[0] == 'E')
        if errors > limit:
            failures.append(f'{errors} erros de validação Vulkan (limite {limit})')
    growth_limit = scenario.get('max_growth_mb_per_min')
    mem = report.get('memory') or {}
    if growth_limit is not None and mem.get('growth_mb_per_min') is not None \
            and mem['growth_mb_per_min'] > growth_limit:
        failures.append(f"memória cresce {mem['growth_mb_per_min']:.1f} MB/min (limite {growth_limit})")
    return failures


def _render_stats(report):
    """Médias por quadro dos contadores do engine (DES_COUNTERS) e dos escopos DES_STAT."""
    L = ['## Contadores por quadro (DES_STATS)\n']
    frames = sum(int(c.get('frames', 0)) for c in report['counters'])
    if frames:
        names = [k for k in report['counters'][0] if k not in ('t', 'frames')]
        L.append(f'- {frames} quadros em {len(report["counters"])} janelas de 5 s\n')
        L.append('| Contador | por quadro |')
        L.append('|---|---:|')
        for name in names:
            total = sum(int(c.get(name, 0)) for c in report['counters'])
            value = total / frames
            shown = f'{value / 1e6:.2f} ms' if name.endswith('_ns') else (
                f'{value / 1024:.0f} KiB' if name.endswith('_bytes') else f'{value:.1f}')
            L.append(f'| {name} | {shown} |')
        L.append('')
    if report['stats'] and frames:
        totals = {}
        for s in report['stats']:
            calls, ms, size = totals.get(s['name'], (0, 0.0, 0))
            totals[s['name']] = (calls + int(s['calls']), ms + float(s['ms']), size + int(s.get('bytes', 0)))
        L.append('| Escopo | chamadas/quadro | ms/quadro | KiB/quadro |')
        L.append('|---|---:|---:|---:|')
        for name, (calls, ms, size) in sorted(totals.items(), key=lambda kv: -kv[1][1]):
            L.append(f'| {name} | {calls / frames:.1f} | {ms / frames:.2f} | {size / 1024 / frames:.0f} |')
        L.append('')
    if report['stat_addrs']:
        regions = {}
        for s in report['stat_addrs']:
            key = (s['name'], s['region'])
            calls, ms = regions.get(key, (0, 0.0))
            regions[key] = (calls + int(s['calls']), ms + float(s['ms']))
        L.append('| Escopo | região de 64 KiB | chamadas | ms |')
        L.append('|---|---|---:|---:|')
        for (name, region), (calls, ms) in sorted(regions.items(), key=lambda kv: -kv[1][1])[:TOP]:
            L.append(f'| {name} | `{region}` | {calls} | {ms:.1f} |')
        L.append('')
    return L


def _by_minute(fps):
    out = {}
    for t_ms, value in fps:
        out.setdefault(t_ms // 60000, []).append(value)
    return out


def render(report):
    L = ['# Triagem da execução\n']
    if 'scenario' in report:
        sc = report['scenario']
        verdict = 'PASSOU' if not sc['failures'] else 'FALHOU'
        L.append(f"**Cenário `{sc['name']}`: {verdict}**" +
                 ''.join(f"\n- {f}" for f in sc['failures']) + '\n')
    run = report.get('run') or {}
    if run:
        L.append(f"- Execução: `{run.get('run_id')}` — resultado **{run.get('result')}**, código "
                 f"{run.get('exit_code')}, {run.get('duration_sec')} s")
        L.append(f"- Flags: `{' '.join(run.get('flags') or []) or '(nenhuma)'}`")
    ms = report['milestones']
    L.append(f"- Último marco: **{ms[-1]['name']}** (t={ms[-1]['t_ms']} ms)" if ms else '- Último marco: nenhum')
    if report['error']:
        L.append(f"- **Parada do engine:** `{report['error']['message']}` em `{report['error']['where']}`")
    if report['host_exception']:
        e = report['host_exception']
        L.append(f"- **Exceção do host:** pc={e['pc']:#x} ({e.get('where') or 'fora dos módulos'}), "
                 f"endereço {e['address']:#x}")
    if not report['error'] and not report['host_exception']:
        L.append('- Parada: nenhuma registrada no log')
    L.append('')
    if ms:
        L.append('## Marcos\n')
        L.append('| Marco | t (ms) | Detalhe |')
        L.append('|---|---:|---|')
        L.extend(f"| {m['name']} | {m['t_ms']} | {m['detail']} |" for m in ms)
        L.append('')
    if report['fps']:
        values = sorted(f for _, f in report['fps'])
        L.append('## FPS (DES_FPS, janelas de 5 s)\n')
        L.append(f"- {len(values)} janelas: mínimo {values[0]:.1f}, mediana {values[len(values) // 2]:.1f}, "
                 f"máximo {values[-1]:.1f}")
        L.append('- Por minuto: ' + ', '.join(
            f"{minute}′ {sum(v) / len(v):.1f}" for minute, v in sorted(_by_minute(report['fps']).items())))
        L.append('')
    if report.get('slow_calls'):
        L.append('## Chamadas acima de 1 s (DES_SLOW)\n')
        L.append('| t (ms) | Escopo | ms | Endereço |')
        L.append('|---:|---|---:|---|')
        L.extend(f"| {s.get('t')} | {s.get('name')} | {s.get('ms')} | `{s.get('vaddr')}` |"
                 for s in report['slow_calls'][:TOP * 3])
        L.append('')
    hitches = report.get('hitches')
    if hitches:
        L.append('## Travadas (SLOW Frame, stdout.txt)\n')
        L.append(f"- {hitches['count']} quadros lentos, {hitches['total_ms'] / 1000:.1f} s no total; pior "
                 f"{hitches['worst_ms']:.0f} ms; ≥ 500 ms: {hitches['over_500']}; ≥ 1 s: {hitches['over_1000']}")
        L.append(f"- Dominados por compilação de shader: {hitches['compile_count']} "
                 f"({hitches['compile_ms'] / 1000:.1f} s)")
        L.append('')
    if report['counters'] or report['stats']:
        L.extend(_render_stats(report))
    L.append('## Imports ausentes\n')
    L.append(f"- Ligados a stub na relocação: {report['stubbed_at_link']}")
    if report['stub_call_rows']:
        L.append(f"- **Chamados durante a execução: {len(report['stub_call_rows'])}**\n")
        L.append('| Símbolo | Biblioteca | Nome | Chamadas registradas |')
        L.append('|---|---|---|---:|')
        L.extend(f"| `{r['symbol']}` | {r['library'] or ''} | {r['name'] or ''} | {r['count']} |"
                 for r in report['stub_call_rows'])
    else:
        L.append('- Chamados durante a execução: nenhum')
    L.append('')
    L.append('## Validação Vulkan\n')
    if report['vulkan']:
        L.append('| Severidade | ID | Mensagem (normalizada) | Vezes |')
        L.append('|---|---|---|---:|')
        for (sev, ident, msg), n in sorted(report['vulkan'].items(), key=lambda kv: -kv[1]):
            L.append(f'| {sev} | {ident} | {msg} | {n} |')
    else:
        L.append('- Nenhuma mensagem.')
    L.append('')
    L.append('## Avisos repetidos\n')
    if report['warnings']:
        L.extend(f'- {n}× `{w}`' for w, n in sorted(report['warnings'].items(), key=lambda kv: -kv[1])[:TOP])
    else:
        L.append('- Nenhum.')
    L.append('')
    mem = report.get('memory')
    L.append('## Memória (PA-001)\n')
    if mem:
        growth = (f"{mem['growth_mb_per_min']:.1f} MB/min após {WARMUP_SEC:.0f} s"
                  if mem['growth_mb_per_min'] is not None else 'execução curta demais para medir')
        L.append(f"- Pico: {mem['peak_private_mb']:.0f} MB privados, {mem['peak_working_set_mb']:.0f} MB "
                 f"working set; final {mem['last_private_mb']:.0f} MB; {mem['samples']} amostras em "
                 f"{mem['duration_sec']:.0f} s")
        L.append(f"- Crescimento: {growth}" + (' — **ALERTA**' if mem['alert'] else ''))
    else:
        L.append('- Sem memory.csv.')
    L.append('')
    if report.get('crashes') or report.get('dumps'):
        L.append('## Crash (DES_CRASH)\n')
        for c in report.get('crashes') or []:
            L.append(f"- **{c.get('kind', '?')}** t={c.get('t')} ms, código {c.get('code')}, pc {c.get('pc')} "
                     f"(`{c.get('module')}`), thread {c.get('thread')} {c.get('name') or ''}".rstrip()
                     + f", dump `{c.get('dump')}`")
            if c.get('message'):
                L.append(f"  - {c['message']}")
        if report.get('dumps'):
            L.append('- Minidumps na pasta da execução: ' + ', '.join(f'`{d}`' for d in report['dumps']))
        L.append('')
    cats = report.get('mem_categories')
    if cats:
        L.append('## Memória por categoria (DES_MEM)\n')
        first = next(iter(cats.values()))
        L.append(f"- {first['samples']} amostras por categoria; inclinação = MB/min depois dos primeiros "
                 f"{MEM_SLOPE_SKIP_SEC:.0f} s (— quando não há amostras suficientes)\n")
        L.append('| Categoria | Inicial (MB) | Final (MB) | Pico (MB) | Inclinação (MB/min) | Contagem final |')
        L.append('|---|---:|---:|---:|---:|---:|')
        ordered = sorted(cats.items(), key=lambda kv: (not kv[0].startswith('process_'), -kv[1]['last_mb']))
        for name, c in ordered:
            slope = '—' if c['slope_mb_per_min'] is None else f"{c['slope_mb_per_min']:+.1f}"
            flag = ' **ALERTA**' if c['slope_mb_per_min'] is not None and c['slope_mb_per_min'] > GROWTH_ALERT_MB_PER_MIN else ''
            L.append(f"| {name} | {c['first_mb']:.0f} | {c['last_mb']:.0f} | {c['peak_mb']:.0f} | {slope}{flag} | {c['last_count']} |")
        L.append('')
    game = report.get('game_log')
    if game:
        L.append('## Log do jogo (game_logs/)\n')
        L.append('| Etapa | s |')
        L.append('|---|---:|')
        L.extend(f'| {name} | {sec:.2f} |' for name, sec in game['timings'].items())
        if game['errors']:
            L.append('')
            L.extend(f'- {n}× `{msg}`' for msg, n in game['errors'].most_common(TOP))
        L.append('')
    calls = report.get('calls')
    if calls:
        L.append('## Rastreamento de chamadas (calls.json)\n')
        L.append(f"- {calls['called']} de {calls['imports']} imports chamados, {calls['total_calls']} chamadas "
                 f"em {calls['elapsed_ms']} ms")
        L.append('\n| Mais chamadas | Função | Chamadas | Primeira (ms) |')
        L.append('|---|---|---:|---:|')
        L.extend(f"| `{e['nid']}` | {e['function']} | {e['count']} | {e['first_ms']} |" for e in calls['top'])
        L.append('')
    return '\n'.join(L) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('target', type=Path, help='pasta da execução ou log.txt')
    parser.add_argument('--no-write', action='store_true', help='não grava triage.md')
    parser.add_argument('--json', action='store_true', help='imprime o relatório em JSON')
    parser.add_argument('--scenario', help='avalia o cenário de tests/regression/scenarios.toml '
                                           '(código de saída 2 se falhar)')
    args = parser.parse_args(argv)
    try:
        report, run_dir = triage(args.target)
        if args.scenario:
            failures = evaluate(report, load_scenario(args.scenario))
            report['scenario'] = dict(name=args.scenario, failures=failures)
    except (OSError, json.JSONDecodeError, KeyError) as error:
        print(f'log_triage: {error}', file=sys.stderr)
        return 1
    text = render(report)
    if args.json:
        printable = dict(report, vulkan=[dict(severity=k[0], id=k[1], message=k[2], count=v)
                                         for k, v in report['vulkan'].items()])
        print(json.dumps(printable, indent=1, default=str))
    else:
        print(text)
    if not args.no_write:
        (run_dir / 'triage.md').write_text(text, encoding='utf-8')
    if args.scenario and report['scenario']['failures']:
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
