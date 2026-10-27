"""Verification policy changes must invalidate the gate's source receipt."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SourceHashTests(unittest.TestCase):
    def test_vendored_dependency_changes_invalidate_the_source_receipt(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'tool').mkdir()
            shutil.copy2(ROOT / 'tool/source-hash', root / 'tool/source-hash')

            def stamp():
                return subprocess.check_output(
                    [sys.executable, str(root / 'tool/source-hash')], text=True)

            previous = stamp()
            for name in ['third_party/flutter_markdown_plus/lib/src/builder.dart',
                         'third_party/flutter_markdown_plus/lib/src/cache/entry.dart',
                         'third_party/flutter_markdown_plus/pubspec.yaml']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('original')
                current = stamp()
                self.assertNotEqual(previous, current)
                path.write_text('changed')
                changed = stamp()
                self.assertNotEqual(current, changed)
                previous = changed

    def test_vendor_receipts_cache_and_external_build_links_are_excluded(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'tool').mkdir()
            shutil.copy2(ROOT / 'tool/source-hash', root / 'tool/source-hash')

            def stamp():
                return subprocess.check_output(
                    [sys.executable, str(root / 'tool/source-hash')], text=True)

            previous = stamp()
            for name in ['third_party/markdown/UPSTREAM.json',
                         'third_party/markdown/README.md',
                         'third_party/markdown/source.tar.gz',
                         'third_party/markdown/build/generated.dart',
                         'third_party/markdown/.dart_tool/generated.dart',
                         'third_party/markdown/cache/generated.dart',
                         'third_party/markdown/.cache/generated.dart']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('transient or explanatory')
                self.assertEqual(stamp(), previous, name)
            if sys.platform != 'win32':
                external = root / 'external-build'
                external.mkdir()
                (external / 'generated.dart').write_text('external cache')
                link = root / 'third_party/linked/build'
                link.parent.mkdir(parents=True)
                link.symlink_to(external, target_is_directory=True)
                self.assertEqual(stamp(), previous)
                (external / 'generated.dart').write_text('changed cache')
                self.assertEqual(stamp(), previous)

    def test_structure_policy_is_hashed_but_documentation_is_not(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'tool').mkdir()
            shutil.copy2(ROOT / 'tool/source-hash', root / 'tool/source-hash')
            def stamp():
                return subprocess.check_output([sys.executable, str(root / 'tool/source-hash')], text=True)
            previous = stamp()
            for name in ['tool/structure-audit', 'tool/structure-audit-baseline.json']:
                path = root / name
                path.write_text('initial')
                current = stamp()
                self.assertNotEqual(previous, current)
                path.write_text('changed')
                changed = stamp()
                self.assertNotEqual(current, changed)
                previous = changed
            (root / 'docs').mkdir()
            (root / 'docs/readme.md').write_text('explanatory text')
            self.assertEqual(previous, stamp())


if __name__ == '__main__':
    unittest.main()
