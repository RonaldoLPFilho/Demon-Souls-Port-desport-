# SPDX-License-Identifier: GPL-2.0-only
"""Testes do tools/log_triage.py com uma execução sintética."""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / 'tools'))
import log_triage  # noqa: E402

LOG = """Initialized: Config
Title ID: PPSA00000
DES_MILESTONE process_started t=12 title=PPSA00000
Loading: D:/game\\eboot.bin
base_vaddr             = 0x0000000900000000
base_size              = 0x0000000000100000
mapped_size            = 0x0000000000200000
Loading: D:/game\\sce_module/libc.prx
base_vaddr             = 0x0000000910000000
mapped_size            = 0x0000000000010000
Relocate: unresolved PLT import patched to stub [1] [0] <- 0, AAAA[x][y][Func], Func, Global, eboot
Relocate: unresolved PLT import patched to stub [2] [0] <- 0, BBBB[x][y][Func], Func, Global, eboot
DES_MILESTONE modules_loaded t=300 programs=2
DES_MILESTONE game_entry t=310
Unresolved import stub called [0]: patch_vaddr=0x1 jmprela_index=1 symbol=AAAA[x_v1][y_v1.1][Func] type=Func bind=Global program=eboot
Unresolved import stub called [1]: patch_vaddr=0x1 jmprela_index=1 symbol=AAAA[x_v1][y_v1.1][Func] type=Func bind=Global program=eboot
[Vulkan][E][123]: Validation Error: [ VUID-x ] Object 0x1234 bad
[Vulkan][E][123]: Validation Error: [ VUID-x ] Object 0x5678 bad
[Vulkan][W][9]: something slow
warning: ignoring indirect uc reg GE_STEREO_CNTL at 0x25f, value = 0x00000000
warning: ignoring indirect uc reg GE_STEREO_CNTL at 0x25f, value = 0x00000001
\t warning: indented parameter lines are ignored
DES_MILESTONE flip_1 t=900 source=gpu
Unhandled host exception: type=1 code=5 pc=0x0000000900001234 access=1 address=0x0000000000000010
--- Build ---
Source build test
--- Error ---
something bad happened
 in D:\\engine\\src\\x.cpp:42
"""


def make_run(root, growth=True):
    run = Path(root) / 'run'
    run.mkdir()
    (run / 'log.txt').write_text(LOG, encoding='utf-8')
    (run / 'run.json').write_text(json.dumps(dict(run_id='run', result='crashed_or_error', exit_code=321,
                                                  duration_sec=100.0, flags=['--x'])), encoding='utf-8-sig')
    rows = ['t_sec,private_mb,working_set_mb']
    for t in range(0, 101):
        mem = 1000 + (t * 1.0 if growth else 0) + (500 if t < 20 else 0)
        rows.append(f'{t},{mem},{mem + 100}')
    (run / 'memory.csv').write_text('\n'.join(rows) + '\n', encoding='utf-8')
    (run / 'calls.json').write_text(json.dumps(dict(elapsed_ms=5000, entries=[
        dict(nid='N1', function='F1', count=10, first_ms=100),
        dict(nid='N2', function='F2', count=0, first_ms=None),
        dict(nid='N3', function='F3', count=3, first_ms=50)])), encoding='utf-8')
    return run


