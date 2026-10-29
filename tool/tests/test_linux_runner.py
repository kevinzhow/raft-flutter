import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


TOOL = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('linux_runner', TOOL / 'linux_runner.py')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class LinuxRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.roots = {name: self.base / name.lower() for name in ('WORK', 'CACHE', 'TMP')}
        for root in self.roots.values():
            root.mkdir()
        self.source = self.roots['WORK'] / 'source'
        self.source.mkdir()
        (self.source / '.fvmrc').write_text(json.dumps({'flutter': '3.47.6'}))
        self.env = {f'RAFT_LINUX_RUNNER_{name}_ROOT': str(root) for name, root in self.roots.items()}
        self.env.update({key: str(self.roots['CACHE'] / key.lower()) for key in runner.CACHE_VARIABLES})
        self.env['TMPDIR'] = str(self.roots['TMP'])

    def test_os_gate_keeps_the_original_ubuntu24_abi(self):
        runner.check_os('Linux', 'x86_64', {'ID': 'ubuntu', 'VERSION_ID': '24.04'})
        for system, arch, release in [('Linux', 'x86_64', '26.04'), ('Darwin', 'x86_64', '24.04'),
                                      ('Linux', 'aarch64', '24.04')]:
            with self.subTest(system=system, arch=arch, release=release), self.assertRaises(ValueError):
                runner.check_os(system, arch, {'ID': 'ubuntu', 'VERSION_ID': release})

    def test_source_and_caches_use_distinct_persistent_roots(self):
        roots, filesystems = runner.check_storage(self.env, self.source, filesystem_type=lambda _: 'ext4')
        self.assertEqual(roots, self.roots)
        self.assertEqual(set(filesystems.values()), {'ext4'})

    def test_ram_storage_or_escaped_cache_and_source_stop(self):
        with self.assertRaises(ValueError):
            runner.check_storage(self.env, self.source, filesystem_type=lambda _: 'tmpfs')
        for changes, source in [({'PUB_CACHE': str(self.base / 'outside')}, self.source),
                                ({'RAFT_LINUX_RUNNER_WORK_ROOT': '/'}, self.source),
                                ({'RAFT_LINUX_RUNNER_CACHE_ROOT': str(self.roots['WORK'])}, self.source),
                                ({}, self.base)]:
            with self.subTest(changes=changes, source=source), self.assertRaises(ValueError):
                runner.check_storage(self.env | changes, source, filesystem_type=lambda _: 'ext4')

    def verification(self, *, flutter='3.47.6', missing=None, bad_package=False):
        def which(tool):
            if tool == missing:
                return None
            return str(self.roots['CACHE'] / 'flutter') if tool == 'flutter' else '/usr/bin/' + tool
        def output(command, **_):
            if '--machine' in command:
                return json.dumps({'frameworkVersion': flutter})
            return 'Python 3.12.3'
        return (
            patch.dict(os.environ, self.env),
            patch.object(runner.platform, 'system', return_value='Linux'),
            patch.object(runner.platform, 'machine', return_value='x86_64'),
            patch.object(runner.platform, 'freedesktop_os_release', return_value={'ID': 'ubuntu', 'VERSION_ID': '24.04'}),
            patch.object(runner, 'check_storage', return_value=(self.roots, {name: 'ext4' for name in self.roots})),
            patch.object(runner.shutil, 'which', side_effect=which),
            patch.object(runner.subprocess, 'check_output', side_effect=output),
            patch.object(runner.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['pkg-config']) if bad_package else None),
        )

    def invoke(self, **options):
        import contextlib
        with contextlib.ExitStack() as stack:
            for patcher in self.verification(**options):
                stack.enter_context(patcher)
            receipt = runner.verify(self.source)
            self.assertEqual(os.environ['RAFT_FLUTTER_BIN'], str(self.roots['CACHE'] / 'flutter'))
            return receipt

    def test_verified_tools_export_the_same_sdk_for_all_build_subprocesses(self):
        receipt = self.invoke()
        self.assertEqual(receipt['flutter'], '3.47.6')
        self.assertNotIn(str(self.base), json.dumps(receipt))

    def test_wrong_sdk_and_missing_packaging_tools_stop(self):
        for options in [{'flutter': '3.44.0'}, {'missing': 'Xvfb'}]:
            with self.subTest(options=options), self.assertRaises(ValueError):
                self.invoke(**options)

    def test_missing_native_development_packages_stop_before_packaging(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.invoke(bad_package=True)


if __name__ == '__main__':
    unittest.main()
