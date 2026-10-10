import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('lab', ROOT / 'tool/performance/lab.py')
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


def frames(ui_ms, raster_ms=2.0, period=16667, start=1_000_000):
    return [{'v': start + i * period, 'b': start + i * period + 100, 'ui': int(u * 1000), 'uit': int(u * 1000),
             'rs': start + i * period + 100 + int(u * 1000), 'r': int(raster_ms * 1000), 'total': 0,
             'ph': {'layout': int(u * 600), 'semantics': int(u * 200)}} for i, u in enumerate(ui_ms)]


def record(scenario='steady-scroll', ui=(2, 3, 4), **extra):
    return {'theme': 'brutal-light', 'scenario': scenario, 'kind': 'continuous', 'displayRefreshRate': 60.0,
            'viewWidth': 1000, 'viewHeight': 700, 'frames': frames(ui), **extra}


class SummaryTest(unittest.TestCase):
    def test_budgets_and_gate(self):
        row = lab.summarize_record(record(ui=[2, 9, 20]))
        self.assertEqual(row['over8Ui'], 2)
        self.assertEqual(row['over16Ui'], 1)
        self.assertFalse(row['gate60'])
        self.assertEqual(row['semanticsShare'], round(100 * (400 + 1800 + 4000) / 31000, 1))
        self.assertTrue(lab.summarize_record(record(ui=[2, 9, 12]))['gate60'])

    def test_stutter_counts_skipped_vsyncs_only_for_continuous(self):
        r = record(ui=[2, 2, 2])
        r['frames'][2]['v'] += 20000  # one doubled frame interval
        self.assertEqual(lab.summarize_record(r)['stutters'], 1)
        r['kind'] = 'transitions'
        self.assertEqual(lab.summarize_record(r)['stutters'], 0)

    def test_mount_steps_cost_per_row(self):
        r = record('mount-plain', ui=[10, 1, 20, 2], kind='mount', rowKind='plain')
        f = r['frames']
        r['steps'] = [{'t0': f[0]['b'] - 10, 't1': f[2]['b'] - 10, 'newRows': 5},
                      {'t0': f[2]['b'] - 10, 't1': f[3]['b'] + 10, 'newRows': 4}]
        m = lab.summarize_record(r)['mount']
        self.assertEqual(m['rowsMounted'], 9)
        self.assertEqual(sorted([2000, 5000]), [lab.pct([2000, 5000], .5), m['perRowUs']['max']])

    def test_compare_flags_regressions(self):
        base = {'hello': {'fixtureVersion': 'v1'}, 'env': {}, 'scenarios': [lab.summarize_record(record(ui=[2] * 50))]}
        worse = {'hello': {'fixtureVersion': 'v1'}, 'env': {}, 'scenarios': [lab.summarize_record(record(ui=[2] * 49 + [20]))]}
        result = lab.compare(base, worse)
        self.assertGreater(result['regressions'], 0)
        self.assertIn('60 Hz gate pass→FAIL', result['rows'][0]['regressions'])
        self.assertEqual(lab.compare(base, base)['regressions'], 0)
        other = dict(worse, hello={'fixtureVersion': 'v2'})
        self.assertIn('fixture versions differ; numbers are not comparable', lab.compare(base, other)['problems'])

    def test_summarize_run_directory(self):
        with tempfile.TemporaryDirectory() as d:
            run = Path(d)
            (run / 'brutal-light-steady-scroll.json').write_text(json.dumps(record()))
            (run / 'brutal-light-steady-scroll.attribution.json').write_text(json.dumps({
                'gcCount': 3, 'cpuWorstUiFrames': {'samples': 10, 'categories': {'fontFallback': 8},
                                                   'appInclusive': [{'name': 'A.build', 'value': 5}], 'self': [], 'inclusive': []},
                'rasterWorstFrames': {'inclusiveUs': [{'name': 'ReactorGLES::React', 'value': 1500}]}}))
            summary = lab.summarize(run)
            self.assertEqual(summary['env']['renderer'], 'Impeller (OpenGLES)')
            self.assertTrue(summary['gate60Passed'])
            text = (run / 'summary.md').read_text()
            self.assertIn('fontFallback 80.0%', text)
            self.assertIn('| steady-scroll | brutal-light | 3 |', text)


if __name__ == '__main__':
    unittest.main()
