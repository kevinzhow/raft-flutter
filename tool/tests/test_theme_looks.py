"""tool/theme_looks.py (which looks the checks test, the guard) and tool/theme-suite (the on-demand legacy suite)."""
import importlib.machinery
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import theme_looks as tl  # noqa: E402

LOADER = importlib.machinery.SourceFileLoader('theme_suite', str(TOOL / 'theme-suite'))
SPEC = importlib.util.spec_from_loader('theme_suite', LOADER)
suite = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(suite)


class SelectionTests(unittest.TestCase):
    def test_the_default_is_the_raft_look(self):
        self.assertEqual(tl.selected_looks({}), ('raft',))
        self.assertEqual(tl.selected_looks({'RAFT_TEST_LOOKS': ''}), ('raft',))

    def test_lists_all_and_the_all_themes_switch(self):
        self.assertEqual(tl.selected_looks({'RAFT_TEST_LOOKS': 'brutal, elegant'}), ('elegant', 'brutal'))
        self.assertEqual(tl.selected_looks({'RAFT_TEST_LOOKS': 'all'}), tl.LOOKS)
        self.assertEqual(tl.selected_looks({'RAFT_TEST_ALL_THEMES': '1'}), tl.LOOKS)

    def test_an_unknown_look_is_an_error(self):
        with self.assertRaises(ValueError):
            tl.selected_looks({'RAFT_TEST_LOOKS': 'elegent'})

    def test_the_dart_helper_has_the_same_default_and_names(self):
        dart = (TOOL.parent / 'packages/raft_ui/lib/test_themes.dart').read_text()
        self.assertIn("const raftDefaultLooks = [raftLookRaft];", dart)
        self.assertIn("const raftLookRaft = 'raft';", dart)
        for look in tl.LEGACY_LOOKS:
            self.assertIn(f"const raftLook{look.capitalize()} = '{look}';", dart)
        self.assertEqual(re.search(r"const raftLooksVariable = '(\w+)'", dart).group(1), tl.LOOKS_VARIABLE)
        self.assertEqual(re.search(r"const raftModesVariable = '(\w+)'", dart).group(1), tl.MODES_VARIABLE)
        self.assertEqual(re.search(r"const raftAllThemesVariable = '(\w+)'", dart).group(1), tl.ALL_THEMES_VARIABLE)


class FileTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.base = Path(tmp.name)

    def write(self, name, text):
        (self.base / name).parent.mkdir(parents=True, exist_ok=True)
        (self.base / name).write_text(text)
        return self.base / name

    def test_tags_are_read_from_the_annotation(self):
        path = self.write('a_test.dart', "@Tags(['slow', \"look-brutal\"])\nlibrary;\nimport 'x.dart';\n")
        self.assertEqual(tl.file_tags(path), ('slow', 'look-brutal'))
        self.assertEqual(tl.file_looks(path), ('brutal',))
        self.assertFalse(tl.runs_by_default(path))
        self.assertTrue(tl.runs_by_default(path, ('raft', 'brutal')))

    def test_a_plain_file_and_a_slow_file_run_by_default(self):
        self.assertTrue(tl.runs_by_default(self.write('p_test.dart', "import 'x.dart';\n")))
        self.assertTrue(tl.runs_by_default(self.write('s_test.dart', "@Tags(['slow'])\nlibrary;\n")))

    def test_a_tag_mentioned_after_the_imports_is_not_an_annotation(self):
        path = self.write('c_test.dart', "import 'x.dart';\n// @Tags(['look-elegant'])\nvoid main() {}\n")
        self.assertEqual(tl.file_looks(path), ())

    def test_split_and_suite_selection(self):
        self.write('plain_test.dart', "void main() {}\n")
        self.write('elegant_test.dart', "@Tags(['look-elegant'])\nlibrary;\n")
        self.write('brutal_test.dart', "@Tags(['look-brutal'])\nlibrary;\n")
        self.write('mixed_elegant_test.dart', "void main() { raftThemeMatrix([elegantThemePackId], look: raftLookOf); }\n")
        self.write('mixed_brutal_test.dart', "void main() { testWidgets('x', f, skip: raftLookSkip(raftLookBrutal)); }\n")
        names = ['plain_test.dart', 'elegant_test.dart', 'brutal_test.dart', 'mixed_elegant_test.dart', 'mixed_brutal_test.dart']
        kept, skipped = tl.split_by_looks(names, tl.DEFAULT_LOOKS, self.base)
        self.assertEqual(kept, ['plain_test.dart', 'mixed_elegant_test.dart', 'mixed_brutal_test.dart'])
        self.assertEqual(skipped, ['elegant_test.dart', 'brutal_test.dart'])
        self.assertEqual(tl.suite_files(names, ('elegant',), self.base), ['elegant_test.dart', 'mixed_elegant_test.dart'])
        self.assertEqual(tl.suite_files(names, ('brutal',), self.base), ['brutal_test.dart', 'mixed_brutal_test.dart'])
        self.assertEqual(len(tl.suite_files(names, tl.LEGACY_LOOKS, self.base)), 4)

    def test_every_tagged_file_in_the_repo_names_known_looks(self):
        repo = TOOL.parent
        for name in tl.discover(['apps/raft_flutter/test', 'packages/raft_ui/test', 'packages/raft_theme/test'], repo):
            for tag in tl.file_tags(repo / name):
                if tag.startswith('look-'):
                    self.assertIn(tag[len('look-'):], tl.LEGACY_LOOKS, name)

    def test_the_tags_are_declared_for_the_runner(self):
        repo = TOOL.parent
        for config in ('apps/raft_flutter/dart_test.yaml', 'packages/raft_ui/dart_test.yaml'):
            text = (repo / config).read_text()
            for look in tl.LEGACY_LOOKS:
                self.assertIn(f'{tl.tag_look(look)}: {{}}', text, config)


