"""tool/test_impact.py: the coverage map and the selection of the test files a diff touches."""
import datetime
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import test_impact as ti  # noqa: E402

CALC = '''// Calculator.
const kStep = 2;

int add(int a, int b) {
  return a + b;
}

int twice(int a) {
  return a * kStep;
}
'''
LOADER = '''String fixturePath() {
  return 'assets/data.json';
}
'''
FILES = {
    'apps/raft_flutter/pubspec.yaml': 'name: raft_flutter\n',
    'packages/raft_ui/pubspec.yaml': 'name: raft_ui\n',
    'apps/raft_flutter/lib/calc.dart': CALC,
    'apps/raft_flutter/lib/loader.dart': LOADER,
    'apps/raft_flutter/assets/data.json': '{}\n',
    'apps/raft_flutter/test/add_test.dart': "import 'package:raft_flutter/calc.dart';\n",
    'apps/raft_flutter/test/twice_test.dart': "import 'package:raft_flutter/calc.dart';\n",
    'apps/raft_flutter/test/loader_test.dart': "import 'package:raft_flutter/loader.dart';\n",
    'apps/raft_flutter/test/support/helper.dart': 'int helper() {\n  return 1;\n}\n',
    'apps/raft_flutter/test/helper_user_test.dart': "import 'support/helper.dart';\n",
    # Never reported by the probe: the import graph decides for it.
    'apps/raft_flutter/test/unmapped_test.dart': "import 'package:raft_flutter/loader.dart';\n",
}


def reports(root):
    """What the probe would have written for FILES at the map commit."""
    app = f'{root}/apps/raft_flutter'
    return [
        {'test': f'{app}/test/add_test.dart', 'hits': {'package:raft_flutter/calc.dart': [4, 5]}, 'misses': {}},
        {'test': f'{app}/test/twice_test.dart', 'hits': {'package:raft_flutter/calc.dart': [8, 9]},
         'misses': {'package:raft_flutter/calc.dart': [4]}},
        {'test': f'{app}/test/loader_test.dart', 'hits': {'package:raft_flutter/loader.dart': [1, 2]}, 'misses': {},
         'paths': [f'{app}/build/unit_test_assets/assets/data.json', '/tmp/elsewhere']},
        {'test': f'{app}/test/helper_user_test.dart', 'hits': {f'file://{app}/test/support/helper.dart': [1, 2]}, 'misses': {}},
    ]


