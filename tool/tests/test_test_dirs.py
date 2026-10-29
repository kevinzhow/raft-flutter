"""Every package's tests are discovered by the gate.

`tool/check-project` runs a hard-coded list of test directories, and
`tool/preflight` keeps the same list to pick affected tests. A new package with
tests that is not added to both lists is silently not run: 37 theme-contract
tests were skipped this way in the round that added them, and the totals looked
normal.

This test turns that silence into a failure: any `apps/*/test` or
`packages/*/test` directory that holds a `*_test.dart` must be listed in both
files.
"""
import importlib.machinery
import importlib.util
import pathlib
import sys
import unittest

TOOL = pathlib.Path(__file__).resolve().parents[1]
REPO = TOOL.parent


def load(name, filename):
    loader = importlib.machinery.SourceFileLoader(name, str(TOOL / filename))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def test_directories() -> list[str]:
    """Every test directory that actually holds a test file."""
    found = []
    for area in ('apps', 'packages'):
        for directory in sorted((REPO / area).glob('*/test')):
            if any(directory.rglob('*_test.dart')):
                found.append(f'{area}/{directory.parent.name}/test')
    return found


class TestDirectoriesTest(unittest.TestCase):
    def setUp(self):
        self.found = test_directories()
        self.check_project = load('check_project_tool', 'check-project')
        self.preflight = load('preflight_tool_dirs', 'preflight')

    def test_the_scan_sees_the_known_packages(self):
        # Guards the scan itself: if the glob broke, the assertions below would
        # pass while testing nothing.
        self.assertIn('apps/raft_flutter/test', self.found)
        self.assertIn('packages/raft_ui/test', self.found)
        self.assertGreaterEqual(len(self.found), 8)

    def test_check_project_discovers_every_test_directory(self):
        missing = sorted(set(self.found) - set(self.check_project.TEST_DIRS))
        self.assertEqual(
            missing, [],
            'tool/check-project TEST_DIRS is missing: ' + ', '.join(missing),
        )

    def test_preflight_uses_the_same_list(self):
        self.assertEqual(
            self.preflight.TEST_DIRS,
            self.check_project.TEST_DIRS,
            'tool/preflight must pick affected tests from the same directories',
        )

    def test_no_listed_directory_is_empty(self):
        stale = sorted(set(self.check_project.TEST_DIRS) - set(self.found))
        self.assertEqual(
            stale, [],
            'TEST_DIRS lists directories with no test files: ' + ', '.join(stale),
        )


if __name__ == '__main__':
    unittest.main()