class GuardTests(unittest.TestCase):
    def test_engine_paths_are_recognised(self):
        for path in ('packages/raft_theme/lib/src/theme_pack.dart', 'packages/raft_theme/assets/themes/elegant.theme.json',
                     'packages/raft_ui/lib/src/theme.dart', 'packages/raft_ui/lib/src/recipes/button_variants.g.dart',
                     'packages/raft_ui/lib/src/message_row_recipe.dart', 'packages/raft_ui/lib/src/tokens/colors.dart',
                     'tool/theme-adapters/build_family_packs.py', 'tool/recipes/gen_dart.mjs', 'packages/raft_ui/lib/test_themes.dart'):
            self.assertTrue(tl.matches_engine_path(path), path)

    def test_ordinary_paths_are_not(self):
        for path in ('apps/raft_flutter/lib/main.dart', 'packages/raft_ui/lib/src/raft/button.dart', 'docs/development.md',
                     'tool/check-project', 'packages/raft_client/lib/a.dart'):
            self.assertFalse(tl.matches_engine_path(path), path)

    def test_a_changed_legacy_look_test_file_counts(self):
        repo = TOOL.parent
        tagged = [n for n in tl.discover(['packages/raft_ui/test'], repo) if tl.file_looks(repo / n)]
        self.assertTrue(tagged)
        self.assertEqual(tl.touched([tagged[0], 'docs/x.md'], repo), [tagged[0]])

    def test_the_notice_is_loud_and_says_what_to_run(self):
        lines = tl.notice_lines(['packages/raft_theme/lib/a.dart'])
        self.assertIn('theme engine touched: run tool/theme-suite --look all before landing', '\n'.join(lines))
        self.assertEqual(tl.notice_lines([]), [])

    def test_a_long_list_is_cut(self):
        lines = tl.notice_lines([f'packages/raft_theme/{i}.dart' for i in range(20)])
        self.assertIn('  ... and 12 more', lines)

    def test_the_guard_does_not_fail_and_prints_nothing_for_an_untouched_diff(self):
        self.assertEqual(tl.guard(changed=['docs/development.md']), [])
        self.assertEqual(tl.guard(changed=[]), [])
        done = subprocess.run([sys.executable, str(TOOL / 'theme_looks.py'), 'guard', '--base', 'HEAD'], capture_output=True, text=True, cwd=TOOL.parent)
        self.assertEqual(done.returncode, 0)

    def test_preflight_and_check_project_call_the_guard(self):
        for name in ('check-project', 'preflight'):
            self.assertIn('theme_looks', (TOOL / name).read_text(), name)


