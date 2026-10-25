"""Extreme-theme differ (tool/parity-ext/extreme_diff.py), pack generator (extreme_pack.py) and report helpers."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
sys.path.insert(0, str(TOOL / 'parity-ext'))
import extreme  # noqa: E402
import extreme_diff as ed  # noqa: E402
import extreme_pack  # noqa: E402

REPO = '/work/repo'
PRODUCT = f'file://{REPO}/packages/raft_ui/lib/src/panel.dart'
HARNESS = f'file://{REPO}/apps/raft_flutter/test/parity/parity_harness.dart'
WHITE, MAGENTA, GREEN = 0xFFFFFFFF, 0xFFFF00FF, 0xFF00FF00


def doc(ops, objects=None, nodes=None, density=1.0, target=None):
    return {
        'nodes': nodes or [[0, 'RaftPanel', PRODUCT, 10, None], [1, 'Container', PRODUCT, 40, 0],
                           [2, 'ColoredBox', HARNESS, 5, None]],
        'objects': objects or [{'id': 0, 'type': 'RenderDecoratedBox', 'path': 'A[0]', 'node': 1, 'rect': [0, 0, 60, 40]},
                               {'id': 1, 'type': '_RenderColoredBox', 'path': 'B[0]', 'node': 2, 'rect': [0, 0, 60, 40]}],
        'ops': ops, 'density': density, 'target': target}


def rect(ro, b, color, **extra):
    return {'k': 'rect', 'ro': ro, 'b': b, 'c': color, **extra}


def rrect(ro, b, color, radius, **extra):
    return {'k': 'rrect', 'ro': ro, 'b': b, 'c': color, 'r': [radius] * 8, **extra}


def png(path, size, fills):
    arr = np.full((size[1], size[0], 3), 255, dtype=np.uint8)
    for (x0, y0, x1, y1), rgb in fills:
        arr[y0:y1, x0:x1] = rgb
    Image.fromarray(arr).save(path)


class PixelTests(unittest.TestCase):
    def test_erode_drops_thin_lines_and_small_blobs(self):
        mask = np.zeros((40, 60), dtype=bool)
        mask[5:25, 5:30] = True   # a fill
        mask[30, 2:58] = True     # a hairline
        mask[34:36, 10:12] = True  # a glyph-sized speck
        core = ed.erode(mask, 3)
        self.assertTrue(core[10, 10])
        self.assertFalse(core[30].any())
        self.assertFalse(core[34:36].any())

    def test_regions_group_connected_pixels_above_the_threshold(self):
        mask = np.zeros((60, 100), dtype=bool)
        mask[5:30, 5:30] = True     # 625 px
        mask[5:30, 50:80] = True    # another one, not connected
        mask[40:44, 5:9] = True     # too small after erosion
        found = ed.regions(mask, 1.0)
        self.assertEqual(len(found), 2)
        self.assertGreater(found[0]['area'], 400)
        self.assertEqual(found[0]['samples'][0][0] in range(5, 30), True)

    def test_label_joins_a_u_shape(self):
        mask = np.zeros((10, 10), dtype=bool)
        mask[0:10, 0:2] = True
        mask[0:10, 8:10] = True
        mask[8:10, 0:10] = True
        labels, count = ed.label(mask)
        self.assertEqual(count, 1)
        self.assertEqual(len(np.unique(labels[mask])), 1)

    def test_density_scales_the_area_threshold(self):
        mask = np.zeros((90, 90), dtype=bool)
        mask[10:28, 10:28] = True  # 18 x 18 device px = 36 logical px^2 at 3x: below nothing, above 24
        self.assertEqual(len(ed.regions(mask, 3.0)), 1)
        mask2 = np.zeros((90, 90), dtype=bool)
        mask2[10:20, 10:20] = True  # 100 device px = 11 logical px^2 at 3x
        self.assertEqual(ed.regions(mask2, 3.0), [])


class AttributionTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.tmp = Path(self.dir.name)

    def analyse(self, normal_fills, extreme_fills, ops):
        png(self.tmp / 'n.png', (60, 40), normal_fills)
        png(self.tmp / 'e.png', (60, 40), extreme_fills)
        extreme_ops = ed.Ops(doc(ops), REPO)
        return ed.analyse_regions(self.tmp / 'n.png', self.tmp / 'e.png', extreme_ops, include_all=True)

    def test_unchanged_white_fill_is_attributed_to_the_widget_that_painted_it(self):
        ops = [rect(0, [0, 0, 60, 40], WHITE)]
        result = self.analyse([((0, 0, 60, 40), (255, 255, 255))], [((0, 0, 60, 40), (255, 255, 255))], ops)
        self.assertEqual(len(result['regions']), 1)
        region = result['regions'][0]
        self.assertEqual(region['site'], {'type': 'Container', 'file': 'packages/raft_ui/lib/src/panel.dart', 'line': 40})
        self.assertEqual(region['color'], '#ffffff')

    def test_a_themed_fill_changes_and_reports_nothing(self):
        ops = [rect(0, [0, 0, 60, 40], MAGENTA)]
        result = self.analyse([((0, 0, 60, 40), (255, 255, 255))], [((0, 0, 60, 40), (255, 0, 255))], ops)
        self.assertEqual(result['regions'], [])

    def test_harness_paint_is_counted_apart(self):
        ops = [rect(1, [0, 0, 60, 40], WHITE)]
        result = self.analyse([((0, 0, 60, 40), (255, 255, 255))], [((0, 0, 60, 40), (255, 255, 255))], ops)
        self.assertEqual(result['regions'], [])
        self.assertEqual(result['ignored']['harness'], 1)

    def test_the_topmost_op_with_the_pixels_colour_wins(self):
        ops = [rect(1, [0, 0, 60, 40], WHITE), rect(0, [0, 0, 60, 40], WHITE)]
        result = self.analyse([((0, 0, 60, 40), (255, 255, 255))], [((0, 0, 60, 40), (255, 255, 255))], ops)
        self.assertEqual(result['regions'][0]['painter'], 'RenderDecoratedBox')

    def test_image_and_text_regions_are_ignored(self):
        ops = [{'k': 'image', 'ro': 0, 'b': [0, 0, 60, 40], 'c': WHITE}]
        result = self.analyse([((0, 0, 60, 40), (9, 9, 9))], [((0, 0, 60, 40), (9, 9, 9))], ops)
        self.assertEqual(result['regions'], [])
        self.assertEqual(result['ignored']['image'], 1)

    def test_rounded_corner_is_not_covered(self):
        op = rrect(0, [0, 0, 40, 40], WHITE, 20)
        self.assertTrue(ed.covers(op, 20, 20))
        self.assertFalse(ed.covers(op, 1, 1))

    def test_overflow_indicator_ops_are_dropped(self):
        d = doc([rect(0, [0, 0, 5, 5], WHITE, rot=1)],
                objects=[{'id': 0, 'type': 'RenderFlex', 'path': 'A[0]', 'node': 1}])
        self.assertEqual(ed.Ops(d, REPO).ops, [])
        d = doc([rect(0, [0, 0, 5, 5], WHITE, rot=1)],
                objects=[{'id': 0, 'type': 'RenderDecoratedBox', 'path': 'A[0]', 'node': 1}])
        self.assertEqual(len(ed.Ops(d, REPO).ops), 1)

    def test_locations_are_made_repo_relative(self):
        ops = ed.Ops(doc([]), REPO)
        self.assertEqual(ops.rel(f'file://{REPO}/packages/raft_ui/lib/a.dart'), 'packages/raft_ui/lib/a.dart')
        self.assertEqual(ops.rel('file:///home/u/flutter-sdks/versions/3.47.6/packages/flutter/lib/src/widgets/framework.dart'),
                         'flutter:flutter/lib/src/widgets/framework.dart')


class FindingTests(unittest.TestCase):
    def pair(self, normal_ops, extreme_ops):
        return ed.Ops(doc(normal_ops), REPO), ed.Ops(doc(extreme_ops), REPO)

    def test_unchanged_radius_stroke_and_colour_are_reported(self):
        n = [rrect(0, [0, 0, 50, 30], WHITE, 6), {'k': 'path', 'ro': 0, 'b': [1, 1, 9, 9], 'c': GREEN, 'st': 1, 'sw': 2}]
        e = [rrect(0, [0, 0, 70, 50], WHITE, 6), {'k': 'path', 'ro': 0, 'b': [1, 1, 9, 9], 'c': MAGENTA, 'st': 1, 'sw': 2}]
        found = ed.paint_findings(*self.pair(n, e))
        kinds = {(f['attr'], f['value']) for f in found}
        self.assertIn(('radius', '6/6/6/6'), kinds)
        self.assertIn(('color', '#ffffff'), kinds)
        self.assertIn(('stroke', '2'), kinds)
        self.assertNotIn(('strokeColor', '#00ff00'), kinds)  # the colour moved

    def test_a_moved_radius_and_a_pill_are_not_reported(self):
        n = [rrect(0, [0, 0, 50, 30], MAGENTA, 6), rrect(0, [0, 0, 30, 30], GREEN, 15)]
        e = [rrect(0, [0, 0, 50, 30], GREEN, 15), rrect(0, [0, 0, 30, 30], MAGENTA, 15)]
        found = ed.paint_findings(*self.pair(n, e))
        self.assertEqual([f for f in found if f['attr'] == 'radius'], [])

    def test_unchanged_font_size_is_reported_but_the_mono_family_is_not(self):
        text = {'k': 'text', 'ro': 0, 'b': [0, 0, 20, 10]}
        objects = lambda fs, fam, col: [{'id': 0, 'type': 'RenderParagraph', 'path': 'A[0]', 'node': 1, 'txt': 'Hi',
                                          'fs': fs, 'fam': fam, 'col': col}]
        normal = ed.Ops(doc([text], objects(12, 'Space Mono', GREEN)), REPO)
        extreme = ed.Ops(doc([text], objects(12, 'Space Mono', MAGENTA)), REPO)
        attrs = {f['attr'] for f in ed.paint_findings(normal, extreme)}
        self.assertEqual(attrs, {'fontSize'})
        sans = lambda col: ed.Ops(doc([text], objects(12, 'packages/raft_ui/SpaceGrotesk', col)), REPO)
        self.assertIn('fontFamily', {f['attr'] for f in ed.paint_findings(sans(GREEN), sans(MAGENTA))})

    def test_findings_in_the_harness_are_dropped(self):
        n = [rect(1, [0, 0, 5, 5], WHITE)]
        self.assertEqual(ed.paint_findings(*self.pair(n, n)), [])


class ClassifyTests(unittest.TestCase):
    site = {'type': 'Container', 'file': 'packages/raft_ui/lib/src/panel.dart', 'line': 40}

    def finding(self, value='6/6/6/6'):
        chain = [{'type': 'Container', 'file': 'packages/raft_ui/lib/src/panel.dart', 'line': 40},
                 {'type': 'RaftPanel', 'file': 'packages/raft_ui/lib/src/panel.dart', 'line': 10}]
        return {'attr': 'radius', 'value': value, 'site': self.site, 'chain': chain}

    key = (('Container', 'packages/raft_ui/lib/src/panel.dart', 40), ('RaftPanel', 'packages/raft_ui/lib/src/panel.dart', 10))

    def test_a_value_that_differs_in_another_look_is_a_likely_defect(self):
        cls, ev = ed.classify(self.finding(), {'elegant': {(self.key, 'radius'): {'4/4/4/4'}}, 'brutal': {(self.key, 'radius'): {'6/6/6/6'}}})
        self.assertEqual(cls, 'a')
        self.assertEqual(ev['elegant'], ['4/4/4/4'])

    def test_the_same_value_everywhere_is_a_possible_shared_form(self):
        tables = {'elegant': {(self.key, 'radius'): {'6/6/6/6'}}, 'brutal': {(self.key, 'radius'): {'6/6/6/6', '2/2/2/2'}}}
        self.assertEqual(ed.classify(self.finding(), tables)[0], 'b')

    def test_no_evidence_is_unknown(self):
        self.assertEqual(ed.classify(self.finding(), {'elegant': {}, 'brutal': {}})[0], 'c')
        self.assertEqual(ed.classify(self.finding(), {})[0], 'c')

    def test_another_caller_of_a_shared_widget_is_not_a_look_difference(self):
        other_caller = (self.key[0], ('RaftPanel', 'packages/raft_ui/lib/src/other.dart', 7))
        tables = {'elegant': {(other_caller, 'radius'): {'4/4/4/4'}}}
        self.assertEqual(ed.classify(self.finding(), tables)[0], 'c')

    def test_look_values_index_by_creation_site(self):
        ops = ed.Ops(doc([rrect(0, [0, 0, 50, 30], WHITE, 6)]), REPO)
        table = ed.look_values(ops)
        self.assertEqual(table[(self.key, 'radius')], {'6/6/6/6'})
        self.assertEqual(table[(self.key, 'color')], {'#ffffff'})


class ReportTests(unittest.TestCase):
    def test_component_is_the_class_that_wrote_the_widget(self):
        classes = {'packages/raft_ui/lib/src/a.dart': [(10, 'RaftA'), (80, '_RaftAState'), (200, 'RaftB')]}
        site = {'type': 'Container', 'file': 'packages/raft_ui/lib/src/a.dart', 'line': 120}
        self.assertEqual(extreme.component_of(site, classes), ('_RaftAState', 'packages/raft_ui/lib/src/a.dart', 80))
        other = {'type': 'Text', 'file': 'apps/x.dart', 'line': 3}
        self.assertEqual(extreme.component_of(other, classes), ('Text', 'apps/x.dart', 3))

    def test_class_index_finds_the_real_overflow_button_owner(self):
        index = extreme.class_index()
        owners = [name for _, name in index.get('packages/raft_ui/lib/src/panel_layout.dart', [])]
        self.assertIn('RaftPanelIconButton', owners)


class PackTests(unittest.TestCase):
    def test_the_committed_pack_is_current(self):
        self.assertEqual(extreme_pack.OUT.read_text(), extreme_pack.render())

    def test_every_contract_name_is_overridden_in_both_modes(self):
        pack = extreme_pack.build()
        roles, tokens = extreme_pack.sections()
        raft = json.loads(extreme_pack.RAFT.read_text())
        self.assertGreater(len(roles), 300)
        self.assertGreater(len(tokens), 400)
        for mode in ('light', 'dark'):
            m = pack['modes'][mode]
            self.assertEqual(set(m['colors']), set(roles))
            self.assertEqual(set(m['geometry']), set(tokens))
            self.assertEqual(set(m['type']), set(raft['modes'][mode]['type']))
            self.assertEqual(set(m['shadows']), set(raft['modes'][mode]['shadows']))
            self.assertEqual(set(m['shadows'].values()), {'none'})
            for token, value in m['geometry'].items():
                if token.startswith('radius.'):
                    self.assertIn(value, (40, 31))
                if token.startswith('stroke.'):
                    self.assertIn(value, (0, 0.75))
            for role, value in m['colors'].items():
                self.assertNotEqual(value, raft['modes'][mode]['colors'][role], role)
        self.assertEqual(pack['extends'], 'raft')
        self.assertFalse(pack['builtIn'])

    def test_families_get_their_own_hues(self):
        pack = extreme_pack.build()['modes']['light']['colors']
        hue = lambda role: extreme_pack.hue_of(role)
        self.assertEqual(hue('layer-card'), extreme_pack.HUE['layer'])
        self.assertEqual(hue('foreground-muted'), extreme_pack.HUE['foreground'])
        self.assertEqual(hue('line-muted'), extreme_pack.HUE['line'])
        self.assertEqual(hue('brand-500'), extreme_pack.HUE['brand'])
        self.assertNotEqual(pack['layer-card'], pack['foreground'])

    def test_a_translucent_role_stays_translucent(self):
        self.assertEqual(extreme_pack.alpha_of('rgba(20 17 17 / 0.302)'), 0.302)
        self.assertEqual(len(extreme_pack.loud_color('foreground-disabled', 'rgba(20 17 17 / 0.302)', False)), 9)


if __name__ == '__main__':
    unittest.main()
