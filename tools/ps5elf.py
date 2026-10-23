# SPDX-License-Identifier: GPL-2.0-only
"""Leitura de executáveis PS4/PS5 (SELF ou ELF) já em texto claro. Sem dependências externas.

O formato segue o loader do KytyPS5 (engine/src/loader/elf.h, elf.cpp, runtimeLinker.cpp);
nada aqui é inventado. O padrão de leitura com limites e a recusa de dados criptografados vêm
do scripts/prepare.py do bbport.

- Toda leitura de bytes passa por span(), que confere limites.
- Segmento SELF criptografado ou comprimido -> EncryptedError. Não há código de
  descriptografia nem de descompressão, e não haverá (PLAN.md §1.1.2).
- Nada é escrito em disco por este módulo.
"""
import base64
import hashlib
import struct

# --- referências: engine/src/loader/elf.h ----------------------------------------------------
PS4_SELF_MAGIC = b'\x4f\x15\x3d\x1d'
PS5_SELF_MAGIC = b'\x54\x14\xf5\xee'
# Bytes 4..11 do ident do SELF e o campo `unknown` aceitos pelo Elf64::IsSelf().
SELF_KINDS = {
    (b'\x00\x01\x01\x12\x01\x01\x00\x00', 0x22): 'ps4',
    (b'\x10\x01\x01\x12\x01\x01\x00\x10', 0x32): 'ps5',
}
SELF_HEADER = '<12sHHQHHI'      # SelfHeader (32 bytes)
SELF_SEGMENT = '<QQQQ'          # SelfSegment: type, offset, compressed_size, decompressed_size
# Bits do campo type do SelfSegment. 0x800: o segmento corresponde a um program header, cujo
# índice está em (type >> 20) & 0xfff (Elf64::LoadSegment). 0x2 criptografado e 0x8 comprimido:
# o mesmo critério do prepare.py do bbport (`flags & 10`).
SEG_HAS_PHDR = 0x800
SEG_ENCRYPTED = 0x2
SEG_COMPRESSED = 0x8

EHDR = '<16sHHIQQQIHHHHHH'      # Elf64_Ehdr (64 bytes)
PHDR = '<IIQQQQQQ'              # Elf64_Phdr (56 bytes)
DYN = '<qQ'                     # Elf64_Dyn (16 bytes)
SYM = '<IBBHQQ'                 # Elf64_Sym (24 bytes)
RELA = '<QQq'                   # Elf64_Rela (24 bytes)

ELFOSABI_FREEBSD = 9
EM_X86_64 = 62
ET_DYNEXEC = 0xfe10
ET_DYNAMIC = 0xfe18

PT_LOAD = 1
PT_DYNAMIC = 2
PT_TLS = 7
PT_GNU_EH_FRAME = 0x6474e550
PT_OS_DYNLIBDATA = 0x61000000
PT_OS_PROCPARAM = 0x61000001
PT_OS_RELRO = 0x61000010
PT_NAMES = {PT_LOAD: 'LOAD', PT_DYNAMIC: 'DYNAMIC', PT_TLS: 'TLS', PT_GNU_EH_FRAME: 'GNU_EH_FRAME',
            PT_OS_DYNLIBDATA: 'OS_DYNLIBDATA', PT_OS_PROCPARAM: 'OS_PROCPARAM',
            PT_OS_RELRO: 'OS_RELRO'}
PF_X, PF_W, PF_R = 1, 2, 4

