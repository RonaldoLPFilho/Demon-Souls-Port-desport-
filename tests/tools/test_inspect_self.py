# SPDX-License-Identifier: GPL-2.0-only
"""Testes do tools/ps5elf.py e tools/inspect_self.py com executáveis sintéticos.

Rodar: python -m unittest discover -s tests/tools -v
"""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent.parent / 'tools'))

import elf_builder as eb  # noqa: E402
import inspect_self  # noqa: E402
import ps5elf  # noqa: E402


class NidTests(unittest.TestCase):
    def test_nid_matches_engine_registrations(self):
        # Pares conferidos em engine/src/libs/libPad.cpp.
        self.assertEqual(ps5elf.nid('scePadInit'), 'hv1luiJrqQM')
        self.assertEqual(ps5elf.nid('scePadClose'), '6ncge5+l5Qs')

    def test_encode_id(self):
        self.assertEqual(ps5elf.encode_id(0), 'A')
        self.assertEqual(ps5elf.encode_id(63), '-')
        self.assertEqual(ps5elf.encode_id(64), 'BA')
        self.assertEqual(ps5elf.encode_id(0x1000), 'BAA')


class ExecutableTests(unittest.TestCase):
    def check_common(self, exe):
        imports = {i['nid']: i for i in exe.imports()}
        self.assertEqual(set(imports), {eb.NID_A, eb.NID_B})
        a, b = imports[eb.NID_A], imports[eb.NID_B]
        self.assertEqual((a['library'], a['module'], a['type']), ('libSceTest', 'libSceTestMod', 'func'))
        self.assertEqual(a['library_version'], 1)
        self.assertEqual(a['module_version'], [1, 2])
        self.assertEqual(a['slots'], [eb.SLOT_A])
        self.assertEqual(a['reloc_kinds'], {'JUMP_SLOT': 1})
        self.assertEqual((b['type'], b['slots'], b['reloc_kinds']), ('object', [eb.SLOT_B], {'GLOB_DAT': 1}))
        exports = exe.exports()
        self.assertEqual(len(exports), 1)
        self.assertEqual((exports[0]['nid'], exports[0]['library'], exports[0]['value']),
                         (eb.NID_C, 'libSceGame', eb.CODE + 0x40))
        self.assertEqual(exe.so_name, 'eboot.prx')
        self.assertEqual(exe.needed, ['libSceTest.sprx'])
        self.assertEqual(exe.reloc_counts(), {'GLOB_DAT': 1, 'RELATIVE': 1, 'JUMP_SLOT': 1})
        self.assertEqual(exe.tls(), dict(vaddr=eb.DATA + 0x40, filesz=0x10, memsz=0x20, align=16))
        self.assertTrue(exe.procparam()['first_bytes'].startswith(eb.PROCPARAM_BYTES.hex()))
        self.assertEqual(exe.entry, eb.CODE)
        self.assertEqual(exe.abi_version, 2)
        sites, stubs = exe.call_sites(exe.imports())
        by_nid = {imp['nid']: sites[i] for i, imp in enumerate(exe.imports())}
        self.assertEqual(stubs, [eb.CODE])
        self.assertEqual(by_nid[eb.NID_A], [eb.CODE + 0x10, eb.CODE + 0x20])
        self.assertEqual(by_nid[eb.NID_B], [eb.CODE + 0x30])

    def test_plain_elf_with_dynlibdata_tables(self):
        elf, _ = eb.build_elf('dynlib')
        exe = ps5elf.Executable(elf, 'eboot.bin')
        self.assertIsNone(exe.self_info)
        self.check_common(exe)

    def test_plain_elf_with_vaddr_tables(self):
        elf, _ = eb.build_elf('vaddr')
        self.check_common(ps5elf.Executable(elf, 'eboot.bin'))

    def test_ps5_self_container(self):
        exe = ps5elf.Executable(eb.build_self(), 'eboot.bin')
        self.assertEqual(exe.self_info['kind'], 'ps5')
        self.check_common(exe)

    def test_encrypted_self_segment_is_refused(self):
        with self.assertRaises(ps5elf.EncryptedError) as ctx:
            ps5elf.Executable(eb.build_self(encrypted=True), 'eboot.bin')
        self.assertIn('criptografado', str(ctx.exception))

    def test_compressed_self_segment_is_refused(self):
        with self.assertRaises(ps5elf.EncryptedError):
            ps5elf.Executable(eb.build_self(compressed_mismatch=True), 'eboot.bin')

    def test_unreadable_elf_inside_self_is_reported_as_encrypted(self):
        with self.assertRaises(ps5elf.EncryptedError):
            ps5elf.Executable(eb.build_self(bad_elf=True), 'eboot.bin')

    def test_unreadable_strings_are_reported_as_encrypted(self):
        elf, _ = eb.build_elf(strtab_bad=True)
        with self.assertRaises(ps5elf.EncryptedError):
            ps5elf.Executable(elf, 'eboot.bin')

    def test_random_bytes_are_a_format_error(self):
        with self.assertRaises(ps5elf.FormatError) as ctx:
            ps5elf.Executable(bytes(range(256)) * 4, 'x.bin')
        self.assertNotIsInstance(ctx.exception, ps5elf.EncryptedError)

    def test_truncated_file_is_bounds_checked(self):
        elf, _ = eb.build_elf()
        with self.assertRaises(ps5elf.FormatError):
            ps5elf.Executable(elf[:0x3010], 'eboot.bin')

    def test_unknown_self_variant_is_refused(self):
        data = bytearray(eb.build_self())
        data[6] = 0x77  # ident[6]: fora das duas variantes aceitas pelo Elf64::IsSelf()
        with self.assertRaises(ps5elf.FormatError):
            ps5elf.Executable(bytes(data), 'eboot.bin')

    def test_span(self):
        self.assertEqual(ps5elf.span(b'abcdef', 2, 3), b'cde')
        for args in ((-1, 1), (0, -1), (4, 3)):
            with self.assertRaises(ps5elf.FormatError):
                ps5elf.span(b'abcdef', *args)


