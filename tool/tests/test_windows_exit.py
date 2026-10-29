"""Compile and run the production exit waiter on an isolated native window."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == 'win32', 'requires Windows message dispatch')
class WindowsExitTest(unittest.TestCase):
    def test_native_exit_scenarios(self):
        vswhere = Path(os.environ.get('ProgramFiles(x86)', 'C:/Program Files (x86)')) / 'Microsoft Visual Studio/Installer/vswhere.exe'
        self.assertTrue(vswhere.is_file(), 'Visual Studio C++ tools are required')
        install = subprocess.check_output([str(vswhere), '-latest', '-products', '*',
            '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
            '-property', 'installationPath'], text=True).strip()
        self.assertTrue(install, 'Visual Studio C++ tools are required')
        vcvars = Path(install) / 'VC/Auxiliary/Build/vcvars64.bat'
        runner = ROOT / 'apps/raft_flutter/windows/runner'
        with tempfile.TemporaryDirectory(prefix='raft-native-exit-') as folder:
            work = Path(folder)
            args = ['cl.exe', '/nologo', '/std:c++17', '/EHsc', '/W4', '/WX',
                '/DUNICODE', '/D_UNICODE', '/DNOMINMAX', f'/I{runner}',
                str(ROOT / 'tool/tests/windows_exit_test.cpp'),
                str(runner / 'windows_exit.cpp'), f'/Fe:{work / "test.exe"}',
                'user32.lib']
            script = work / 'compile.cmd'
            script.write_text(f'@echo off\ncall "{vcvars}" >nul\nif errorlevel 1 exit /b 1\n'
                + subprocess.list2cmdline(args) + '\nexit /b %errorlevel%\n', encoding='utf-8')
            result = subprocess.run(['cmd.exe', '/d', '/c', 'call', str(script)],
                cwd=work, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(work / 'test.exe')], text=True,
                capture_output=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout.strip())


if __name__ == '__main__':
    unittest.main()
