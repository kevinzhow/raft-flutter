"""Compile the real AppDelegate and run native Cocoa contract tests offscreen."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == 'darwin', 'Requires macOS Cocoa and the pinned Flutter SDK')
class MacOSWindowLifecycleTests(unittest.TestCase):
    def test_native_window_lifecycle(self):
        version = json.loads((ROOT / '.fvmrc').read_text())['flutter']
        candidates = [Path(os.environ['RAFT_FLUTTER_BIN'])] if os.environ.get('RAFT_FLUTTER_BIN') else [
            ROOT / '.fvm/flutter_sdk/bin/flutter',
            Path.home() / 'flutter-sdks/versions' / version / 'bin/flutter',
            Path.home() / 'fvm/versions' / version / 'bin/flutter',
        ]
        executable = next((p.resolve() for p in candidates if p.is_file()), None)
        if executable is None:
            self.skipTest('Install the pinned Flutter SDK before running native window tests')
        engine = executable.parent.parent / 'bin/cache/artifacts/engine/darwin-x64/FlutterMacOS.xcframework'
        framework = engine / 'macos-arm64_x86_64'
        self.assertTrue((framework / 'FlutterMacOS.framework').exists(), 'Build macOS once to fetch its engine')
        common = ['-F', str(framework), '-framework', 'FlutterMacOS', '-framework', 'Cocoa']
        with tempfile.TemporaryDirectory(prefix='raft-window-lifecycle-') as temporary:
            directory = Path(temporary)
            library = directory / 'libRaftMacAppDelegate.dylib'
            binary = directory / 'window-tests'
            # MainFlutterWindow's real event guard is compiled too. These
            # offscreen contract tests never initialize the plugin registry.
            registry = directory / 'GeneratedPluginRegistry.swift'
            registry.write_text('import FlutterMacOS\nfunc RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {}\n')
            commands = [
                ['xcrun', 'swiftc', '-parse-as-library', '-emit-library', '-emit-module',
                 '-enable-testing', '-module-name', 'RaftMacAppDelegate',
                 str(ROOT / 'apps/raft_flutter/macos/Runner/AppDelegate.swift'),
                 str(ROOT / 'apps/raft_flutter/macos/Runner/MainFlutterWindow.swift'),
                 str(ROOT / 'apps/raft_flutter/macos/Runner/AttachmentFilesChannel.swift'),
                 str(ROOT / 'apps/raft_flutter/macos/Runner/AttachmentFileWriter.swift'),
                 str(registry),
                 '-emit-module-path', str(directory / 'RaftMacAppDelegate.swiftmodule'),
                 *common, '-o', str(library)],
                ['xcrun', 'swiftc', '-I', str(directory), '-L', str(directory), '-lRaftMacAppDelegate',
                 *common,
                 str(ROOT / 'tool/tests/macos_window_lifecycle.swift'), '-o', str(binary),
                 '-Xlinker', '-rpath', '-Xlinker', str(directory),
                 '-Xlinker', '-rpath', '-Xlinker', str(framework),
                 ],
                [str(binary)],
            ]
            for command in commands:
                result = subprocess.run(command, capture_output=True, text=True, timeout=120)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if command == [str(binary)]:
                    self.assertIn('13 cases, 0 failed assertions', result.stdout)


if __name__ == '__main__':
    unittest.main()
