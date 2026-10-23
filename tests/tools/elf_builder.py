# SPDX-License-Identifier: GPL-2.0-only
"""Monta executáveis PS5 sintéticos (ELF ou SELF) para os testes das ferramentas.

Nada aqui vem de arquivos do jogo: tudo é gerado pelo próprio teste (PLAN.md §6 Fase 1,
tarefa 6). O layout segue as estruturas de engine/src/loader/elf.h.

Conteúdo do executável gerado (endereços virtuais = deslocamentos no ELF):
  0x1000  código (LOAD r-x): stub PLT `jmp [rip->0x2000]`, `call stub`, `jmp stub`,
          `call [rip->0x2008]`
  0x2000  dados (LOAD rw-): slot GOT de A (0x2000), slot de B (0x2008), TLS (0x2040),
          procparam (0x2080) e, na variante tables='vaddr', as tabelas dinâmicas (0x2400)
  0x3000  PT_DYNAMIC
  0x3400  PT_OS_DYNLIBDATA (tabelas, na variante tables='dynlib')
Símbolos: import A (func, JUMP_SLOT), import B (object, GLOB_DAT), export C (func em 0x1040).
"""
import struct

NID_A = 'AAAAAAAAAAA'
NID_B = 'BBBBBBBBBBB'
NID_C = 'CCCCCCCCCCC'
CODE, DATA, DYNAMIC, DYNLIB = 0x1000, 0x2000, 0x3000, 0x3400
SLOT_A, SLOT_B = 0x2000, 0x2008
TABLES_VADDR = 0x2400
PROCPARAM_BYTES = b'PPRM' + bytes(range(1, 29))


def _strtab():
    names = ['', f'{NID_A}#A#B', f'{NID_B}#A#B', f'{NID_C}#C#D', 'libSceTest', 'libSceTestMod',
             'libSceGame', 'libSceGameMod', 'eboot.prx', 'libSceTest.sprx']
    blob, offsets = b'', {}
    for n in names:
        offsets[n] = len(blob)
        blob += n.encode() + b'\0'
    return blob, offsets


def build_tables(strtab_bad=False):
    strtab, off = _strtab()
    if strtab_bad:
        strtab = strtab.replace(b'libSceTest\0', b'libSce\xff\xfet\0', 1)
    sym = struct.Struct('<IBBHQQ')
    symtab = (sym.pack(0, 0, 0, 0, 0, 0)
              + sym.pack(off[f'{NID_A}#A#B'], (1 << 4) | 2, 0, 0, 0, 0)
              + sym.pack(off[f'{NID_B}#A#B'], (1 << 4) | 1, 0, 0, 0, 0)
              + sym.pack(off[f'{NID_C}#C#D'], (1 << 4) | 2, 0, 1, CODE + 0x40, 4))
    rela = struct.Struct('<QQq')
    relatab = rela.pack(SLOT_B, (2 << 32) | 6, 0) + rela.pack(DATA + 0x10, 8, CODE + 0x40)
    jmprel = rela.pack(SLOT_A, (1 << 32) | 7, 0)
    return strtab, off, symtab, relatab, jmprel


