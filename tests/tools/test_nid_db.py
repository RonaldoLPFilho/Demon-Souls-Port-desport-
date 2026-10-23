# SPDX-License-Identifier: GPL-2.0-only
"""Testes do tools/nid_db.py com um "engine" sintético (nenhum arquivo do jogo).

Rodar: python -m unittest discover -s tests/tools -v
"""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / 'tools'))

import nid_db  # noqa: E402
import ps5elf  # noqa: E402

NID_PAD_INIT = ps5elf.nid('scePadInit')     # 'hv1luiJrqQM', igual ao engine
NID_PAD_OPEN = ps5elf.nid('scePadOpen')

ENGINE_SOURCE = r'''
#include "libs/libs.h"
namespace Libs {

namespace LibPad {
LIB_VERSION("Pad", 1, "Pad", 1, 1);

int KYTY_SYSV_ABI PadInit() {
	PRINT_NAME();
	g_state = Init(); // faz algo de verdade
	return OK;
}

static KYTY_SYSV_ABI int PadOpen(int user) {
	PRINT_NAME();
	LOGF("\t user = %d\n", user);
	return OK;
}

static int KYTY_SYSV_ABI PadGetResolution() {
	PRINT_NAME();
	return 1000000;
}

static int KYTY_SYSV_ABI PadFails(int x) {
	PRINT_NAME();
	(void)x;
	return PAD_ERROR_NOT_SUPPORTED;
}

static void KYTY_SYSV_ABI PadOpenStub() {
	DoSomething();
}

static void KYTY_SYSV_ABI PadAbort() {
	EXIT("not implemented\n");
}

int plain_helper(int a) {
	return 0;
}

static void PlatformSpecific() {
#if defined(_WIN32)
	if (WinCall() == 0) {
#else
	if (PosixCall() != 0) {
#endif
		std::abort();
	}
}
} // namespace LibPad

namespace Other {
LIB_VERSION("Other", 2, "OtherModule", 3, 4);
static int KYTY_SYSV_ABI OtherCall() { return Work(); }
} // namespace Other

namespace LibPad {
LIB_DEFINE(InitPad_1) {
	LIB_FUNC("@INIT@", PadInit);
	LIB_FUNC("@OPEN@",
	         LibPad::PadOpen);
	LIB_FUNC("RES00000000", PadGetResolution);
	LIB_FUNC("FAIL0000000", PadFails);
	LIB_FUNC("STUB0000000", PadOpenStub);
	LIB_FUNC("ABRT0000000", PadAbort);
	LIB_FUNC("PLAIN000000", plain_helper);
	// LIB_FUNC("COMMENTED00", PadInit);
	LIB_OBJECT("OBJ00000000", &g_object);
}
} // namespace LibPad

namespace Other {
LIB_DEFINE(InitOther_1) {
	LIB_FUNC("OTHER000000", OtherCall);
	LIB_FUNC("DUPNID00000", OtherCall);
}
} // namespace Other

} // namespace Libs
'''.replace('@INIT@', NID_PAD_INIT).replace('@OPEN@', NID_PAD_OPEN)


def make_engine(root):
    src = Path(root) / 'engine' / 'src'
    (src / 'libs').mkdir(parents=True)
    (src / 'libs' / 'libPad.cpp').write_text(ENGINE_SOURCE, encoding='utf-8')
    return src


class ScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        src = make_engine(cls.tmp.name)
        cls.regs, cls.defs = nid_db.scan_engine(src)
        cls.by_nid = {r['nid']: r for r in cls.regs}

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_registrations_found_and_comments_ignored(self):
        self.assertEqual(len(self.regs), 10)
        self.assertNotIn('COMMENTED00', self.by_nid)

    def test_version_follows_reopened_namespace(self):
        r = self.by_nid[NID_PAD_INIT]
        self.assertEqual((r['library'], r['library_version'], r['module'], r['module_version']),
                         ('Pad', 1, 'Pad', [1, 1]))
        o = self.by_nid['OTHER000000']
        self.assertEqual((o['library'], o['library_version'], o['module'], o['module_version']),
                         ('Other', 2, 'OtherModule', [3, 4]))

    def test_multiline_entry_and_qualified_target(self):
        r = self.by_nid[NID_PAD_OPEN]
        self.assertEqual((r['target'], r['function']), ('LibPad::PadOpen', 'PadOpen'))

    def test_body_classification(self):
        expected = {
            NID_PAD_INIT: ('implemented', None),
            NID_PAD_OPEN: ('stub', 'return_constant'),      # só loga e retorna OK
            'RES00000000': ('implemented', None),          # constante legítima
            'FAIL0000000': ('stub', 'return_constant'),    # código de erro
            'STUB0000000': ('stub', 'name'),
            'ABRT0000000': ('stub', 'aborts'),
            'PLAIN000000': ('stub', 'return_constant'),    # definição sem KYTY_SYSV_ABI
            'OBJ00000000': ('implemented', None),
            'OTHER000000': ('implemented', None),
        }
        for nid_value, (status, reason) in expected.items():
            r = self.by_nid[nid_value]
            self.assertEqual((r['body_status'], r['stub_reason']), (status, reason), r['function'])

    def test_preprocessor_branches_do_not_unbalance_braces(self):
        # Sem descartar o ramo #else, o `{` duplicado de PlatformSpecific faria o escopo de
        # LibPad "vazar" e o InitOther_1 herdaria a versão errada.
        self.assertEqual(self.by_nid['DUPNID00000']['library'], 'Other')

    def test_names_only_when_verified_by_hash(self):
        self.assertEqual(self.by_nid[NID_PAD_INIT]['name'], 'scePadInit')
        self.assertEqual(self.by_nid[NID_PAD_OPEN]['name'], 'scePadOpen')
        self.assertIsNone(self.by_nid['RES00000000']['name'])

    def test_names_file(self):
        with tempfile.TemporaryDirectory() as root:
            src = make_engine(root)
            regs, _ = nid_db.scan_engine(src, names=['sceSomething'])
        self.assertTrue(all(r['name'] != 'sceSomething' for r in regs))  # NID não bate


class ResolveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.regs, _ = nid_db.scan_engine(make_engine(self.tmp.name))

    def tearDown(self):
        self.tmp.cleanup()

    @staticmethod
    def imp(nid_value, library, module, typ='func', lib_ver=1, mod_ver=(1, 1)):
        return dict(nid=nid_value, library=library, library_version=lib_ver, module=module,
                    module_version=list(mod_ver), type=typ, slots=[0x10], call_sites=[0x100, 0x200],
                    call_site_count=2)

    def inventory(self):
        eboot_imports = [
            self.imp(NID_PAD_INIT, 'libScePad', 'libScePad'),            # exata (prefixo libSce removido)
            self.imp(NID_PAD_OPEN, 'libScePadOther', 'libScePad'),       # só pelo NID -> stub
            self.imp('LIBC0000000', 'libc', 'libc'),                     # módulo do dump
            self.imp('NOWHERE0000', 'libSceGone', 'libSceGone'),         # missing
            self.imp('OBJ00000000', 'libScePad', 'libScePad', typ='func'),  # tipo diferente -> missing
        ]
        libc_exports = [dict(nid='LIBC0000000', library='libc', module='libc', type='func')]
        return dict(param=dict(titleId='PPSA00000', region='EU', contentVersion='01.000.000'),
                    files=[dict(path='eboot.bin', imports=eboot_imports, exports=[]),
                           dict(path='sce_module/libc.prx', imports=[], exports=libc_exports)])

    def test_resolution_order_and_status(self):
        rows = {r['nid']: r for r in nid_db.resolve(self.inventory(), self.regs)}
        self.assertEqual((rows[NID_PAD_INIT]['status'], rows[NID_PAD_INIT]['match']), ('implemented', 'exact'))
        self.assertEqual((rows[NID_PAD_OPEN]['status'], rows[NID_PAD_OPEN]['match']), ('stub', 'nid_fallback'))
        libc = rows['LIBC0000000']
        self.assertEqual((libc['status'], libc['provider'], libc['module_loaded']),
                         ('provided_by_game_module', 'sce_module/libc.prx', 'auto'))
        self.assertEqual(rows['NOWHERE0000']['status'], 'missing')
        self.assertEqual(rows['OBJ00000000']['status'], 'missing')

    def test_report_files(self):
        with tempfile.TemporaryDirectory() as root:
            inv = Path(root) / 'inventory.json'
            inv.write_text(json.dumps(self.inventory()), encoding='utf-8')
            md = Path(root) / 'IMPORTS.md'
            with redirect_stdout(io.StringIO()):
                code = nid_db.main(['--engine', str(Path(self.tmp.name) / 'engine' / 'src'),
                                    '--inventory', str(inv), '--out-dir', str(Path(root) / 'out'),
                                    '--imports-md', str(md)])
            self.assertEqual(code, 0)
            text = md.read_text(encoding='utf-8')
            self.assertIn('| `missing` | 2 | 40.0% |', text)
            self.assertIn('**Funções que faltam (`missing` + `stub`): 3.**', text)
            self.assertIn('scePadInit', text)
            status = json.loads((Path(root) / 'out' / 'nid_status.json').read_text(encoding='utf-8'))
            self.assertEqual(len(status['rows']), 5)


if __name__ == '__main__':
    unittest.main()
