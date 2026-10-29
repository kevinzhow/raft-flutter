#!/usr/bin/env python3
"""Create a persistent local release key and export GitHub Actions secrets.

  python3 tool/android-release-signing.py init
  python3 tool/android-release-signing.py export
  python3 tool/android-release-signing.py export --secret RAFT_ANDROID_KEYSTORE_BASE64
  python3 tool/android-release-signing.py export --output .local/android-release-secrets.json

Never run export in CI: its output contains private signing material.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
DIRECTORY = ROOT / '.local/android-release-signing'
SECRET_NAMES = (
    'RAFT_ANDROID_KEYSTORE_BASE64',
    'RAFT_ANDROID_STORE_PASSWORD',
    'RAFT_ANDROID_KEY_ALIAS',
    'RAFT_ANDROID_KEY_PASSWORD',
)


def keytool():
    java_home = os.environ.get('JAVA_HOME')
    if java_home and (Path(java_home) / 'bin/keytool').is_file():
        return str(Path(java_home) / 'bin/keytool')
    executable = shutil.which('keytool')
    if not executable:
        raise ValueError('Java keytool is required (install JDK 17).')
    return executable


def private_write(path, text):
    # Exclusive creation protects existing keys, credentials and exports.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as stream:
        stream.write(text)


def check_local():
    if os.environ.get('CI') or os.environ.get('GITHUB_ACTIONS'):
        raise ValueError('Signing key creation/export is local-only; do not print secrets in CI.')


def create():
    check_local()
    executable = keytool()
    DIRECTORY.parent.mkdir(parents=True, exist_ok=True)
    # Never regenerate a release identity, including after partial failure.
    DIRECTORY.mkdir(mode=0o700, exist_ok=False)
    credentials = {
        'RAFT_ANDROID_STORE_PASSWORD': secrets.token_urlsafe(32),
        'RAFT_ANDROID_KEY_ALIAS': 'raft-release',
        'RAFT_ANDROID_KEY_PASSWORD': secrets.token_urlsafe(32),
    }
    private_write(DIRECTORY / 'credentials.json', json.dumps(credentials, indent=2) + '\n')
    env = dict(os.environ, **credentials)
    keystore = DIRECTORY / 'release.jks'
    # keytool requires a nonexistent keystore, so the private directory is the
    # protection while it creates the file; tighten its mode immediately after.
    try:
        subprocess.run([
            executable, '-genkeypair', '-noprompt', '-storetype', 'JKS',
            '-keystore', str(keystore), '-alias', credentials['RAFT_ANDROID_KEY_ALIAS'],
            '-keyalg', 'RSA', '-keysize', '4096', '-sigalg', 'SHA256withRSA',
            '-validity', '10000', '-dname', 'CN=Raft Flutter',
            '-storepass:env', 'RAFT_ANDROID_STORE_PASSWORD',
            '-keypass:env', 'RAFT_ANDROID_KEY_PASSWORD',
        ], check=True, env=env, capture_output=True, text=True)
    finally:
        if keystore.exists():
            keystore.chmod(0o600)
    # Read the certificate without exposing either password in argv or logs.
    certificate = subprocess.check_output([
        executable, '-exportcert', '-keystore', str(keystore),
        '-alias', credentials['RAFT_ANDROID_KEY_ALIAS'],
        '-storepass:env', 'RAFT_ANDROID_STORE_PASSWORD',
    ], env=env, stderr=subprocess.PIPE)
    fingerprint = hashlib.sha256(certificate).hexdigest().upper()
    print(json.dumps({
        'keystore': str(keystore), 'credentials': str(DIRECTORY / 'credentials.json'),
        'certificateSHA256': ':'.join(fingerprint[i:i + 2] for i in range(0, 64, 2)),
        'githubActionsSecrets': SECRET_NAMES,
    }, indent=2))


def export_values():
    check_local()
    keystore = DIRECTORY / 'release.jks'
    values = json.loads((DIRECTORY / 'credentials.json').read_text(encoding='utf-8'))
    if (set(values) != set(SECRET_NAMES[1:])
            or any(not isinstance(value, str) or not value.strip() for value in values.values())):
        raise ValueError('Invalid signing credentials; restore the original backup.')
    data = keystore.read_bytes()
    if not data:
        raise ValueError('Empty keystore; restore the original backup.')
    return {SECRET_NAMES[0]: base64.b64encode(data).decode('ascii'), **values}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('init', help='Create a new key; refuses to replace an existing directory')
    exporter = commands.add_parser('export', help='Output secret names and values (PRIVATE)')
    destination = exporter.add_mutually_exclusive_group()
    destination.add_argument('--secret', choices=SECRET_NAMES, help='Print only one value for copying')
    destination.add_argument('--output', type=Path, help='Create a private JSON file; never overwrite')
    args = parser.parse_args()
    check_local()
    if args.command == 'init':
        create()
    else:
        values = export_values()
        if args.secret:
            print(values[args.secret])
        elif args.output:
            # Exports must remain in the ignored local directory.
            target = args.output.resolve()
            if not target.is_relative_to((ROOT / '.local').resolve()):
                raise ValueError('--output must be inside the ignored .local directory.')
            private_write(target, json.dumps(values, indent=2) + '\n')
            print(f'Private GitHub Actions secrets exported to {target}')
        else:
            print(json.dumps(values, indent=2))


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError:
        sys.exit('keytool failed. Local files were retained; inspect them before retrying. No key was replaced.')
    except (OSError, ValueError) as error:
        sys.exit(str(error))
