"""tool/diff_coverage.py: lcov parsing/merging, diff parsing and the changed-but-unexecuted report."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import diff_coverage as dc  # noqa: E402

LCOV = """TN:
SF:lib/a.dart
DA:1,1
DA:2,0
DA:3,4
end_of_record
SF:../../packages/raft_ui/lib/src/b.dart
DA:10,0
end_of_record
SF:lib/a.dart
DA:2,2
DA:5,0
end_of_record
"""

DIFF = """diff --git a/apps/raft_flutter/lib/a.dart b/apps/raft_flutter/lib/a.dart
--- a/apps/raft_flutter/lib/a.dart
+++ b/apps/raft_flutter/lib/a.dart
@@ -1,0 +2,2 @@
+x
+y
@@ -9 +11 @@
-old
+new
diff --git a/gone.dart b/gone.dart
--- a/gone.dart
+++ /dev/null
@@ -1,3 +0,0 @@
-a
-b
-c
diff --git a/packages/raft_ui/lib/src/b.dart b/packages/raft_ui/lib/src/b.dart
--- a/packages/raft_ui/lib/src/b.dart
+++ b/packages/raft_ui/lib/src/b.dart
@@ -10,0 +10,1 @@
+z
diff --git a/apps/raft_flutter/lib/untested.dart b/apps/raft_flutter/lib/untested.dart
new file mode 100644
--- /dev/null
+++ b/apps/raft_flutter/lib/untested.dart
@@ -0,0 +1,2 @@
+q
+r
"""


class LcovTests(unittest.TestCase):
    def test_repeated_records_add_hits(self):
        cov = dc.parse_lcov(LCOV)
        self.assertEqual(cov['lib/a.dart'], {1: 1, 2: 2, 3: 4, 5: 0})

    def test_paths_are_made_repo_relative_for_the_run_dir(self):
        self.assertEqual(dc.normalize_path('lib/a.dart', 'apps/raft_flutter'), 'apps/raft_flutter/lib/a.dart')
        self.assertEqual(dc.normalize_path('../../packages/raft_ui/lib/x.dart', 'apps/raft_flutter'), 'packages/raft_ui/lib/x.dart')
        self.assertEqual(dc.normalize_path('lib/x.dart', '.'), 'lib/x.dart')

    def test_absolute_paths_under_the_root_are_stripped(self):
        self.assertEqual(dc.strip_root('/r/repo/packages/p/lib/x.dart', '/r/repo'), 'packages/p/lib/x.dart')
        self.assertEqual(dc.strip_root('/elsewhere/x.dart', '/r/repo'), '/elsewhere/x.dart')

    def test_merge_adds_across_runs(self):
        merged = dc.merge_coverage([{'f': {1: 0, 2: 1}}, {'f': {1: 3}, 'g': {4: 0}}])
        self.assertEqual(merged, {'f': {1: 3, 2: 1}, 'g': {4: 0}})

    def test_load_coverage_combines_run_dirs(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / 'app.lcov'
            app.write_text('SF:lib/a.dart\nDA:1,1\nend_of_record\nSF:../../packages/raft_ui/lib/b.dart\nDA:2,0\nend_of_record\n')
            ui = Path(tmp) / 'ui.lcov'
            ui.write_text(f'SF:{tmp}/packages/raft_ui/lib/b.dart\nDA:2,5\nend_of_record\n')
            cov = dc.load_coverage([f'{app}:apps/raft_flutter', f'{ui}:packages/raft_ui'], tmp)
        self.assertEqual(cov, {'apps/raft_flutter/lib/a.dart': {1: 1}, 'packages/raft_ui/lib/b.dart': {2: 5}})


class DiffTests(unittest.TestCase):
    def test_added_modified_lines_deleted_files_ignored(self):
        changed = dc.parse_diff(DIFF)
        self.assertEqual(changed['apps/raft_flutter/lib/a.dart'], [2, 3, 11])
        self.assertEqual(changed['packages/raft_ui/lib/src/b.dart'], [10])
        self.assertEqual(changed['apps/raft_flutter/lib/untested.dart'], [1, 2])
        self.assertNotIn('gone.dart', changed)

    def test_pure_deletion_hunk_adds_no_lines(self):
        diff = '+++ b/x.dart\n@@ -4,2 +3,0 @@\n-a\n-b\n'
        self.assertEqual(dc.parse_diff(diff), {})

    def test_line_ranges(self):
        self.assertEqual(dc.line_ranges([3, 4, 5, 9, 11, 12]), '3-5, 9, 11-12')
        self.assertEqual(dc.line_ranges([]), '')


class DiffCoverageTests(unittest.TestCase):
    def test_only_instrumented_lines_count_and_unloaded_files_are_flagged(self):
        coverage = {
            'apps/raft_flutter/lib/a.dart': {1: 1, 2: 0, 3: 4, 11: 0},
            'packages/raft_ui/lib/src/b.dart': {10: 0},
        }
        result = dc.diff_coverage(dc.parse_diff(DIFF), coverage)
        by_file = {f['file']: f for f in result['files']}
        a = by_file['apps/raft_flutter/lib/a.dart']
        self.assertEqual((a['executable'], a['uncovered']), (3, [2, 11]))  # lines 2, 3, 11 are executable
        self.assertEqual(by_file['packages/raft_ui/lib/src/b.dart']['uncovered'], [10])
        self.assertFalse(by_file['apps/raft_flutter/lib/untested.dart']['loaded'])
        self.assertEqual((result['executable'], result['covered']), (4, 1))

    def test_a_change_with_no_executable_lines_is_fully_covered(self):
        result = dc.diff_coverage({'f.dart': [1, 2]}, {'f.dart': {50: 0}})
        self.assertEqual((result['executable'], dc.percent(result['covered'], result['executable'])), (0, 100.0))

    def test_report_text(self):
        result = dc.diff_coverage({'a.dart': [1, 2, 3], 'n.dart': [1]}, {'a.dart': {1: 1, 2: 0, 3: 0}})
        text = dc.format_report(result)
        self.assertIn('1/3  a.dart  unexecuted: 2-3', text)
        self.assertIn('not loaded by any test  n.dart', text)
        self.assertTrue(text.endswith('DIFF COVERAGE 1/3 = 33.3%'))


class GitTests(unittest.TestCase):
    def test_three_dot_diff_against_a_real_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            def git(*args):
                return subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@t', *args], cwd=tmp, check=True, text=True,
                                      capture_output=True).stdout
            git('init', '-q', '-b', 'main')
            (Path(tmp) / 'a.dart').write_text('one\ntwo\n')
            git('add', '.')
            git('commit', '-qm', 'base')
            git('checkout', '-qb', 'topic')
            (Path(tmp) / 'a.dart').write_text('one\nTWO\nthree\n')
            git('commit', '-qam', 'change')
            changed = dc.parse_diff(dc.git_diff(tmp, 'main', 'topic'))
            self.assertEqual(changed, {'a.dart': [2, 3]})


if __name__ == '__main__':
    unittest.main()
