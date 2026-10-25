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
