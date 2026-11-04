#!/usr/bin/env python3
"""Record the fixed system sandbox helper's installed-package provenance.

This is a read-only deployment check, not a package/policy installer. --probe
also performs a bounded namespace-creation check; it does not run WebKit.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import stat
import subprocess


BWRAP = Path('/usr/bin/bwrap')


def protected(path, executable=True):
    if not path.is_absolute() or path.resolve(strict=True) != path:
        raise ValueError('The system helper must use its fixed canonical path')
    for candidate in [*reversed(path.parents), path]:
        info = candidate.lstat()
        expected = stat.S_ISREG(info.st_mode) if candidate == path else stat.S_ISDIR(info.st_mode)
        if not expected or info.st_uid != 0 or info.st_mode & 0o022:
            raise ValueError('The system helper and parents must be root-owned and not writable by others')
    if path.lstat().st_mode & (stat.S_ISUID | stat.S_ISGID) or not os.access(path, os.R_OK | (os.X_OK if executable else 0)):
        raise ValueError('The system helper must be executable without setuid/setgid')


def command(arguments):
    env = {key: value for key, value in os.environ.items()
           if key not in {'LD_LIBRARY_PATH', 'LD_PRELOAD', 'LD_AUDIT'}}
    return subprocess.run(arguments, env=env, text=True, capture_output=True, timeout=15)


def check(probe=False):
    protected(BWRAP)
    info = BWRAP.lstat()
    with BWRAP.open('rb') as stream:
        header = stream.read(20)
    machine = {'x86_64': 62, 'aarch64': 183}.get(platform.machine())
    if (len(header) != 20 or header[:6] != b'\x7fELF\x02\x01'
            or machine is None or int.from_bytes(header[18:20], 'little') != machine):
        raise ValueError('The system helper must be a native ELF executable')
    record = {
        'executable': str(BWRAP), 'uid': info.st_uid, 'gid': info.st_gid,
        'mode': oct(stat.S_IMODE(info.st_mode)),
        'sha256': hashlib.sha256(BWRAP.read_bytes()).hexdigest(),
        'scope': 'Fixed system-helper ownership and installed-package verification; not WebKit acceptance',
    }
    dpkg_query, rpm = Path('/usr/bin/dpkg-query'), Path('/usr/bin/rpm')
    if dpkg_query.exists():
        protected(dpkg_query)
        owner = command([str(dpkg_query), '--admindir=/var/lib/dpkg', '-S', str(BWRAP)])
        if owner.returncode or owner.stdout.strip() != 'bubblewrap: /usr/bin/bwrap':
            raise ValueError('The fixed helper is not owned by the installed bubblewrap package')
        package = command([str(dpkg_query), '--admindir=/var/lib/dpkg', '-W',
                           '-f=${Package}\t${Version}\t${source:Package}\t${source:Version}', 'bubblewrap'])
        dpkg = Path('/usr/bin/dpkg')
        protected(dpkg)
        verified = command([str(dpkg), '--admindir=/var/lib/dpkg', '--verify', 'bubblewrap'])
        checksum_file = Path('/var/lib/dpkg/info/bubblewrap.md5sums')
        protected(checksum_file, executable=False)
        checksums = dict(line.split(maxsplit=1)[::-1] for line in checksum_file.read_text().splitlines())
        expected = checksums.get('usr/bin/bwrap')
        actual = hashlib.md5(BWRAP.read_bytes(), usedforsecurity=False).hexdigest()
        if (package.returncode or verified.returncode or verified.stderr.strip()
                or expected != actual):
            raise ValueError('The installed bubblewrap package did not pass verification')
        # Minimal images may omit documentation; verify the executable itself.
        record['otherPackageDifferences'] = verified.stdout.splitlines()
        record['installedExecutableChecksum'] = {'algorithm': 'dpkg-md5', 'value': actual}
        record['packageManager'] = 'dpkg'
        record['package'] = package.stdout.strip().split('\t')
    elif rpm.exists():
        protected(rpm)
        package = command([str(rpm), '-qf', '--qf', '%{NAME}\t%{VERSION}-%{RELEASE}\t%{SOURCERPM}', str(BWRAP)])
        verified = command([str(rpm), '-Vf', str(BWRAP)])
        target_changed = any(line.split()[-1:] == [str(BWRAP)]
                             for line in verified.stdout.splitlines())
        if (package.returncode or not package.stdout.startswith('bubblewrap\t')
                or verified.returncode not in {0, 1} or target_changed or verified.stderr.strip()):
            raise ValueError('The installed bubblewrap RPM did not pass verification')
        record['otherPackageDifferences'] = verified.stdout.splitlines()
        record['packageManager'] = 'rpm'
        record['package'] = package.stdout.strip().split('\t')
    else:
        raise ValueError('No supported installed-package database for helper provenance')
    version = command([str(BWRAP), '--version'])
    if version.returncode:
        raise ValueError('The fixed system helper could not report its version')
    record['version'] = version.stdout.strip()
    current = BWRAP.lstat()
    if (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns) != (
            current.st_dev, current.st_ino, current.st_size, current.st_mtime_ns):
        raise ValueError('The system helper changed during package verification; repeat the check')
    if probe:
        result = command([str(BWRAP), '--ro-bind', '/', '/', '--unshare-all',
                          '--die-with-parent', '/usr/bin/true'])
        record['sandboxProbe'] = {
            'returncode': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr,
            'scope': 'Read-only namespace creation only; not the WebKit renderer sandbox',
        }
    record['verified'] = not probe or record['sandboxProbe']['returncode'] == 0
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--probe', action='store_true')
    args = parser.parse_args()
    try:
        result = check(args.probe)
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        result = {'verified': False, 'error': str(error)}
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['verified'] else 1)


if __name__ == '__main__':
    main()
