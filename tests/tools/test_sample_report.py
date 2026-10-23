from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import sample_report  # noqa: E402


def frame(addr, module='', symbol=''):
    return dict(addr=addr, module=module, symbol=symbol)


DATA = dict(pid=1, seconds=2.0, hz=100, threads=[
    dict(tid=10, name='guest', cpu_ms=1900.0, samples=4, stacks=[
        dict(count=3, frames=[frame(1, 'ntdll', 'NtYield'), frame(2, 'kyty_emulator', 'Usleep'),
                              frame(0x1010)]),
        dict(count=1, frames=[frame(0x1020)])]),
    dict(tid=11, name='', cpu_ms=10.0, samples=4, stacks=[
        dict(count=4, frames=[frame(3, 'ntdll', 'NtWait')])])])
MODULES = [dict(path='/app0/eboot.bin', base=0x1000, size=0x100)]


class SampleReportTests(unittest.TestCase):
    def test_summary_and_labels(self):
        threads = sample_report.summarize(DATA, MODULES)
        busy = threads[0]
        self.assertEqual((busy['tid'], round(busy['cpu_pct'])), (10, 95))
        self.assertEqual(busy['leaf'].most_common(1)[0], ('ntdll!NtYield', 3))
        self.assertEqual(busy['engine']['kyty_emulator!Usleep'], 3)
        self.assertEqual(busy['engine']['(fora do engine)'], 1)
        self.assertEqual(busy['leaf']['eboot.bin+0x20'], 1)
        self.assertEqual(busy['inclusive']['eboot.bin+0x10'], 3)
        text = sample_report.render(DATA, threads)
        self.assertIn('1 threads acima de 5%', text)
        self.assertIn('| `kyty_emulator!Usleep` | 71 |', text)
        self.assertNotIn('Thread 11', text)


if __name__ == '__main__':
    unittest.main()
