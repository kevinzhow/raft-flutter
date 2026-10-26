import importlib.machinery
import importlib.util
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
EXT = ROOT / 'tool/parity-ext'
sys.path.insert(0, str(EXT))
import builders  # noqa: E402
import react_cache  # noqa: E402
import sampling  # noqa: E402
_inv_loader = importlib.machinery.SourceFileLoader('parity_ext_inventory_test', str(EXT / 'inventory.py'))
inventory = importlib.util.module_from_spec(importlib.util.spec_from_loader(_inv_loader.name, _inv_loader))
_inv_loader.exec_module(inventory)

_loader = importlib.machinery.SourceFileLoader('parity_ext_analyze_diffs_test', str(EXT / 'analyze-diffs.py'))
analyze = importlib.util.module_from_spec(importlib.util.spec_from_loader(_loader.name, _loader))
sys.modules[_loader.name] = analyze
_loader.exec_module(analyze)


def write(path, text):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


class BuilderOrderTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.ext = pathlib.Path(self.tmp.name) / 'tool/parity-ext'
        self.ext.mkdir(parents=True)
        for name in ('build-b.py', 'build-a.py', 'build-z.py', 'build-new.py'):
            write(self.ext / name, 'print(1)\n')

    def tearDown(self):
        self.tmp.cleanup()

    def test_discovered_alphabetically_with_build_cases_first(self):
        write(self.ext / 'build-cases.py', 'print(1)\n')
        names = builders.ordered_builders(self.ext)
        self.assertEqual(names, ['build-cases.py', 'build-a.py', 'build-b.py', 'build-new.py', 'build-z.py'])

    def test_order_constant_sorts_before_filename(self):
        write(self.ext / 'build-z.py', '"""doc"""\nORDER = 10\nprint(1)\n')
        write(self.ext / 'build-b.py', 'ORDER = 20  # after z\n')
        write(self.ext / 'build-new.py', 'x = 1\n    ORDER = 5\n')  # indented: not a top-level constant
        self.assertEqual(builders.ordered_builders(self.ext), ['build-z.py', 'build-b.py', 'build-a.py', 'build-new.py'])

    def test_build_manifest_runs_in_order_and_writes_the_output_dir(self):
        write(self.ext / 'build-z.py', 'ORDER = 10\n')
        for name in ('build-a.py', 'build-b.py', 'build-z.py', 'build-new.py'):
            tag = name[6:-3]
            path = self.ext / name
            body = path.read_text() if name == 'build-z.py' else ''
            write(path, body + 'import json, os, pathlib\n'
                  "p = pathlib.Path(os.environ['PARITY_EXT_MANIFEST'])\n"
                  "m = json.loads(p.read_text()) if p.exists() else {'cases': []}\n"
                  f"m['cases'].append({{'id': 'components.{tag}.x'}})\n"
                  'p.write_text(json.dumps(m))\n')
        out = pathlib.Path(self.tmp.name) / 'out'
        target = builders.build_manifest(out, ext=self.ext)
        self.assertEqual(target, out / 'cases.json')
        self.assertEqual([c['id'].split('.')[1] for c in json.loads(target.read_text())['cases']],
                         ['z', 'a', 'b', 'new'])

    def test_failing_builder_stops_the_run(self):
        write(self.ext / 'build-a.py', 'raise SystemExit(3)\n')
        with self.assertRaises(SystemExit):
            builders.build_manifest(pathlib.Path(self.tmp.name) / 'out', ext=self.ext)

    def test_builders_need_the_manifest_env(self):
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop('PARITY_EXT_MANIFEST', None)
            with self.assertRaises(SystemExit):
                builders.manifest_path()

    def test_repo_builders_are_discovered_with_build_cases_first(self):
        names = builders.ordered_builders(EXT)
        self.assertEqual(names[0], 'build-cases.py')  # creates the manifest the others amend
        self.assertEqual(sorted(names), sorted(p.name for p in EXT.glob('build-*.py')))
        self.assertFalse((EXT / 'builders.txt').exists(), 'builders are discovered; there is no registry to edit')


