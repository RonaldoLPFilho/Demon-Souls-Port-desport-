#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Base de NIDs do KytyPS5 e cobertura dos imports do jogo (PLAN.md §6 Fase 1, tarefas 2–3).

1. Lê o código do engine (engine/src, somente leitura) e monta a base de NIDs que a HLE
   registra: cada LIB_FUNC/LIB_OBJECT dentro de um LIB_DEFINE, com a biblioteca e o módulo do
   LIB_VERSION em vigor, a função C++, o arquivo e a linha.
2. Com --inventory (saída do inspect_self.py), classifica cada import do jogo seguindo a ordem
   de resolução do RuntimeLinker::Resolve (engine/src/loader/runtimeLinker.cpp):
     a) HLE com chave exata nid[lib_vN][mod_vA.B][Tipo] (SymbolDatabase::GenerateName);
     b) export de um módulo do dump com a mesma biblioteca e módulo;
     c) só pelo NID e tipo: primeiro a HLE, depois os módulos do dump ("PS5 NID fallback").
   Status:
     implemented             - HLE com corpo que faz algo
     stub                    - HLE cujo corpo não faz nada útil (ver STUB_RULES)
     provided_by_game_module - exportado por um .prx do dump (roda nativo)
     missing                 - ninguém fornece; o KytyPS5 liga a um stub que só loga
3. Grava out/nid_db.json, out/nid_status.json e docs/IMPORTS.md.

Nomes: o código do engine não guarda o nome original dos NIDs. Um nome só aparece no relatório
quando é **verificado pelo hash**: candidatos derivados da função C++ (ex.: PadInit ->
scePadInit) ou de um arquivo de nomes opcional (--names, um nome por linha), aceitos apenas se
nid(nome) == NID.

Uso:
    python tools/nid_db.py                         # só a base do engine -> out/nid_db.json
    python tools/nid_db.py --inventory out/inventory.json
"""
import argparse
import bisect
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ps5elf  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
LIB_PREFIX = 'libSce'
SYMBOL_TYPE = {'func': 'Func', 'object': 'Object', 'notype': 'NoType'}

# Regras de stub, aplicadas ao corpo da função sem comentários nem strings. Documentadas no
# relatório para quem ler saber o que "stub" significa aqui.
STUB_RULES = [
    ('name', 'nome da função contém "Stub" ou "Unknown"'),
    ('empty', 'corpo sem nenhuma instrução além de log/validação'),
    ('return_constant', 'corpo só loga/valida e retorna uma constante neutra (OK, 0, -1, nullptr, '
                        'true/false) ou um código de erro; algumas estão corretas assim (ex.: '
                        '"captura em andamento" = false), por isso é "stub provável"'),
    ('aborts', 'corpo só aborta (EXIT/EXIT_NOT_IMPLEMENTED)'),
]
NOISE_CALLS = ('PRINT_NAME', 'LOGF', 'LOGF_COLOR', 'EXIT_IF', 'KYTY_PROFILER_FUNCTION',
               'KYTY_PROFILER_BLOCK', 'UNUSED', 'Q_UNUSED')
ABORT_CALLS = ('EXIT', 'EXIT_NOT_IMPLEMENTED')
# Constantes "neutras" (sucesso sem efeito) e códigos de erro. Outras constantes (ex.: uma
# resolução de relógio, um tamanho fixo) são implementações legítimas e não contam como stub.
NEUTRAL_RE = re.compile(
    r'^\(?\s*(?:static_cast<[^>]+>\s*\()?\s*(?:0|0x0+|-1|OK|nullptr|NULL|true|false)[uUlL]*\s*\)?\s*\)?$'
    r'|^(?:[\w:]*::)?[A-Z0-9_]*ERR[A-Z0-9_]*$')


# --- leitura do código C++ -----------------------------------------------------------------------
def strip_code(text):
    """Troca comentários e literais de string/char por espaços, preservando as posições."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            j = n if j < 0 else j
            out[i:j] = ' ' * (j - i)
            i = j
        elif c == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out[i:j] = [ch if ch == '\n' else ' ' for ch in text[i:j]]
            i = j
        elif c == 'R' and text.startswith('R"', i):
            m = re.match(r'R"([^(]*)\(', text[i:])
            if m:
                end = text.find(')' + m.group(1) + '"', i)
                j = n if end < 0 else end + len(m.group(1)) + 2
                out[i:j] = [ch if ch == '\n' else ' ' for ch in text[i:j]]
                i = j
            else:
                i += 1
        elif c in '"\'':
            j = i + 1
            while j < n and text[j] != c and text[j] != '\n':
                j += 2 if text[j] == '\\' else 1
            j = min(j + 1, n)
            out[i + 1:j - 1] = ' ' * max(0, j - i - 2)
            i = j
        else:
            i += 1
    return first_preprocessor_branch(''.join(out))


