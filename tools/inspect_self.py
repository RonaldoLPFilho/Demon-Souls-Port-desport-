#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Inventário estático do dump do Demon's Souls (PLAN.md §6 Fase 1, tarefa 1).

Lê eboot.bin e cada .prx/.sprx de sce_module/ (somente leitura), mais sce_sys/param.json, e
grava out/inventory.json. Não há código de descriptografia: um arquivo criptografado ou
comprimido para a ferramenta com erro (código de saída 3).

Uso:
    python tools/inspect_self.py                 # DES_GAME_DIR do desport.local.ini
    python tools/inspect_self.py D:/caminho/do/dump --out out/inventory.json
    python tools/inspect_self.py --file eboot.bin  # um arquivo só, saída no stdout

Estrutura de out/inventory.json (versão 1):
{
  "tool": "inspect_self", "format_version": 1,
  "game_dir": str,
  "param": {                      # de sce_sys/param.json; null se ausente
     "titleId", "contentId", "contentVersion", "masterVersion",
     "region": "US"|"EU"|"JP"|"ASIA"|null,   # pelo prefixo do contentId (UP/EP/JP/HP)
     "keys": [str]                # todas as chaves de primeiro nível
  },
  "files": [{
     "path": str (relativo ao dump), "size": int, "sha256": str,
     "container": "self"|"elf",
     "self": {"kind": "ps4"|"ps5", "magic", "file_size", "segments": [...]} | null,
     "abi_version": int, "is_shared": bool, "entry": int,
     "so_name": str|null, "needed": [str],
     "program_headers": [{"type": str, "flags", "offset", "vaddr", "filesz", "memsz", "align"}],
     "import_modules"/"export_modules": [{"id", "name", "version_major", "version_minor"}],
     "import_libs"/"export_libs": [{"id", "name", "version"}],
     "imports": [{"nid", "library", "library_id", "library_version", "module", "module_id",
                  "module_version", "symbol", "type", "bind",
                  "slots": [vaddr],           # alvos das relocações (GOT/PLT)
                  "reloc_kinds": {tipo: n},
                  "call_sites": [vaddr],      # varredura heurística (ps5elf.call_sites)
                  "call_site_count": int}],
     "exports": [{"nid", "library", "module", "symbol", "type", "bind", "value", "size"}],
     "relocation_counts": {tipo: n},
     "tls": {"vaddr", "filesz", "memsz", "align"} | null,
     "procparam": {"vaddr", "memsz", "first_bytes": hex} | null,
     "plt_stubs": int
  }],
  "summary": {"files": n, "imports": n, "unique_import_nids": n, "exports": n}
}
Endereços são números (JSON não tem hexadecimal); o relatório humano fica para o nid_db.py.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ps5elf  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
REGION_PREFIX = {'UP': 'US', 'EP': 'EU', 'JP': 'JP', 'HP': 'ASIA'}
CALL_SITE_LIST_LIMIT = 64


def read_local_ini():
    path = ROOT / 'desport.local.ini'
    values = {}
    if path.exists():
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            line = line.strip()
            if not line or line[0] in '#;' or '=' not in line:
                continue
            key, value = line.split('=', 1)
            values[key.strip()] = value.strip().strip('"')
    return values


def read_param(game):
    path = game / 'sce_sys' / 'param.json'
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    content_id = data.get('contentId')
    region = REGION_PREFIX.get(content_id[:2]) if isinstance(content_id, str) else None
    return dict(titleId=data.get('titleId'), contentId=content_id,
                contentVersion=data.get('contentVersion'), masterVersion=data.get('masterVersion'),
                region=region, keys=sorted(data.keys()))