DT_NULL = 0
DT_NEEDED = 1
DT_PLTRELSZ = 2
DT_STRTAB = 5
DT_SYMTAB = 6
DT_RELA = 7
DT_RELASZ = 8
DT_STRSZ = 10
DT_SYMENT = 11
DT_INIT = 12
DT_FINI = 13
DT_SONAME = 14
DT_PLTREL = 20
DT_JMPREL = 23
DT_INIT_ARRAY = 25
DT_FINI_ARRAY = 26
DT_INIT_ARRAYSZ = 27
DT_FINI_ARRAYSZ = 28
DT_OS_MODULE_INFO = 0x6100000d
DT_OS_NEEDED_MODULE = 0x6100000f
DT_OS_EXPORT_LIB = 0x61000013
DT_OS_IMPORT_LIB = 0x61000015
DT_OS_JMPREL = 0x61000029
DT_OS_PLTRELSZ = 0x6100002d
DT_OS_RELA = 0x6100002f
DT_OS_RELASZ = 0x61000031
DT_OS_STRTAB = 0x61000035
DT_OS_STRSZ = 0x61000037
DT_OS_SYMTAB = 0x61000039
DT_OS_SYMTABSZ = 0x6100003f
DT_OS_MODULE_INFO_1 = 0x61000043
DT_OS_NEEDED_MODULE_1 = 0x61000045
DT_OS_EXPORT_LIB_1 = 0x61000047
DT_OS_IMPORT_LIB_1 = 0x61000049

R_X86_64_64 = 1
R_X86_64_GLOB_DAT = 6
R_X86_64_JUMP_SLOT = 7
R_X86_64_RELATIVE = 8
R_X86_64_DTPMOD64 = 16
RELOC_NAMES = {R_X86_64_64: '64', R_X86_64_GLOB_DAT: 'GLOB_DAT', R_X86_64_JUMP_SLOT: 'JUMP_SLOT',
               R_X86_64_RELATIVE: 'RELATIVE', R_X86_64_DTPMOD64: 'DTPMOD64'}

STB_LOCAL, STB_GLOBAL, STB_WEAK = 0, 1, 2
STT_NOTYPE, STT_OBJECT, STT_FUNC = 0, 1, 2
SYM_TYPES = {STT_NOTYPE: 'notype', STT_OBJECT: 'object', STT_FUNC: 'func'}
SYM_BINDS = {STB_LOCAL: 'local', STB_GLOBAL: 'global', STB_WEAK: 'weak'}

# Limite de sanidade para não alocar memória absurda a partir de um cabeçalho corrompido.
MAX_TABLE = 512 * 1024 * 1024

NID_SALT = bytes.fromhex('518d64a635ded8c1e6b039b1c3e55230')


class FormatError(ValueError):
    """O arquivo não segue o formato esperado."""


class EncryptedError(FormatError):
    """O arquivo tem dados criptografados ou comprimidos. Este projeto não os aceita."""


def span(data, offset, size):
    if offset < 0 or size < 0 or offset + size > len(data):
        raise FormatError(f'fora dos limites: {offset:#x}+{size:#x} / {len(data):#x}')
    return data[offset:offset + size]


def unpack(fmt, data, offset):
    return struct.unpack(fmt, span(data, offset, struct.calcsize(fmt)))


def nid(name):
    """NID de um símbolo (mesmo algoritmo no PS4 e no PS5; conferido contra o KytyPS5)."""
    digest = hashlib.sha1(name.encode('ascii') + NID_SALT).digest()[:8][::-1]
    return base64.b64encode(digest).decode().rstrip('=').replace('/', '-')


def encode_id(value):
    """Codificação dos IDs de biblioteca/módulo nos nomes "nid#lib#mod" (EncodeId64)."""
    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-'
    value &= 0xffff
    if value < 0x40:
        return alphabet[value]
    if value < 0x1000:
        return alphabet[(value >> 6) & 0x3f] + alphabet[value & 0x3f]
    return alphabet[(value >> 12) & 0x3f] + alphabet[(value >> 6) & 0x3f] + alphabet[value & 0x3f]


def c_string(table, offset, what):
    if offset < 0 or offset >= len(table):
        raise FormatError(f'{what}: deslocamento de string fora da tabela ({offset:#x})')
    end = table.find(b'\0', offset)
    if end < 0:
        raise FormatError(f'{what}: string sem terminador em {offset:#x}')
    raw = table[offset:end]
    try:
        return raw.decode('ascii')
    except UnicodeDecodeError:
        raise EncryptedError(f'{what}: string ilegível em {offset:#x}; o arquivo parece criptografado')