class InventoryTests(unittest.TestCase):
    def make_game(self, root, eboot=None):
        game = Path(root) / 'PPSA00000-app'
        (game / 'sce_sys').mkdir(parents=True)
        (game / 'sce_module').mkdir()
        (game / 'eboot.bin').write_bytes(eboot if eboot is not None else eb.build_self())
        (game / 'sce_module' / 'libc.prx').write_bytes(eb.build_elf()[0])
        (game / 'sce_module' / 'readme.txt').write_text('ignorado')
        (game / 'sce_sys' / 'param.json').write_text(json.dumps(
            {'titleId': 'PPSA00000', 'contentId': 'EP0000-PPSA00000_00-TESTTESTTESTTEST',
             'contentVersion': '01.007.000', 'masterVersion': '01.00'}))
        return game

    def test_inventory_of_a_synthetic_game(self):
        with tempfile.TemporaryDirectory() as root:
            game = self.make_game(root)
            out = Path(root) / 'out' / 'inventory.json'
            with redirect_stdout(io.StringIO()):
                code = inspect_self.main([str(game), '--out', str(out)])
            self.assertEqual(code, 0)
            report = json.loads(out.read_text(encoding='utf-8'))
            self.assertEqual(report['param']['region'], 'EU')
            self.assertEqual(report['param']['contentVersion'], '01.007.000')
            self.assertEqual([f['path'] for f in report['files']], ['eboot.bin', 'sce_module/libc.prx'])
            self.assertEqual(report['files'][0]['container'], 'self')
            self.assertEqual(report['summary'], dict(files=2, imports=4, unique_import_nids=2, exports=2))
            imp = {i['nid']: i for i in report['files'][0]['imports']}
            self.assertEqual(imp[eb.NID_A]['call_site_count'], 2)

    def test_encrypted_dump_stops_with_exit_code_3(self):
        with tempfile.TemporaryDirectory() as root:
            game = self.make_game(root, eboot=eb.build_self(encrypted=True))
            err = io.StringIO()
            with redirect_stdout(io.StringIO()), redirect_stderr(err):
                code = inspect_self.main([str(game), '--out', str(Path(root) / 'inv.json')])
            self.assertEqual(code, 3)
            self.assertIn('PARADO', err.getvalue())
            self.assertFalse((Path(root) / 'inv.json').exists())

    def test_output_inside_the_dump_is_refused(self):
        with tempfile.TemporaryDirectory() as root:
            game = self.make_game(root)
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()), \
                    self.assertRaises(SystemExit):
                inspect_self.main([str(game), '--out', str(game / 'inventory.json')])
            self.assertFalse((game / 'inventory.json').exists())

    def test_pkg_is_refused(self):
        with tempfile.TemporaryDirectory() as root:
            pkg = Path(root) / 'game.pkg'
            pkg.write_bytes(b'\x7fFIH' + bytes(60))
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()), \
                    self.assertRaises(SystemExit):
                inspect_self.main([str(pkg)])

    def test_dump_is_not_modified(self):
        with tempfile.TemporaryDirectory() as root:
            game = self.make_game(root)
            before = {p: (p.stat().st_mtime_ns, p.read_bytes()) for p in game.rglob('*') if p.is_file()}
            with redirect_stdout(io.StringIO()):
                inspect_self.main([str(game), '--out', str(Path(root) / 'inv.json')])
            after = {p: (p.stat().st_mtime_ns, p.read_bytes()) for p in game.rglob('*') if p.is_file()}
            self.assertEqual(before, after)


if __name__ == '__main__':
    unittest.main()