CASE = {
    'id': 'components.demo.card.brutal', 'theme': 'brutal-light', 'viewport': {'width': 640, 'height': 600, 'density': 1},
    'variants': [{'id': 'default', 'props': {'extKind': 'demo', 'state': 'a'}}],
    'capture': {'selector': '#x', 'interactions': [{'type': 'hover', 'target': '#x'}],
                'androidKey': 'demo-card', 'androidInteractions': []},
    'androidCaseHint': 'hint', 'notes': 'n', 'tolerance': {'pixelRatio': 0.02}, 'reactPathHint': 'x.tsx',
}


class ReactCacheKeyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name) / 'wt'
        self.source = pathlib.Path(self.tmp.name) / 'raft-source'
        self.source.mkdir()
        self.reset()

    def tearDown(self):
        self.tmp.cleanup()

    def reset(self):
        ext = self.root / 'tool/parity-ext'
        write(ext / 'host/DemoCases.tsx', 'import f from "virtual:parity-ext/demo";\n'
              'function parityExtDemoElement() { return params.get("extKind") === "demo" ? helper() : null; }\n'
              'function demoOwn() {}\n')
        write(ext / 'host/OtherCases.tsx', 'import g from "virtual:parity-ext/other";\n'
              'function parityExtOtherElement() { return null; }\n')
        write(ext / 'fixtures/demo.json', json.dumps({'routes': {'GET /a': {'x': 1}}}))
        write(ext / 'fixtures/other.json', json.dumps({'routes': {'GET /b': {'y': 1}}}))
        write(self.root / 'tool/parity-ext-web.mjs', 'web v1')
        write(self.root / 'tool/parity', 'parity v1')
        write(self.root / 'tool/parity-fonts/manifest.json', '{}')

    def key(self, case=CASE, machinery='m1', root_name=None):
        ctx = react_cache.KeyContext(self.root, self.root / 'tool/parity-ext', self.source, machinery)
        return ctx.key(case)

    def variant(self, **changes):
        case = json.loads(json.dumps(CASE))
        for path, value in changes.items():
            node = case
            *head, last = path.split('/')
            for part in head:
                node = node[int(part)] if part.isdigit() else node[part]
            node[int(last) if last.isdigit() else last] = value
        return case

    def test_stable_and_sensitive_to_case_content(self):
        base = self.key()
        self.assertEqual(base, self.key())
        for change in ({'variants/0/props/state': 'b'}, {'viewport/width': 641}, {'theme': 'elegant-light'},
                       {'capture/interactions/0/type': 'press'}, {'capture/selector': '#y'}, {'id': 'components.demo.card.elegant'}):
            self.assertNotEqual(base, self.key(self.variant(**change)), change)

    def test_ignores_flutter_only_fields(self):
        base = self.key()
        for change in ({'capture/androidKey': 'other'}, {'capture/androidInteractions': [{'type': 'tap'}]},
                       {'androidCaseHint': 'z'}, {'notes': 'z'}, {'tolerance': {'pixelRatio': 0.5}}, {'reactPathHint': 'z'}):
            self.assertEqual(base, self.key(self.variant(**change)), change)

    def test_own_host_and_fixture_invalidate_others_do_not(self):
        base = self.key()
        ext = self.root / 'tool/parity-ext'
        write(ext / 'host/OtherCases.tsx', 'import g from "virtual:parity-ext/other";\nfunction parityExtOtherElement() { return 1; }\n')
        write(ext / 'fixtures/other.json', json.dumps({'routes': {'GET /b': {'y': 2}}}))  # same route keys, other body
        self.assertEqual(base, self.key())
        write(ext / 'fixtures/other.json', json.dumps({'routes': {'GET /b': {}, 'GET /new': {}}}))  # new route: may shadow
        self.assertNotEqual(base, self.key())
        self.reset()
        write(ext / 'fixtures/demo.json', json.dumps({'routes': {'GET /a': {'x': 2}}}))
        self.assertNotEqual(base, self.key())
        self.reset()
        write(ext / 'host/DemoCases.tsx', (ext / 'host/DemoCases.tsx').read_text() + '// edit\n')
        self.assertNotEqual(base, self.key())

    def test_host_using_another_hosts_declarations_depends_on_it(self):
        ext = self.root / 'tool/parity-ext'
        write(ext / 'host/OtherCases.tsx', 'function helper() {}\nfunction parityExtOtherElement() { return null; }\n')
        before = self.key()
        write(ext / 'host/OtherCases.tsx', 'function helper() { return 1; }\nfunction parityExtOtherElement() { return null; }\n')
        self.assertNotEqual(before, self.key())

    def test_machinery_and_tool_files_invalidate(self):
        base = self.key()
        self.assertNotEqual(base, self.key(machinery='m2'))
        write(self.root / 'tool/parity-ext-web.mjs', 'web v2')
        self.assertNotEqual(base, self.key())
        self.reset()
        write(self.root / 'tool/parity', 'parity v2')
        self.assertNotEqual(base, self.key())

    def test_key_is_independent_of_the_worktree_path(self):
        a = self.key(machinery=f'cmd node {self.root}/tool/parity-ext-web.mjs')
        moved = pathlib.Path(self.tmp.name) / 'wt2'
        self.root.rename(moved)
        self.root = moved
        self.assertEqual(a, self.key(machinery=f'cmd node {self.root}/tool/parity-ext-web.mjs'))