class Executable:
    """Um eboot.bin ou .prx lido. Atributos públicos são dados simples (JSON-serializáveis)."""

    def __init__(self, data, name='<memória>'):
        self.data = data
        self.name = name
        self.self_info = None
        self._self_segments = []
        self._parse_headers()
        self._parse_dynamic()

    # --- SELF / ELF ---------------------------------------------------------------------------
    def _parse_headers(self):
        data = self.data
        ehdr_pos = 0
        magic = data[:4]
        if magic in (PS4_SELF_MAGIC, PS5_SELF_MAGIC):
            ident, size1, size2, file_size, count, unknown, _ = unpack(SELF_HEADER, data, 0)
            kind = SELF_KINDS.get((ident[4:12], unknown))
            if kind is None:
                raise FormatError(f'{self.name}: SELF desconhecido (ident {ident.hex()}, '
                                  f'unknown {unknown:#x}); o KytyPS5 também o recusaria')
            segments = []
            for i in range(count):
                stype, offset, csize, dsize = unpack(SELF_SEGMENT, data, 32 + i * 32)
                segments.append(dict(type=stype, offset=offset, compressed_size=csize,
                                     decompressed_size=dsize))
                if stype & SEG_HAS_PHDR and stype & (SEG_ENCRYPTED | SEG_COMPRESSED):
                    raise EncryptedError(
                        f'{self.name}: segmento SELF {i} criptografado/comprimido '
                        f'(type {stype:#x}). Só são aceitos dumps em texto claro.')
            self._self_segments = segments
            self.self_info = dict(kind=kind, magic=magic.hex(), file_size=file_size,
                                  segments=[{k: (hex(v) if k == 'type' else v) for k, v in s.items()}
                                            for s in segments])
            ehdr_pos = 32 + count * 32
        self._ehdr_pos = ehdr_pos

        (ident, e_type, machine, version, entry, phoff, shoff, flags, ehsize, phentsize, phnum,
         shentsize, shnum, shstrndx) = unpack(EHDR, data, ehdr_pos)
        problems = []
        if ident[:4] != b'\x7fELF':
            problems.append('magic ELF ausente')
        elif ident[4] != 2 or ident[5] != 1 or ident[6] != 1:
            problems.append('não é ELF64 little-endian versão 1')
        elif ident[7] != ELFOSABI_FREEBSD:
            problems.append(f'OSABI {ident[7]} (esperado {ELFOSABI_FREEBSD})')
        elif ident[8] not in (0, 2):
            problems.append(f'ABIVERSION {ident[8]} (esperado 0 ou 2)')
        elif e_type not in (ET_DYNEXEC, ET_DYNAMIC):
            problems.append(f'e_type {e_type:#x}')
        elif machine != EM_X86_64:
            problems.append(f'e_machine {machine}')
        elif phentsize != 56:
            problems.append(f'e_phentsize {phentsize}')
        if problems:
            if self.self_info:
                raise EncryptedError(f'{self.name}: cabeçalho ELF ilegível após o SELF '
                                     f'({problems[0]}); o arquivo parece criptografado')
            raise FormatError(f'{self.name}: não é um executável PS4/PS5 ({problems[0]})')

        self.abi_version = ident[8]
        self.is_shared = e_type == ET_DYNAMIC
        self.entry = entry
        self.phdrs = []
        for i in range(phnum):
            p = dict(zip(('type', 'flags', 'offset', 'vaddr', 'paddr', 'filesz', 'memsz', 'align'),
                         unpack(PHDR, data, ehdr_pos + phoff + i * 56)))
            if p['filesz'] > p['memsz'] and p['type'] in (PT_LOAD, PT_OS_RELRO):
                raise FormatError(f'{self.name}: program header {i} com filesz > memsz')
            self.phdrs.append(p)

    def read_file(self, offset, size):
        """Bytes do ELF no deslocamento `offset` (como Elf64::LoadSegment)."""
        if size == 0:
            return b''
        if self.self_info is None:
            return span(self.data, offset, size)
        for seg in self._self_segments:
            if not seg['type'] & SEG_HAS_PHDR:
                continue
            index = (seg['type'] >> 20) & 0xfff
            if index >= len(self.phdrs):
                raise FormatError(f'{self.name}: segmento SELF aponta para program header {index}')
            p = self.phdrs[index]
            if p['offset'] <= offset < p['offset'] + p['filesz']:
                if seg['compressed_size'] != seg['decompressed_size']:
                    raise EncryptedError(f'{self.name}: segmento SELF comprimido')
                if seg['decompressed_size'] != p['filesz']:
                    raise FormatError(f'{self.name}: segmento SELF com tamanho diferente do phdr')
                rel = offset - p['offset']
                if rel + size > seg['decompressed_size']:
                    raise FormatError(f'{self.name}: leitura além do segmento SELF')
                return span(self.data, seg['offset'] + rel, size)
        # Dados anexados após o SELF (mesmo fallback do Elf64::LoadSegment).
        if len(self.data) - self.self_info['file_size'] == size:
            return span(self.data, self.self_info['file_size'], size)
        raise FormatError(f'{self.name}: segmento SELF ausente para o deslocamento {offset:#x}')

    def mapped_segments(self):
        return [p for p in self.phdrs if p['type'] in (PT_LOAD, PT_OS_RELRO)]

    def read_vaddr(self, vaddr, size):
        """Bytes da imagem carregada no endereço virtual `vaddr` (zero além de filesz)."""
        for p in self.mapped_segments():
            if p['vaddr'] <= vaddr and vaddr + size <= p['vaddr'] + p['memsz']:
                rel = vaddr - p['vaddr']
                in_file = max(0, min(size, p['filesz'] - rel))
                return self.read_file(p['offset'] + rel, in_file) + bytes(size - in_file)
        raise FormatError(f'{self.name}: endereço {vaddr:#x}+{size:#x} fora dos segmentos')

    def is_mapped(self, vaddr, size=8):
        return any(p['vaddr'] <= vaddr and vaddr + size <= p['vaddr'] + p['memsz']
                   for p in self.mapped_segments())

    # --- segmento dinâmico ---------------------------------------------------------------------
    def _phdr(self, ptype):
        found = [p for p in self.phdrs if p['type'] == ptype]
        if len(found) > 1:
            raise FormatError(f'{self.name}: mais de um program header {PT_NAMES.get(ptype, ptype)}')
        return found[0] if found else None

    def _table(self, os_tag, tag, os_size_tag, size_tag, what):
        tags = self.dyn_tags
        if os_tag in tags and tag in tags:
            raise FormatError(f'{self.name}: {what} em DT_OS_* e DT_* ao mesmo tempo')
        size = tags.get(os_size_tag, tags.get(size_tag, 0)) if os_size_tag or size_tag else 0
        if size > MAX_TABLE:
            raise FormatError(f'{self.name}: {what} com tamanho absurdo ({size:#x})')
        if os_tag in tags:
            return span(self.dynlibdata, tags[os_tag], size)
        if tag in tags:
            return self.read_vaddr(tags[tag], size)
        return b''

    def _parse_dynamic(self):
        dp = self._phdr(PT_DYNAMIC)
        lp = self._phdr(PT_OS_DYNLIBDATA)
        dynamic = self.read_file(dp['offset'], dp['filesz']) if dp else b''
        self.dynlibdata = self.read_file(lp['offset'], lp['filesz']) if lp else b''
        self.dynamic = []
        for pos in range(0, len(dynamic) - len(dynamic) % 16, 16):
            tag, value = unpack(DYN, dynamic, pos)
            if tag == DT_NULL:
                break
            self.dynamic.append((tag, value))
        self.dyn_tags = {}
        for tag, value in self.dynamic:
            self.dyn_tags.setdefault(tag, value)

        self.strtab = self._table(DT_OS_STRTAB, DT_STRTAB, DT_OS_STRSZ, DT_STRSZ, 'tabela de strings')
        symtab = self._table(DT_OS_SYMTAB, DT_SYMTAB, DT_OS_SYMTABSZ, None, 'tabela de símbolos')
        if len(symtab) % 24:
            raise FormatError(f'{self.name}: tabela de símbolos com tamanho {len(symtab)} (não múltiplo de 24)')

        def string(off, what='string'):
            return c_string(self.strtab, off, what)

        self.so_name = string(self.dyn_tags[DT_SONAME], 'DT_SONAME') if DT_SONAME in self.dyn_tags else None
        self.needed = [string(v, 'DT_NEEDED') for t, v in self.dynamic if t == DT_NEEDED]

        def modules(tags):
            out = []
            for t, v in self.dynamic:
                if t in tags:
                    out.append(dict(id=encode_id(v >> 48), name=string(v & 0xffffffff, 'módulo'),
                                    version_major=(v >> 40) & 0xff, version_minor=(v >> 32) & 0xff))
            return out

        def libraries(tags):
            out = []
            for t, v in self.dynamic:
                if t in tags:
                    out.append(dict(id=encode_id(v >> 48), name=string(v & 0xffffffff, 'biblioteca'),
                                    version=(v >> 32) & 0xffff))
            return out

        self.import_modules = modules((DT_OS_NEEDED_MODULE, DT_OS_NEEDED_MODULE_1))
        self.export_modules = modules((DT_OS_MODULE_INFO, DT_OS_MODULE_INFO_1))
        self.import_libs = libraries((DT_OS_IMPORT_LIB, DT_OS_IMPORT_LIB_1))
        self.export_libs = libraries((DT_OS_EXPORT_LIB, DT_OS_EXPORT_LIB_1))

        self.symbols = []
        for pos in range(0, len(symtab), 24):
            name, info, other, shndx, value, size = unpack(SYM, symtab, pos)
            self.symbols.append(dict(name=string(name, 'símbolo') if name else '', bind=info >> 4,
                                     type=info & 0xf, section=shndx, value=value, size=size))

        self.relocations = []
        for os_tag, tag, os_size, size_tag, plt in ((DT_OS_RELA, DT_RELA, DT_OS_RELASZ, DT_RELASZ, False),
                                                    (DT_OS_JMPREL, DT_JMPREL, DT_OS_PLTRELSZ, DT_PLTRELSZ, True)):
            table = self._table(os_tag, tag, os_size, size_tag, 'tabela de relocações')
            if len(table) % 24:
                raise FormatError(f'{self.name}: tabela de relocações com tamanho {len(table)}')
            for pos in range(0, len(table), 24):
                offset, info, addend = unpack(RELA, table, pos)
                sym = info >> 32
                kind = info & 0xffffffff
                if kind in (R_X86_64_64, R_X86_64_GLOB_DAT, R_X86_64_JUMP_SLOT, R_X86_64_DTPMOD64) \
                        and sym >= len(self.symbols):
                    raise FormatError(f'{self.name}: relocação aponta para símbolo {sym} inexistente')
                self.relocations.append(dict(offset=offset, type=kind, symbol=sym, addend=addend, plt=plt))

    # --- visões de alto nível ------------------------------------------------------------------
    def split_name(self, name):
        """"nid#L#M" -> (nid, biblioteca, módulo) com os nomes reais; None para nomes simples."""
        parts = name.split('#')
        if len(parts) != 3:
            return None
        libs = {l['id']: l for l in self.import_libs + self.export_libs}
        mods = {m['id']: m for m in self.import_modules + self.export_modules}
        lib, mod = libs.get(parts[1]), mods.get(parts[2])
        return dict(nid=parts[0], library_id=parts[1], module_id=parts[2],
                    library=lib['name'] if lib else None,
                    library_version=lib['version'] if lib else None,
                    module=mod['name'] if mod else None,
                    module_version=[mod['version_major'], mod['version_minor']] if mod else None)

    def imports(self):
        """Símbolos indefinidos com nome "nid#L#M", com as relocações que os usam."""
        by_symbol = {}
        for r in self.relocations:
            if r['type'] in (R_X86_64_64, R_X86_64_GLOB_DAT, R_X86_64_JUMP_SLOT):
                by_symbol.setdefault(r['symbol'], []).append(r)
        out = []
        for index, s in enumerate(self.symbols):
            if s['section'] != 0 or s['bind'] not in (STB_GLOBAL, STB_WEAK):
                continue
            ident = self.split_name(s['name'])
            if ident is None:
                continue
            relocs = by_symbol.get(index, [])
            kinds = {}
            for r in relocs:
                kinds[RELOC_NAMES[r['type']]] = kinds.get(RELOC_NAMES[r['type']], 0) + 1
            out.append(dict(ident, symbol=s['name'], symbol_index=index,
                            type=SYM_TYPES.get(s['type'], s['type']),
                            bind=SYM_BINDS.get(s['bind'], s['bind']),
                            slots=sorted(r['offset'] for r in relocs), reloc_kinds=kinds))
        return out

    def exports(self):
        out = []
        for s in self.symbols:
            if s['section'] == 0 or s['bind'] not in (STB_GLOBAL, STB_WEAK) \
                    or s['type'] not in (STT_OBJECT, STT_FUNC):
                continue
            ident = self.split_name(s['name'])
            if ident is None:
                continue
            out.append(dict(ident, symbol=s['name'], type=SYM_TYPES[s['type']],
                            bind=SYM_BINDS[s['bind']], value=s['value'], size=s['size']))
        return out

    def reloc_counts(self):
        counts = {}
        for r in self.relocations:
            key = RELOC_NAMES.get(r['type'], str(r['type']))
            counts[key] = counts.get(key, 0) + 1
        return counts

    def tls(self):
        p = self._phdr(PT_TLS)
        return None if p is None else dict(vaddr=p['vaddr'], filesz=p['filesz'], memsz=p['memsz'],
                                           align=p['align'])

    def procparam(self):
        p = self._phdr(PT_OS_PROCPARAM)
        if p is None:
            return None
        head = min(p['memsz'], 64)
        raw = self.read_vaddr(p['vaddr'], head) if self.is_mapped(p['vaddr'], head) else b''
        return dict(vaddr=p['vaddr'], memsz=p['memsz'], first_bytes=raw.hex())

    def executable_segments(self):
        return [p for p in self.phdrs if p['type'] == PT_LOAD and p['flags'] & PF_X]

    def call_sites(self, imports):
        """Varredura de bytes: chamadas a imports via PLT (call/jmp rel32 para um stub
        `jmp [rip+GOT]`) e via `call [rip+GOT]`. Heurística: pode haver falsos positivos em
        bytes que não são instruções; serve para ordenar por uso, não como prova."""
        slot_to_import = {}
        for i, imp in enumerate(imports):
            for slot in imp['slots']:
                slot_to_import[slot] = i
        sites = {i: [] for i in range(len(imports))}
        stubs = {}
        segments = [(p['vaddr'], self.read_file(p['offset'], p['filesz']))
                    for p in self.executable_segments()]
        for base, code in segments:
            pos = code.find(b'\xff', 0)
            while 0 <= pos <= len(code) - 6:
                op = code[pos + 1]
                if op in (0x25, 0x15):
                    disp, = struct.unpack_from('<i', code, pos + 2)
                    target = base + pos + 6 + disp
                    imp = slot_to_import.get(target)
                    if imp is not None:
                        if op == 0x25:
                            stubs[base + pos] = imp
                        else:
                            sites[imp].append(base + pos)
                pos = code.find(b'\xff', pos + 1)
        if stubs:
            for base, code in segments:
                limit = len(code) - 5
                for opcode in (b'\xe8', b'\xe9'):
                    pos = code.find(opcode, 0)
                    while 0 <= pos <= limit:
                        rel, = struct.unpack_from('<i', code, pos + 1)
                        imp = stubs.get(base + pos + 5 + rel)
                        if imp is not None:
                            sites[imp].append(base + pos)
                        pos = code.find(opcode, pos + 1)
        return {i: sorted(v) for i, v in sites.items()}, sorted(stubs)
