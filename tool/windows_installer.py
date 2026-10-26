#!/usr/bin/env python3
"""Build the per-user Inno Setup installer that WinSparkle downloads and runs.

WinSparkle can only launch an .exe/.msi installer, never unpack a ZIP, so the
Windows release ships both the portable ZIP and this installer. Inno Setup is
preinstalled or installed by choco on the CI runner. Notification support is
installed per user from a verified, bundled Microsoft Windows App Runtime.
"""
import argparse
import base64
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request

SCRIPT = Path(__file__).resolve().parent.parent / 'packaging/windows/raft.iss'
DEFAULT_LOCATIONS = [r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
                     r'C:\Program Files\Inno Setup 6\ISCC.exe']
EXCLUDED = {'RUN.txt'}  # explains the portable ZIP only
# Microsoft Learn's 1.7 archive: match the runner's pinned Windows App SDK line.
RUNTIME_URL = 'https://download.microsoft.com/download/34d94204-2846-4746-9f6d-6c23ca7e869d/WindowsAppRuntimeInstall-x64.exe'
RUNTIME_SHA256 = '8de73b13a010c6aeb84040e5587a46d21b36decce0ccd582c346536cad63ae73'
RUNTIME_VERSION = '1.7.9'


def verify_runtime_installer(path):
    if not path or not Path(path).is_file():
        raise ValueError('Windows App Runtime installer is required; set RAFT_WINDOWS_APP_RUNTIME_INSTALLER')
    path = Path(path).resolve()
    with path.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
    if actual != RUNTIME_SHA256:
        raise ValueError('Windows App Runtime installer SHA-256 does not match the pinned Microsoft download')
    return path


def download_runtime(destination, opener=urllib.request.urlopen):
    """Keep the runtime outside the app payload, and never publish an unverified download."""
    destination = Path(destination)
    if destination.exists():
        return verify_runtime_installer(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_name(destination.name + '.download')
    with opener(RUNTIME_URL, timeout=60) as response, partial.open('xb') as stream:
        total = 0
        while block := response.read(1024 * 1024):
            total += len(block)
            if total > 128 * 1024 * 1024:
                raise ValueError('Windows App Runtime download exceeds the expected size limit')
            stream.write(block)
    verify_runtime_installer(partial)
    partial.replace(destination)
    return destination.resolve()


def runtime_check_script(package_query='Get-AppxPackage -ErrorAction Stop'):
    # Framework alone does not provide notification delivery. Check per-user
    # registration of Main, Singleton and the matching x64 DDLM as well.
    # Singleton is shared across SDK lines, so a newer version is acceptable.
    return r"""$ErrorActionPreference='Stop';try {
$packages=@(& { QUERY });
foreach($name in @('Microsoft.WindowsAppRuntime.1.7','MicrosoftCorporationII.WinAppRuntime.Main.1.7','MicrosoftCorporationII.WinAppRuntime.Singleton','Microsoft.WinAppRuntime.DDLM.7000.*-x6')) {
  $found=@($packages | Where-Object { $_.Name -like $name -and [string]$_.Architecture -in @('X64','9') -and [version]$_.Version -ge [version]'7000.0.0.0' -and [string]$_.Status -eq 'Ok' });
  if($found.Count -eq 0){exit 1}
};exit 0
} catch {exit 2}""".replace('QUERY', package_query)


def runtime_check_arguments():
    encoded = base64.b64encode(runtime_check_script().encode('utf-16-le')).decode('ascii')
    return '-NoLogo -NoProfile -NonInteractive -EncodedCommand ' + encoded


def numeric_version(version, build_number):
    """Inno VersionInfoVersion must be four numeric fields."""
    match = re.fullmatch(r'([0-9]+)\.([0-9]+)\.([0-9]+)(?:-[0-9A-Za-z.-]+)?', version)
    if not match or not re.fullmatch(r'[1-9][0-9]*', str(build_number)):
        raise ValueError('Installer needs X.Y.Z[-prerelease] and a positive build number')
    return '.'.join([*match.groups(), str(build_number)])


def installer_name(asset_version, arch):
    return f'raft-flutter-{asset_version}-windows-{arch}-setup'


def find_compiler(environ=None, which=shutil.which, exists=os.path.exists):
    environ = os.environ if environ is None else environ
    for candidate in [environ.get('ISCC', ''), which('ISCC') or '', *DEFAULT_LOCATIONS]:
        if candidate and exists(candidate):
            return candidate
    raise ValueError('Inno Setup compiler (ISCC.exe) not found; install Inno Setup 6')


def command(compiler, stage, output_dir, stem, version, build_number, script=SCRIPT, runtime_installer=None):
    return [compiler, '/Q', f'/DSourceDir={stage}', f'/DOutputDir={output_dir}', f'/DOutputName={stem}',
            f'/DAppVersion={version}', f'/DNumericVersion={numeric_version(version, build_number)}',
            f'/DRuntimeInstaller={runtime_installer}', f'/DRuntimeCheckArguments={runtime_check_arguments()}', str(script)]


def build(stage, output_dir, asset_version, version, build_number, arch, run=subprocess.run, compiler=None, runtime_installer=None):
    """Compile the installer from the staged bundle; returns the .exe path."""
    stage, output_dir = Path(stage), Path(output_dir)
    for required in ['raft_flutter.exe', 'raft.ico', 'flutter_windows.dll']:
        if not (stage / required).is_file():
            raise ValueError(f'Incomplete Windows bundle for installer: {required}')
    if arch != 'x64':
        raise ValueError('Windows App Runtime installer is pinned for x64')
    runtime = verify_runtime_installer(runtime_installer or os.environ.get('RAFT_WINDOWS_APP_RUNTIME_INSTALLER'))
    # Installer payload: the ZIP's contents without portable-only notes.
    payload = output_dir / f'.installer-payload-{os.getpid()}'
    shutil.copytree(stage, payload, ignore=lambda _dir, names: [n for n in names if n in EXCLUDED])
    try:
        stem = installer_name(asset_version, arch)
        run(command(compiler or find_compiler(), payload, output_dir, stem, version, build_number,
                    runtime_installer=runtime), check=True)
    finally:
        shutil.rmtree(payload, ignore_errors=True)
    result = output_dir / f'{stem}.exe'
    if not result.is_file():
        raise ValueError('Inno Setup did not produce the expected installer')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-runtime', type=Path, required=True)
    arguments = parser.parse_args()
    print(download_runtime(arguments.download_runtime))