class TriageTests(unittest.TestCase):
    def test_full_report(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            report, run_dir = log_triage.triage(run)
            self.assertEqual([m['name'] for m in report['milestones']],
                             ['process_started', 'modules_loaded', 'game_entry', 'flip_1'])
            self.assertEqual(report['error'], dict(message='something bad happened', where='D:\\engine\\src\\x.cpp:42'))
            self.assertEqual(report['host_exception']['where'], 'eboot.bin+0x1234')
            self.assertEqual(report['stubbed_at_link'], 2)
            self.assertEqual(report['stub_calls'], {'AAAA[x_v1][y_v1.1][Func]': 2})
            self.assertEqual(sum(report['vulkan'].values()), 3)
            self.assertEqual(len([k for k in report['vulkan'] if k[0] == 'E']), 1)  # agrupadas
            self.assertEqual(list(report['warnings'].values()), [2])
            mem = report['memory']
            self.assertAlmostEqual(mem['growth_mb_per_min'], 60.0, places=3)
            self.assertTrue(mem['alert'])
            self.assertEqual(mem['peak_private_mb'], 1519.0)
            calls = report['calls']
            self.assertEqual((calls['called'], calls['imports'], calls['total_calls']), (2, 3, 13))
            self.assertEqual(calls['first'][0]['nid'], 'N3')
            text = log_triage.render(report)
            self.assertIn('Último marco: **flip_1**', text)
            self.assertIn('**ALERTA**', text)

    def test_fps_windows(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            (run / 'log.txt').write_text('DES_FPS t=5000 fps=3.0\nDES_FPS t=10000 fps=5.0\n'
                                         'DES_FPS t=65000 fps=40.0\n', encoding='utf-8')
            report, _ = log_triage.triage(run)
            self.assertEqual(report['fps'], [(5000, 3.0), (10000, 5.0), (65000, 40.0)])
            text = log_triage.render(report)
            self.assertIn('3 janelas: mínimo 3.0, mediana 5.0, máximo 40.0', text)
            self.assertIn("0′ 4.0, 1′ 40.0", text)

    FRAME_LINES = (
        'DES_FRAME t=5000 frames=300 vblank=120 v1=100 v2=190 v3=8 v4p=2 p50=16.70 p95=25.00 p99=33.40 max=41.00 '
        'gpu_wait=1.000 readback_wait=2.000 download_wait=0.000 compile=0.100 record_wait=0.000 upload_wait=0.000 '
        'idle=0.500 cpu=9.000 sync_reads_guest=2400 sync_reads_render=10 rb_reject_size=5 rb_reject_backing=0 '
        'rb_reject_image=0 rb_reject_capacity=0 sync_downloads=3 async_readbacks=40 pipeline_static_hits=90 '
        'pipeline_static_misses=10 pipeline_driver_hits=4\n'
        'DES_FRAME t=10000 frames=100 vblank=120 v1=0 v2=100 v3=0 v4p=0 p50=16.70 p95=16.80 p99=17.00 max=60.00 '
        'gpu_wait=3.000 readback_wait=4.000 download_wait=0.000 compile=0.000 record_wait=0.000 upload_wait=0.000 '
        'idle=0.000 cpu=7.000 sync_reads_guest=800 sync_reads_render=0 rb_reject_size=0 rb_reject_backing=1 '
        'rb_reject_image=0 rb_reject_capacity=0 sync_downloads=0 async_readbacks=10 pipeline_static_hits=10 '
        'pipeline_static_misses=0 pipeline_driver_hits=0\n'
        'DES_FRAME t=15000 frames=0 sync_reads_guest=0 sync_reads_render=0 rb_reject_size=0 rb_reject_backing=0 '
        'rb_reject_image=0 rb_reject_capacity=0 sync_downloads=0 async_readbacks=0 pipeline_static_hits=0 '
        'pipeline_static_misses=0 pipeline_driver_hits=0\n')

    def test_frame_windows(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            (run / 'log.txt').write_text('DES_FPS t=5000 fps=60.0\n' + self.FRAME_LINES, encoding='utf-8')
            report, _ = log_triage.triage(run)
            self.assertEqual(len(report['frames']), 3)
            summary = log_triage.frame_summary(report['frames'])
            self.assertEqual(summary['windows'], 2)  # a janela sem quadros fica fora
            self.assertEqual(summary['frames'], 400)
            self.assertEqual(summary['hist'], dict(v1=100, v2=290, v3=8, v4p=2))
            self.assertAlmostEqual(summary['waits']['gpu_wait'], (1.0 * 300 + 3.0 * 100) / 400)
            self.assertAlmostEqual(summary['waits']['cpu'], (9.0 * 300 + 7.0 * 100) / 400)
            self.assertEqual(summary['counts']['sync_reads_guest'], 3200)
            self.assertEqual(summary['p99_worst'], 33.4)
            self.assertEqual(summary['max'], 60.0)
            text = log_triage.render(report)
            self.assertIn('### Quadros (DES_FRAME)', text)
            self.assertIn('1 100 (25.0%), 2 290 (72.5%), 3 8 (2.0%), 4+ 2 (0.5%)', text)
            self.assertIn('guest 3200 (8.0/quadro)', text)
            self.assertIn('100 acertos, 10 erros (90.9% de acerto)', text)

    def test_frame_lines_from_stdout_and_absent(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            self.assertIsNone(log_triage.frame_summary(log_triage.triage(run)[0]['frames']))
            self.assertNotIn('DES_FRAME', log_triage.render(log_triage.triage(run)[0]))
            (run / 'stdout.txt').write_text(self.FRAME_LINES, encoding='utf-8')
            report, _ = log_triage.triage(run)
            self.assertEqual(len(report['frames']), 3)

    def test_slow_calls(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            (run / 'stdout.txt').write_text('DES_SLOW t=372000 name=net_connect ms=30012 vaddr=0x0\n',
                                            encoding='utf-8')
            report, _ = log_triage.triage(run)
            self.assertEqual(report['slow_calls'][0]['name'], 'net_connect')
            self.assertIn('| 372000 | net_connect | 30012 | `0x0` |', log_triage.render(report))

    def test_des_lines_from_stdout(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            (run / 'log.txt').write_text('DES_MILESTONE process_started t=10 title=X\n', encoding='utf-8')
            (run / 'stdout.txt').write_text('DES_MILESTONE process_started t=10 title=X\n'
                                            'DES_MILESTONE flip_1 t=500 source=cpu\n'
                                            'DES_FPS t=5000 fps=59.9\n', encoding='utf-8')
            report, _ = log_triage.triage(run)
            self.assertEqual([m['name'] for m in report['milestones']], ['process_started', 'flip_1'])
            self.assertEqual(report['fps'], [(5000, 59.9)])

    def test_hitches_from_stdout(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            self.assertIsNone(log_triage.triage(run)[0]['hitches'])
            (run / 'stdout.txt').write_text(
                '[tsc 1] SLOW Frame 764.3 ms idle=0.0 compile=757.0 record_wait=1.5\n'
                'other line\n'
                '[tsc 2] SLOW Frame 1200.0 ms idle=3.8 cpu=385.9 compile=100.0\n'
                '[tsc 3] SLOW Frame 120.0 ms idle=0.0 cpu=2.0\n', encoding='utf-8')
            h = log_triage.triage(run)[0]['hitches']
            self.assertEqual((h['count'], h['over_500'], h['over_1000'], h['compile_count']), (3, 2, 1, 1))
            self.assertAlmostEqual(h['worst_ms'], 1200.0)
            self.assertIn('3 quadros lentos', log_triage.render(log_triage.triage(run)[0]))

    def test_stats_per_frame(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            (run / 'log.txt').write_text(
                'DES_COUNTERS t=5000 frames=20 draws=2000 gpu_wait_ns=40000000 buffer_download_bytes=20480\n'
                'DES_COUNTERS t=10000 frames=30 draws=3000 gpu_wait_ns=60000000 buffer_download_bytes=30720\n'
                'DES_STAT t=5000 name=srt_materialize calls=1000 ms=500.0 bytes=0\n'
                'DES_STAT t=10000 name=readback calls=50 ms=250.0 bytes=51200\n'
                'DES_STAT_ADDR t=5000 name=readback region=0x2000000 calls=40 ms=200.0\n', encoding='utf-8')
            report, _ = log_triage.triage(run)
            text = log_triage.render(report)
            self.assertIn('- 50 quadros em 2 janelas de 5 s', text)
            self.assertIn('| draws | 100.0 |', text)
            self.assertIn('| gpu_wait_ns | 2.00 ms |', text)
            self.assertIn('| buffer_download_bytes | 1 KiB |', text)
            self.assertIn('| srt_materialize | 20.0 | 10.00 | 0 |', text)
            self.assertIn('| readback | `0x2000000` | 40 | 200.0 |', text)

    def test_game_log_timings_and_errors(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            self.assertIsNone(log_triage.triage(run)[0]['game_log'])
            (run / 'game_logs').mkdir()
            # O jogo escreve as linhas em dobro; vale a primeira ocorrência de cada etapa.
            (run / 'game_logs' / 'g_0.log').write_text(
                '[MSG-Init] Starting Initialization: 49.5ms\n'
                '[MSG-Init] Pool::Load() took 437.5ms\n'
                '[MSG-Init] Finished Initialization: 4.4s\n'
                '[MSG-Init] Pool::Gather() took 30.9s\n'
                '[MSG-Init] Pool::Gather() took 99.0s\n'
                '[00:00:41.51 ERROR-General] could not find "x"\n'
                '[00:00:41.51 ERROR-General] could not find "x"\n'
                '[MSG-Init] Starting main loop: 41.5s\n', encoding='utf-8')
            game = log_triage.triage(run)[0]['game_log']
            self.assertEqual(game['timings'], {'Pool::Load()': 0.4375, 'Finished Initialization': 4.4,
                                               'Pool::Gather()': 30.9, 'Starting main loop': 41.5})
            self.assertEqual(dict(game['errors']), {'General: could not find "x"': 2})
            self.assertIn('| Pool::Gather() | 30.90 |', log_triage.render(log_triage.triage(run)[0]))

    def test_flat_memory_has_no_alert(self):
        with tempfile.TemporaryDirectory() as root:
            report, _ = log_triage.triage(make_run(root, growth=False))
            self.assertAlmostEqual(report['memory']['growth_mb_per_min'], 0.0, places=6)
            self.assertFalse(report['memory']['alert'])

    def test_mem_categories(self):
        mib = 1 << 20
        lines = []
        # t em ms; 'vma_device_local' cresce 10 MB/min a partir do início, 'guest' fica plano.
        for minute in range(0, 6):
            t = minute * 60000 + 5000
            lines.append(f'DES_MEM t={t} name=process_private bytes={(1000 + 12 * minute) * mib} count=0')
            lines.append(f'DES_MEM t={t} name=vma_device_local bytes={(200 + 10 * minute) * mib} count=7')
            lines.append(f'DES_MEM t={t} name=guest_direct_mapped bytes={500 * mib} count=3')
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            (run / 'stdout.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
            report, _ = log_triage.triage(run)
            cats = report['mem_categories']
            self.assertEqual(set(cats), {'process_private', 'vma_device_local', 'guest_direct_mapped'})
            vma = cats['vma_device_local']
            self.assertAlmostEqual(vma['first_mb'], 200.0)
            self.assertAlmostEqual(vma['last_mb'], 250.0)
            self.assertAlmostEqual(vma['peak_mb'], 250.0)
            self.assertAlmostEqual(vma['slope_mb_per_min'], 10.0, places=3)
            self.assertEqual(vma['last_count'], 7)
            self.assertAlmostEqual(cats['guest_direct_mapped']['slope_mb_per_min'], 0.0, places=6)
            text = log_triage.render(report)
            self.assertIn('## Memória por categoria (DES_MEM)', text)
            self.assertIn('| vma_device_local | 200 | 250 | 250 | +10.0 **ALERTA** | 7 |', text)
            self.assertIn('| guest_direct_mapped | 500 | 500 | 500 | +0.0 | 3 |', text)
            # process_ vem primeiro
            self.assertLess(text.index('| process_private |'), text.index('| vma_device_local |'))

    def test_mem_slope_needs_samples_after_warmup(self):
        cats = log_triage.mem_by_category([(5000, 'a', 1 << 20, 1), (35000, 'a', 2 << 20, 1)])
        self.assertIsNone(cats['a']['slope_mb_per_min'])
        self.assertAlmostEqual(cats['a']['peak_mb'], 2.0)

    def test_crash_section(self):
        line = ('DES_CRASH t=91234 kind=exception code=0xc0000005 pc=0x7ff612345678 module=kyty_emulator.exe+0x1a2b '
                'thread=4242 name=Render dump=crash-20261024-101500-777.dmp message="Unhandled host exception: type=1 in x.cpp:9"')
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            (run / 'stdout.txt').write_text(line + '\n', encoding='utf-8')
            (run / 'crash-20261024-101500-777.dmp').write_bytes(b'MDMP')
            report, _ = log_triage.triage(run)
            self.assertEqual(len(report['crashes']), 1)
            crash = report['crashes'][0]
            self.assertEqual((crash['kind'], crash['code'], crash['thread'], crash['name']),
                             ('exception', '0xc0000005', '4242', 'Render'))
            self.assertEqual(crash['message'], 'Unhandled host exception: type=1 in x.cpp:9')
            self.assertEqual(report['dumps'], ['crash-20261024-101500-777.dmp'])
            text = log_triage.render(report)
            self.assertIn('## Crash (DES_CRASH)', text)
            self.assertIn('**exception** t=91234 ms', text)
            self.assertIn('Minidumps na pasta da execução: `crash-20261024-101500-777.dmp`', text)

    def test_no_crash_section_without_crash(self):
        with tempfile.TemporaryDirectory() as root:
            report, _ = log_triage.triage(make_run(root))
            self.assertEqual((report['crashes'], report['dumps']), ([], []))
            self.assertNotIn('DES_CRASH', log_triage.render(report))

    def test_faults_section(self):
        lines = [
            'DES_FAULTS t=5000 write_direct=300 write_flexible=100 write_pooled=0 write_other=0 read=0 other=0 '
            'window=250 restore=10 invalidate=140 readback=0 guest=400 gpu_thread=0',
            'DES_FAULTS t=10000 write_direct=100 write_flexible=500 write_pooled=0 write_other=0 read=20 other=0 '
            'window=300 restore=0 invalidate=300 readback=20 guest=600 gpu_thread=20',
        ]
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            (run / 'stdout.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
            report, _ = log_triage.triage(run)
            f = report['faults']
            self.assertEqual((f['windows'], f['faults'], f['writes']), (2, 1020, 1000))
            self.assertAlmostEqual(f['seconds'], 10.0)
            self.assertEqual(f['totals']['write_direct'], 400)
            self.assertEqual(f['totals']['gpu_thread'], 20)
            text = log_triage.render(report)
            self.assertIn('## Faults (DES_FAULTS)', text)
            self.assertIn('1020 faults, 102/s', text)
            self.assertIn('| direta (view da seção) | 400 | 40.0 | 40.0 |', text)
            self.assertIn('| flexível (privada) | 600 | 60.0 | 60.0 |', text)
            self.assertIn('| leitura (NOACCESS) | 20 | 2.0 | 2.0 |', text)
            self.assertIn('| janela de escrita | 550 | 55.0 | 53.9 |', text)

    def test_no_faults_section_without_des_faults(self):
        with tempfile.TemporaryDirectory() as root:
            report, _ = log_triage.triage(make_run(root))
            self.assertIsNone(report['faults'])
            self.assertNotIn('DES_FAULTS', log_triage.render(report))

    def test_no_mem_section_without_des_mem(self):
        with tempfile.TemporaryDirectory() as root:
            report, _ = log_triage.triage(make_run(root))
            self.assertEqual(report['mem_categories'], {})
            self.assertNotIn('DES_MEM', log_triage.render(report))

    def test_cli_writes_triage_md(self):
        with tempfile.TemporaryDirectory() as root:
            run = make_run(root)
            with redirect_stdout(io.StringIO()):
                self.assertEqual(log_triage.main([str(run)]), 0)
            self.assertTrue((run / 'triage.md').exists())

    def test_scenario_evaluation(self):
        with tempfile.TemporaryDirectory() as root:
            report, _ = log_triage.triage(make_run(root))
            ok = dict(expect_milestones=['game_entry'], allow_engine_stop=True)
            self.assertEqual(log_triage.evaluate(dict(report, host_exception=None), ok), [])
            strict = dict(expect_milestones=['flip_1', 'flip_60'], deadline_ms=500,
                          allow_engine_stop=False, max_vulkan_errors=0, max_growth_mb_per_min=10)
            failures = log_triage.evaluate(report, strict)
            joined = '\n'.join(failures)
            for expected in ('marco ausente: flip_60', 'flip_1 em 900 ms', 'parada do engine',
                             'exceção do host', 'erros de validação', 'memória cresce'):
                self.assertIn(expected, joined)

    def test_real_scenarios_file_parses(self):
        boot = log_triage.load_scenario('boot')
        self.assertIn('flip_1', boot['expect_milestones'])
        with self.assertRaises(KeyError):
            log_triage.load_scenario('nao-existe')

    def test_missing_log(self):
        with tempfile.TemporaryDirectory() as root:
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(log_triage.main([str(Path(root) / 'nope.txt'), '--no-write']), 1)


if __name__ == '__main__':
    unittest.main()
