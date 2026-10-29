"""Control-state cases: the state -> interaction mapping, ids, levels and the Flutter key list."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL / 'parity-ext'))
import levels  # noqa: E402

SPEC = importlib.util.spec_from_file_location('build_states_cases', TOOL / 'parity-ext/build-states-cases.py')
states = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(states)


class StateStepTests(unittest.TestCase):
    def test_pressed_hovers_then_holds_then_marks(self):
        web, flutter = states.steps('pressed', '#a', 'key-a', {})
        self.assertEqual([s['type'] for s in web], ['hover', 'hold', 'mark'])
        self.assertEqual([s['type'] for s in flutter], ['hold', 'mark'])
        self.assertEqual(flutter[0]['key'], 'key-a')

    def test_focus_uses_programmatic_focus_on_both_sides(self):
        web, flutter = states.steps('focus', '#a', 'key-a', {})
        self.assertEqual((web[0]['type'], flutter[0]['type']), ('focus', 'focus'))

    def test_default_only_marks(self):
        web, flutter = states.steps('default', '#a', 'key-a', {})
        self.assertEqual((len(web), len(flutter)), (1, 1))

    def test_a_row_revealed_control_hovers_the_row_first(self):
        extra = {'reveal': ('#row', 'row-key')}
        web, flutter = states.steps('hover', '#btn', {'key': 'btn', 'in': 'row-key'}, extra)
        self.assertEqual(web[0], {'type': 'hover', 'target': '#row'})
        self.assertEqual(flutter[0], {'type': 'hover', 'key': 'row-key'})
        self.assertEqual(flutter[1]['finder'], {'key': 'btn', 'in': 'row-key'})

    def test_unknown_state_is_rejected(self):
        with self.assertRaises(ValueError):
            states.steps('sparkly', '#a', 'k', {})


class StateCaseTests(unittest.TestCase):
    def test_ids_levels_and_surface_split(self):
        cases = states.build_cases()
        ids = {c['id'] for c in cases}
        self.assertEqual(len(ids), len(cases), 'ids are unique')
        self.assertIn('components.states.desktop.sidebar-row.hover.brutal', ids)
        self.assertEqual(levels.level_of('components.states.desktop.sidebar-row.hover.brutal'), levels.FRAME)
        self.assertEqual(levels.level_of('components.states.desktop.composer-submit.disabled.brutal'), levels.PAGE)
        for c in cases:
            self.assertEqual(c['capture']['androidKey'], 'states-crop')
            self.assertEqual(c['variants'][0]['props']['machineryRev'], states.MACHINERY_REV)

    def test_unmapped_controls_have_no_flutter_key(self):
        cases = {c['id']: c for c in states.build_cases()}
        self.assertFalse(cases['components.states.desktop.activity-row-done.hover.brutal']['flutterSurface'])
        self.assertTrue(cases['components.states.desktop.rail-tab.hover.brutal']['flutterSurface'])

    def test_topbar_states_reach_the_mounted_native_controls(self):
        cases = states.build_cases()
        keys = {'topbar-search': 'topbar-search', 'topbar-bell': 'topbar-notifications',
                'topbar-workspace': 'topbar-workspace'}
        selected = [case for case in cases if case['variants'][0]['props'].get('control') in keys]
        self.assertEqual(len(selected), 33)
        for case in selected:
            control = case['variants'][0]['props']['control']
            self.assertTrue(case['flutterSurface'], case['id'])
            self.assertEqual(case['capture']['androidInteractions'][-1]['key'], keys[control])
            web = case['capture']['interactions']
            reveal = next(i for i, step in enumerate(web) if step.get('target') == '[data-testid="desktop-workspace-strip"]')
            self.assertLess(reveal, len(web) - 1)

    def test_settings_clones_keep_the_base_family(self):
        base = {'id': 'components.ext-settings.appearance.page.brutal', 'title': 't',
                'capture': {'interactions': [], 'androidInteractions': []}, 'variants': [{'props': {}}]}
        clones, keys = states.settings_clones([base])
        self.assertTrue(clones)
        self.assertTrue(all(c['id'].startswith('components.ext-settings.appearance.states-') for c in clones))
        self.assertEqual(levels.level_of(clones[0]['id']), levels.PAGE)
        self.assertEqual(keys[0][1], 'components.ext-settings.appearance.page')


if __name__ == '__main__':
    unittest.main()
