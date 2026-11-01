"""Three-level visual suite: level assignment, frozen references, regression cells and the nightly summary."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
sys.path.insert(0, str(TOOL / 'parity-ext'))
import frozen_ref  # noqa: E402
import levels  # noqa: E402
import nightly_visual  # noqa: E402
import regress  # noqa: E402


class LevelTests(unittest.TestCase):
    def test_mounted_framework_is_in_the_frame_gate(self):
        for platform, region in [('desktop', 'navigation'), ('tablet', 'frame'), ('mobile', 'frame')]:
            case = f'components.framework.{platform}.{region}.default.raft-light'
            self.assertEqual(levels.level_of(case), levels.FRAME)
            self.assertTrue(levels.is_assigned(case))

    def test_frame_page_component_assignment(self):
        self.assertEqual(levels.level_of('components.navigation.tabbar.states'), levels.FRAME)
        self.assertEqual(levels.level_of('components.shell.desktop.sidebar.default.brutal'), levels.FRAME)
        self.assertEqual(levels.level_of('components.frame.desktop.topbar.elegant-dark'), levels.FRAME)
        self.assertEqual(levels.level_of('screens.members.agent-detail.profile'), levels.PAGE)
        self.assertEqual(levels.level_of('components.ext-settings.account.page.brutal'), levels.PAGE)
        self.assertEqual(levels.level_of('components.members-pages.desktop.window.agent.brutal'), levels.PAGE)
        self.assertEqual(levels.level_of('components.ui.button.states'), levels.COMPONENT)
        self.assertEqual(levels.level_of('components.shell.desktop.menu.channel.brutal'), levels.COMPONENT,
                         'the shell family menus and dialogs are components; only rail + sidebar states are frame')

    def test_new_families_are_assigned_by_their_area(self):
        self.assertEqual(levels.unassigned(['components.frame.desktop.rail.brutal', 'components.errors.toast.success.brutal']), [])
        self.assertEqual(levels.unassigned(['components.brand-new.thing.default.brutal']), [])  # not a known extension area

    def test_raft_frame_plan_keeps_explicit_raft_theme_cases(self):
        from argparse import Namespace
        from unittest.mock import patch
        cases = [
            {'id': 'components.framework.desktop.navigation.default.raft-light', 'theme': 'raft-light'},
            {'id': 'components.frame.desktop.rail.brutal-light', 'theme': 'brutal-light'},
        ]
        args = Namespace(level='frame', theme='raft', mode='light', fast=False,
                         out='unused', cases=None, no_ext=False, no_official=True)
        with patch.object(regress, 'manifests', return_value=(cases, cases)), \
             patch.object(regress, 'official_cases', return_value=[]):
            jobs = regress.plan(args)
        self.assertEqual(jobs[0]['ext'], [c['id'] for c in cases])
        args.theme = 'elegant'
        with patch.object(regress, 'manifests', return_value=(cases, cases)), \
             patch.object(regress, 'official_cases', return_value=[]):
            jobs = regress.plan(args)
        self.assertEqual(jobs[0]['ext'], [])

    def test_raft_plan_keeps_the_repaired_official_references(self):
        from argparse import Namespace
        from unittest.mock import patch
        ids = ['components.thread.header.states', 'components.thread.message-row.md-wrap-slice1']
        args = Namespace(level='all', theme='raft', mode='light', fast=False,
                         out='unused', cases=','.join(ids), no_ext=True, no_official=False)
        with patch.object(regress, 'manifests', return_value=([], [])), \
             patch.object(regress, 'official_cases', return_value=[{'id': cid} for cid in ids]):
            jobs = regress.plan(args)
        self.assertEqual(jobs[0]['official'], ids)

    def test_fast_pages_are_page_level_and_named(self):
        self.assertTrue(levels.is_fast_page('screens.auth.login'))
        self.assertFalse(levels.is_fast_page('components.ext-settings.billing.page.brutal'))


class FrozenReferenceTests(unittest.TestCase):
    def test_install_copies_found_and_reports_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            src, results = tmp / 'frozen', tmp / 'results'
            src.mkdir()
            (src / 'a.png').write_bytes(b'png')
            (src / 'a.metadata.json').write_text(json.dumps({'source': 'flutter', 'theme': 'brutal-light'}))
            stale = results / 'react'
            stale.mkdir(parents=True)
            (stale / 'b.png').write_bytes(b'old')  # a leftover must never survive for a case without a frozen image
            found, missing = frozen_ref.install(results, ['a', 'b'], [src])
            self.assertEqual((found, missing), (['a'], ['b']))
            self.assertTrue((results / 'react/a.png').is_file())
            self.assertFalse((results / 'react/b.png').exists())
            self.assertEqual(json.loads((results / 'react/a.metadata.json').read_text())['source'], 'frozen-a57b9dab')

    def test_registry_names_all_three_looks(self):
        self.assertEqual(set(frozen_ref.REGISTRY['official']), {'brutal-light', 'elegant-light', 'elegant-dark'})
        self.assertTrue(frozen_ref.REGISTRY['commit'].startswith('a57b9dab'))


class RegressTests(unittest.TestCase):
    def test_explicit_selection_requires_its_reference(self):
        from argparse import Namespace
        from unittest.mock import patch
        args = Namespace(out='unused', plan_only=False, summary_only=True, cases='example*')
        rows = [{'score': 0.99, 'verdict': 'passing'}, {'score': None, 'verdict': 'react-missing'}]
        with patch.object(regress, 'plan', return_value=[]), \
             patch.object(regress, 'manifests', return_value=([], [])), \
             patch.object(regress.pathlib.Path, 'mkdir'), \
             patch.object(regress, 'summarize', return_value=rows):
            with self.assertRaises(SystemExit) as error:
                regress.command(args)
        self.assertEqual(error.exception.code, 1)

    def test_full_run_reports_known_structural_gaps_without_failing(self):
        from argparse import Namespace
        from unittest.mock import patch
        args = Namespace(out='unused', plan_only=False, summary_only=True, cases=None)
        rows = [{'score': 0.99, 'verdict': 'passing'},
                *[{'score': None, 'verdict': v} for v in ['react-missing', 'not-covered', 'web-not-dark']]]
        with patch.object(regress, 'plan', return_value=[]), \
             patch.object(regress, 'manifests', return_value=([], [])), \
             patch.object(regress.pathlib.Path, 'mkdir'), \
             patch.object(regress, 'summarize', return_value=rows):
            regress.command(args)

    def test_empty_report_cannot_succeed(self):
        from argparse import Namespace
        from unittest.mock import patch
        args = Namespace(out='unused', plan_only=False, summary_only=True)
        with patch.object(regress, 'plan', return_value=[]), \
             patch.object(regress, 'manifests', return_value=([], [])), \
             patch.object(regress.pathlib.Path, 'mkdir'), \
             patch.object(regress, 'summarize', return_value=[]):
            with self.assertRaises(SystemExit) as error:
                regress.command(args)
        self.assertEqual(error.exception.code, 1)

    def test_explicit_selection_does_not_count_unselected_official_rows(self):
        from argparse import Namespace
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp) / 'raft-light/official'
            directory.mkdir(parents=True)
            directory.joinpath('summary.json').write_text(json.dumps({'cases': [
                {'id': 'components.thread.header.states', 'pixelPerfectSimilarity': 0.97, 'verdict': 'passing'},
                {'id': 'components.thread.message-row.md-wrap-slice1', 'pixelPerfectSimilarity': 0.8, 'verdict': 'failing'},
                {'id': 'components.ui.button.states', 'pixelPerfectSimilarity': None, 'verdict': 'flutter-capture-failed'},
            ]}))
            args = Namespace(out=temp, also=[], cases='components.thread.header.states',
                             level='all', theme='raft', mode='light', fast=False,
                             no_official=False, no_ext=True)
            with patch.object(regress, 'manifests', return_value=([], [])), \
                 patch.object(regress, 'official_cases', return_value=[{'id': args.cases}]):
                rows = regress.load_rows(args, [])
            self.assertEqual([row['id'] for row in rows], ['components.thread.header.states'])

    def test_cell_counts_pass_line_and_unscored(self):
        rows = [{'score': 0.99}, {'score': 0.5}, {'score': None}]
        self.assertEqual(regress.cell(rows), '1/3 (74.5%), 1 no capture/ref')
        self.assertEqual(regress.cell([]), '-')

    def test_regress_returns_failure_for_missing_reference_after_writing_summary(self):
        from argparse import Namespace
        from unittest.mock import patch
        args = Namespace(out='unused', plan_only=False, summary_only=True)
        with patch.object(regress, 'plan', return_value=[]), \
             patch.object(regress, 'manifests', return_value=([], [])), \
             patch.object(regress.pathlib.Path, 'mkdir'), \
             patch.object(regress, 'summarize', return_value=[{'score': None}]) as summary:
            with self.assertRaises(SystemExit) as error:
                regress.command(args)
        self.assertEqual(error.exception.code, 1)
        summary.assert_called_once()

    def test_regress_keeps_running_after_failed_job_and_reports_failure(self):
        from argparse import Namespace
        from unittest.mock import patch
        jobs = [dict(look='raft', mode=m, ext=['a'], official=[]) for m in ['light', 'dark']]
        args = Namespace(out='unused', plan_only=False, summary_only=False)
        with patch.object(regress, 'plan', return_value=jobs), \
             patch.object(regress, 'manifests', return_value=([], [])), \
             patch.object(regress.pathlib.Path, 'mkdir'), \
             patch.object(regress, 'run_job', side_effect=[1, 0]) as run_job, \
             patch.object(regress, 'summarize', return_value=[{'score': 0.99}]):
            with self.assertRaises(SystemExit) as error:
                regress.command(args)
        self.assertEqual(error.exception.code, 1)
        self.assertEqual(run_job.call_count, 2)

    def test_regress_retains_report_only_pixel_scores_when_captures_exist(self):
        from argparse import Namespace
        from unittest.mock import patch
        args = Namespace(out='unused', plan_only=False, summary_only=True)
        with patch.object(regress, 'plan', return_value=[]), \
             patch.object(regress, 'manifests', return_value=([], [])), \
             patch.object(regress.pathlib.Path, 'mkdir'), \
             patch.object(regress, 'summarize', return_value=[{'score': 0.50}]):
            regress.command(args)

    def test_each_look_reads_its_own_theme_names(self):
        self.assertEqual(regress.EXT_THEME['raft'], {'light': 'brutal-light', 'dark': 'elegant-dark'})
        self.assertNotIn('dark', regress.EXT_THEME['brutal'])


class RegressSelectionTests(unittest.TestCase):
    """Replay job summaries through the same selection used for execution."""

    def args(self, out, **changes):
        import argparse
        parser = argparse.ArgumentParser()
        regress.add_arguments(parser)
        args = parser.parse_args(['--out', str(out), '--summary-only'])
        for name, value in changes.items():
            setattr(args, name, value)
        return args

    def case(self, cid, theme='brutal-light', width=390):
        return {'id': cid, 'theme': theme, 'viewport': {'width': width}}

    def row(self, case, score=0.99, verdict='passing'):
        return {'id': case['id'], 'pixelPerfectSimilarity': score, 'verdict': verdict}

    def report(self, out, job, engine, rows):
        path = Path(out) / job / engine / 'summary.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({'cases': rows}))
        return path

    def sources(self, official, extension):
        from contextlib import ExitStack
        from unittest.mock import patch
        stack = ExitStack()
        stack.enter_context(patch.object(regress, 'official_cases', return_value=official))
        stack.enter_context(patch.object(regress, 'manifests', return_value=(extension, extension)))
        return stack

    def test_fast_summary_uses_all_394_selected_rows_and_keeps_225_coverage_gaps_separate(self):
        official = [self.case(f'screens.fast-{i}') for i in range(24)]
        components = [self.case(f'components.ui.control-{i}.states') for i in range(67)]
        tablets = [self.case(f'screens.tablet-{i}', width=816) for i in range(8)]
        official += components + tablets
        extension = [self.case(f'components.states.desktop.row-{i}.default.{look}', f'{look}-light')
                     for look in ['brutal', 'elegant'] for i in range(106)]
        framework = [self.case(f'components.framework.{platform}.{region}.default.raft-light',
                               'raft-light', width)
                     for platform, region, width in [('desktop', 'frame', 1280),
                                                     ('desktop', 'navigation', 1280),
                                                     ('mobile', 'frame', 390),
                                                     ('phone-short', 'frame', 390)]]
        extension += framework
        with tempfile.TemporaryDirectory() as temp, self.sources(official, extension):
            original = []
            for look in ['raft', 'elegant', 'brutal']:
                rows = [self.row(c) for c in official[:24]] + [
                    self.row(c, None, 'flutter-capture-failed') for c in official[24:]]
                original.append(self.report(temp, f'{look}-light', 'official', rows))
                theme = 'brutal-light' if look == 'raft' else f'{look}-light'
                selected = [c for c in extension if c['theme'] == theme or
                            look == 'raft' and c['theme'] == 'raft-light']
                ext_rows = [self.row(c) for c in selected]
                if look == 'raft':
                    ext_rows[-4:] = [self.row(c, score, verdict) for c, score, verdict in zip(
                        framework, [0.90, 0.68, 0.98, 0.99], ['failing', 'failing', 'passing', 'passing'])]
                original.append(self.report(temp, f'{look}-light', 'ext', ext_rows))
            before = {str(p): p.read_bytes() for p in original}
            rows = regress.summarize(self.args(temp, fast=True), extension)
            self.assertEqual(len(rows), 394)
            actual = {r['id']: (r['score'], r['verdict']) for r in rows if r['look'] == 'raft'}
            self.assertEqual({c['id']: actual[c['id']] for c in framework}, dict(zip(
                [c['id'] for c in framework], [(0.90, 'failing'), (0.68, 'failing'),
                                              (0.98, 'passing'), (0.99, 'passing')])))
            self.assertFalse(any(r['score'] is None for r in rows))
            summary = json.loads((Path(temp) / 'regress-summary.json').read_text())
            self.assertEqual(summary['selection'], {'planned': 394, 'reported': 394, 'outsidePlan': 225})
            self.assertEqual(sum(r['level'] == 'component' for r in summary['outsidePlan']), 201)
            self.assertEqual(sum(r['level'] == 'page' for r in summary['outsidePlan']), 24)
            self.assertEqual({str(p): p.read_bytes() for p in original}, before)

    def test_summary_respects_level_look_mode_case_and_engine_filters(self):
        button = self.case('components.ui.button.states')
        header = self.case('components.thread.header.states')
        official = [button, header]
        extension = [self.case(f'components.frame.desktop.rail.{look}', theme)
                     for look, theme in [('brutal', 'brutal-light'), ('elegant', 'elegant-light'),
                                         ('elegant-dark', 'elegant-dark')]]
        with tempfile.TemporaryDirectory() as temp, self.sources(official, extension):
            for job in ['raft-light', 'raft-dark', 'elegant-light', 'elegant-dark', 'brutal-light']:
                self.report(temp, job, 'official', [self.row(c) for c in official])
                self.report(temp, job, 'ext', [self.row(c) for c in extension])
            args = self.args(temp, level='component', theme='elegant', mode='dark',
                             cases='components.ui.*', no_ext=True)
            rows = regress.load_rows(args, extension)
            self.assertEqual([(r['look'], r['mode'], r['engine'], r['id']) for r in rows],
                             [('elegant', 'dark', 'official', button['id'])])
            args = self.args(temp, level='frame', theme='raft', mode='light', no_official=True)
            rows = regress.load_rows(args, extension)
            self.assertEqual([(r['look'], r['mode'], r['engine'], r['id']) for r in rows],
                             [('raft', 'light', 'ext', extension[0]['id'])])

    def test_selected_failed_capture_still_fails_after_unselected_rows_are_removed(self):
        button, header = self.case('components.ui.button.states'), self.case('components.thread.header.states')
        with tempfile.TemporaryDirectory() as temp, self.sources([button, header], []):
            self.report(temp, 'raft-light', 'official', [self.row(button, None, 'flutter-capture-failed'), self.row(header)])
            args = self.args(temp, theme='raft', mode='light', cases=button['id'], no_ext=True)
            with self.assertRaises(SystemExit) as error:
                regress.command(args)
            self.assertEqual(error.exception.code, 1)
            rows = json.loads((Path(temp) / 'regress-summary.json').read_text())['rows']
            self.assertEqual([(r['id'], r['score'], r['verdict']) for r in rows],
                             [(button['id'], None, 'flutter-capture-failed')])

    def test_selected_case_missing_from_job_summary_cannot_disappear(self):
        first, missing = self.case('screens.first'), self.case('screens.missing')
        with tempfile.TemporaryDirectory() as temp, self.sources([first, missing], []):
            self.report(temp, 'raft-light', 'official', [self.row(first)])
            with self.assertRaises(SystemExit) as error:
                regress.command(self.args(temp, theme='raft', mode='light', no_ext=True))
            self.assertEqual(error.exception.code, 1)
            rows = json.loads((Path(temp) / 'regress-summary.json').read_text())['rows']
            self.assertEqual(len(rows), 2)
            row = next(r for r in rows if r['id'] == missing['id'])
            self.assertIsNone(row['score'])
            self.assertEqual(row['verdict'], 'capture-not-reported')

    def test_also_keeps_the_latest_selected_result_without_expanding_the_plan(self):
        button, header = self.case('components.ui.button.states'), self.case('components.thread.header.states')
        with tempfile.TemporaryDirectory() as temp, self.sources([button, header], []):
            base, extra = Path(temp) / 'base', Path(temp) / 'extra'
            self.report(base, 'raft-light', 'official', [self.row(button, 0.5, 'failing'), self.row(header)])
            self.report(extra, 'raft-light', 'official', [self.row(button, 0.98), self.row(header)])
            rows = regress.load_rows(self.args(base, also=[str(extra)], theme='raft', mode='light',
                                              cases=button['id'], no_ext=True), [])
            self.assertEqual([(r['id'], r['score']) for r in rows], [(button['id'], 0.98)])


class NightlyVisualTests(unittest.TestCase):
    def rows(self, score):
        return {'rows': [{'id': 'components.frame.desktop.home.brutal', 'level': 'frame', 'look': 'raft', 'mode': 'light', 'score': score},
                         {'id': 'screens.auth.login', 'level': 'page', 'look': 'raft', 'mode': 'light', 'score': None}]}

    def test_summary_cells_drops_and_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / 's.json'
            f.write_text(json.dumps(self.rows(0.80)))
            out = nightly_visual.summarize(f, {'raft/light/components.frame.desktop.home.brutal': 0.90})
            self.assertEqual(out['cells']['frame|raft-light'], [0, 1, 0.8, 0])
            self.assertEqual(out['cells']['page|raft-light'][3], 1)
            self.assertEqual(out['dropCount'], 1)
            lines = []
            nightly_visual.render(out, lines.append)
            self.assertTrue(any('90.0% → 80.0%' in line for line in lines))

    def test_first_night_has_no_comparison(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / 's.json'
            f.write_text(json.dumps(self.rows(0.99)))
            out = nightly_visual.summarize(f, None)
            self.assertFalse(out['previousCompared'])
            lines = []
            nightly_visual.render(out, lines.append)
            self.assertTrue(any('基准' in line for line in lines))


if __name__ == '__main__':
    unittest.main()