class Repo:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.git('init', '-q', '-b', 'main')
        for path, text in FILES.items():
            self.write(path, text)
        self.commit('base')

    def git(self, *args):
        env = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t', GIT_COMMITTER_EMAIL='t@t')
        return subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True, text=True, env=env).stdout.strip()

    def write(self, path, text):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)

    def commit(self, message):
        self.git('add', '-A')
        self.git('commit', '-q', '-m', message)
        return self.git('rev-parse', 'HEAD')

    def map(self, commit, built=None):
        roots = {'raft_flutter': 'apps/raft_flutter', 'raft_ui': 'packages/raft_ui'}
        data = ti.assemble(reports(self.root), self.root, roots, commit, 'apps/raft_flutter',
                           meta={'built': built or datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')})
        return ti.ImpactMap(data)

    def select(self, base='main', maps=None, **kwargs):
        if maps is None:
            maps = [self.map(self.git('rev-parse', base))]
        selector = ti.Selector(self.root, maps, base, **kwargs)
        return selector.run()

    def branch(self, name='work'):
        self.git('checkout', '-q', '-b', name)


def chosen(selection):
    return {t.rsplit('/', 1)[-1] for t in selection.tests}


class AssembleTests(unittest.TestCase):
    def test_sets_are_shared_and_paths_are_repo_relative(self):
        repo = Repo()
        self.addCleanup(repo.tmp.cleanup)
        imap = repo.map('c0')
        self.assertEqual(imap.tests[0], 'apps/raft_flutter/test/add_test.dart')
        self.assertEqual(imap.tests_at('apps/raft_flutter/lib/calc.dart', 5), {'apps/raft_flutter/test/add_test.dart'})
        # lines 4 and 5 were run by the same test: one stored set
        self.assertEqual(imap.data['lines']['apps/raft_flutter/lib/calc.dart'][0][1], imap.data['lines']['apps/raft_flutter/lib/calc.dart'][1][1])
        # misses count as executable lines; ranges are compact
        self.assertEqual(imap.data['coverable']['apps/raft_flutter/lib/calc.dart'], [[4, 5], [8, 9]])
        self.assertTrue(imap.is_coverable('apps/raft_flutter/lib/calc.dart', 4))
        self.assertFalse(imap.is_coverable('apps/raft_flutter/lib/calc.dart', 2))
        self.assertEqual(imap.neighbours('apps/raft_flutter/lib/calc.dart', 6), (5, 8))
        self.assertIn('apps/raft_flutter/test/support/helper.dart', imap.coverable)

    def test_opened_assets_map_back_to_their_sources(self):
        roots = {'raft_flutter': 'apps/raft_flutter', 'raft_ui': 'packages/raft_ui'}
        self.assertEqual(ti.opened_path('/r/apps/raft_flutter/build/unit_test_assets/assets/a.json', '/r', roots), 'apps/raft_flutter/assets/a.json')
        self.assertEqual(ti.opened_path('/r/apps/raft_flutter/build/unit_test_assets/packages/raft_ui/fonts/f.ttf', '/r', roots),
                         'packages/raft_ui/fonts/f.ttf')
        self.assertIsNone(ti.opened_path('/r/apps/raft_flutter/.dart_tool/x', '/r', roots))
        self.assertIsNone(ti.opened_path('/elsewhere/x', '/r', roots))
        self.assertEqual(ti.opened_path('/r/apps/raft_flutter/test/../lib/a.dart', '/r', roots), 'apps/raft_flutter/lib/a.dart')

    def test_a_failed_probe_is_an_error_not_a_test(self):
        data = ti.assemble([{'test': '/r/a_test.dart', 'error': 'boom'}], '/r', {}, 'c', 'apps/x')
        self.assertEqual(data['tests'], [])
        self.assertEqual(data['errors'], {'a_test.dart': 'boom'})


class DiffTests(unittest.TestCase):
    def test_parse_diff_statuses_and_hunks(self):
        text = '''diff --git a/a.dart b/a.dart
index 1..2 100644
--- a/a.dart
+++ b/a.dart
@@ -3,2 +3 @@ x
-old one
-old two
+new
@@ -9,0 +10,2 @@
+added
+added
diff --git a/n.dart b/n.dart
new file mode 100644
--- /dev/null
+++ b/n.dart
@@ -0,0 +1 @@
+x
diff --git a/o.dart b/p.dart
similarity index 90%
rename from o.dart
rename to p.dart
diff --git a/g.png b/g.png
deleted file mode 100644
Binary files a/g.png and /dev/null differ
'''
        files = ti.parse_diff(text)
        self.assertEqual([(f.status, f.path) for f in files], [('M', 'a.dart'), ('A', 'n.dart'), ('R', 'p.dart'), ('D', 'g.png')])
        self.assertEqual(files[0].hunks[0][:4], [3, 2, 3, 1])
        self.assertEqual(files[0].hunks[0][4:], [['old one', 'old two'], ['new']])
        self.assertEqual(files[0].hunks[1][:4], [9, 0, 10, 2])
        self.assertEqual(files[2].old, 'o.dart')
        self.assertTrue(files[3].binary)

    def test_translator_shifts_and_widens(self):
        diff = ti.FileDiff('a.dart', 'a.dart', 'M')
        diff.hunks = [[2, 0, 3, 3, [], ['x', 'y', 'z']], [10, 2, 13, 1, ['a', 'b'], ['c']]]
        t = ti.LineTranslator([diff, ti.FileDiff(None, 'new.dart', 'A')])
        self.assertEqual(t.lines('a.dart', 1), [1])
        self.assertEqual(t.lines('a.dart', 4), [2, 3])  # inserted line: both sides of the insertion point
        self.assertEqual(t.lines('a.dart', 8), [5])
        self.assertEqual(t.lines('a.dart', 13), [10, 11])  # inside a changed hunk: the whole hunk
        self.assertEqual(t.lines('a.dart', 20), [18])  # 3 lines inserted above, 1 removed
        self.assertEqual(t.lines('other.dart', 7), [7])
        self.assertEqual(t.lines('new.dart', 1), [])
        self.assertIsNone(t.path('new.dart'))

    def test_code_lines_skip_comments_and_directives(self):
        lines = ["import 'a.dart'", '    show A, B;', '// note', '', '  return 1;', "export 'b.dart';", '  /* x */']
        self.assertEqual(ti.code_lines(lines), [(4, '  return 1;')])

    def test_declared_names(self):
        self.assertEqual(ti.declared_names('const kGap = 4;'), ['kGap'])
        self.assertEqual(ti.declared_names('  final String? title;'), ['title'])
        self.assertEqual(ti.declared_names('  const RaftKbd(this.keys, {super.key});'), ['RaftKbd'])
        self.assertEqual(ti.declared_names('const Map<String, String> zhCatalogX = <String, String>{'), ['zhCatalogX'])
        self.assertEqual(ti.declared_names('    final local = 1;'), [])
        self.assertEqual(ti.declared_names('  @override'), [])

    def test_function_declarations(self):
        def fn(*lines):
            return ti.is_function_declaration(list(lines), 1)
        self.assertTrue(fn('int add(int a, int b) {'))
        self.assertTrue(fn('  Widget build(', '    BuildContext context,', '  ) {'))
        self.assertTrue(fn('  int get count => _count;'))
        self.assertTrue(fn('  int get count {'))
        self.assertTrue(fn('  Future<void> load() async {'))
        self.assertTrue(fn('  Foo(this.x) : y = x * 2 {'))
        self.assertTrue(fn('  Foo(this.x) : y = x;'))
        self.assertFalse(fn('  const Foo(this.x) : assert(x > 0);'))
        self.assertFalse(fn('  const RaftKbd(this.keys, {super.key});'))
        self.assertFalse(fn('class Foo extends Bar {'))
        self.assertFalse(fn('const Map<String, String> zh = <String, String>{'))
        self.assertFalse(fn('enum Mode { a, b }'))
        self.assertFalse(fn('  final String title;'))
        self.assertFalse(fn("  static const label = 'a { b';"))

    def test_enclosing_declaration(self):
        lines = ['const zhCatalog = <String, String>{', "  'a': 'b',", "  'c':", "      'd',", '};']
        self.assertEqual(ti.Selector.enclosing_declaration(lines, 4), (1, ['zhCatalog']))
        self.assertEqual(ti.Selector.enclosing_declaration(CALC.splitlines(), 2), (2, ['kStep']))
        ctor = ['class Services {', '  Services(', '    this.a, {', '    this.b,', '  }) : c = a {', '    run();', '  }']
        self.assertEqual(ti.Selector.enclosing_declaration(ctor, 6), (2, ['Services']))
        self.assertTrue(ti.is_function_declaration(ctor, 2))


class SelectTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()
        self.addCleanup(self.repo.tmp.cleanup)

    def test_a_changed_executable_line_selects_the_tests_that_ran_it(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/calc.dart', CALC.replace('return a + b;', 'return b + a;'))
        self.repo.commit('change add')
        selection = self.repo.select()
        self.assertEqual(chosen(selection), {'add_test.dart'})
        self.assertIn('changes apps/raft_flutter/lib/calc.dart:5', selection.tests['apps/raft_flutter/test/add_test.dart'])

    def test_a_comment_only_change_selects_nothing(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/calc.dart', CALC.replace('// Calculator.', '// A calculator.\n// Two lines.'))
        self.repo.commit('comment')
        self.assertEqual(chosen(self.repo.select()), set())

    def test_a_constant_selects_the_tests_that_run_its_uses(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/calc.dart', CALC.replace('kStep = 2', 'kStep = 3'))
        self.repo.commit('step')
        selection = self.repo.select()
        self.assertEqual(chosen(selection), {'twice_test.dart'})

    def test_a_new_case_selects_every_test_that_ran_the_function(self):
        kinds = ("String kind(int a) {\n  switch (a) {\n    case 1:\n      return 'one';\n"
                 "    case 2:\n      return 'two';\n    default:\n      return 'many';\n  }\n}\n")
        self.repo.write('apps/raft_flutter/lib/kinds.dart', kinds)
        base = self.repo.commit('kinds')
        app = f'{self.repo.root}/apps/raft_flutter'
        extra = [  # one test runs case 1, another only the default branch
            {'test': f'{app}/test/one_test.dart', 'hits': {'package:raft_flutter/kinds.dart': [1, 2, 4]}, 'misses': {}},
            {'test': f'{app}/test/many_test.dart', 'hits': {'package:raft_flutter/kinds.dart': [1, 2, 8]},
             'misses': {'package:raft_flutter/kinds.dart': [6]}},
        ]
        roots = {'raft_flutter': 'apps/raft_flutter'}
        imap = ti.ImpactMap(ti.assemble(reports(self.repo.root) + extra, self.repo.root, roots, base, 'apps/raft_flutter',
                                        meta={'built': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}))
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/kinds.dart', kinds.replace("      return 'two';\n", "      return 'two';\n    case 3:\n      return 'three';\n"))
        self.repo.commit('case 3')
        # the next lines (default) and the previous (case 2) alone would miss one_test
        self.assertEqual(chosen(self.repo.select(maps=[imap])), {'one_test.dart', 'many_test.dart'})

    def test_a_function_no_test_runs_selects_nothing(self):
        self.repo.write('apps/raft_flutter/lib/calc.dart', CALC + '\nint unused(int a) {\n  return a;\n}\n')
        self.repo.commit('unused function')
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/calc.dart', CALC + '\nint unused(int a) {\n  return -a;\n}\n')
        self.repo.commit('change it')
        selection = self.repo.select()
        self.assertEqual(chosen(selection), set())
        self.assertEqual(selection.unexecuted, {'apps/raft_flutter/lib/calc.dart:12'})

    def test_an_insertion_selects_the_tests_around_it(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/calc.dart', CALC.replace('  return a + b;\n', '  return a + b;\n  // unreachable\n  print(a);\n'))
        self.repo.commit('insert')
        self.assertIn('add_test.dart', chosen(self.repo.select()))

    def test_changed_tests_and_test_helpers(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/test/add_test.dart', FILES['apps/raft_flutter/test/add_test.dart'] + 'void main() {}\n')
        self.repo.write('apps/raft_flutter/test/support/helper.dart', 'int helper() {\n  return 2;\n}\n')
        self.repo.commit('tests')
        self.assertEqual(chosen(self.repo.select()), {'add_test.dart', 'helper_user_test.dart'})

    def test_a_new_file_selects_its_test_importers_not_the_import_closure(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/fresh.dart', 'int fresh() {\n  return 1;\n}\n')
        self.repo.write('apps/raft_flutter/lib/calc.dart', "import 'fresh.dart';\n" + CALC)
        self.repo.write('apps/raft_flutter/test/fresh_test.dart', "import 'package:raft_flutter/fresh.dart';\n")
        self.repo.commit('new file')
        selection = self.repo.select()
        self.assertEqual(chosen(selection), {'fresh_test.dart'})
        self.assertTrue(any('fresh.dart: new file' in note for note in selection.notes))
        wide = self.repo.select(absent='import-graph')
        self.assertTrue({'fresh_test.dart', 'add_test.dart', 'twice_test.dart'} <= chosen(wide))

    def test_a_fixture_selects_tests_that_open_or_mention_it(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/assets/data.json', '{"a": 1}\n')
        self.repo.commit('fixture')
        selection = self.repo.select()
        self.assertEqual(chosen(selection), {'loader_test.dart'})
        reasons = ' '.join(selection.tests['apps/raft_flutter/test/loader_test.dart'])
        self.assertIn('recorded file access', reasons)
        self.assertIn('loader.dart:2', reasons)

    def test_unmapped_tests_fall_back_to_imports(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/loader.dart', LOADER.replace('data.json', 'other.json'))
        self.repo.commit('loader')
        self.assertEqual(chosen(self.repo.select()), {'loader_test.dart', 'unmapped_test.dart'})

    def test_a_build_input_selects_everything(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/pubspec.yaml', 'name: raft_flutter_renamed\n')
        self.repo.commit('pubspec')
        selection = self.repo.select()
        self.assertIn('pubspec.yaml', selection.select_all)
        rendered = ti.render(selection, self.repo.root, [], 'x' * 40, 'files')
        self.assertEqual(len(rendered.split()), 5)

    def test_a_new_package_alone_selects_nothing(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/pubspec.yaml', 'name: raft_flutter\ndependencies:\n  tuple: 2.0.2\n')
        self.repo.commit('add a package')
        selection = self.repo.select()
        self.assertIsNone(selection.select_all)
        self.assertEqual(chosen(selection), set())

    def test_lines_move_between_the_map_commit_and_the_merge_base(self):
        old = self.repo.git('rev-parse', 'HEAD')
        self.repo.write('apps/raft_flutter/lib/calc.dart', '// one\n// two\n// three\n' + CALC)
        self.repo.commit('integration moved on')
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/calc.dart', ('// one\n// two\n// three\n' + CALC).replace('a * kStep', 'kStep * a'))
        self.repo.commit('change twice')
        selection = self.repo.select(maps=[self.repo.map(old)])
        self.assertEqual(chosen(selection), {'twice_test.dart'})
        self.assertEqual(selection.warnings, [])

    def test_stale_maps_warn(self):
        self.repo.git('checkout', '-q', '-b', 'side')
        self.repo.write('apps/raft_flutter/lib/side.dart', 'int side() => 1;\n')
        side = self.repo.commit('side')
        self.repo.git('checkout', '-q', 'main')
        self.repo.branch()
        selection = self.repo.select(maps=[self.repo.map(side, built='2000-01-01T00:00:00Z')])
        text = ' '.join(selection.warnings)
        self.assertIn('not an ancestor', text)
        self.assertIn('built', text)
        self.assertIsNone(self.repo.select(maps=[self.repo.map(self.repo.git('rev-parse', 'main'))]).select_all)
        self.assertIn('no impact map', self.repo.select(maps=[]).select_all)

    def test_worktree_mode_sees_uncommitted_and_untracked_files(self):
        self.repo.branch()
        self.repo.write('apps/raft_flutter/lib/calc.dart', CALC.replace('return a + b;', 'return b + a;'))
        self.repo.write('apps/raft_flutter/test/brand_new_test.dart', '')
        self.assertEqual(chosen(self.repo.select(worktree=True)), {'add_test.dart', 'brand_new_test.dart'})


class MapFileTests(unittest.TestCase):
    def test_write_and_load_round_trip(self):
        repo = Repo()
        self.addCleanup(repo.tmp.cleanup)
        imap = repo.map('c0')
        with tempfile.TemporaryDirectory() as cache:
            ti.write_map(imap.data, ti.map_path('apps/raft_flutter', cache))
            loaded = ti.load_maps(cache)
        self.assertEqual(len(loaded), 1)
        self.assertEqual(loaded[0].tests_at('apps/raft_flutter/lib/calc.dart', 9), {'apps/raft_flutter/test/twice_test.dart'})

    def test_temporary_config_is_created_and_removed(self):
        with tempfile.TemporaryDirectory() as root:
            package = Path(root) / 'packages/p'
            (package / 'test').mkdir(parents=True)
            config = ti.ensure_probe_config(package, root)
            self.assertIn("import '../../../tool/testing/impact_probe.dart';", config.read_text())
            ti.remove_temp_config(config)
            self.assertFalse(config.exists())
            config.write_text('void testExecutable() {}\n')
            with self.assertRaises(RuntimeError):
                ti.ensure_probe_config(package, root)
            ti.remove_temp_config(config)
            self.assertTrue(config.exists())  # not ours: kept


if __name__ == '__main__':
    unittest.main()