class ReactCacheStorageTest(unittest.TestCase):
    def test_store_restore_roundtrip_and_incomplete_entries_miss(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            results = tmp / 'results/react'
            write(results / 'c.metadata.json', '{"caseId":"c"}')
            (results / 'c.png').write_bytes(b'png-bytes')
            cache = react_cache.Cache(tmp / 'cache')
            self.assertFalse(cache.has('k'))
            self.assertTrue(cache.store('k', 'c', results, {'a': 1}))
            self.assertTrue(cache.has('k'))
            self.assertEqual(json.loads(cache.paths('k')[2].read_text())['inputs'], {'a': 1})
            other = tmp / 'wt2/react'
            cache.restore('k', 'c', other)
            self.assertEqual((other / 'c.png').read_bytes(), b'png-bytes')
            self.assertEqual(json.loads((other / 'c.metadata.json').read_text())['caseId'], 'c')
            self.assertEqual([p for p in cache.dir.iterdir() if p.name.endswith('.tmp')], [])
            cache.paths('k')[1].unlink()  # metadata lands last: png alone is not an entry
            self.assertFalse(cache.has('k'))

    def test_failed_capture_is_not_stored(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = react_cache.Cache(pathlib.Path(tmp) / 'cache')
            self.assertFalse(cache.store('k', 'missing', pathlib.Path(tmp) / 'empty', {}))
            self.assertFalse(cache.has('k'))


def save(path, array):
    Image.fromarray(array.astype(np.uint8)).save(path)


class NonTextScoreTest(unittest.TestCase):
    def scores(self, react, flutter):
        with tempfile.TemporaryDirectory() as tmp:
            rp, fp = pathlib.Path(tmp) / 'r.png', pathlib.Path(tmp) / 'f.png'
            save(rp, react)
            save(fp, flutter)
            return analyze.non_text_scores({'c': (rp, fp, 1)}, jobs=1)['c']

    def test_identical_images(self):
        img = np.full((40, 60, 3), 255)
        s = self.scores(img, img)
        self.assertEqual((s['similarity'], s['nonTextSimilarity'], s['textShare']), (100.0, 100.0, 0.0))

    def test_glyph_noise_is_excluded_but_a_wrong_fill_is_not(self):
        rng = np.random.default_rng(1)
        react = np.full((60, 80, 3), 255)
        react[10:30, 10:50] = rng.integers(0, 256, (20, 40, 1)).repeat(3, 2)  # dense "ink"
        flutter = react.copy()
        flutter[10:30, 10:50] = rng.integers(0, 256, (20, 40, 1)).repeat(3, 2)  # different AA, no shift explains it
        s = self.scores(react, flutter)
        self.assertLess(s['similarity'], 99)
        self.assertGreater(s['textShare'], 0.5)
        self.assertGreater(s['nonTextSimilarity'], s['similarity'] + 10)  # block rim stays in other buckets
        wrong = np.full((60, 80, 3), 255)
        wrong[10:40, 10:70] = (0, 0, 0)
        other = wrong.copy()
        other[10:40, 10:70] = (200, 30, 30)  # a flat region of the wrong colour: not text
        s = self.scores(wrong, other)
        self.assertEqual(s['textShare'], 0.0)
        self.assertLess(s['nonTextSimilarity'], 99.5)

    def test_memo_reuses_results(self):
        with tempfile.TemporaryDirectory() as tmp:
            rp = pathlib.Path(tmp) / 'r.png'
            save(rp, np.full((10, 10, 3), 255))
            memo = {}
            analyze.non_text_scores({'c': (rp, rp, 1)}, jobs=1, memo=memo)
            self.assertEqual(len(memo), 1)
            with mock.patch.object(analyze, 'classify', side_effect=AssertionError('classified again')):
                analyze.non_text_scores({'c': (rp, rp, 1)}, jobs=1, memo=memo)


if __name__ == '__main__':
    unittest.main()


class ThemeSamplingTest(unittest.TestCase):
    THEMES = (('brutal-light', 'brutal'), ('elegant-light', 'elegant'), ('elegant-dark', 'elegant-dark'))

    def manifest(self, surfaces):
        cases = []
        for surface, names in surfaces.items():
            for name in names:
                for theme, suffix in self.THEMES:
                    cases.append({'id': '.'.join(filter(None, [surface, name, suffix])), 'theme': theme})
        return {'cases': cases}

    def names(self, manifest, theme, surface):
        return [sampling.case_name(c) for c in manifest['cases']
                if c['theme'] == theme and sampling.surface_of(c['id']) == surface]

    SURFACES = {
        'components.a.list': ['default', 'empty', 'loading', 'many-rows', 'error'],
        'components.a.dialog': ['one', 'two', 'three'],
        'components.a.single': ['only'],
        'components.a.bare': [''],
    }

    def test_default_theme_is_complete_and_others_keep_first_plus_dense(self):
        full = self.manifest(self.SURFACES)
        out = sampling.sample_themes(full, {})
        for theme in ('elegant-light', 'elegant-dark'):
            self.assertEqual(self.names(out, theme, 'components.a.list'), ['default', 'many-rows'])
            self.assertEqual(self.names(out, theme, 'components.a.dialog'), ['one', 'three'])  # no keyword: last
            self.assertEqual(self.names(out, theme, 'components.a.single'), ['only'])
            self.assertEqual(self.names(out, theme, 'components.a.bare'), [''])
        self.assertEqual(self.names(out, 'brutal-light', 'components.a.list'), self.SURFACES['components.a.list'])
        self.assertEqual(sum(c['theme'] == 'brutal-light' for c in out['cases']), 10)
        self.assertEqual(len(out['cases']), 10 + 2 * 6)

    def test_deterministic_and_same_variants_in_both_themes(self):
        full = self.manifest(self.SURFACES)
        first = sampling.sample_themes(full, {})
        self.assertEqual(first, sampling.sample_themes(full, {}))
        for surface in self.SURFACES:
            self.assertEqual(self.names(first, 'elegant-light', surface), self.names(first, 'elegant-dark', surface))

    def test_all_themes_switch_keeps_everything(self):
        full = self.manifest(self.SURFACES)
        self.assertEqual(sampling.sample_themes(full, {'PARITY_EXT_ALL_THEMES': '1'}), full)

    def test_all_dark_switch_keeps_dark_complete_but_light_sampled(self):
        full = self.manifest(self.SURFACES)
        out = sampling.sample_themes(full, {'PARITY_EXT_ALL_DARK': '1'})
        self.assertEqual(self.names(out, 'elegant-dark', 'components.a.list'), self.SURFACES['components.a.list'])
        self.assertEqual(self.names(out, 'elegant-light', 'components.a.list'), ['default', 'many-rows'])

    def test_every_repo_surface_keeps_one_or_two_cases_per_sampled_theme(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            target = builders.build_manifest(pathlib.Path(tmp))
            full = json.loads(target.read_text())
        out = sampling.sample_themes(full, {})
        for theme in sampling.SAMPLED_THEMES:
            per = {}
            for c in out['cases']:
                if c['theme'] == theme:
                    per.setdefault(sampling.surface_of(c['id']), []).append(c['id'])
            wanted = {sampling.surface_of(c['id']) for c in full['cases'] if c['theme'] == theme}
            self.assertEqual(set(per), wanted)
            self.assertTrue(all(1 <= len(v) <= 2 for v in per.values()))
        self.assertEqual(sum(c['theme'] == 'brutal-light' for c in out['cases']),
                         sum(c['theme'] == 'brutal-light' for c in full['cases']))


class FrameFixtureContractTest(unittest.TestCase):
    def test_channel_tasks_use_the_canonical_empty_projection(self):
        with tempfile.TemporaryDirectory() as tmp:
            builders.build_manifest(pathlib.Path(tmp))
        frame = json.loads((EXT / 'fixtures/frame.json').read_text())
        screens = json.loads((EXT / 'fixtures/screens.json').read_text())
        channel = screens['scenes']['channel']['selected']
        self.assertEqual(frame['routeSets']['fr-channel'].get(f'GET /tasks/channel/{channel}'), {'tasks': []})


class ChannelSettingsFixtureContractTest(unittest.TestCase):
    def test_channel_task_responses_match_both_clients(self):
        with tempfile.TemporaryDirectory() as tmp:
            ext = pathlib.Path(tmp)
            (ext / 'fixtures').mkdir()
            for name in ('builders.py', 'build-channel-settings.py'):
                shutil.copyfile(EXT / name, ext / name)
            manifest = ext / 'manifest.json'
            manifest.write_text('{"cases": []}')
            subprocess.run(
                [sys.executable, str(ext / 'build-channel-settings.py')],
                env={**os.environ, 'PARITY_EXT_MANIFEST': str(manifest)},
                check=True, capture_output=True, text=True,
            )
            generated = json.loads((ext / 'fixtures/channelsettings.json').read_text())
        checked = json.loads((EXT / 'fixtures/channelsettings.json').read_text())
        for fixture in (generated, checked):
            routes = {key: value for key, value in fixture['routes'].items()
                      if key.startswith('GET /tasks/channel/')}
            self.assertTrue(routes)
            for key, value in routes.items():
                self.assertEqual(value, {'tasks': []}, key)


class FeedbackFixtureScopeTest(unittest.TestCase):
    def test_feedback_cases_bind_their_own_route_family(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest = json.loads(builders.build_manifest(pathlib.Path(tmp)).read_text())
        feedback = [case for case in manifest['cases']
                    if case['id'].startswith('components.ext-settings.feedback.')]
        self.assertTrue(feedback)
        for case in feedback:
            props = case['variants'][0]['props']
            self.assertEqual(props.get('extFixture'), 'settings', case['id'])


class DesktopDownloadFixtureContractTest(unittest.TestCase):
    def test_about_families_supply_a_platform_status_for_every_os(self):
        with tempfile.TemporaryDirectory() as tmp:
            builders.build_manifest(pathlib.Path(tmp))
        for family in ('settings', 'public-server'):
            with self.subTest(family=family):
                fixture = json.loads((EXT / f'fixtures/{family}.json').read_text())
                response = fixture['routes'].get('GET /desktop-download/platforms')
                self.assertIsInstance(response, dict)
                self.assertEqual(set(response), {'mac', 'linux', 'windows'})
                for platform in response.values():
                    self.assertIn(platform['status'], {'available', 'none', 'unknown'})
                    if platform['status'] == 'available':
                        self.assertIsInstance(platform['version'], str)


class PageInventoryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = inventory.default_context()  # manifest from the builders, official ids when the checkout exists

    def test_rows_and_id_globs_are_consistent(self):
        self.assertEqual(inventory.problems(self.ctx), [])

    def test_document_renders_without_a_committed_copy(self):
        self.assertFalse((ROOT / 'docs/parity-page-inventory.md').exists(),
                         'the inventory is generated on demand: python3 tool/parity-ext/inventory.py --write <path>')
        text = inventory.render(self.ctx)
        self.assertIn('## Prioritized missing pages', text)
        self.assertIn('## Cases no row claims', text)
        self.assertNotIn('wip', text.split('## Summary')[1].split('## Prioritized')[0])

    def test_status_is_computed_from_existing_case_ids(self):
        row = inventory.Row('9.99', 'demo', 'x.tsx', 'DP', off=['components.demo.official'],
                            d=['components.demo.desktop.*', '!*.skip'], p=['components.demo.mobile.a'])
        cases = [('components.demo.desktop.a', 1280), ('components.demo.desktop.skip', 1280), ('components.demo.mobile.a', 390)]
        st = lambda ctx, plat: row.state(plat, ctx)
        # official ids unknown (no checkout) count as existing
        self.assertEqual((st(inventory.Context(cases), 'D'), st(inventory.Context(cases), 'P')), ('ok', 'ok'))
        # nothing built yet: expected ids, no cases
        none = inventory.Context([], official=[])
        self.assertEqual((st(none, 'D'), st(none, 'P')), ('MISSING', 'MISSING'))
        # only part of the expected phone ids exist
        part = inventory.Context([('components.demo.mobile.a', 390)], official=[])
        self.assertEqual(st(part, 'P'), 'partial')
        # negations only remove matches
        only_skip = inventory.Context([('components.demo.desktop.skip', 1280)], official=[])
        self.assertEqual(st(only_skip, 'D'), 'MISSING')
        # noFlutterSurface-only coverage
        web = inventory.Context(cases, official=['components.demo.official'], web_only={'components.demo.desktop.a'})
        self.assertEqual(st(web, 'D'), 'web-only')
        self.assertEqual(st(web, 'P'), 'ok')
        # a case appearing flips the status without touching the row
        later = inventory.Context(cases + [('components.demo.mobile.b', 390)], official=['components.demo.official'])
        self.assertEqual(st(later, 'P'), 'ok')
        # mark: known fewer states than the page has
        marked = inventory.Row('9.98', 'demo', 'x.tsx', 'D', d=['components.demo.desktop.*'], d_state='partial')
        self.assertEqual(marked.state('D', inventory.Context(cases)), 'partial')
        self.assertEqual(marked.state('P', inventory.Context(cases)), 'n/a')
        self.assertEqual(inventory.Row('9.97', 'demo', 'x', 'D', d=['components.demo.*'],
                                       excl=('obsolete', 'reason')).state('D', inventory.Context(cases)), 'excluded')

    def test_problems_report_malformed_globs_and_wrong_platform_matches(self):
        bad = inventory.Row('9.96', 'demo', 'x', 'D', d=['nothing.demo', 'components.demo.*'], p=['components.demo.*'])
        ctx = inventory.Context([('components.demo.a', 390)])
        with mock.patch.object(inventory, 'all_rows', return_value=[bad]):
            out = inventory.problems(ctx)
        self.assertTrue(any('malformed or unknown extension id prefix: nothing.demo' in o for o in out), out)
        self.assertTrue(any('desktop glob components.demo.* matches a 390 wide' in o for o in out), out)
        self.assertTrue(any('extension ids given for P' in o for o in out), out)
        # an expected id with no case yet is fine
        ok = inventory.Row('9.95', 'demo', 'x', 'D', d=['components.not-built-yet.*'])
        with mock.patch.object(inventory, 'all_rows', return_value=[ok]):
            self.assertEqual(inventory.problems(inventory.Context([])), [])

    def test_row_numbers_are_unique_and_states_are_known(self):
        rows = inventory.all_rows()
        self.assertEqual(len({r.num for r in rows}), len(rows))
        for r in rows:
            self.assertIn(r.prio, (1, 2, 3))
            self.assertTrue(set(r.ap) <= set('DP') and r.ap, r.num)
            self.assertTrue({r.state('D'), r.state('P')} <= {'ok', 'partial', 'web-only', 'MISSING', 'n/a', 'excluded'})

    def test_missing_list_is_ordered_by_priority(self):
        prios = [r.prio for r in inventory.missing_rows()]
        self.assertEqual(prios, sorted(prios))
        self.assertTrue(all('MISSING' in (r.state('D'), r.state('P')) for r in inventory.missing_rows()))

    def test_excluded_rows_have_a_known_reason_and_stay_out_of_the_ranking(self):
        excluded = inventory.excluded_rows()
        self.assertTrue(excluded)
        for r in excluded:
            reason, evidence = r.excl
            self.assertIn(reason, inventory.REASONS, r.num)
            self.assertGreater(len(evidence), 20, f'{r.num}: cite evidence')
            self.assertEqual({r.state(p) for p in r.ap}, {'excluded'})
        ranked = {r.num for r in inventory.missing_rows()}
        self.assertFalse(ranked & {r.num for r in excluded})
        self.assertTrue(all(reason in inventory.REASONS for _, reason, _ in inventory.EXCLUDED))
        counts = inventory.counts()
        self.assertEqual(counts['rows'] + sum(counts['excluded'].values()), counts['all_rows'])
