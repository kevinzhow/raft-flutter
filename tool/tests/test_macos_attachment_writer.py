"""Exercise real Foundation publication, including inherited quarantine metadata.

This offscreen test does not claim NSSavePanel or Gatekeeper acceptance. Those
need the actual sandboxed macOS app with a real user-selected destination.
"""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == 'darwin', 'Requires macOS Foundation')
class MacOSAttachmentWriterTests(unittest.TestCase):
    def test_native_atomic_publication(self):
        with tempfile.TemporaryDirectory(prefix='raft-attachment-writer-') as temporary:
            directory = Path(temporary)
            binary = directory / 'writer-tests'
            command = ['xcrun', 'swiftc', '-parse-as-library',
                       '-module-cache-path', str(directory / 'modules'),
                       str(ROOT / 'apps/raft_flutter/macos/Runner/AttachmentFileWriter.swift'),
                       str(ROOT / 'tool/tests/macos_attachment_writer.swift'),
                       '-o', str(binary)]
            result = subprocess.run(command, capture_output=True, text=True, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(binary), str(directory)], capture_output=True,
                                    text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('5 cases, 0 failed assertions', result.stdout)


if __name__ == '__main__':
    unittest.main()
