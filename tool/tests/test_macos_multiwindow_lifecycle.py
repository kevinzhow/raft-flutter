"""Offscreen production AppKit host contracts, using the pinned Flutter engine.

This does not run Dart, launch the application, or replace end-to-end macOS QA.
"""
import json
from contextlib import nullcontext
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def plugin_sources(name, version):
    override = os.environ.get('RAFT_MACOS_PLUGIN_SOURCES')
    if override and (Path(override) / name).is_dir():
        return Path(override) / name
    cache = Path(os.environ.get('PUB_CACHE', str(Path.home() / '.pub-cache')))
    return cache / 'hosted/pub.dev' / f'{name}-{version}'


def pinned_flutter_executable(override=None):
    """Fail before native compilation if the executable reports another SDK."""
    version = json.loads((ROOT / '.fvmrc').read_text())['flutter']
    configured = override if override is not None else os.environ.get('RAFT_FLUTTER_BIN')
    candidates = [Path(configured)] if configured else [
        ROOT / '.fvm/flutter_sdk/bin/flutter',
        Path.home() / 'flutter-sdks/versions' / version / 'bin/flutter',
        Path.home() / 'fvm/versions' / version / 'bin/flutter',
    ]
    executable = next((p.resolve() for p in candidates if p.is_file()), None)
    if executable is None:
        if configured:
            raise RuntimeError('Configured RAFT_FLUTTER_BIN does not exist')
        return None
    result = subprocess.run([str(executable), '--version', '--machine'],
                            capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(f'Flutter SDK version query failed (exit {result.returncode})')
    try:
        actual = json.loads(result.stdout)['frameworkVersion']
    except (ValueError, KeyError, TypeError) as error:
        raise RuntimeError('Flutter SDK did not report a machine-readable frameworkVersion') from error
    if actual != version:
        raise RuntimeError(f'Flutter SDK version mismatch: repository requires {version}, executable reports {actual}')
    return executable


def native_plugin_sources():
    return {
        'desktop_drop': [ROOT / 'packages/desktop_drop/macos/desktop_drop/Sources/desktop_drop/DesktopDropPlugin.swift'],
        'desktop_multi_window': sorted((plugin_sources('desktop_multi_window', '0.3.1') / 'macos/desktop_multi_window/Sources/desktop_multi_window').glob('*.swift')),
        'app_links': sorted((plugin_sources('app_links', '7.2.2') / 'macos/app_links/Sources/app_links').glob('*.swift')),
    }


class FlutterSdkPinTests(unittest.TestCase):
    @unittest.skipIf(os.name == 'nt', 'The executable fixture uses a POSIX shell')
    def test_mismatched_executable_is_rejected_before_loading_framework(self):
        with tempfile.TemporaryDirectory(prefix='raft-sdk-pin-') as temporary:
            executable = Path(temporary) / 'flutter'
            executable.write_text('#!/bin/sh\nprintf \'%s\\n\' \'{"frameworkVersion":"0.0.0-test-fixture"}\'\n')
            executable.chmod(0o700)
            with self.assertRaisesRegex(RuntimeError, 'Flutter SDK version mismatch'):
                pinned_flutter_executable(override=executable)


@unittest.skipUnless(sys.platform == 'darwin', 'Requires macOS Cocoa and Flutter')
class MacOSMultiwindowLifecycleTests(unittest.TestCase):
    def test_primary_quit_close_and_child_menu(self):
        executable = pinned_flutter_executable()
        if executable is None:
            self.skipTest('Install the pinned Flutter SDK')
        framework = executable.parent.parent / 'bin/cache/artifacts/engine/darwin-x64/FlutterMacOS.xcframework/macos-arm64_x86_64'
        self.assertTrue((framework / 'FlutterMacOS.framework').is_dir())
        plugins = native_plugin_sources()
        for name, sources in plugins.items():
            self.assertTrue(sources, f'Run pub get to install {name}')
        baseline = os.environ.get('RAFT_MACOS_BASELINE_REF')
        output = os.environ.get('RAFT_MACOS_CONTRACT_OUTPUT')
        if output:
            Path(output).mkdir(exist_ok=False)
        storage = nullcontext(output) if output else tempfile.TemporaryDirectory(prefix='raft-multiwindow-contract-')
        with storage as temporary:
            directory = Path(temporary)
            common = ['-F', str(framework), '-framework', 'FlutterMacOS', '-framework', 'Cocoa',
                      '-module-cache-path', str(directory / 'module-cache')]
            link = ['-I', str(directory), '-L', str(directory)]
            commands = []
            for name, sources in plugins.items():
                commands.append(['xcrun', 'swiftc', '-parse-as-library', '-emit-library', '-emit-module',
                                 '-module-name', name, *map(str, sources),
                                 '-emit-module-path', str(directory / f'{name}.swiftmodule'),
                                 *common, '-o', str(directory / f'lib{name}.dylib')])
                link.append(f'-l{name}')
            # Registration policy has its own test. These contracts create no
            # real application controller or child, so unrelated plugins stay off.
            registry = directory / 'Registry.swift'
            registry.write_text('import FlutterMacOS\n'
                                'func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {}\n'
                                'func RegisterRaftChildPlugins(registry: FlutterPluginRegistry) {}\n')
            sources = []
            for name in ['AppDelegate.swift', 'MainFlutterWindow.swift', 'AttachmentFilesChannel.swift', 'AttachmentFileWriter.swift']:
                path = ROOT / 'apps/raft_flutter/macos/Runner' / name
                if baseline:
                    original = subprocess.run(['git', 'show', f'{baseline}:{path.relative_to(ROOT)}'],
                                              cwd=ROOT, capture_output=True, check=True).stdout
                    path = directory / name
                    path.write_bytes(original)
                sources.append(str(path))
            library = directory / 'libRaftMacMultiwindowLifecycle.dylib'
            commands.append(['xcrun', 'swiftc', '-parse-as-library', '-emit-library', '-emit-module',
                             '-enable-testing', '-module-name', 'RaftMacMultiwindowLifecycle',
                             *sources, str(registry), '-emit-module-path',
                             str(directory / 'RaftMacMultiwindowLifecycle.swiftmodule'),
                             *link, *common, '-o', str(library)])
            binary = directory / 'multiwindow-tests'
            commands.append(['xcrun', 'swiftc', *(['-D', 'OLD_BASELINE'] if baseline else []),
                             *link, '-lRaftMacMultiwindowLifecycle', *common,
                             str(ROOT / 'tool/tests/macos_multiwindow_lifecycle.swift'), '-o', str(binary),
                             '-Xlinker', '-rpath', '-Xlinker', str(directory),
                             '-Xlinker', '-rpath', '-Xlinker', str(framework)])
            commands.append([str(binary)])
            for command in commands:
                result = subprocess.run(command, capture_output=True, text=True, timeout=120)
                if result.returncode or command == [str(binary)]:
                    print(result.stdout + result.stderr, flush=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if command == [str(binary)]:
                    self.assertIn('0 failed assertions', result.stdout)


if __name__ == '__main__':
    unittest.main()