def first_preprocessor_branch(text):
    """Apaga os ramos #elif/#else, mantendo só o primeiro ramo de cada #if. Ramos alternativos
    costumam repetir uma linha com `{` (ex.: `if (...) {` por plataforma) e desbalanceariam as
    chaves. As posições são preservadas."""
    out, skip = [], []
    for line in text.splitlines(keepends=True):
        directive = re.match(r'\s*#\s*(if|ifdef|ifndef|elif|else|endif)\b', line)
        keyword = directive.group(1) if directive else None
        if keyword in ('if', 'ifdef', 'ifndef'):
            skip.append(False)
        elif keyword in ('elif', 'else') and skip:
            skip[-1] = True
        hidden = any(skip) or keyword is not None
        if keyword == 'endif' and skip:
            skip.pop()
        out.append(re.sub(r'[^\n]', ' ', line) if hidden else line)
    return ''.join(out)


def matching(text, start, open_ch, close_ch):
    """Posição do fechamento que casa com text[start] == open_ch (texto já sem strings)."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == open_ch:
            depth += 1
        elif text[i] == close_ch:
            depth -= 1
            if depth == 0:
                return i
    return -1


class LineIndex:
    def __init__(self, text):
        self.starts = [0] + [m.end() for m in re.finditer('\n', text)]

    def line(self, pos):
        return bisect.bisect_right(self.starts, pos)


VERSION_RE = re.compile(r'\bLIB_VERSION\s*\(\s*"([^"]*)"\s*,\s*(\d+)\s*,\s*"([^"]*)"\s*,\s*(\d+)\s*,\s*(\d+)\s*\)')
DEFINE_RE = re.compile(r'\bLIB_DEFINE\s*\(\s*(\w+)\s*\)\s*\{')
ENTRY_RE = re.compile(r'\bLIB_(FUNC|OBJECT)\s*\(\s*"([^"]*)"\s*,\s*([^;]*?)\)\s*;', re.S)
# A macro aparece antes ou depois do tipo de retorno: `int KYTY_SYSV_ABI F(` e
# `static KYTY_SYSV_ABI void F(`; o nome é o último identificador antes do '('.
SYSV_DEF_RE = re.compile(r'\bKYTY_SYSV_ABI\b[^;{}()]*?(\w+)\s*\(')


def scan_file(path, rel):
    raw = path.read_text(encoding='utf-8', errors='replace')
    code = strip_code(raw)
    # Valores de string apagados pelo strip_code são lidos do texto original nas mesmas posições.
    lines = LineIndex(code)

    # Os g_library/g_module do LIB_VERSION valem para o namespace onde foram declarados, também
    # quando esse namespace é reaberto mais abaixo (regra de busca de nomes do C++). Por isso a
    # versão de um LIB_DEFINE é a do namespace-prefixo mais longo, declarada antes dele.
    paths = namespace_paths(code)
    versions = []  # (pos, caminho de namespace, dados)
    for m in VERSION_RE.finditer(raw):
        if code[m.start():m.start() + 11] != 'LIB_VERSION':
            continue  # dentro de comentário ou de ramo #else
        versions.append((m.start(), paths(m.start()),
                         dict(library=m.group(1), library_version=int(m.group(2)),
                              module=m.group(3), module_version=[int(m.group(4)), int(m.group(5))])))

    registrations = []
    for d in DEFINE_RE.finditer(code):
        body_end = matching(code, d.end() - 1, '{', '}')
        here = paths(d.start())
        active = [v for v in versions if v[0] < d.start() and here[:len(v[1])] == v[1]]
        version = max(active, key=lambda v: (len(v[1]), v[0]))[2] if active else None
        for e in ENTRY_RE.finditer(code, d.end(), body_end):
            nid_value = ENTRY_RE.match(raw, e.start()).group(2)
            target = re.sub(r'\s+', '', raw[e.start(3):e.end(3)])
            registrations.append(dict(
                nid=nid_value, kind='func' if e.group(1) == 'FUNC' else 'object',
                target=target, function=target.lstrip('&').split('::')[-1],
                init=d.group(1), file=rel, line=lines.line(e.start()),
                **(version or dict(library=None, library_version=None, module=None, module_version=None))))

    definitions = []
    for m in SYSV_DEF_RE.finditer(code):
        close = matching(code, m.end() - 1, '(', ')')
        if close < 0:
            continue
        rest = code[close + 1:close + 200]
        brace = re.match(r'\s*(?:const\s*)?(?:noexcept\s*)?\{', rest)
        if not brace:
            continue  # declaração, não definição
        start = close + 1 + brace.end() - 1
        end = matching(code, start, '{', '}')
        if end < 0:
            continue
        definitions.append(dict(name=m.group(1), file=rel, line=lines.line(m.start()),
                                body=code[start + 1:end]))
    return registrations, definitions, code


def namespace_paths(code):
    """Função pos -> tupla com os namespaces abertos naquela posição."""
    events = []  # (pos, +nome | None para fechar)
    stack = []
    opener = re.compile(r'\bnamespace\s+([\w:]*)\s*\{')
    openers = {m.end() - 1: tuple(p for p in m.group(1).split('::')) for m in opener.finditer(code)}
    for i, ch in enumerate(code):
        if ch == '{':
            stack.append(openers.get(i))
        elif ch == '}' and stack:
            stack.pop()
            events.append((i, tuple(stack)))
            continue
        else:
            continue
        events.append((i, tuple(stack)))
    positions = [e[0] for e in events]

    def at(pos):
        k = bisect.bisect_right(positions, pos) - 1
        if k < 0:
            return ()
        names = []
        for entry in events[k][1]:
            if entry is not None:
                names.extend(entry)
        return tuple(names)
    return at


def find_plain_definition(code, name):
    """Definição sem KYTY_SYSV_ABI (ex.: `int chmod(...) {`), no mesmo arquivo."""
    for m in re.finditer(r'(?<![\w.>])' + re.escape(name) + r'\s*\(', code):
        close = matching(code, m.end() - 1, '(', ')')
        if close < 0:
            continue
        brace = re.match(r'\s*(?:const\s*)?(?:noexcept\s*)?\{', code[close + 1:close + 120])
        line_start = code.rfind('\n', 0, m.start()) + 1
        prefix = code[line_start:m.start()]
        if brace and re.search(r'\w[\w:<>\*&\s]*\s[\*&]?$', prefix) and 'return' not in prefix:
            start = close + 1 + brace.end() - 1
            end = matching(code, start, '{', '}')
            if end > 0:
                return m.start(), code[start + 1:end]
    return None


def remove_calls(body, names):
    """Remove chamadas `NOME(...)` balanceadas do corpo."""
    pattern = re.compile(r'\b(?:' + '|'.join(map(re.escape, names)) + r')\s*\(')
    out, pos = [], 0
    for m in pattern.finditer(body):
        if m.start() < pos:
            continue
        end = matching(body, m.end() - 1, '(', ')')
        if end < 0:
            break
        out.append(body[pos:m.start()])
        pos = end + 1
    out.append(body[pos:])
    return ''.join(out)


def classify_body(name, body):
    """('implemented'|'stub', motivo|None) segundo STUB_RULES."""
    if 'Stub' in name or 'Unknown' in name:
        return 'stub', 'name'
    text = remove_calls(body, NOISE_CALLS)
    text = re.sub(r'\(\s*void\s*\)\s*\w+\s*;', ';', text)               # (void)arg;
    text = re.sub(r'\[\[maybe_unused\]\]', '', text)
    statements = [s.strip() for s in re.split(r'[;\n]', text) if s.strip() and s.strip() not in '{}']
    statements = [s for s in statements if s != ';']
    if not statements:
        return 'stub', 'empty'
    if all(re.match(r'^(?:' + '|'.join(ABORT_CALLS) + r')\s*\(', s) for s in statements):
        return 'stub', 'aborts'
    if len(statements) == 1 and statements[0].startswith('return'):
        expr = statements[0][len('return'):].strip()
        if NEUTRAL_RE.match(expr):
            return 'stub', 'return_constant'
    return 'implemented', None


def name_candidates(function):
    base = re.sub(r'(?:Stub|Impl|Internal|_\d+)$', '', function)
    snake = re.sub(r'(?<=[a-z0-9])(?=[A-Z])', '_', base).lower()
    return [f'sce{base}', base, base[:1].lower() + base[1:], snake, f'_{snake}']


def scan_engine(src, names=()):
    registrations, definitions, sources = [], [], {}
    for path in sorted(src.rglob('*.cpp')):
        rel = path.relative_to(src.parent).as_posix()
        r, d, code = scan_file(path, rel)
        registrations += r
        definitions += d
        sources[rel] = code
    by_name = {}
    for d in definitions:
        by_name.setdefault(d['name'], []).append(d)
    known_names = {ps5elf.nid(n): n for n in names}
    for r in registrations:
        if r['kind'] == 'object':
            r['body_status'], r['stub_reason'], r['definition'] = 'implemented', None, None
        else:
            candidates = by_name.get(r['function'], [])
            same_file = [c for c in candidates if c['file'] == r['file']]
            chosen = (same_file or candidates or [None])[0]
            if chosen is None:
                plain = find_plain_definition(sources[r['file']], r['function'])
                if plain is not None:
                    chosen = dict(file=r['file'], line=LineIndex(sources[r['file']]).line(plain[0]),
                                  body=plain[1])
            if chosen is None:
                r['body_status'], r['stub_reason'], r['definition'] = 'implemented', 'body_not_found', None
            else:
                r['body_status'], r['stub_reason'] = classify_body(r['function'], chosen['body'])
                r['definition'] = f"{chosen['file']}:{chosen['line']}"
                if len(candidates) > 1 and not same_file:
                    r['stub_reason'] = (r['stub_reason'] or '') + ' (definição ambígua)'
        r['name'] = known_names.get(r['nid'])
        if r['name'] is None:
            r['name'] = next((c for c in name_candidates(r['function']) if ps5elf.nid(c) == r['nid']), None)
    return registrations, len(definitions)


# --- resolução dos imports ------------------------------------------------------------------------
def strip_prefix(name):
    return name[len(LIB_PREFIX):] if name and name.startswith(LIB_PREFIX) else name


def exact_key(nid, library, library_version, module, module_version, symbol_type):
    return (nid, strip_prefix(library), library_version, strip_prefix(module),
            tuple(module_version or ()), symbol_type)


def build_index(registrations):
    exact, by_nid = {}, {}
    for r in registrations:
        stype = SYMBOL_TYPE[r['kind']]
        if r['library'] is not None:
            exact.setdefault(exact_key(r['nid'], r['library'], r['library_version'], r['module'],
                                       r['module_version'], stype), r)
        by_nid.setdefault((r['nid'], stype), []).append(r)
    return exact, by_nid


def resolve(inventory, registrations, auto_modules=('libc.prx',)):
    exact, by_nid = build_index(registrations)
    module_exports, module_by_nid = {}, {}
    for f in inventory['files']:
        if f['path'] == 'eboot.bin':
            continue
        for e in f['exports']:
            stype = SYMBOL_TYPE[e['type']]
            module_exports.setdefault((e['nid'], e['library'], e['module'], stype), f['path'])
            module_by_nid.setdefault((e['nid'], stype), f['path'])
    rows = []
    for f in inventory['files']:
        for imp in f['imports']:
            stype = SYMBOL_TYPE.get(imp['type'], imp['type'])
            key = exact_key(imp['nid'], imp['library'], imp['library_version'], imp['module'],
                            imp['module_version'], stype)
            row = dict(importer=f['path'], nid=imp['nid'], library=imp['library'], module=imp['module'],
                       type=imp['type'], call_site_count=imp.get('call_site_count'),
                       call_sites=imp.get('call_sites', []), slots=imp['slots'],
                       provider=None, match=None, function=None, definition=None, stub_reason=None,
                       name=None, hle_candidates=len(by_nid.get((imp['nid'], stype), [])))
            hle = exact.get(key)
            module_path = module_exports.get((imp['nid'], imp['library'], imp['module'], stype))
            if hle is None and module_path is None:
                fallback = by_nid.get((imp['nid'], stype))
                hle = fallback[0] if fallback else None
                if hle is None:
                    module_path = module_by_nid.get((imp['nid'], stype))
                row['match'] = 'nid_fallback' if (hle or module_path) else None
            else:
                row['match'] = 'exact'
            if module_path and module_path == f['path']:
                module_path = None
            if hle is not None:
                row.update(status=hle['body_status'] if hle['body_status'] == 'stub' else 'implemented',
                           provider='hle', function=hle['target'], definition=hle['definition'] or
                           f"{hle['file']}:{hle['line']}", stub_reason=hle['stub_reason'], name=hle['name'],
                           hle_library=hle['library'])
            elif module_path is not None:
                row.update(status='provided_by_game_module', provider=module_path,
                           module_loaded='auto' if Path(module_path).name in auto_modules else 'on_request')
            else:
                row.update(status='missing')
            rows.append(row)
    return rows


# --- relatório ------------------------------------------------------------------------------------
STATUSES = ('implemented', 'stub', 'missing', 'provided_by_game_module')


def pct(n, total):
    return f'{100.0 * n / total:.1f}%' if total else '—'


def write_imports_md(path, inventory, rows, registrations, definition_count, names_file):
    eboot = [r for r in rows if r['importer'] == 'eboot.bin']
    total = len(eboot)
    counts = {s: sum(1 for r in eboot if r['status'] == s) for s in STATUSES}
    param = inventory.get('param') or {}
    by_lib = {}
    for r in eboot:
        by_lib.setdefault(r['library'] or '?', []).append(r)
    worst = sorted(by_lib.items(), key=lambda kv: (-sum(r['status'] in ('missing', 'stub') for r in kv[1]), kv[0]))
    L = []
    L.append('# Cobertura dos imports do jogo\n')
    L.append('> Gerado por `tools/nid_db.py` a partir de `out/inventory.json` e do código de `engine/src`. '
             'Não editar à mão.\n')
    L.append(f"Jogo: `{param.get('titleId')}` região {param.get('region')} versão {param.get('contentVersion')}. "
             f"Engine: {len(registrations)} registros HLE, {definition_count} definições `KYTY_SYSV_ABI` lidas.\n")
    L.append('## Resumo (eboot.bin)\n')
    L.append('| Status | Imports | % |')
    L.append('|---|---:|---:|')
    for s in STATUSES:
        L.append(f'| `{s}` | {counts[s]} | {pct(counts[s], total)} |')
    L.append(f'| **total** | **{total}** | |\n')
    fallback = sum(1 for r in eboot if r['match'] == 'nid_fallback')
    L.append(f'**Funções que faltam (`missing` + `stub`): {counts["missing"] + counts["stub"]}.** '
             f'Resolvidos só pelo NID (sem casar biblioteca/módulo): {fallback}.\n')
    others = [r for r in rows if r['importer'] != 'eboot.bin']
    if others:
        L.append('Imports dos módulos do dump (`sce_module/`): ' + ', '.join(
            f"{s} {sum(1 for r in others if r['status'] == s)}" for s in STATUSES) + '.\n')
    L.append('### 20 bibliotecas com mais `missing` + `stub`\n')
    L.append('| Biblioteca | missing | stub | implemented | módulo do jogo | total |')
    L.append('|---|---:|---:|---:|---:|---:|')
    for lib, items in worst[:20]:
        c = {s: sum(1 for r in items if r['status'] == s) for s in STATUSES}
        L.append(f"| {lib} | {c['missing']} | {c['stub']} | {c['implemented']} | "
                 f"{c['provided_by_game_module']} | {len(items)} |")
    L.append('\n### Critérios\n')
    L.append('- A ordem de resolução segue `RuntimeLinker::Resolve`: HLE com chave exata, export de módulo '
             'com a mesma biblioteca/módulo, depois só pelo NID e tipo.')
    L.append('- `stub` (heurística sobre o corpo da função, sem comentários/strings):')
    for key, text in STUB_RULES:
        L.append(f'  - `{key}`: {text}')
    L.append('- `body_not_found`: a função registrada não foi achada como definição `KYTY_SYSV_ABI`; '
             'conta como `implemented` e merece conferência manual.')
    L.append('- Sítios de chamada: varredura de bytes (`call/jmp rel32` para stubs PLT e `call [rip+GOT]`); '
             'serve para ordenar por uso, pode ter falsos positivos.')
    L.append(f"- Nomes: só os verificados pelo hash do NID{' (inclui ' + names_file + ')' if names_file else ''}.\n")
    L.append('## Por biblioteca (eboot.bin)\n')
    for lib in sorted(by_lib):
        items = sorted(by_lib[lib], key=lambda r: (STATUSES.index(r['status']), -(r['call_site_count'] or 0), r['nid']))
        L.append(f'### {lib}\n')
        L.append('| NID | Nome | Status | Função no engine | Sítios | Primeiros endereços |')
        L.append('|---|---|---|---|---:|---|')
        for r in items:
            where = r['function'] or (r['provider'] if r['provider'] not in (None, 'hle') else '')
            if r['stub_reason']:
                where += f" ({r['stub_reason']})"
            if r['match'] == 'nid_fallback':
                where += ' [só NID]'
            addrs = ', '.join(f'{a:#x}' for a in r['call_sites'][:3])
            sites = '' if r['call_site_count'] is None else r['call_site_count']
            L.append(f"| `{r['nid']}` | {r['name'] or ''} | `{r['status']}` | {where} | {sites} | {addrs} |")
        L.append('')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(L) + '\n', encoding='utf-8')


GPU_LIBRARIES = ('libSceAgc', 'libSceAgcDriver', 'libSceVideoOut', 'libSceAmpr')


def write_gpu_surface(path, rows):
    """Superfície gráfica importada pelo eboot (PLAN.md §6 Fase 1, tarefa 5)."""
    eboot = [r for r in rows if r['importer'] == 'eboot.bin' and r['library'] in GPU_LIBRARIES]
    L = ['# Superfície AGC / VideoOut / Ampr importada pelo eboot\n',
         '> Gerado por `tools/nid_db.py`. Escopo da Fase 4 (PLAN.md §6).\n',
         '| Biblioteca | implemented | stub | missing | total | sítios de chamada |',
         '|---|---:|---:|---:|---:|---:|']
    for lib in GPU_LIBRARIES:
        items = [r for r in eboot if r['library'] == lib]
        c = {s: sum(r['status'] == s for r in items) for s in STATUSES}
        sites = sum(r['call_site_count'] or 0 for r in items)
        L.append(f"| {lib} | {c['implemented']} | {c['stub']} | {c['missing']} | {len(items)} | {sites} |")
    L.append('')
    for lib in GPU_LIBRARIES:
        items = sorted((r for r in eboot if r['library'] == lib),
                       key=lambda r: (STATUSES.index(r['status']), -(r['call_site_count'] or 0), r['nid']))
        if not items:
            continue
        L.append(f'## {lib}\n')
        L.append('| NID | Nome verificado | Status | Função no engine | Biblioteca na HLE | Sítios |')
        L.append('|---|---|---|---|---|---:|')
        for r in items:
            fn = r['function'] or ''
            if r['stub_reason']:
                fn += f" ({r['stub_reason']})"
            L.append(f"| `{r['nid']}` | {r['name'] or ''} | `{r['status']}` | {fn} | "
                     f"{r.get('hle_library') or ''} | {r['call_site_count'] or 0} |")
        L.append('')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(L) + '\n', encoding='utf-8')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--engine', type=Path, default=ROOT / 'engine' / 'src')
    parser.add_argument('--inventory', type=Path, help='out/inventory.json do inspect_self.py')
    parser.add_argument('--names', type=Path, help='arquivo opcional com nomes de símbolos, um por linha')
    parser.add_argument('--out-dir', type=Path, default=ROOT / 'out')
    parser.add_argument('--imports-md', type=Path, default=ROOT / 'docs' / 'IMPORTS.md')
    parser.add_argument('--gpu-surface', type=Path, default=ROOT / 'docs' / 'GPU_SURFACE.md',
                        help='tabela da superfície AGC/VideoOut/Ampr (resumo em docs/GPU_NOTES.md)')
    args = parser.parse_args(argv)
    if not args.engine.is_dir():
        parser.error(f'{args.engine} não existe (git submodule update --init --recursive)')
    names = []
    if args.names:
        names = [n.strip() for n in args.names.read_text(encoding='utf-8').splitlines()
                 if n.strip() and not n.startswith('#')]
    registrations, definition_count = scan_engine(args.engine, names)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    stubs = sum(r['body_status'] == 'stub' for r in registrations)
    named = sum(r['name'] is not None for r in registrations)
    (args.out_dir / 'nid_db.json').write_text(json.dumps(dict(
        tool='nid_db', format_version=1, registrations=registrations,
        definitions_scanned=definition_count), indent=1) + '\n', encoding='utf-8')
    print(f'Engine: {len(registrations)} registros HLE ({len({r["nid"] for r in registrations})} NIDs), '
          f'{stubs} stubs, {named} com nome verificado -> {args.out_dir / "nid_db.json"}')
    if args.inventory:
        inventory = json.loads(args.inventory.read_text(encoding='utf-8'))
        rows = resolve(inventory, registrations)
        (args.out_dir / 'nid_status.json').write_text(json.dumps(dict(
            tool='nid_db', format_version=1, rows=rows), indent=1) + '\n', encoding='utf-8')
        write_imports_md(args.imports_md, inventory, rows, registrations, definition_count,
                         args.names.name if args.names else None)
        write_gpu_surface(args.gpu_surface, rows)
        eboot = [r for r in rows if r['importer'] == 'eboot.bin']
        print('eboot.bin: ' + ', '.join(f"{s} {sum(r['status'] == s for r in eboot)}" for s in STATUSES)
              + f' -> {args.imports_md}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
