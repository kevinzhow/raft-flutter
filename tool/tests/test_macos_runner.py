import importlib.util
import os
from pathlib import Path
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location('macos_runner', Path(__file__).resolve().parents[1] / 'macos_runner.py')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class MacRunnerStorageTests(unittest.TestCase):
    def environment(self, root):
        return {'RAFT_MACOS_RUNNER_ROOT': str(root),
                **{key: str(root / 'cache' / key) for key in runner.CACHE_VARIABLES}}

    def test_unmounted_volume_stops_without_creating_a_fallback(self):
        root = Path('/Volumes/Data/runner-missing-volume-test')
        with self.assertRaisesRegex(ValueError, 'mounted data volume'):
            runner.check_storage(self.environment(root), root / 'work', mounted=lambda _: False)
        self.assertFalse(root.exists())

    def test_complete_data_volume_environment_is_accepted(self):
        root = Path('/Volumes/Data/dedicated-runner-test')
        self.assertEqual(runner.check_storage(self.environment(root), root / 'work', mounted=lambda _: True), root)

    def test_system_workspace_or_cache_is_rejected(self):
        root = Path('/Volumes/Data/dedicated-runner-test')
        with self.assertRaisesRegex(ValueError, 'checkout'):
            runner.check_storage(self.environment(root), Path('/Users/runner/work'), mounted=lambda _: True)
        for key in runner.CACHE_VARIABLES:
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, key):
                runner.check_storage({**self.environment(root), key: '/private/tmp/cache'},
                                     root / 'work', mounted=lambda _: True)

    def test_symlink_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            root = base / 'root'
            root.mkdir()
            (root / 'escape').symlink_to(base)
            self.assertFalse(runner.inside(root / 'escape/cache', root))


if __name__ == '__main__':
    unittest.main()
