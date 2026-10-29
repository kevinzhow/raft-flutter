#!/usr/bin/env python3
"""Prepare/inspect one isolated test-signing PE; no network or credentials."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import uuid

REPOSITORY = 'kevinzhow/raft-flutter'
REF = 'refs/heads/cindy/integration'
RUNNER = 'raft_flutter.exe'


def guard(repository, event, ref, sha, attempt):
    if (repository != REPOSITORY or event != 'workflow_dispatch' or ref != REF
            or attempt != '1' or not re.fullmatch(r'[0-9a-f]{40}', sha)
            or sha == '0' * 40):
        raise ValueError('Only a fresh manual run on the canonical integration ref is allowed')


def settings(env):
    organization = uuid.UUID(env.get('SIGNPATH_TEST_ORGANIZATION_ID', ''))
    if organization.int == 0:
        raise ValueError('Set a non-placeholder SignPath organization UUID')
    project = env.get('SIGNPATH_TEST_PROJECT_SLUG', '')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,127}', project):
        raise ValueError('Set SIGNPATH_TEST_PROJECT_SLUG to the approved project slug')
    if env.get('SIGNPATH_TEST_POLICY_SLUG') != 'test-signing':
        raise ValueError('Only the test-signing policy is allowed')
    if env.get('SIGNPATH_TEST_ARTIFACT_SLUG') != 'windows-runner-test':
        raise ValueError('Only the windows-runner-test artifact configuration is allowed')
    pin = env.get('SIGNPATH_TEST_CERTIFICATE_SHA1', '')
    if not re.fullmatch(r'[0-9A-Fa-f]{40}', pin) or set(pin) == {'0'}:
        raise ValueError('Set the public self-signed TEST certificate SHA1 thumbprint')


def image(data):
    """Accept a canonical contiguous-section x64 EXE, not arbitrary vendor PEs."""
    if len(data) > 128 * 1024 * 1024 or len(data) < 256 or data[:2] != b'MZ':
        raise ValueError('Expected a bounded Windows PE executable')
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    if pe < 64 or pe + 24 > len(data) or data[pe:pe + 4] != b'PE\0\0':
        raise ValueError('Invalid PE header')
    machine, sections = struct.unpack_from('<HH', data, pe + 4)
    optional_size, flags = struct.unpack_from('<HH', data, pe + 20)
    optional = pe + 24
    if (machine != 0x8664 or flags & 0x2000 or not 1 <= sections <= 96
            or optional_size < 152 or optional + optional_size > len(data)
            or struct.unpack_from('<H', data, optional)[0] != 0x20b
            or struct.unpack_from('<I', data, optional + 108)[0] < 5):
        raise ValueError('Expected an x64 PE32+ EXE with a security directory')
    header_size = struct.unpack_from('<I', data, optional + 60)[0]
    table = optional + optional_size
    if not table + sections * 40 <= header_size <= len(data):
        raise ValueError('Invalid section headers')
    ranges = []
    for index in range(sections):
        size, offset = struct.unpack_from('<II', data, table + index * 40 + 16)
        if size:
            ranges.append((offset, size))
    cursor = header_size
    for offset, size in sorted(ranges):
        if offset != cursor or offset + size > len(data):
            raise ValueError('Noncanonical or truncated PE sections; review before signing')
        cursor += size
    slot = optional + 144
    certificate_offset, certificate_size = struct.unpack_from('<II', data, slot)
    return optional + 64, slot, certificate_offset, certificate_size


def normalize(data):
    checksum, slot, _, _ = image(data)
    result = bytearray(data)
    result[checksum:checksum + 4] = b'\0' * 4
    result[slot:slot + 8] = b'\0' * 8
    return bytes(result)


def stage(source, output, manifest):
    source, output, manifest = Path(source), Path(output), Path(manifest)
    if source.is_symlink() or source.name != RUNNER or not source.is_file():
        raise ValueError('Input must be the regular built raft_flutter.exe')
    data = source.read_bytes()
    if image(data)[2:] != (0, 0):
        raise ValueError('Test input must be unsigned')
    if output.exists() and any(output.iterdir()):
        raise ValueError('Refuse to reuse a nonempty test payload directory')
    output.mkdir(parents=True, exist_ok=True)
    (output / RUNNER).write_bytes(data)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({
        'file': RUNNER, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
        'scope': 'one runner only; no DLLs, installer, updater or release assets',
    }, indent=2) + '\n', encoding='utf-8')


def inspect_return(unsigned, signed, output):
    unsigned, signed, output = Path(unsigned), Path(signed), Path(output)
    if unsigned.is_symlink() or signed.is_symlink():
        raise ValueError('Refuse a symbolic-link signing result')
    before, after = unsigned.read_bytes(), signed.read_bytes()
    if image(before)[2:] != (0, 0):
        raise ValueError('Original input is not unsigned')
    _, _, offset, size = image(after)
    expected_offset = (len(before) + 7) & ~7
    if (offset != expected_offset or size < 8 or offset + size != len(after)
            or normalize(after[:len(before)]) != normalize(before)
            or any(after[len(before):offset])):
        raise ValueError('Signing changed payload bytes or returned an unexpected layout')
    length, revision, kind = struct.unpack_from('<IHH', after, offset)
    if (revision != 0x200 or kind != 2 or length < 8 or length > size
            or (length + 7) & ~7 != size or any(after[offset + length:])):
        raise ValueError('Expected exactly one PKCS#7 WIN_CERTIFICATE')
    checksum, slot, _, _ = image(after)
    # Canonical section layout was checked above. Include zero alignment padding.
    digest = hashlib.sha256(
        after[:checksum] + after[checksum + 4:slot] + after[slot + 8:offset]
    ).hexdigest()
    output.mkdir(parents=True, exist_ok=True)
    (output / 'signature.p7b').write_bytes(after[offset + 8:offset + length])
    result = {
        'unsignedSHA256': hashlib.sha256(before).hexdigest(),
        'signedSHA256': hashlib.sha256(after).hexdigest(),
        'authenticodeSHA256': digest, 'payloadPreserved': True,
    }
    (output / 'inspection.json').write_text(json.dumps(result, indent=2) + '\n',
                                             encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('guard')
    sub.add_parser('settings')
    prepare = sub.add_parser('stage')
    prepare.add_argument('--source', required=True)
    prepare.add_argument('--output', required=True)
    prepare.add_argument('--manifest', required=True)
    inspect = sub.add_parser('inspect')
    inspect.add_argument('--unsigned', required=True)
    inspect.add_argument('--signed', required=True)
    inspect.add_argument('--output', required=True)
    args = parser.parse_args()
    if args.command == 'guard':
        guard(*(os.environ.get(key, '') for key in [
            'GITHUB_REPOSITORY', 'GITHUB_EVENT_NAME', 'GITHUB_REF', 'GITHUB_SHA',
            'GITHUB_RUN_ATTEMPT',
        ]))
    elif args.command == 'settings':
        settings(os.environ)
    elif args.command == 'stage':
        stage(args.source, args.output, args.manifest)
    else:
        inspect_return(args.unsigned, args.signed, args.output)


if __name__ == '__main__':
    main()
