"""Exercise the production titlebar channel against real offscreen AppKit windows."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == 'darwin', 'Requires macOS AppKit')
class MacOSTitlebarTests(unittest.TestCase):
    def test_integrated_titlebar_native(self):
        version = json.loads((ROOT / '.fvmrc').read_text())['flutter']
        candidates = [Path(os.environ['RAFT_FLUTTER_BIN'])] if os.environ.get('RAFT_FLUTTER_BIN') else [
            ROOT / '.fvm/flutter_sdk/bin/flutter',
            Path.home() / 'fvm/versions' / version / 'bin/flutter',
        ]
        executable = next((p.resolve() for p in candidates if p.is_file()), None)
        if executable is None:
            self.skipTest('Install the pinned Flutter SDK')
        framework = executable.parent.parent / 'bin/cache/artifacts/engine/darwin-x64/FlutterMacOS.xcframework/macos-arm64_x86_64'
        self.assertTrue((framework / 'FlutterMacOS.framework').is_dir())
        common = ['-F', str(framework), '-framework', 'FlutterMacOS', '-framework', 'Cocoa']
        with tempfile.TemporaryDirectory(prefix='raft-titlebar-') as temporary:
            directory = Path(temporary)
            registry = directory / 'Registry.swift'
            registry.write_text('import FlutterMacOS\nfunc RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {}\n')
            binary = directory / 'titlebar-tests'
            commands = [
                ['xcrun', 'swiftc', '-parse-as-library', '-emit-library', '-emit-module',
                 '-enable-testing', '-module-name', 'RaftMacTitleBar',
                 str(ROOT / 'apps/raft_flutter/macos/Runner/AppDelegate.swift'),
                 str(ROOT / 'apps/raft_flutter/macos/Runner/MainFlutterWindow.swift'),
                 str(ROOT / 'apps/raft_flutter/macos/Runner/AttachmentFilesChannel.swift'),
                 str(ROOT / 'apps/raft_flutter/macos/Runner/AttachmentFileWriter.swift'), str(registry),
                 '-emit-module-path', str(directory / 'RaftMacTitleBar.swiftmodule'),
                 *common, '-o', str(directory / 'libRaftMacTitleBar.dylib')],
                ['xcrun', 'swiftc', '-I', str(directory), '-L', str(directory), '-lRaftMacTitleBar',
                 *common, str(ROOT / 'tool/tests/macos_titlebar.swift'), '-o', str(binary),
                 '-Xlinker', '-rpath', '-Xlinker', str(directory),
                 '-Xlinker', '-rpath', '-Xlinker', str(framework)],
                [str(binary)],
            ]
            for command in commands:
                result = subprocess.run(command, capture_output=True, text=True, timeout=120)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if command == [str(binary)]:
                    self.assertIn('9 cases, 0 failed assertions', result.stdout)


if __name__ == '__main__':
    unittest.main()
