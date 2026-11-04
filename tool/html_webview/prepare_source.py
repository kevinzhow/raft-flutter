#!/usr/bin/env python3
"""Prepare the reviewed WPE source adapter; never build or install host packages."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile


VERSION = '2.54.2'
ARCHIVE_SHA256 = 'f3284e19e47fcb5ac8c63c2e1c113dbd65b2423eb8a545f5b345707829004f56'
HERE = Path(__file__).resolve().parent


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def prepare(archive, destination):
    archive, destination = Path(archive), Path(destination)
    if sha256(archive) != ARCHIVE_SHA256:
        raise ValueError('WPE archive differs from the reviewed current stable source')
    if destination.exists():
        raise ValueError('Use a new source directory; previous work and failures are retained')
    destination.mkdir(parents=True)
    record = {
        'engine': 'wpewebkit', 'version': VERSION,
        'sourceUrl': f'https://wpewebkit.org/releases/wpewebkit-{VERSION}.tar.xz',
        'sourceSha256': ARCHIVE_SHA256,
        'patchSha256': sha256(HERE / 'wpe-relocation.patch'),
        'buildOrderPatchSha256': sha256(HERE / 'wpe-build-order.patch'),
        'networkDataPatchSha256': sha256(HERE / 'wpe-network-data-order.patch'),
        'headerSha256': sha256(HERE / 'raft_wpe_runtime_paths.h'),
        'state': 'preparing',
    }
    receipt = destination / 'source-inputs.json'
    receipt.write_text(json.dumps(record, indent=2) + '\n')
    with tarfile.open(archive) as tar:
        if any(Path(member.name).parts[0] != f'wpewebkit-{VERSION}' for member in tar):
            raise ValueError('Unexpected source archive layout')
        tar.extractall(destination, filter='data')
    source = destination / f'wpewebkit-{VERSION}'
    shutil.copy2(HERE / 'raft_wpe_runtime_paths.h',
                 source / 'Source/WebKit/Shared/glib/RaftWPERuntimePaths.h')
    with (destination / 'relocation-apply.log').open('w') as log:
        subprocess.run(['patch', '--batch', '--forward', '-p1', '-i',
                        str(HERE / 'wpe-relocation.patch')],
                       cwd=source, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (destination / 'build-order-apply.log').open('w') as log:
        subprocess.run(['patch', '--batch', '--forward', '-p1', '-i',
                        str(HERE / 'wpe-build-order.patch')],
                       cwd=source, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (destination / 'network-data-order-apply.log').open('w') as log:
        subprocess.run(['patch', '--batch', '--forward', '-p1', '-i',
                        str(HERE / 'wpe-network-data-order.patch')],
                       cwd=source, stdout=log, stderr=subprocess.STDOUT, check=True)
    record['state'] = 'prepared'
    receipt.write_text(json.dumps(record, indent=2) + '\n')
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--destination', required=True, type=Path)
    args = parser.parse_args()
    print(prepare(args.archive, args.destination))


if __name__ == '__main__':
    main()
