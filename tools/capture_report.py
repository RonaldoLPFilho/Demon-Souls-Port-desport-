#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Resume uma captura de quadros do engine (src/local/frame-capture.h) em captures.md.

    python tools/capture_report.py <pasta com frame-N.jsonl> [--out captures.md] [--taa-cs HASH]
                                   [--output-size 3840x2160] [--chain 3]

Para cada quadro, em ordem de chamada: cada draw/dispatch com seus shaders (cs/vs/ps), alvos de cor e profundidade
(formato e extensão), viewport e scissor, imagens amostradas (slot, formato, extensão, endereço, escrita/storage) e
buffers. Duas marcações automáticas:
  (a) a dispatch do TAA (cs a44e580f4f0cfb2b, -taa-cs) e TODAS as passadas seguintes que leem o endereço da saída do TAA
      (marca T+1); o que essas passadas escrevem vira "derivado" e quem o lê leva T+2, e assim por diante até --chain
      níveis: serve para achar o upscale 2560 -> 3840 (ou equivalente) que vem depois do TAA;
  (b) as draws cujo alvo de cor tem o tamanho da saída (3840x2160 por padrão): a interface (UI).
O formato do .jsonl é o de frame-capture.h (uma linha por chamada: i, t, us, cs/vs/ps, vp, sc, img[], buf[]...).

