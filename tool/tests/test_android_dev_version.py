from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import android_app


class LocalDevVersionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='raft-dev-version-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'apps/raft_flutter'
        self.app.mkdir(parents=True)
        (self.app / 'pubspec.yaml').write_text('name: raft\nversion: 0.1.0+1\n')
        (self.root / '.gitignore').write_text('.local/\n')
        self.git('init', '-q')
        self.git('config', 'user.name', 'Raft test')
        self.git('config', 'user.email', 'test@invalid')
        self.git('add', '.')
        self.git('commit', '-qm', 'fixture')
        self.commit = self.git('rev-parse', '--short=7', 'HEAD')

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True).strip()

    def test_clean_uses_pubspec_and_actual_tree_head(self):
        self.assertEqual(android_app.local_dev_version(self.root), f'0.1.0-dev.{self.commit}')
        (self.root / '.local').mkdir()
        (self.root / '.local/log.txt').write_text('ignored build output')
        self.assertEqual(android_app.local_dev_version(self.root), f'0.1.0-dev.{self.commit}')

    def test_tracked_and_untracked_changes_add_dirty_suffix(self):
        (self.app / 'pubspec.yaml').write_text('name: raft\nversion: 0.2.0+1\n')
        self.assertEqual(android_app.local_dev_version(self.root), f'0.2.0-dev.{self.commit}.dirty')
        self.git('restore', '.')
        (self.root / 'new-source.dart').write_text('new code')
        self.assertEqual(android_app.local_dev_version(self.root), f'0.1.0-dev.{self.commit}.dirty')

    def test_builder_keeps_about_and_package_version_identical_without_installing(self):
        run = Mock()
        result = android_app.build_local_android(6050, self.root, run_build=run)
        command = run.call_args.args[0]
        version = f'0.1.0-dev.{self.commit}'
        self.assertIn(f'--build-name={version}', command)
        self.assertIn(f'--dart-define=RAFT_APP_VERSION={version}', command)
        self.assertIn('--build-number=6050', command)
        self.assertIn('--target-platform=android-arm64', command)
        self.assertNotIn('install', command)
        self.assertEqual(run.call_args.kwargs, {'cwd': self.app, 'check': True})
        self.assertEqual(result['versionName'], version)

    def test_invalid_build_number_and_missing_version_fail_before_compile(self):
        run = Mock()
        for number in [0, -1, True]:
            with self.subTest(number=number), self.assertRaises(android_app.SafetyError):
                android_app.build_local_android(number, self.root, run_build=run)
        (self.app / 'pubspec.yaml').write_text('name: raft\n')
        with self.assertRaises(android_app.SafetyError):
            android_app.build_local_android(6050, self.root, run_build=run)
        run.assert_not_called()
