#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Corpus local de compute shaders do jogo, tirado do arquivo de entradas do compilador do engine.

O precompile estático (e o KYTY_SHADER_WARMUP) guarda as entradas do recompilador num arquivo
`_PipelineCache/<...>/PPSA01341_01.007.000.shaders` (src/local/shader-warmup-cache.h, assinatura
"KytyShaderWarmup3:..."): o código RDNA2 de cada shader e a forma do grupo. Este script lê esse arquivo
(só leitura) e:
  - extrai os compute shaders pedidos para `out/shaders/g<threads>/CS_<hash>.bin`, no formato que o
    `lane_local_tests` do engine lê (`lane_local_tests -m 1 -g 64 out/shaders/g64/CS_*.bin`: veredito da
    prova de wave64 lane-local e do modo KYTY_WAVE64_MODE para cada um, sem rodar o jogo);
  - imprime, por shader, a forma do grupo, o tamanho da LDS e as instruções entre lanes que contam para a
    prova (V_READLANE/WRITELANE/READFIRSTLANE, MBCNT, PERMLANE, DPP por controle, DS por opcode, S_BARRIER,
    desvios em EXEC/VCC). É uma varredura estática aproximada (só decodifica tamanhos); o motivo exato vem do
    engine (KYTY_WAVE64_REPORT=1 ou lane_local_tests).

Tudo o que sai é derivado do jogo: fica em out/ (fora do git).

Uso:
    python -I tools/shader_corpus.py --hash 7e676bf37482d768 a44e580f4f0cfb2b [--out out/shaders]
    python -I tools/shader_corpus.py --all --scan-only
