"""Bind private package extraction to Ubuntu's signed APT indices and fixed archive hashes."""
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import subprocess
import tarfile

from .prepare_source import sha256

LIBWPE = {name: item['sha256'] for name, item in
          json.loads(Path(__file__).with_name('libwpe-pins.json').read_text())['packages'].items()}


def control(text):
    return {line.split(': ', 1)[0]: line.split(': ', 1)[1]
            for line in text.splitlines() if ': ' in line and not line[0].isspace()}


def release_checksums(text):
    if not re.search(r'^Origin: Ubuntu$', text, re.M):
        raise ValueError('SDK package indices must have signed Ubuntu origin')
    match = re.search(r'^Valid-Until: (.+)$', text, re.M)
    if match and parsedate_to_datetime(match[1]) < datetime.now(timezone.utc):
        raise ValueError('SDK package index expired; do not ignore authentication failure')
    block = re.search(r'^SHA256:\n((?:[ \t].+\n)+)', text, re.M)
    if not block:
        raise ValueError('Signed release has no SHA256 index table')
    return {row.split()[2]: (row.split()[0], int(row.split()[1])) for row in block[1].splitlines()}


def authenticate(lists=Path('/var/lib/apt/lists')):
    """Read current APT metadata; do not update it or trust an archive's own claims."""
    packages, proofs = {}, []
    keyring = Path('/usr/share/keyrings/ubuntu-archive-keyring.gpg')
    for release in sorted(Path(lists).glob('*_InRelease')):
        match = re.fullmatch(r'(.*)_dists_(noble(?:-updates|-security|-backports)?)_InRelease', release.name)
        if not match:
            continue
        signed = subprocess.run(['gpgv', '--keyring', str(keyring), '--status-fd=1', str(release)],
                                capture_output=True, text=True, timeout=30)
        if signed.returncode or '[GNUPG:] VALIDSIG ' not in signed.stdout:
            raise ValueError('Ubuntu InRelease authentication failed: ' + signed.stderr)
        checksums = release_checksums(release.read_text())
        for index in sorted(Path(lists).glob(match[1] + '_dists_' + match[2] + '_*_binary-amd64_Packages*')):
            relative = index.name.split('_dists_' + match[2] + '_', 1)[1]
            relative = relative.split('_binary-amd64_Packages', 1)[0] + '/binary-amd64/Packages'
            data = subprocess.check_output(['/usr/lib/apt/apt-helper', 'cat-file', str(index)], timeout=30)
            expected = checksums.get(relative)
            if expected != (hashlib.sha256(data).hexdigest(), len(data)):
                raise ValueError('APT Packages bytes differ from their signed release table')
            proof = {'releaseSha256': sha256(release), 'indexSha256': sha256(index),
                     'uncompressedSha256': expected[0], 'indexPath': relative,
                     'suite': match[2], 'signature': signed.stdout}
            proofs.append(proof)
            for block in data.decode().split('\n\n'):
                item = control(block)
                if not {'Package', 'Version', 'Architecture', 'SHA256', 'Filename', 'Size'} <= item.keys():
                    continue
                key = (item['Package'], item['Version'], item['Architecture'])
                packages.setdefault(key, []).append((item, proof))
    if not proofs:
        raise ValueError('No authenticated Noble APT index was found')
    return packages, {'keyringSha256': sha256(keyring), 'indices': proofs}


class Store:
    """A fresh private extraction workspace; no host-file fallback or package installation."""
    def __init__(self, cache, workspace, packages, proof):
        self.workspace, self.packages, self.proof = Path(workspace), packages, proof
        self.workspace.mkdir(parents=True)
        self.records, self.roots = {}, {}
        for archive in sorted(Path(cache).glob('*.deb')):
            fields = control(subprocess.check_output(['dpkg-deb', '--field', str(archive)], text=True, timeout=15))
            key = (fields['Package'], fields['Version'], fields['Architecture'])
            digest = sha256(archive)
            if fields['Package'] in LIBWPE:
                if key[1:] != ('1.16.3-2', 'amd64') or digest != LIBWPE[key[0]]:
                    raise ValueError('Foreign libwpe archive differs from its reviewed source pin')
                url = 'https://deb.debian.org/debian/pool/main/libw/libwpe/' + archive.name
                origin = 'Source-reviewed fixed Debian libwpe archive SHA256, extracted only'
            else:
                candidates = [(c, p) for c, p in packages.get(key, [])
                              if c['SHA256'] == digest and int(c['Size']) == archive.stat().st_size]
                if not candidates:
                    raise ValueError('Package archive has no authenticated exact-byte Noble reference: ' + archive.name)
                item, index = candidates[0]
                url = 'https://archive.ubuntu.com/ubuntu/' + item['Filename']
                origin = index
            if key in self.records and self.records[key]['sha256'] != digest:
                raise ValueError('Conflicting archive bytes for one package/version')
            self.records[key] = {'name': key[0], 'version': key[1], 'architecture': key[2],
                                 'sourcePackage': fields.get('Source', key[0]), 'sha256': digest,
                                 'url': url, 'authentication': origin, 'archive': str(archive)}

    def installed_key(self, package):
        data = subprocess.check_output(['dpkg-query', '-W', '-f=${Package}\t${Version}\t${Architecture}', package],
                                       text=True, timeout=15)
        return tuple(data.split('\t'))

    def extract(self, key):
        if key not in self.records:
            raise ValueError('Exact package archive is missing; retain this failed stage: ' + repr(key))
        if key not in self.roots:
            destination = self.workspace / key[0]
            if destination.exists():
                raise ValueError('Refusing to replace an extracted package')
            archive = self.records[key]['archive']
            if sha256(archive) != self.records[key]['sha256']:
                raise ValueError('Package archive changed after authentication')
            # dpkg-deb emits a data tar only. Python's data filter rejects escaping links/special files.
            data = subprocess.check_output(['dpkg-deb', '--fsys-tarfile', archive], timeout=30)
            destination.mkdir()
            with tarfile.open(fileobj=io.BytesIO(data)) as tar:
                tar.extractall(destination, filter='data')
            self.roots[key] = destination
        return self.roots[key]

    def file(self, key, relative):
        root = self.extract(key)
        target = root / relative
        if not target.is_file() or not target.resolve().is_relative_to(root):
            raise ValueError('Archive file is absent or leaves its private package root: ' + relative)
        return target

    def notice(self, key):
        self.extract(key)
        name = 'usr/share/doc/' + key[0] + '/copyright'
        for _ in range(24):
            parts = PurePosixPath(name).parts
            changed = False
            for count in range(1, len(parts) + 1):
                component = '/'.join(parts[:count])
                link = next((root / component for root in self.roots.values() if (root / component).is_symlink()), None)
                if link is not None:
                    target = os.readlink(link)
                    name = posixpath.normpath(posixpath.dirname(component) + '/' + target)
                    if target.startswith('/') or name.startswith('../'):
                        raise ValueError('Copyright link leaves the private archive namespace')
                    if count < len(parts):
                        name += '/' + '/'.join(parts[count:])
                    changed = True
                    break
            if changed:
                continue
            result = next((root / name for root in self.roots.values() if (root / name).is_file()), None)
            if result:
                return result
            # A notice-only dependency can be in another installed exact package (e.g. gcc-14-base).
            target_package = name.split('/')[3] if name.startswith('usr/share/doc/') else ''
            candidates = [k for k in self.records if k[0] == target_package]
            if len(candidates) != 1 or candidates[0] in self.roots:
                raise ValueError('No authenticated target for copyright link: ' + name)
            self.extract(candidates[0])
        raise ValueError('Copyright link cycle')
