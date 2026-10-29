#!/usr/bin/env python3
"""Build the per-user Inno Setup installer that WinSparkle downloads and runs.

WinSparkle can only launch an .exe/.msi installer, never unpack a ZIP, so the
Windows release ships both the portable ZIP and this installer. Inno Setup is
preinstalled or installed by choco on the CI runner; this host cannot run it.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess

SCRIPT = Path(__file__).resolve().parent.parent / 'packaging/windows/raft.iss'
DEFAULT_LOCATIONS = [r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
                     r'C:\Program Files\Inno Setup 6\ISCC.exe']
EXCLUDED = {'RUN.txt'}  # explains the portable ZIP only


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


def command(compiler, stage, output_dir, stem, version, build_number, script=SCRIPT):
    return [compiler, '/Q', f'/DSourceDir={stage}', f'/DOutputDir={output_dir}', f'/DOutputName={stem}',
            f'/DAppVersion={version}', f'/DNumericVersion={numeric_version(version, build_number)}', str(script)]


def build(stage, output_dir, asset_version, version, build_number, arch, run=subprocess.run, compiler=None):
    """Compile the installer from the staged bundle; returns the .exe path."""
    stage, output_dir = Path(stage), Path(output_dir)
    for required in ['raft_flutter.exe', 'raft.ico', 'flutter_windows.dll']:
        if not (stage / required).is_file():
            raise ValueError(f'Incomplete Windows bundle for installer: {required}')
    # Installer payload: the ZIP's contents without portable-only notes.
    payload = output_dir / f'.installer-payload-{os.getpid()}'
    shutil.copytree(stage, payload, ignore=lambda _dir, names: [n for n in names if n in EXCLUDED])
    try:
        stem = installer_name(asset_version, arch)
        run(command(compiler or find_compiler(), payload, output_dir, stem, version, build_number), check=True)
    finally:
        shutil.rmtree(payload, ignore_errors=True)
    result = output_dir / f'{stem}.exe'
    if not result.is_file():
        raise ValueError('Inno Setup did not produce the expected installer')
    return result