"""
import argparse
from collections import Counter
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SHADERS = ROOT / 'user' / 'kyty-fg' / '_PipelineCache' / 'static' / 'PPSA01341_01.007.000.shaders'
SIGNATURE = b'KytyShaderWarmup3:'
COMPUTE = 4  # ShaderType::Compute (src/graphics/shader/shader.h)

DS_NAMES = {
    0x0d: 'ds_write_b32', 0x0e: 'ds_write2_b32', 0x0f: 'ds_write2st64_b32', 0x36: 'ds_read_b32',
    0x37: 'ds_read2_b32', 0x38: 'ds_read2st64_b32', 0x35: 'ds_swizzle', 0x3d: 'ds_consume', 0x3e: 'ds_append',
    0x4d: 'ds_write_b64', 0x4e: 'ds_write2_b64', 0x4f: 'ds_write2st64_b64', 0x76: 'ds_read_b64',
    0x77: 'ds_read2_b64', 0x78: 'ds_read2st64_b64', 0xb0: 'ds_write_addtid', 0xb1: 'ds_read_addtid',
    0xb3: 'ds_bpermute', 0xde: 'ds_write_b96', 0xdf: 'ds_write_b128', 0xfe: 'ds_read_b96', 0xff: 'ds_read_b128',
}
VOP3_NAMES = {0x360: 'v_readlane', 0x361: 'v_writelane', 0x365: 'v_mbcnt_lo', 0x366: 'v_mbcnt_hi',
              0x377: 'v_permlane16', 0x378: 'v_permlanex16'}
SOPP_BRANCH = {6: 's_cbranch_vccz', 7: 's_cbranch_vccnz', 8: 's_cbranch_execz', 9: 's_cbranch_execnz'}


def read_words(path):
    """As palavras do conteúdo (depois da assinatura e do XXH3 de 8 bytes)."""
    data = Path(path).read_bytes()
    if not data.startswith(SIGNATURE):
        raise ValueError(f'{path}: não é um arquivo de entradas do recompilador (assinatura)')
    newline = data.index(b'\n')
    body = data[newline + 1 + 8:]
    if len(body) % 4:
        raise ValueError(f'{path}: tamanho não é múltiplo de 4')
    return struct.unpack(f'<{len(body) // 4}I', body)


def records(words):
    """Os registros de shader (vetores de palavras), na ordem do arquivo."""
    cursor = 0
    count = words[cursor]
    cursor += 1
    for _ in range(count):
        size = words[cursor]
        cursor += 1
        yield words[cursor:cursor + size]
        cursor += size


def parse_record(record):
    """(stage, hash, code, compute) de um registro; compute: dict com threads, lds_dwords, wave."""
    c = 0
    stage = record[c]
    shader_hash = record[c + 1] | (record[c + 2] << 32)
    c += 5  # stage, hash (2), user_data_count, push_cursor
    size = record[c]
    code = record[c + 1:c + 1 + size]
    c += 1 + size
    for _ in range(2):  # back_code, static_key
        c += 1 + record[c]
    compute = None
    if stage == COMPUTE:
        threads = tuple(record[c:c + 3])
        lds, _scratch, host_subgroup, wave = record[c + 3:c + 7]
        compute = {'threads': threads, 'lds_dwords': lds, 'host_subgroup': host_subgroup, 'wave': wave}
    return stage, shader_hash, code, compute


def decode(code):
    """(pc, família, opcode, palavras) de cada instrução RDNA2: só o que dá o tamanho e o opcode."""
    out = []
    i = 0
    while i < len(code):
        w = code[i]
        length, literal, extra = 1, False, None
        if w & 0x80000000 == 0:
            bits = (w >> 25) & 0x3f
            if bits == 0x3e:
                family, op = 'VOPC', (w >> 17) & 0xff
            elif bits == 0x3f:
                family, op = 'VOP1', (w >> 9) & 0xff
            else:
                family, op = 'VOP2', bits
            src0 = w & 0x1ff
            literal = src0 == 255 or (family == 'VOP2' and op in (0x2c, 0x2d, 0x37, 0x38))
            if src0 in (0xe9, 0xea, 0xf9, 0xfa):
                length += 1
                extra = (src0, code[i + 1] if i + 1 < len(code) else 0)
        elif w & 0xc0000000 == 0x80000000:
            op7 = (w >> 23) & 0x7f
            if op7 == 0x7d:
                family, op = 'SOP1', (w >> 8) & 0xff
                literal = (w & 0xff) == 255
            elif op7 == 0x7e:
                family, op = 'SOPC', (w >> 16) & 0x7f
                literal = (w & 0xff) == 255 or ((w >> 8) & 0xff) == 255
            elif op7 == 0x7f:
                family, op = 'SOPP', (w >> 16) & 0x7f
            elif op7 >= 0x60:
                family, op = 'SOPK', (w >> 23) & 0x1f
                literal = op == 0x15  # s_setreg_imm32_b32
            else:
                family, op = 'SOP2', op7
                literal = (w & 0xff) == 255 or ((w >> 8) & 0xff) == 255
        else:
            top = w >> 26
            family = {0x32: 'VINTRP', 0x33: 'VOP3P', 0x35: 'VOP3', 0x36: 'DS', 0x37: 'FLAT', 0x38: 'MUBUF',
                      0x3a: 'MTBUF', 0x3c: 'MIMG', 0x3d: 'SMEM', 0x3e: 'EXP'}.get(top, 'UNKNOWN')
            if family == 'UNKNOWN':
                out.append((i * 4, family, 0, None))
                break
            if family == 'VINTRP':
                op = (w >> 16) & 3
            elif family in ('VOP3', 'VOP3P'):
                length = 2
                op = (w >> 16) & (0x3ff if family == 'VOP3' else 0x7f)
                w1 = code[i + 1] if i + 1 < len(code) else 0
                literal = 255 in (w1 & 0x1ff, (w1 >> 9) & 0x1ff, (w1 >> 18) & 0x1ff)
            elif family == 'MIMG':
                length = 2 + ((w >> 1) & 3)  # NSA: dwords de endereço a mais
                op = (w >> 18) & 0x7f
            else:
                length = 2
                op = (w >> 18) & (0xff if family in ('DS', 'SMEM', 'EXP') else 0x7f)
        if literal:
            length += 1
        out.append((i * 4, family, op, extra))
        i += length
        if family == 'SOPP' and op == 1:  # s_endpgm
            break
    return out


def scan(code):
    """Contagem das instruções entre lanes (e afins) do shader."""
    counts = Counter()
    for _pc, family, op, extra in decode(code):
        if family == 'DS':
            counts[DS_NAMES.get(op, f'ds_0x{op:02x}')] += 1
        elif family == 'VOP3' and op in VOP3_NAMES:
            counts[VOP3_NAMES[op]] += 1
        elif family == 'VOP1' and op == 0x02:
            counts['v_readfirstlane'] += 1
        elif family == 'SOPP' and op == 0x0a:
            counts['s_barrier'] += 1
        elif family == 'SOPP' and op in SOPP_BRANCH:
            counts[SOPP_BRANCH[op]] += 1
        elif family == 'UNKNOWN':
            counts['?decode'] += 1
        if extra is not None:
            src0, word = extra
            if src0 == 0xfa:
                counts[f'dpp:0x{(word >> 8) & 0x1ff:03x}'] += 1
            elif src0 in (0xe9, 0xea):
                counts['dpp8'] += 1
    return counts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--shaders', default=str(DEFAULT_SHADERS), help='arquivo .shaders (só leitura)')
    parser.add_argument('--out', default=str(ROOT / 'out' / 'shaders'), help='pasta de saída (fora do git)')
    parser.add_argument('--hash', nargs='*', default=[], help='hashes de compute shader (hex)')
    parser.add_argument('--all', action='store_true', help='todos os compute shaders')
    parser.add_argument('--scan-only', action='store_true', help='só imprime a varredura, não extrai')
    args = parser.parse_args(argv)
    if not args.all and not args.hash:
        parser.error('dê --hash ou --all')
    wanted = {int(h, 16) for h in args.hash}
    seen = set()
    out = Path(args.out)
    for record in records(read_words(args.shaders)):
        stage, shader_hash, code, compute = parse_record(record)
        if stage != COMPUTE or shader_hash in seen or (not args.all and shader_hash not in wanted):
            continue
        seen.add(shader_hash)
        threads = compute['threads'][0] * max(compute['threads'][1], 1) * max(compute['threads'][2], 1)
        counts = scan(code)
        summary = ' '.join(f'{k}={v}' for k, v in sorted(counts.items())) or '-'
        print(f'{shader_hash:016x} group={"x".join(map(str, compute["threads"]))} ({threads}) '
              f'lds_dwords={compute["lds_dwords"]} wave={compute["wave"]} words={len(code)} {summary}')
        if not args.scan_only:
            target = out / f'g{threads}'
            target.mkdir(parents=True, exist_ok=True)
            (target / f'CS_{shader_hash:016x}.bin').write_bytes(struct.pack(f'<{len(code)}I', *code))
    missing = wanted - seen
    for shader_hash in sorted(missing):
        print(f'{shader_hash:016x}: não encontrado', file=sys.stderr)
    return 1 if missing else 0


if __name__ == '__main__':
    sys.exit(main())