def build_elf(tables='dynlib', strtab_bad=False):
    strtab, off, symtab, relatab, jmprel = build_tables(strtab_bad)
    # Tabelas concatenadas: strtab | symtab | rela | jmprel
    t_str = 0
    t_sym = t_str + len(strtab)
    t_rela = t_sym + len(symtab)
    t_jmp = t_rela + len(relatab)
    blob = strtab + symtab + relatab + jmprel

    code = bytearray(0x100)
    code[0:6] = b'\xff\x25' + struct.pack('<i', SLOT_A - (CODE + 6))           # stub PLT de A
    code[0x10:0x15] = b'\xe8' + struct.pack('<i', CODE - (CODE + 0x10 + 5))   # call stub
    code[0x20:0x25] = b'\xe9' + struct.pack('<i', CODE - (CODE + 0x20 + 5))   # jmp stub
    code[0x30:0x36] = b'\xff\x15' + struct.pack('<i', SLOT_B - (CODE + 0x30 + 6))  # call [B]
    code[0x40:0x41] = b'\xc3'

    data = bytearray(0x800)
    data[0x80:0x80 + len(PROCPARAM_BYTES)] = PROCPARAM_BYTES
    data[0x40:0x50] = b'T' * 16
    if tables == 'vaddr':
        data[TABLES_VADDR - DATA:TABLES_VADDR - DATA + len(blob)] = blob
        dynlib = b''
    else:
        dynlib = blob

    lib = lambda ident, ver, name: (ident << 48) | (ver << 32) | off[name]        # noqa: E731
    mod = lambda ident, ma, mi, name: (ident << 48) | (ma << 40) | (mi << 32) | off[name]  # noqa: E731
    if tables == 'vaddr':
        base = TABLES_VADDR
        table_tags = [(5, base + t_str), (10, len(strtab)), (6, base + t_sym),
                      (0x6100003f, len(symtab)), (7, base + t_rela), (8, len(relatab)),
                      (23, base + t_jmp), (2, len(jmprel))]
    else:
        table_tags = [(0x61000035, t_str), (0x61000037, len(strtab)), (0x61000039, t_sym),
                      (0x6100003f, len(symtab)), (0x6100002f, t_rela), (0x61000031, len(relatab)),
                      (0x61000029, t_jmp), (0x6100002d, len(jmprel))]
    tags = table_tags + [
        (14, off['eboot.prx']), (1, off['libSceTest.sprx']),
        (0x61000015, lib(0, 1, 'libSceTest')), (0x6100000f, mod(1, 1, 2, 'libSceTestMod')),
        (0x61000013, lib(2, 1, 'libSceGame')), (0x6100000d, mod(3, 1, 0, 'libSceGameMod')),
        (0, 0)]
    dynamic = b''.join(struct.pack('<qQ', t, v) for t, v in tags)

    phdrs = [  # type, flags, offset, vaddr, filesz, memsz, align
        (1, 5, CODE, CODE, len(code), len(code), 0x1000),
        (1, 6, DATA, DATA, len(data), 0x1000, 0x1000),
        (2, 4, DYNAMIC, 0, len(dynamic), len(dynamic), 8),
        (7, 4, DATA + 0x40, DATA + 0x40, 0x10, 0x20, 16),
        (0x61000001, 4, DATA + 0x80, DATA + 0x80, 0x40, 0x40, 8),
    ]
    if dynlib:
        phdrs.append((0x61000000, 4, DYNLIB, 0, len(dynlib), len(dynlib), 16))
    ehdr = struct.pack('<16sHHIQQQIHHHHHH', b'\x7fELF\x02\x01\x01\x09\x02' + bytes(7),
                       0xfe10, 62, 1, CODE, 64, 0, 0, 64, 56, len(phdrs), 64, 0, 0)
    elf = bytearray(DYNLIB + len(dynlib) + 0x10)
    elf[0:64] = ehdr
    for i, (pt, fl, of, va, fs, ms, al) in enumerate(phdrs):
        struct.pack_into('<IIQQQQQQ', elf, 64 + i * 56, pt, fl, of, va, va, fs, ms, al)
    elf[CODE:CODE + len(code)] = code
    elf[DATA:DATA + len(data)] = data
    elf[DYNAMIC:DYNAMIC + len(dynamic)] = dynamic
    elf[DYNLIB:DYNLIB + len(dynlib)] = dynlib
    return bytes(elf), phdrs


def build_self(tables='dynlib', encrypted=False, compressed_mismatch=False, bad_elf=False):
    """Envolve o ELF num SELF do PS5 (ident e `unknown` aceitos pelo Elf64::IsSelf())."""
    elf, phdrs = build_elf(tables)
    header_end = 64 + len(phdrs) * 56
    with_data = [i for i, p in enumerate(phdrs) if p[4] and p[0] in (1, 2, 0x61000000)]
    count = len(with_data)
    ehdr_pos = 32 + count * 32
    body = bytearray(elf[:header_end])
    if bad_elf:
        body[0:4] = b'\x13\x37\xbe\xef'
    segments, payload = [], b''
    data_start = ehdr_pos + len(body)
    for i in with_data:
        pt, fl, of, va, fs, ms, al = phdrs[i]
        stype = 0x800 | (i << 20) | (0x2 if encrypted else 0)
        csize = fs + 16 if compressed_mismatch else fs
        segments.append(struct.pack('<QQQQ', stype, data_start + len(payload), csize, fs))
        payload += elf[of:of + fs]
    total = ehdr_pos + len(body) + len(payload)
    ident = b'\x54\x14\xf5\xee' + b'\x10\x01\x01\x12\x01\x01\x00\x10'
    head = struct.pack('<12sHHQHHI', ident, 0, 0, total, count, 0x32, 0)
    return head + b''.join(segments) + bytes(body) + payload