Baseado no tools/local/frame-capture-report.py do KytyPS5-DemonsSouls-FrameGen (ceremony88, GPL-2.0): mesma leitura do
formato e a mesma ideia de fluxos de imagens; este relatório é por chamada e marca o TAA e a UI.
"""
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

TAA_CS = 'a44e580f4f0cfb2b'
OUTPUT_SIZE = (3840, 2160)
DEFAULT_CHAIN = 3

# Formatos VkFormat mais comuns (o cabeçalho do SDK, se existir, completa a tabela).
FORMATS = {
    9: 'R8_UNORM', 16: 'R8G8_UNORM', 37: 'R8G8B8A8_UNORM', 43: 'R8G8B8A8_SRGB', 44: 'B8G8R8A8_UNORM',
    50: 'B8G8R8A8_SRGB', 64: 'A2B10G10R10_UNORM', 70: 'R16_SFLOAT', 76: 'R16_SFLOAT', 83: 'R16G16_SFLOAT',
    91: 'R16G16B16A16_UNORM', 97: 'R16G16B16A16_SFLOAT', 98: 'R32_UINT', 100: 'R32_SFLOAT', 103: 'R32G32_SFLOAT',
    109: 'R32G32B32A32_SFLOAT', 122: 'B10G11R11_UFLOAT', 124: 'D16_UNORM', 126: 'D32_SFLOAT',
    129: 'D32_SFLOAT_S8_UINT', 130: 'D24_UNORM_S8_UINT', 131: 'BC1', 139: 'BC3',
}
for header in (Path('C:/VulkanSDK/1.4.357.0/Include/vulkan/vulkan_core.h'),):
    if header.exists():
        for match in re.finditer(r'VK_FORMAT_(\w+) = (\d+),', header.read_text(errors='replace')):
            FORMATS.setdefault(int(match.group(2)), match.group(1))


def fmt(number):
    return FORMATS.get(number, str(number))


def load(path):
    """Chamadas (linhas com 'i') de um frame-N.jsonl; linhas inválidas são ignoradas."""
    calls = []
    complete = False
    with Path(path).open(encoding='utf-8', errors='replace') as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except ValueError:
                continue
            if 'i' in record:
                calls.append(record)
            elif record.get('t') == 'flip':
                complete = True
    return calls, complete


def label(image):
    extent = f"{image.get('w', 0)}x{image.get('h', 0)}"
    if image.get('arr', 1) > 1:
        extent += f"x{image['arr']}"
    mips = f" m{image['mip']}" if image.get('mip', 1) > 1 else ''
    return f"{image.get('a', '?')}:{fmt(image.get('f', 0))}:{extent}{mips}"


def is_dispatch(call):
    return call.get('t') == 'Dispatch' or 'cs' in call


def written(image):
    """Escrita pela chamada: alvo de cor ou profundidade, ou imagem escrita/storage."""
    return image.get('k') in (0, 1) or bool(image.get('rw')) or bool(image.get('uav'))


def viewport(call):
    vp = call.get('vp')
    if not vp or len(vp) < 4:
        return None
    width, height = abs(vp[0]) * 2, abs(vp[2]) * 2
    return f"{width:g}x{height:g}@{vp[1] - abs(vp[0]):g},{vp[3] - abs(vp[2]):g}"


def shader(call):
    if is_dispatch(call):
        return f"cs {call.get('cs', '?')}"
    return f"vs {call.get('vs', '?')} ps {call.get('ps', '?')}"


def targets(call):
    return [m for m in call.get('img', []) if m.get('k') in (0, 1)]


def reads(call):
    return [m for m in call.get('img', []) if not written(m) or (m.get('k') == 2 and not m.get('rw'))]


def writes(call):
    return [m for m in call.get('img', []) if written(m)]


def is_ui(call, output_size):
    """Draw cujo alvo de cor tem o tamanho da saída."""
    if is_dispatch(call):
        return False
    return any(m.get('k') == 0 and (m.get('w'), m.get('h')) == output_size for m in call.get('img', []))


def analyse(calls, taa_cs=TAA_CS, output_size=OUTPUT_SIZE, chain=DEFAULT_CHAIN):
    """Marca cada chamada: taa (a dispatch do TAA), level (1.. = lê saída do TAA ou derivada) e ui."""
    notes = []
    taa_outputs = {}   # endereço -> nível (0 = escrita pelo TAA)
    taa_seen = False
    for call in calls:
        note = {'taa': False, 'level': 0, 'reads_from': [], 'ui': is_ui(call, output_size)}
        if is_dispatch(call) and taa_cs and str(call.get('cs', '')).lower().endswith(taa_cs.lower()):
            note['taa'] = True
            taa_seen = True
            for m in writes(call):
                taa_outputs.setdefault(m.get('a'), 0)
        elif taa_seen:
            sources = [(m, taa_outputs[m.get('a')]) for m in call.get('img', [])
                       if m.get('k') == 2 and not m.get('rw') and m.get('a') in taa_outputs]
            if sources:
                level = min(level for _, level in sources) + 1
                if level <= chain:
                    note['level'] = level
                    note['reads_from'] = [label(m) for m, _ in sources]
                    for m in writes(call):
                        taa_outputs.setdefault(m.get('a'), level)
        notes.append(note)
    return notes


def call_lines(call, note):
    """Linhas de uma chamada para o relatório."""
    tags = []
    if note['taa']:
        tags.append('**TAA**')
    if note['level']:
        tags.append(f"**T+{note['level']}**")
    if note['ui']:
        tags.append('**UI**')
    head = f"- #{call['i']} {call.get('t', '?')} {shader(call)} {call.get('us', 0):.0f} us" + (f" [{' '.join(tags)}]" if tags else '')
    if is_dispatch(call):
        head += f" groups={call.get('groups')} local={call.get('local')}"
    else:
        head += f" n={call.get('n', 0)} inst={call.get('inst', 0)}"
        vp = viewport(call)
        if vp:
            head += f" vp={vp} sc={call.get('sc')}"
        if call.get('blend0') not in (None, '0'):
            head += f" blend0={call.get('blend0')}"
    if call.get('consumed'):
        head += f" consumed={call['consumed']}"
    lines = [head]
    tg = targets(call)
    if tg:
        lines.append('  - alvos: ' + ', '.join(('D ' if m['k'] == 1 else f"C{m.get('slot', 0)} ") + label(m) for m in tg))
    smp = [m for m in call.get('img', []) if m.get('k') == 2]
    if smp:
        parts = []
        for m in smp:
            flags = ('W' if m.get('rw') else '') + ('S' if m.get('uav') else '')
            parts.append(f"s{m.get('slot', 0)} {label(m)}" + (f" [{flags}]" if flags else ''))
        lines.append('  - imagens: ' + '; '.join(parts))
    if note['reads_from']:
        lines.append('  - lê saída do TAA/derivada: ' + ', '.join(note['reads_from']))
    return lines


def collapse(calls, notes):
    """Agrupa chamadas consecutivas iguais (mesmo shader, alvos, marcas) em uma só linha 'xN'."""
    groups = []
    for call, note in zip(calls, notes):
        key = (shader(call), tuple(label(m) for m in targets(call)), note['taa'], note['level'], note['ui'],
               tuple(label(m) for m in call.get('img', []) if m.get('k') == 2) if note['level'] or note['taa'] else ())
        if groups and groups[-1]['key'] == key:
            groups[-1]['calls'].append(call)
        else:
            groups.append({'key': key, 'calls': [call], 'note': note})
    return groups


def render_frame(name, calls, notes, complete, full=False):
    L = [f'## {name}\n']
    dispatches = sum(1 for c in calls if is_dispatch(c))
    taa = [c for c, n in zip(calls, notes) if n['taa']]
    L.append(f"- {len(calls)} chamadas ({len(calls) - dispatches} draws, {dispatches} dispatches), "
             f"{sum(c.get('us', 0) for c in calls) / 1000:.2f} ms de thread de render nas chamadas"
             + ('' if complete else ' — **frame incompleto (sem linha flip)**'))
    L.append(f"- TAA: {'#' + ', #'.join(str(c['i']) for c in taa) if taa else 'não encontrada neste quadro'}")
    tagged = [(c, n) for c, n in zip(calls, notes) if n['level']]
    L.append(f"- Passadas que leem a saída do TAA (ou derivada): {len(tagged)}")
    ui = [(c, n) for c, n in zip(calls, notes) if n['ui']]
    L.append(f"- Draws no alvo do tamanho de saída (UI): {len(ui)}\n")

    for c, n in zip(calls, notes):
        if n['taa']:
            L.append('### Dispatch do TAA\n')
            L.extend(call_lines(c, n))
            L.append('  - escreve: ' + (', '.join(label(m) for m in writes(c)) or '—'))
            L.append('')
    if tagged:
        L.append('### Depois do TAA: quem lê a saída (candidatas ao upscale)\n')
        for c, n in tagged:
            L.extend(call_lines(c, n))
            outputs = writes(c)
            if outputs:
                L.append('  - escreve: ' + ', '.join(label(m) for m in outputs))
        L.append('')
    if ui:
        L.append('### Draws no alvo de saída (UI)\n')
        for group in collapse([c for c, _ in ui], [n for _, n in ui]):
            first = group['calls'][0]
            count = len(group['calls'])
            lines = call_lines(first, group['note'])
            lines[0] += f" x{count}" if count > 1 else ''
            L.extend(lines)
        L.append('')
    L.append('### Todas as chamadas, em ordem (repetições consecutivas iguais agrupadas)\n')
    groups = [{'calls': [c], 'note': n} for c, n in zip(calls, notes)] if full else collapse(calls, notes)
    for group in groups:
        count = len(group['calls'])
        lines = call_lines(group['calls'][0], group['note'])
        if count > 1:
            lines[0] += f" x{count} (#{group['calls'][0]['i']}-#{group['calls'][-1]['i']})"
        L.extend(lines)
    L.append('')
    return L


def frame_files(directory):
    def number(path):
        match = re.search(r'frame-(\d+)\.jsonl$', path.name)
        return int(match.group(1)) if match else -1
    return sorted((p for p in Path(directory).glob('frame-*.jsonl') if number(p) >= 0), key=number)


def build_report(directory, taa_cs=TAA_CS, output_size=OUTPUT_SIZE, chain=DEFAULT_CHAIN, full=False):
    files = frame_files(directory)
    if not files:
        raise FileNotFoundError(f'nenhum frame-N.jsonl em {directory}')
    L = [f'# Captura de quadros: {Path(directory).name}\n',
         f"- Arquivos: {len(files)}; shader do TAA: `{taa_cs}`; tamanho de saída (UI): {output_size[0]}x{output_size[1]}; "
         f"cadeia depois do TAA: {chain} níveis\n"]
    summaries = []
    for path in files:
        calls, complete = load(path)
        notes = analyse(calls, taa_cs, output_size, chain)
        summaries.append((path.stem, calls, notes))
        L.extend(render_frame(path.stem, calls, notes, complete, full))
    # Resumo entre quadros: shaders que leem a saída do TAA.
    readers = defaultdict(int)
    for _, calls, notes in summaries:
        for c, n in zip(calls, notes):
            if n['level']:
                readers[(n['level'], shader(c))] += 1
    if readers:
        L.append('## Resumo: shaders depois do TAA (todos os quadros)\n')
        L.append('| Nível | Shader | Chamadas |')
        L.append('|---|---|---:|')
        for (level, name), count in sorted(readers.items()):
            L.append(f'| T+{level} | {name} | {count} |')
        L.append('')
    return '\n'.join(L) + '\n'


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)

    def option(name, default=None):
        if name in argv:
            at = argv.index(name)
            value = argv[at + 1]
            del argv[at:at + 2]
            return value
        return default

    out = option('--out')
    taa = option('--taa-cs', TAA_CS)
    size_text = option('--output-size', f'{OUTPUT_SIZE[0]}x{OUTPUT_SIZE[1]}')
    chain = int(option('--chain', DEFAULT_CHAIN))
    full = '--full' in argv
    argv = [a for a in argv if a != '--full']
    if len(argv) != 1:
        print(__doc__)
        return 2
    directory = Path(argv[0])
    width, height = (int(v) for v in size_text.lower().split('x'))
    text = build_report(directory, taa, (width, height), chain, full)
    target = Path(out) if out else directory / 'captures.md'
    target.write_text(text, encoding='utf-8')
    print(target)
    return 0


if __name__ == '__main__':
    sys.exit(main())
