# SPDX-License-Identifier: GPL-2.0-only
"""Testes do tools/perf_ab_report.py com execuções sintéticas."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / 'tools'))
import perf_ab_report  # noqa: E402


def make_run(root, name, fps, with_frames=False):
    d = Path(root) / name
    d.mkdir()
    (d / 'log.txt').write_text('DES_MILESTONE process_started t=1\n', encoding='utf-8')
    lines = [f'DES_FPS t={t} fps={v}' for t, v in fps]
    lines += ['Vulkan pipeline cache: loading _PipelineCache/local/x/PPSA.bin',
              'Vulkan compute wave64: emulated on 32-lane subgroups (default)',
              'PIPEKEY graphics key=00ab layout=01 1/2', 'PIPEKEY graphics key=00ab layout=01 1/2',
              'SLOW Frame 150.0 ms compile=120', 'SLOW Frame 30.0 ms compile=0']
    if with_frames:
        lines.append('DES_FRAME t=200000 frames=100 vblank=120 v1=50 v2=50 v3=0 v4p=0 p50=8.3 p95=16 p99=17 max=20 '
                     'readback_wait=1.5 sync_reads_guest=800 pipeline_static_misses=3')
        lines.append('DES_FRAME t=1000 frames=100 vblank=120 v1=0 v2=0 v3=0 v4p=100 p99=99 pipeline_static_misses=99')
    (d / 'stdout.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return d


class PerfAbTests(unittest.TestCase):
    def test_percentile(self):
        self.assertIsNone(perf_ab_report.percentile([], 5))
        self.assertEqual(perf_ab_report.percentile(list(range(1, 101)), 50), 51)
        self.assertEqual(perf_ab_report.percentile([7], 1), 7)

    def test_fps_stats_warmup(self):
        fps = [(1000, 10.0), (200000, 60.0), (205000, 80.0)]
        s = perf_ab_report.fps_stats(fps, 180)
        self.assertEqual(s['windows'], 2)
        self.assertAlmostEqual(s['mean'], 70.0)
        s = perf_ab_report.fps_stats(fps[:1], 180)
        self.assertTrue(s['note'])

    def test_render(self):
        with tempfile.TemporaryDirectory() as root:
            a = make_run(root, 'a', [(200000, 60.0), (205000, 70.0)], with_frames=True)
            b = make_run(root, 'b', [(200000, 90.0)])
            manifest = dict(date='x', minutes=6, runs=[
                dict(id='base', desc='d', run_dir=str(a), outcome='completed', env={'K': '1'}),
                dict(id='B', desc='v240', run_dir=str(b), outcome='completed', flags=['--vblank-frequency', '240']),
                dict(id='C1', desc='falhou', run_dir=None, outcome='error')])
            text = perf_ab_report.render(manifest, 180)
            self.assertIn('| base | completed | 65.0 |', text)
            self.assertIn('2 / 0.2 / 150', text)
            self.assertIn('50.0 / 50.0 / 0.0 / 0.0', text)  # a janela t=1000 fica fora do aquecimento
            self.assertIn('| 3 |', text)
            self.assertIn('PIPEKEY: 2 linhas, 1 chaves distintas', text)
            self.assertIn('wave64', text)
            self.assertIn('| C1 | error |', text)
            self.assertIn('`--vblank-frequency 240`', text)

    def test_main(self):
        with tempfile.TemporaryDirectory() as root:
            a = make_run(root, 'a', [(200000, 60.0)])
            m = Path(root) / 'm.json'
            m.write_text(json.dumps(dict(runs=[dict(id='base', run_dir=str(a))])), encoding='utf-8')
            out = Path(root) / 'r.md'
            self.assertEqual(perf_ab_report.main([str(m), '--out', str(out)]), 0)
            self.assertIn('Nenhuma linha DES_FRAME', out.read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