def describe(data, rel_path, call_sites=True):
    exe = ps5elf.Executable(data, rel_path)
    imports = exe.imports()
    stubs = []
    if call_sites and imports:
        sites, stubs = exe.call_sites(imports)
        for i, imp in enumerate(imports):
            imp['call_site_count'] = len(sites[i])
            imp['call_sites'] = sites[i][:CALL_SITE_LIST_LIMIT]
    return dict(
        path=rel_path, size=len(data), sha256=hashlib.sha256(data).hexdigest(),
        container='self' if exe.self_info else 'elf', self=exe.self_info,
        abi_version=exe.abi_version, is_shared=exe.is_shared, entry=exe.entry,
        so_name=exe.so_name, needed=exe.needed,
        program_headers=[dict(type=ps5elf.PT_NAMES.get(p['type'], hex(p['type'])),
                              **{k: p[k] for k in ('flags', 'offset', 'vaddr', 'filesz', 'memsz', 'align')})
                         for p in exe.phdrs],
        import_modules=exe.import_modules, export_modules=exe.export_modules,
        import_libs=exe.import_libs, export_libs=exe.export_libs,
        imports=imports, exports=exe.exports(), relocation_counts=exe.reloc_counts(),
        tls=exe.tls(), procparam=exe.procparam(), plt_stubs=len(stubs))


def game_files(game):
    eboot = game / 'eboot.bin'
    if not eboot.is_file():
        raise ps5elf.FormatError(f'não há eboot.bin em {game}')
    files = [eboot]
    module_dir = game / 'sce_module'
    if module_dir.is_dir():
        files += sorted(p for p in module_dir.iterdir()
                        if p.is_file() and p.suffix.lower() in ('.prx', '.sprx'))
    return files


def inventory(game, call_sites=True, log=print):
    result = dict(tool='inspect_self', format_version=1, game_dir=str(game),
                  param=read_param(game), files=[])
    for path in game_files(game):
        rel = path.relative_to(game).as_posix()
        log(f'  {rel} ...')
        result['files'].append(describe(path.read_bytes(), rel, call_sites))
    nids = {i['nid'] for f in result['files'] for i in f['imports']}
    result['summary'] = dict(files=len(result['files']),
                             imports=sum(len(f['imports']) for f in result['files']),
                             unique_import_nids=len(nids),
                             exports=sum(len(f['exports']) for f in result['files']))
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('game', nargs='?', type=Path, help='pasta do dump (padrão: DES_GAME_DIR)')
    parser.add_argument('--out', type=Path, default=ROOT / 'out' / 'inventory.json')
    parser.add_argument('--file', type=Path, help='inspeciona um arquivo só e imprime o JSON')
    parser.add_argument('--no-call-sites', action='store_true', help='pula a varredura de chamadas')
    args = parser.parse_args(argv)
    try:
        if args.file:
            report = describe(args.file.read_bytes(), args.file.name, not args.no_call_sites)
            json.dump(report, sys.stdout, indent=1)
            print()
            return 0
        game = args.game or (Path(read_local_ini()['DES_GAME_DIR'])
                             if read_local_ini().get('DES_GAME_DIR') else None)
        if game is None:
            parser.error('informe a pasta do dump ou defina DES_GAME_DIR em desport.local.ini')
        if game.suffix.lower() in ('.pkg', '.zar') or not game.is_dir():
            parser.error(f'{game} não é uma pasta de dump extraído (eboot.bin, sce_sys/, sce_module/)')
        print(f'Lendo {game} (somente leitura)')
        report = inventory(game, not args.no_call_sites)
        out = args.out.resolve()
        if game.resolve() in out.parents:
            parser.error('a saída não pode ficar dentro da pasta do dump')
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=1) + '\n', encoding='utf-8')
        p = report['param'] or {}
        s = report['summary']
        print(f"{p.get('titleId')} {p.get('region')} v{p.get('contentVersion')} | "
              f"{s['files']} arquivos, {s['imports']} imports ({s['unique_import_nids']} NIDs únicos), "
              f"{s['exports']} exports")
        print(f'Saída: {out}')
        return 0
    except ps5elf.EncryptedError as error:
        print(f'PARADO: {error}', file=sys.stderr)
        print('Este projeto só aceita dumps já em texto claro, tirados do seu próprio console.',
              file=sys.stderr)
        return 3
    except (ps5elf.FormatError, OSError, json.JSONDecodeError, KeyError) as error:
        print(f'inspect_self: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
