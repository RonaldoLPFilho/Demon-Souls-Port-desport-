# SPDX-License-Identifier: GPL-2.0-only
"""Testes do tools/capture_report.py com um frame-N.jsonl sintético (formato de src/local/frame-capture.h)."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / 'tools'))
import capture_report  # noqa: E402

TAA = 'a44e580f4f0cfb2b'


def image(kind, address, width, height, fmt=97, slot=0, rw=0, uav=0):
    return {'k': kind, 'st': 1, 'slot': slot, 'a': address, 'sz': width * height * 8, 'f': fmt, 'gf': 0, 'ty': 1,
            'w': width, 'h': height, 'd': 1, 'mip': 1, 'arr': 1, 'pitch': width, 'tile': 0, 'ms': 1, 'rw': rw, 'uav': uav}


def draw(i, ps, imgs, n=3):
    return {'i': i, 't': 'Draw', 'us': 10.0, 'prep': 1, 'vs': '00000000000000aa', 'ps': ps, 'n': n, 'inst': 1,
            'vp': [1280.0, 1280.0, -720.0, 720.0, 0.5, 0.5], 'sc': [0, 0, 2560, 1440], 'blend0': '0', 'img': imgs, 'buf': []}


def dispatch(i, cs, imgs):
    return {'i': i, 't': 'Dispatch', 'us': 20.0, 'prep': 1, 'cs': cs, 'groups': [320, 180, 1], 'local': [8, 8, 1],
            'img': imgs, 'buf': []}


def write_frame(directory, number, calls):
    lines = [{'t': 'frame', 'frame': number}] + calls + [{'t': 'flip', 'frame': number, 'calls': len(calls)}]
    (Path(directory) / f'frame-{number}.jsonl').write_text('\n'.join(json.dumps(l) for l in lines) + '\n', encoding='utf-8')


CALLS = [
    draw(0, '00000000000000b1', [image(0, 'a1000', 2560, 1440, 37), image(1, 'a2000', 2560, 1440, 126)]),   # G-buffer
    dispatch(1, '0000000000000c01', [image(2, 'a1000', 2560, 1440, 37, slot=0)]),                           # antes do TAA
    dispatch(2, '00000000' + TAA[:8] + TAA[8:], [image(2, 'a1000', 2560, 1440, 37), image(2, 'a3000', 2560, 1440, 97, slot=1, rw=1, uav=1)]),
    dispatch(3, '0000000000000d02', [image(2, 'a3000', 2560, 1440, 97, slot=0), image(2, 'a4000', 3840, 2160, 97, slot=1, rw=1, uav=1)]),  # upscale
    draw(4, '00000000000000b2', [image(0, 'a4000', 3840, 2160, 97), image(2, 'a9000', 256, 256, 37, slot=0)], n=6),            # UI
    draw(5, '00000000000000b2', [image(0, 'a4000', 3840, 2160, 97), image(2, 'a9000', 256, 256, 37, slot=0)], n=6),            # UI
    dispatch(6, '0000000000000e03', [image(2, 'a4000', 3840, 2160, 97, slot=0), image(2, 'a5000', 3840, 2160, 97, slot=1, rw=1)]),
    dispatch(7, '0000000000000f04', [image(2, 'a7777', 64, 64, 37, slot=0)]),                                # não relacionada
]


class CaptureReportTests(unittest.TestCase):
    def test_taa_and_followers_and_ui(self):
        notes = capture_report.analyse(CALLS)
        self.assertEqual([n['taa'] for n in notes], [False, False, True, False, False, False, False, False])
        self.assertEqual([n['level'] for n in notes], [0, 0, 0, 1, 0, 0, 2, 0])
        self.assertEqual([n['ui'] for n in notes], [False, False, False, False, True, True, False, False])
        self.assertTrue(notes[3]['reads_from'][0].startswith('a3000:'))

    def test_chain_limit(self):
        notes = capture_report.analyse(CALLS, chain=1)
        self.assertEqual([n['level'] for n in notes], [0, 0, 0, 1, 0, 0, 0, 0])

    def test_without_taa_nothing_is_marked(self):
        notes = capture_report.analyse(CALLS[:2] + CALLS[3:])
        self.assertFalse(any(n['taa'] or n['level'] for n in notes))

    def test_report_file(self):
        with tempfile.TemporaryDirectory() as root:
            write_frame(root, 0, CALLS)
            write_frame(root, 1, CALLS[:3])
            text = capture_report.build_report(root)
            self.assertIn('## frame-0', text)
            self.assertIn('## frame-1', text)
            self.assertIn('### Dispatch do TAA', text)
            self.assertIn('### Depois do TAA: quem lê a saída (candidatas ao upscale)', text)
            self.assertIn('cs 0000000000000d02', text)
            self.assertIn(':3840x2160', text)
            self.assertIn('Draws no alvo de saída (UI)', text)
            self.assertIn('x2', text)  # as duas draws de UI iguais agrupadas
            self.assertIn('| T+1 | cs 0000000000000d02 | 1 |', text)
            self.assertIn('| T+2 | cs 0000000000000e03 | 1 |', text)
            self.assertIn('vp=2560x1440@0,0', text)

    def test_main_writes_captures_md(self):
        with tempfile.TemporaryDirectory() as root:
            write_frame(root, 0, CALLS)
            self.assertEqual(capture_report.main([root]), 0)
            self.assertTrue((Path(root) / 'captures.md').exists())

    def test_incomplete_frame_is_flagged(self):
        with tempfile.TemporaryDirectory() as root:
            (Path(root) / 'frame-0.jsonl').write_text(json.dumps(CALLS[0]) + '\n{broken\n', encoding='utf-8')
            self.assertIn('frame incompleto', capture_report.build_report(root))

    def test_missing_directory(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(FileNotFoundError):
                capture_report.build_report(root)


if __name__ == '__main__':
    unittest.main()
