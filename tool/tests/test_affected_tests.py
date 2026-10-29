"""tool/affected_tests.py: the static import closure that picks the tests worth running for a change."""
from pathlib import Path
import sys
import unittest

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
import affected_tests as at  # noqa: E402

ROOTS = {'raft_flutter': 'apps/raft_flutter', 'raft_ui': 'packages/raft_ui'}

SOURCES = {
    'apps/raft_flutter/lib/leaf.dart': "import 'dart:async';\nimport 'package:flutter/material.dart';\n",
    'apps/raft_flutter/lib/mid.dart': "import 'leaf.dart';\nexport 'package:raft_ui/raft_ui.dart';\n",
    'packages/raft_ui/lib/raft_ui.dart': "export 'src/widget.dart';\n",
    'packages/raft_ui/lib/src/widget.dart': "part 'widget_part.dart';\n",
    'packages/raft_ui/lib/src/widget_part.dart': "part of 'widget.dart';\n",
    'apps/raft_flutter/test/mid_test.dart': "import 'package:raft_flutter/mid.dart';\n",
    'apps/raft_flutter/test/leaf_only_test.dart': "import 'package:raft_flutter/leaf.dart';\nimport 'helper.dart';\n",
    'apps/raft_flutter/test/helper.dart': '',
    'apps/raft_flutter/test/helped_test.dart': "import 'helper.dart';\n",
    'apps/raft_flutter/test/unrelated_test.dart': "import 'package:flutter_test/flutter_test.dart';\n",
    'packages/raft_ui/test/widget_test.dart': "import 'package:raft_ui/raft_ui.dart';\n",
}


class DirectiveTests(unittest.TestCase):
    def test_conditional_imports_name_every_branch_and_part_of_is_skipped(self):
        source = "import 'a.dart' if (dart.library.io) 'a_io.dart' if (dart.library.html) \"a_web.dart\";\npart of 'lib.dart';\npart 'p.dart';\n"
        self.assertEqual(at.directive_targets(source), ['a.dart', 'a_io.dart', 'a_web.dart', 'p.dart'])

    def test_resolve(self):
        self.assertIsNone(at.resolve('dart:io', 'x.dart', ROOTS))
        self.assertIsNone(at.resolve('package:flutter/material.dart', 'x.dart', ROOTS))
        self.assertEqual(at.resolve('package:raft_ui/src/a.dart', 'x.dart', ROOTS), 'packages/raft_ui/lib/src/a.dart')
        self.assertEqual(at.resolve('../b.dart', 'apps/raft_flutter/lib/f/a.dart', ROOTS), 'apps/raft_flutter/lib/b.dart')


class ClosureTests(unittest.TestCase):
    def select(self, *changed):
        return at.affected_tests(set(changed), SOURCES, ROOTS)

    def test_a_leaf_reaches_every_test_that_imports_it_transitively(self):
        self.assertEqual(self.select('apps/raft_flutter/lib/leaf.dart'),
                         ['apps/raft_flutter/test/leaf_only_test.dart', 'apps/raft_flutter/test/mid_test.dart'])

    def test_a_package_file_reaches_app_tests_through_exports(self):
        self.assertEqual(self.select('packages/raft_ui/lib/src/widget.dart'),
                         ['apps/raft_flutter/test/mid_test.dart', 'packages/raft_ui/test/widget_test.dart'])

    def test_editing_a_part_file_reaches_its_librarys_tests(self):
        self.assertEqual(self.select('packages/raft_ui/lib/src/widget_part.dart'),
                         ['apps/raft_flutter/test/mid_test.dart', 'packages/raft_ui/test/widget_test.dart'])

    def test_a_test_helper_reaches_the_tests_using_it_and_a_changed_test_runs_itself(self):
        self.assertEqual(self.select('apps/raft_flutter/test/helper.dart'),
                         ['apps/raft_flutter/test/helped_test.dart', 'apps/raft_flutter/test/leaf_only_test.dart'])
        self.assertEqual(self.select('apps/raft_flutter/test/unrelated_test.dart'), ['apps/raft_flutter/test/unrelated_test.dart'])

    def test_a_file_nothing_imports_selects_no_test(self):
        self.assertEqual(self.select('apps/raft_flutter/lib/mid.dart'), ['apps/raft_flutter/test/mid_test.dart'])
        self.assertEqual(self.select('apps/raft_flutter/lib/nothing_imports_me.dart'), [])


class RankingTests(unittest.TestCase):
    def test_tests_are_ordered_by_import_distance_then_name(self):
        ranked = at.ranked_affected_tests({'apps/raft_flutter/lib/leaf.dart'}, SOURCES, ROOTS)
        self.assertEqual(ranked, [(1, 'apps/raft_flutter/test/leaf_only_test.dart'), (2, 'apps/raft_flutter/test/mid_test.dart')])

    def test_a_changed_test_is_closest_and_ranking_selects_the_same_tests_as_affected_tests(self):
        changed = {'apps/raft_flutter/lib/leaf.dart', 'apps/raft_flutter/test/unrelated_test.dart'}
        ranked = at.ranked_affected_tests(changed, SOURCES, ROOTS)
        self.assertEqual(ranked[0], (0, 'apps/raft_flutter/test/unrelated_test.dart'))
        self.assertEqual(sorted(name for _, name in ranked), at.affected_tests(changed, SOURCES, ROOTS))

    def test_distance_follows_the_part_library_and_export_chain(self):
        ranked = at.ranked_affected_tests({'packages/raft_ui/lib/src/widget_part.dart'}, SOURCES, ROOTS)
        self.assertEqual(ranked, [(3, 'packages/raft_ui/test/widget_test.dart'), (4, 'apps/raft_flutter/test/mid_test.dart')])


if __name__ == '__main__':
    unittest.main()
