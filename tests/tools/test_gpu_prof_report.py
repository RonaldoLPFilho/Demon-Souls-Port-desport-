# SPDX-License-Identifier: GPL-2.0-only
"""Testes do tools/gpu_prof_report.py com linhas DES_GPU_PROF sintéticas."""
import io
import json
from contextlib import redirect_stdout
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / 'tools'))
import gpu_prof_report  # noqa: E402

TOTAL = ('DES_GPU_PROF total t={t} window_ms=10000 frames=20 every=30 cbs=400 calls=8000 keys=300 '
         'attributed_ms={att} draw_ms=150.000 dispatch_ms=50.000 busy_ms={busy} cb_sum_ms=260.000 span_ms=300.000 '
         'frame_attributed_ms=10.000 frame_busy_ms=12.500 frame_span_ms=15.000 coverage_pct=80.0 dropped=0 lost=1 '
         'orphans=2')
TAA = ('DES_GPU_PROF rank=1 t={t} kind=dispatch pipe=cs-table hash=a44e580f4f0cfb2b groups=320x180x1 calls=20 '
       'calls_per_frame=1.0 gpu_ms={ms} ms_per_frame=1.000 pct=8.00 avg_us=1000.00 max_us={mx} wave=64e')
DRAW = ('DES_GPU_PROF rank=2 t={t} kind=draw_indexed pipe=gfx-native hash=0000000012345678 target=2560x1440 '
        'calls=400 calls_per_frame=20.0 gpu_ms=10.000 ms_per_frame=0.500 pct=4.00 avg_us=25.00 max_us=90.0 '
        'vs=1e5a000000000001 verts=3000')


def sample(t=10000, ms='20.000', mx='1500.0', att='200.000', busy='250.000'):
    return [
        'DES_GPU_PROF on=1 every=30 seconds=10 top=25 pairs=32768 period_ns=1.000 valid_bits=64 mesh=1',
        'ruído qualquer',
        TOTAL.format(t=t, att=att, busy=busy),
        TAA.format(t=t, ms=ms, mx=mx),
        DRAW.format(t=t),
    ]


class GpuProfReportTests(unittest.TestCase):
    def test_parse_line_keeps_hex_hashes_as_text(self):
        rec = gpu_prof_report.parse_line(DRAW.format(t=5))
        self.assertEqual(rec['type'], 'rank')
        self.assertEqual(rec['hash'], '0000000012345678')  # não vira 12345678.0
        self.assertEqual(rec['vs'], '1e5a000000000001')    # não vira float
        self.assertEqual(rec['target'], '2560x1440')
        self.assertEqual(rec['gpu_ms'], 10.0)
        self.assertEqual(rec['rank'], 1.0 + 1)
        self.assertIsNone(gpu_prof_report.parse_line('DES_GPU_PROF on=1 every=30'))
        self.assertIsNone(gpu_prof_report.parse_line('DES_GPU_TS t=1 subs=2'))
        total = gpu_prof_report.parse_line('[log] ' + TOTAL.format(t=7, att='1', busy='2'))
        self.assertEqual(total['type'], 'total')
        self.assertEqual(total['busy_ms'], 2.0)

    def test_collect_groups_by_period_and_skips_warmup(self):
        lines = sample(t=10000) + sample(t=20000)
        periods = gpu_prof_report.collect(lines)
        self.assertEqual(list(periods), [10000, 20000])
        self.assertEqual(len(periods[10000]['ranks']), 2)
        self.assertIsNotNone(periods[20000]['total'])
        self.assertEqual(list(gpu_prof_report.collect(lines, skip_sec=15)), [20000])

    def test_aggregate_sums_periods(self):
        lines = sample(t=10000, ms='20.000', mx='1500.0') + sample(t=20000, ms='30.000', mx='2500.0')
        result = gpu_prof_report.aggregate(gpu_prof_report.collect(lines))
        s = result['summary']
        self.assertEqual(s['periods'], 2)
        self.assertEqual(s['frames'], 40)
        self.assertAlmostEqual(s['frame_busy_ms'], 500.0 / 40)
        self.assertAlmostEqual(s['coverage_pct'], 80.0)
        top = result['by_key'][0]
        self.assertEqual(top['hash'], 'a44e580f4f0cfb2b')
        self.assertEqual(top['shape'], 'groups=320x180x1')
        self.assertAlmostEqual(top['gpu_ms'], 50.0)
        self.assertAlmostEqual(top['ms_per_frame'], 50.0 / 40)
        self.assertAlmostEqual(top['pct_busy'], 10.0)
        self.assertEqual(top['max_us'], 2500.0)
        self.assertEqual(top['periods'], 2)
        self.assertEqual(top['wave'], '64e')
        self.assertIn('TAA', top['name'])
        self.assertAlmostEqual(top['avg_us'], 1000.0 * 50.0 / 40)
        self.assertAlmostEqual(s['listed_pct'], 100.0 * 70.0 / 500.0)

    def test_by_shader_merges_shapes(self):
        other = DRAW.format(t=10000).replace('target=2560x1440', 'target=1280x720').replace('rank=2', 'rank=3')
        result = gpu_prof_report.aggregate(gpu_prof_report.collect(sample(t=10000) + [other]))
        self.assertEqual(len(result['by_key']), 3)
        shader = next(e for e in result['by_shader'] if e['hash'] == '0000000012345678')
        self.assertAlmostEqual(shader['gpu_ms'], 20.0)
        self.assertEqual(shader['shapes'], ['target=1280x720', 'target=2560x1440'])
        self.assertEqual(shader['calls'], 800)

    def test_render_and_empty(self):
        result = gpu_prof_report.aggregate(gpu_prof_report.collect(sample()))
        text = gpu_prof_report.render(result, top=1)
        self.assertIn('a44e580f4f0cfb2b', text)
        self.assertIn('Cobertura', text)
        self.assertNotIn('| 2 |', text.split('## Top 1 por shader')[0])
        empty = gpu_prof_report.render(gpu_prof_report.aggregate({}))
        self.assertIn('Nenhuma linha', empty)

    def test_main_with_run_dirs(self):
        with tempfile.TemporaryDirectory() as root:
            a = Path(root) / 'a'
            b = Path(root) / 'b'
            a.mkdir()
            b.mkdir()
            (a / 'stdout.txt').write_text('\n'.join(sample(t=10000)) + '\n', encoding='utf-8')
            (b / 'log.txt').write_text('\n'.join(sample(t=10000)) + '\n', encoding='utf-8')
            out = Path(root) / 'r.md'
            with redirect_stdout(io.StringIO()):
                self.assertEqual(gpu_prof_report.main([str(a), str(b), '--out', str(out)]), 0)
            self.assertIn('Períodos: 2', out.read_text(encoding='utf-8'))
            buf = io.StringIO()
            with redirect_stdout(buf):
                gpu_prof_report.main([str(a), '--json'])
            data = json.loads(buf.getvalue())
            self.assertEqual(data['summary']['frames'], 20)


if __name__ == '__main__':
    unittest.main()