class SuiteTests(unittest.TestCase):
    def test_looks(self):
        self.assertEqual(suite.looks_for('all'), ('elegant', 'brutal'))
        self.assertEqual(suite.looks_for('brutal'), ('brutal',))

    def test_the_dart_environment_selects_only_the_legacy_looks(self):
        env = suite.dart_env(('elegant',), 'light', {'RAFT_TEST_ALL_THEMES': '1', 'PATH': '/bin'})
        self.assertEqual((env['RAFT_TEST_LOOKS'], env['RAFT_TEST_MODES'], env['RAFT_TEST_TIER']), ('elegant', 'light', 'full'))
        self.assertNotIn('RAFT_TEST_ALL_THEMES', env)

    def test_the_selection_covers_tagged_and_per_look_files_but_not_the_engine_package(self):
        files = suite.select_files(('elegant', 'brutal'))
        self.assertTrue(files)
        self.assertFalse([f for f in files if f.startswith('packages/raft_theme/')])
        self.assertTrue(all(f.endswith('_test.dart') for f in files))

    def test_the_dart_command_runs_from_the_app_directory(self):
        command = suite.dart_command(['packages/raft_ui/test/a_test.dart'], Path('/x/e.json'), 3)
        self.assertEqual(command[-1], '../../packages/raft_ui/test/a_test.dart')
        self.assertIn('json:/x/e.json', command)

    def test_counts_and_verdict(self):
        events = [json.dumps(e) for e in (
            {'type': 'suite', 'suite': {'id': 1, 'path': '/r/a_test.dart'}, 'time': 0},
            {'type': 'testStart', 'test': {'id': 1, 'name': 'one', 'suiteID': 1}, 'time': 0},
            {'type': 'testDone', 'testID': 1, 'result': 'success', 'skipped': False, 'hidden': False, 'time': 5},
            {'type': 'testStart', 'test': {'id': 2, 'name': 'two', 'suiteID': 1}, 'time': 5},
            {'type': 'testDone', 'testID': 2, 'result': 'success', 'skipped': True, 'hidden': False, 'time': 6},
        )]
        counts = suite.summarize_events(events)
        self.assertEqual((counts['passed'], counts['skipped'], counts['failed']), (1, 1, []))
        self.assertEqual(suite.tests_verdict(0, counts), (True, ''))
        self.assertFalse(suite.tests_verdict(1, counts)[0])
        self.assertFalse(suite.tests_verdict(0, counts, timed_out=True)[0])
        empty = suite.summarize_events([])
        self.assertIn('no test ran', suite.tests_verdict(0, empty)[1])

    def test_visual_verdict_judges_only_against_a_baseline(self):
        rows = [{'look': 'elegant', 'mode': 'light', 'id': 'a', 'score': 0.90}, {'look': 'elegant', 'mode': 'light', 'id': 'b', 'score': None}]
        ok, detail, drops = suite.visual_verdict(rows)
        self.assertTrue(ok)
        self.assertIn('not judged', detail)
        before = [{'look': 'elegant', 'mode': 'light', 'id': 'a', 'score': 0.99}]
        ok, detail, drops = suite.visual_verdict(rows, before)
        self.assertFalse(ok)
        self.assertEqual(drops, ['elegant/light/a: 0.990 -> 0.900'])
        self.assertFalse(suite.visual_verdict([])[0])

    def test_the_visual_command_names_the_look_and_mode(self):
        command = suite.visual_command('brutal', 'light', '/o', 'a.*')
        self.assertIn('regress', command)
        self.assertIn('--theme', command)
        self.assertEqual(command[command.index('--theme') + 1], 'brutal')
        self.assertEqual(command[command.index('--cases') + 1], 'a.*')

    def test_web_source_needs_the_shared_cases(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(suite.web_source({'PARITY_RAFT_SOURCE': tmp}))
            (Path(tmp) / 'packages/visual-testing/shared').mkdir(parents=True)
            (Path(tmp) / 'packages/visual-testing/shared/sharedCases.json').write_text('{}')
            self.assertEqual(suite.web_source({'PARITY_RAFT_SOURCE': tmp}), Path(tmp))

    def test_the_summary_names_failed_steps(self):
        lines = suite.format_summary([{'name': 'dart-tests', 'status': 'PASS', 'detail': 'x'}, {'name': 'visual-brutal', 'status': 'FAIL', 'detail': 'y'}], ('brutal',), 'all')
        self.assertEqual(lines[-1], 'theme-suite: FAILED (visual-brutal)')

    def test_the_plan_exits_zero_and_the_engine_target_takes_no_look(self):
        done = subprocess.run([sys.executable, str(TOOL / 'theme-suite'), '--look', 'brutal', '--plan'], capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn('theme-suite plan: looks brutal', done.stdout)
        done = subprocess.run([sys.executable, str(TOOL / 'theme-suite'), 'engine', '--plan'], capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn('engine only', done.stdout)
        done = subprocess.run([sys.executable, str(TOOL / 'theme-suite'), 'engine', '--look', 'all'], capture_output=True, text=True)
        self.assertNotEqual(done.returncode, 0)
        done = subprocess.run([sys.executable, str(TOOL / 'theme-suite')], capture_output=True, text=True)
        self.assertNotEqual(done.returncode, 0)


if __name__ == '__main__':
    unittest.main()
