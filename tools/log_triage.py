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
WARMUP_SEC = 30.0           # memória: ignora o carregamento inicial ao medir a inclinação
GROWTH_ALERT_MB_PER_MIN = 5.0
TOP = 10

MILESTONE_RE = re.compile(r'^DES_MILESTONE (\S+) t=(\d+)(?: (.*))?$')
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


def parse_log(path):
    text = path.read_text(encoding='utf-8', errors='replace')
    lines = text.splitlines()
    report = dict(lines=len(lines), milestones=[], modules=[], error=None, host_exception=None,
                  stub_calls={}, stubbed_at_link=0, vulkan={}, warnings={})
    pending_module = None
    for i, line in enumerate(lines):
        if m := MILESTONE_RE.match(line):
            report['milestones'].append(dict(name=m.group(1), t_ms=int(m.group(2)), detail=m.group(3) or ''))
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
    report['run'] = run
    report['memory'] = memory_summary(run_dir / 'memory.csv')
    report['calls'] = calls_summary(run_dir / 'calls.json')
    report['game_log'] = game_log_summary(run_dir)
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
