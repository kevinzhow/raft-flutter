import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

import numpy as np

spec = importlib.util.spec_from_file_location('region_report', Path(__file__).with_name('analyze-regions.py'))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class RegionAdmissionTest(unittest.TestCase):
    def setUp(self):
        self.case = {'id': 'actual.case', 'theme': 'brutal',
                     'viewport': {'width': 4, 'height': 2, 'density': 1}}
        self.meta = {**self.case, 'caseId': self.case['id'], 'sourceCommit': report.SOURCE_COMMIT,
                     'fixtureSha256': 'same-fixture', 'route': '/s/demo/channel/one', 'regions': {}}
        self.measured = {**self.meta, 'schemaVersion': 1, 'coordinateSystem': 'Source CSS viewport',
                         'regions': {name: {'status': 'absent', 'rect': None} for name in report.NAMES}}
        self.measured['regions']['rail'] = {'status': 'eligible', 'rect': {'x': 0, 'y': 0, 'width': 2, 'height': 2}}
        self.web = np.full((2, 4, 4), 255, dtype=np.uint8)
        self.native = self.web.copy()

    def analyze(self, **changes):
        args = dict(case=self.case, web_meta=self.meta, native_meta=self.meta,
                    measured=self.measured, web=self.web, native=self.native)
        return report.analyze(**{**args, **changes})

    def test_provider_own_rectangles_cannot_move_the_shared_source_region(self):
        self.native[:, 2:, :3] = 0
        native_meta = {**self.meta, 'regions': {'rail': {'x': 2, 'y': 0, 'width': 2, 'height': 2}}}
        result = self.analyze(native_meta=native_meta)
        self.assertEqual(result['regions']['rail']['pixelRect'], {'x': 0, 'y': 0, 'width': 2, 'height': 2})
        self.assertEqual(result['regions']['rail']['metrics']['rawRgbaExactSimilarity'], 1)
        self.assertEqual(result['wholeFrameRawDiagnostic']['rawRgbaExactSimilarity'], .5)
        self.assertEqual(result['regionCoverage']['unassignedPixels'], 4)
        self.assertEqual(result['regionCoverage']['coveredPixels'], 4)
        self.assertEqual(result['regionCoverage']['overlapPixels'], 0)
        self.assertFalse(result['regions']['rail']['metrics']['formalAccepted'])

    def test_absent_hidden_ambiguous_regions_have_no_score_or_above96_credit(self):
        for name, status in [('sidebar', 'absent'), ('header', 'hidden'), ('rightPanel', 'ambiguous')]:
            self.measured['regions'][name]['status'] = status
        result = self.analyze()
        summary = report.summarize([result], 105)
        for name in ('sidebar', 'header', 'rightPanel'):
            self.assertNotIn('metrics', result['regions'][name])
            self.assertEqual(summary[name]['eligibleMeasured'], 0)
            self.assertEqual(summary[name]['above96Denominator'], 0)
            self.assertEqual(summary[name]['diagnosticAbove96Count'], 0)
            self.assertEqual(summary[name]['totalManifestCases'], 105)

    def test_original_size_mismatch_withholds_every_region_without_intersection(self):
        result = self.analyze(native=self.native[:, :3])
        self.assertTrue(result['admissionErrors'])
        self.assertNotIn('wholeFrameRawDiagnostic', result)
        self.assertTrue(all(r['status'] == 'blocked' for r in result['regions'].values()))

    def test_fixture_theme_and_density_mismatches_withhold_metrics(self):
        self.assertEqual(self.analyze()['admissionErrors'], [])
        for key, value in [('fixtureSha256', 'foreign-fixture'), ('theme', 'elegant-dark'),
                           ('viewport', {'width': 4, 'height': 2, 'density': 2})]:
            with self.subTest(key=key):
                result = self.analyze(native_meta={**self.meta, key: value})
                self.assertTrue(result['admissionErrors'])
                self.assertNotIn('metrics', result['regions']['rail'])

    def test_later_dom_geometry_must_match_existing_frozen_web_probe(self):
        web_meta = {**self.meta, 'regions': {'rail': {'x': 0, 'y': 0, 'width': 3, 'height': 2}}}
        result = self.analyze(web_meta=web_meta)
        self.assertIn('rail DOM differs from original Web capture geometry', result['admissionErrors'])
        self.assertNotIn('metrics', result['regions']['rail'])

    def test_out_of_bounds_region_is_not_clipped_or_counted_as_pass(self):
        measured = copy.deepcopy(self.measured)
        measured['regions']['rail']['rect']['width'] = 5
        result = self.analyze(measured=measured)
        self.assertEqual(result['regions']['rail']['status'], 'blocked')
        self.assertNotIn('metrics', result['regions']['rail'])
        self.assertEqual(report.summarize([result], 105)['rail']['eligibleMeasured'], 0)

    def test_last_pixel_and_alpha_are_included_without_normalization(self):
        self.native[-1, -1, 3] = 0
        result = self.analyze()
        self.assertEqual(result['wholeFrameRawDiagnostic']['rawRgbaExactSimilarity'], 7 / 8)
        self.assertEqual(result['wholeFrameRawDiagnostic']['delta24MismatchRatio'], 1 / 8)

    def test_adjacent_fractional_regions_partition_pixel_centers_once(self):
        left = report.pixel_box({'x': 0, 'y': 0, 'width': 1.5, 'height': 2}, 1, (4, 2))
        right = report.pixel_box({'x': 1.5, 'y': 0, 'width': 2.5, 'height': 2}, 1, (4, 2))
        self.assertEqual(left, [0, 0, 1, 2])
        self.assertEqual(right, [1, 0, 4, 2])
        self.assertEqual(left[2], right[0])

    def test_asset_copy_preserves_original_png_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / 'original.png'
            source.write_bytes(b'original exact provider bytes')
            original_sha = report.sha(source)
            copied = report.asset(source, root / 'diagnostic', 'frames/copied.png')
            self.assertEqual(copied['sha256'], original_sha)
            self.assertEqual(report.sha(source), original_sha)
            self.assertEqual((root / 'diagnostic/frames/copied.png').read_bytes(), source.read_bytes())

    def test_previous_source_bytes_must_match_before_attributing_regional_change(self):
        current, previous = self.analyze(), self.analyze()
        current['assets'] = {'web': {'sha256': 'frozen-original'}}
        previous['assets'] = {'web': {'sha256': 'changed-original'}}
        comparison = report.compare_runs(current, previous)
        self.assertFalse(comparison['admitted'])
        self.assertEqual(comparison['regions'], {})
        self.assertIn('previous/current original Source PNG bytes differ', comparison['admissionErrors'])

    def test_regional_and_unassigned_changes_use_original_whole_frame_denominator(self):
        previous = self.analyze()
        self.native[0, 0, 0] = 0  # One rail pixel regresses, retained.
        self.native[0, 3, 0] = 0  # One uncovered pixel regresses, retained.
        current = self.analyze()
        for row in (current, previous):
            row['assets'] = {'web': {'sha256': 'same-frozen-original'}}
        comparison = report.compare_runs(current, previous)
        self.assertTrue(comparison['admitted'])
        self.assertEqual(comparison['wholeFrameRawDeltaPercentagePoints'], -25)
        self.assertEqual(comparison['regions']['rail']['regionDeltaPercentagePoints'], -25)
        self.assertEqual(comparison['regions']['rail']['wholeFrameContributionPercentagePoints'], -12.5)
        self.assertEqual(comparison['unassignedWholeFrameContributionPercentagePoints'], -12.5)

    def test_full_change_summary_retains_tiny_regressions_and_all_case_denominators(self):
        rows = []
        for cid, old, now in [('large.improvement', .7, .8), ('tiny.regression', .9, .9 - 1e-9),
                              ('unchanged', .8, .8)]:
            rows.append({'id': cid, 'comparison': {'admitted': True, 'officialWholeFrame': {
                'previousSimilarity': old, 'currentSimilarity': now,
                'deltaPercentagePoints': (now - old) * 100}}})
        rows.append({'id': 'missing', 'comparison': {'admitted': False}})
        result = report.summarize_changes(rows)
        self.assertEqual(result['totalCases'], 4)
        self.assertEqual(result['admittedCases'], 3)
        self.assertEqual(result['officialBoundCases'], 3)
        self.assertEqual(result['officialImproved'], 1)
        self.assertEqual(result['officialRegressed'], 1)
        self.assertEqual(result['officialUnchanged'], 1)
        self.assertEqual(result['officialRegressions'][0]['id'], 'tiny.regression')
        self.assertFalse(result['formalAccepted'])

    def test_stale_official_sha_binding_cannot_be_reused_as_current_acceptance(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            web, native = root / 'web.png', root / 'native.png'
            web.write_bytes(b'current Source bytes')
            native.write_bytes(b'current Flutter bytes')
            result = report.bind_official({'status': 'pass', 'baselineSha256': report.sha(web),
                                          'currentSha256': 'stale-native'}, web, native)
            self.assertFalse(result['inputHashesMatch'])
            self.assertEqual(result['status'], 'stale-input-binding')


if __name__ == '__main__':
    unittest.main()
