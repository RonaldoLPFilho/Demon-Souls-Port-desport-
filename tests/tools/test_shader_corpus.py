# SPDX-License-Identifier: GPL-2.0-only
"""Testes do tools/shader_corpus.py com um arquivo de entradas sintético (nada do jogo)."""
import io
from contextlib import redirect_stdout
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / 'tools'))
import shader_corpus  # noqa: E402

# v_readlane_b32 s4, v1, 63; ds_write_b32 v0, v1; ds_read_b32 v2, v0; v_mov_b32 v1, v1 row_shr:1;
# v_add_f32 v0, 0x3f800000, v0 (literal); s_cbranch_execz +0; s_barrier; s_endpgm
CODE = [0xd7600004, 0x00017f01, 0xd8340000, 0x00000100, 0xd8d80000, 0x02000000, 0x7e0202fa, 0xff011101,
        0x060000ff, 0x3f800000, 0xbf880000, 0xbf8a0000, 0xbf810000]
HASH = 0x7e676bf37482d768


def compute_record(shader_hash, code, threads=(8, 8, 1), lds=128):
    words = [shader_hash & 0xffffffff, shader_hash >> 32]
    words = [shader_corpus.COMPUTE] + words + [16, 0]
    words += [len(code)] + list(code)
    words += [0]  # back_code
    words += [0]  # static_key
    words += list(threads) + [lds, 0, 32, 64]  # workgroup
    words += [0, 0, 0, 1, 1, 1, 0, 2, 12, 0]  # resto do compute (não lido)
    return words


def shaders_file(path, records):
    words = [len(records)]
    for record in records:
        words += [len(record)] + record
    body = struct.pack(f'<{len(words)}I', *words)
    Path(path).write_bytes(b'KytyShaderWarmup3:TESTE\n' + b'\0' * 8 + body)


class ShaderCorpusTest(unittest.TestCase):
    def test_decode_lengths(self):
        pcs = [pc for pc, *_ in shader_corpus.decode(CODE)]
        self.assertEqual(pcs, [0x00, 0x08, 0x10, 0x18, 0x20, 0x28, 0x2c, 0x30])

    def test_scan(self):
        counts = shader_corpus.scan(CODE)
        self.assertEqual(counts['v_readlane'], 1)
        self.assertEqual(counts['ds_write_b32'], 1)
        self.assertEqual(counts['ds_read_b32'], 1)
        self.assertEqual(counts['dpp:0x111'], 1)
        self.assertEqual(counts['s_cbranch_execz'], 1)
        self.assertEqual(counts['s_barrier'], 1)
        self.assertNotIn('?decode', counts)

    def test_extract(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'x.shaders'
            shaders_file(source, [compute_record(HASH, CODE), compute_record(0x1234, CODE, threads=(256, 1, 1))])
            out = Path(tmp) / 'out'
            buffer = io.StringIO()
            with redirect_stdout(buffer):
                status = shader_corpus.main(['--shaders', str(source), '--out', str(out), '--hash', f'{HASH:x}'])
            self.assertEqual(status, 0)
            self.assertIn('group=8x8x1 (64)', buffer.getvalue())
            data = (out / 'g64' / f'CS_{HASH:016x}.bin').read_bytes()
            self.assertEqual(list(struct.unpack(f'<{len(data) // 4}I', data)), CODE)
            self.assertFalse((out / 'g256').exists())

    def test_missing_and_signature(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'x.shaders'
            shaders_file(source, [compute_record(HASH, CODE)])
            with redirect_stdout(io.StringIO()):
                self.assertEqual(shader_corpus.main(['--shaders', str(source), '--hash', 'abc', '--scan-only']), 1)
            bad = Path(tmp) / 'bad.shaders'
            bad.write_bytes(b'outra coisa\n' + b'\0' * 12)
            with self.assertRaises(ValueError):
                shader_corpus.read_words(bad)


if __name__ == '__main__':
    unittest.main()
