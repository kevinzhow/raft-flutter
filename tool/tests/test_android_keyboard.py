import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('android_keyboard', ROOT / 'tool/performance/android_keyboard.py')
keyboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(keyboard)


def log(animation_inset, build_us):
    """A logcat excerpt: one keyboard animation of len(animation_inset) frames, 16 ms apart."""
    lines = ['10-14 18:50:40.000  1  1 I flutter : KBJ m 100 0 h=2400 pad=63 vpad=63']
    t = 1_000_000
    for inset in animation_inset:
        lines.append(f'10-14 18:50:41.000  1  1 I flutter : KBJ m {t} {inset} h=2400 pad=0 vpad=63')
        lines.append(f'10-14 18:50:41.000  1  1 I flutter : KBJ f {t + 100} {build_us} 2000 {build_us + 2000}')
        t += 16_000
    return '\n'.join(lines)


class KeyboardProbeTest(unittest.TestCase):
    def test_frames_of_each_animation_are_summarised(self):
        result = keyboard.summarize(log([0, 100, 400, 700, 883], 1500))
        self.assertEqual(len(result['animations']), 1)
        self.assertEqual(result['animations'][0]['direction'], 'open')
        self.assertEqual(result['frames'], 5)
        self.assertAlmostEqual(result['buildMs']['p50'], 1.5)
        self.assertEqual(result['overBudget'], 0)

    def test_idle_frames_outside_an_animation_are_ignored(self):
        text = log([0, 0], 1500) + '\n10-14 18:50:50.000  1  1 I flutter : KBJ f 9000000 90000 2000 92000'
        self.assertEqual(keyboard.summarize(text)['frames'], 0)

    def test_slow_frames_count_against_the_budget(self):
        result = keyboard.summarize(log([100, 300, 600], 12000))
        self.assertEqual(result['overBudget'], 3)

    def test_compare_flags_a_regression_only(self):
        def write(root, p50, p90, p99):
            Path(root).mkdir(parents=True, exist_ok=True)
            (Path(root) / 'result.json').write_text(json.dumps({'buildMs': {'p50': p50, 'p90': p90, 'p99': p99}}))
        with tempfile.TemporaryDirectory() as tmp:
            write(f'{tmp}/base', 4.0, 5.0, 8.0)
            write(f'{tmp}/better', 1.4, 2.0, 4.5)
            write(f'{tmp}/worse', 6.0, 8.0, 12.0)
            self.assertEqual(keyboard.main(['compare', f'{tmp}/base', f'{tmp}/better']), 0)
            self.assertEqual(keyboard.main(['compare', f'{tmp}/base', f'{tmp}/worse']), 1)


if __name__ == '__main__':
    unittest.main()
