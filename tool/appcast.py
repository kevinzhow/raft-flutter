#!/usr/bin/env python3
"""Sparkle / WinSparkle appcast generation with a stdlib-only Ed25519 signer.

Sparkle 2 (macOS) and WinSparkle 0.9+ (Windows) verify `sparkle:edSignature`:
a base64 Ed25519 signature over the raw bytes of the update archive/installer.
`generate_keys -x` exports the private key as base64 of the 32-byte seed; the
base64 public key is what `SUPublicEDKey` / `win_sparkle_set_eddsa_public_key`
receive. Both frameworks use the same key format, so one key pair serves both.

The signer below is RFC 8032 Ed25519 (pure) in plain Python so that the Ubuntu
publish job needs no third-party package and no macOS-only `sign_update`. It
streams the archive. The private key is only ever read from an environment
variable or file by the caller, never printed, never put in argv.
"""
import base64
import binascii
import hashlib
from email.utils import format_datetime
from datetime import datetime
from pathlib import Path
import re
from xml.sax.saxutils import escape, quoteattr

# --- Ed25519 (RFC 8032, section 6 reference arithmetic) -----------------------

_P = 2 ** 255 - 19
_L = 2 ** 252 + 27742317777372353535851937790883648493
_D = -121665 * pow(121666, -1, _P) % _P
_I = pow(2, (_P - 1) // 4, _P)


def _recover_x(y, sign):
    if y >= _P:
        return None
    x2 = (y * y - 1) * pow(_D * y * y + 1, -1, _P) % _P
    if x2 == 0:
        return None if sign else 0
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P:
        x = x * _I % _P
    if (x * x - x2) % _P:
        return None
    if (x & 1) != sign:
        x = _P - x
    return x


_GY = 4 * pow(5, -1, _P) % _P
_GX = _recover_x(_GY, 0)
_G = (_GX, _GY, 1, _GX * _GY % _P)


def _add(a, b):
    a1 = (a[1] - a[0]) * (b[1] - b[0]) % _P
    b1 = (a[1] + a[0]) * (b[1] + b[0]) % _P
    c = 2 * a[3] * b[3] * _D % _P
    d = 2 * a[2] * b[2] % _P
    e, f, g, h = b1 - a1, d - c, d + c, b1 + a1
    return (e * f % _P, g * h % _P, f * g % _P, e * h % _P)


def _mul(scalar, point):
    result = (0, 1, 1, 0)
    while scalar:
        if scalar & 1:
            result = _add(result, point)
        point = _add(point, point)
        scalar >>= 1
    return result


def _encode(point):
    zi = pow(point[2], -1, _P)
    x, y = point[0] * zi % _P, point[1] * zi % _P
    return (y | ((x & 1) << 255)).to_bytes(32, 'little')


def _decode(data):
    if len(data) != 32:
        return None
    y = int.from_bytes(data, 'little')
    sign, y = y >> 255, y & ((1 << 255) - 1)
    x = _recover_x(y, sign)
    return None if x is None else (x, y, 1, x * y % _P)


def _equal(a, b):
    return (a[0] * b[2] - b[0] * a[2]) % _P == 0 and (a[1] * b[2] - b[1] * a[2]) % _P == 0


def _expand(seed):
    if len(seed) != 32:
        raise ValueError('Ed25519 private key must be a 32-byte seed')
    digest = hashlib.sha512(seed).digest()
    scalar = int.from_bytes(digest[:32], 'little')
    scalar &= (1 << 254) - 8
    scalar |= 1 << 254
    return scalar, digest[32:]


def public_key(seed):
    """Raw 32-byte public key for a 32-byte seed."""
    return _encode(_mul(_expand(seed)[0], _G))


def _file_hash(prefix, path):
    digest = hashlib.sha512(prefix)
    size = 0
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
            size += len(chunk)
    return digest, size


def sign_file(seed, path):
    """Ed25519 signature (64 bytes) over the file's bytes, and the file length."""
    scalar, prefix = _expand(seed)
    pub = _encode(_mul(scalar, _G))
    digest, size = _file_hash(prefix, path)
    r = int.from_bytes(digest.digest(), 'little') % _L
    r_point = _encode(_mul(r, _G))
    digest, _ = _file_hash(r_point + pub, path)
    k = int.from_bytes(digest.digest(), 'little') % _L
    s = (r + k * scalar) % _L
    return r_point + s.to_bytes(32, 'little'), size


def verify_file(pub, signature, path):
    """True when `signature` is a valid Ed25519 signature of the file under `pub`."""
    if len(signature) != 64:
        return False
    a_point, r_point = _decode(pub), _decode(signature[:32])
    s = int.from_bytes(signature[32:], 'little')
    if a_point is None or r_point is None or s >= _L:
        return False
    digest, _ = _file_hash(signature[:32] + pub, path)
    k = int.from_bytes(digest.digest(), 'little') % _L
    return _equal(_mul(s, _G), _add(r_point, _mul(k, a_point)))


# --- Keys as Sparkle presents them --------------------------------------------

def decode_seed(text):
    """Sparkle private key text -> 32-byte seed. Rejects the legacy 96-byte form."""
    try:
        raw = base64.b64decode(''.join(text.split()), validate=True)
    except (binascii.Error, ValueError):
        raise ValueError('Sparkle private key must be base64 text') from None
    if len(raw) == 96:
        raise ValueError('Legacy 96-byte Sparkle private keys are not supported; '
                         'export a current key with generate_keys -x')
    if len(raw) != 32:
        raise ValueError('Sparkle private key must decode to a 32-byte Ed25519 seed')
    return raw


def decode_public_key(text):
    """Base64 SUPublicEDKey text -> raw 32 bytes (validated)."""
    try:
        raw = base64.b64decode(''.join(text.split()), validate=True)
    except (binascii.Error, ValueError):
        raise ValueError('Sparkle public key must be base64 text') from None
    if len(raw) != 32 or _decode(raw) is None:
        raise ValueError('Sparkle public key must decode to a valid 32-byte Ed25519 key')
    return raw


def public_key_text(seed):
    return base64.b64encode(public_key(seed)).decode('ascii')


def read_public_key(environ):
    """The single source of the app's update public key.

    The repository Actions variable SPARKLE_ED_PUBLIC_KEY (no checked-in key).
    Empty means "auto-update disabled for this build".
    """
    value = environ.get('SPARKLE_ED_PUBLIC_KEY', '').strip()
    if value:
        decode_public_key(value)
    return value


# --- Appcast -------------------------------------------------------------------

SPARKLE_NS = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
FEED_BASE = 'https://github.com/{repo}/releases/latest/download'
MIN_SYSTEM = {'macos': '12.0'}
# Documented WinSparkle arguments for Inno Setup; the app is relaunched by the
# installer's postinstall entry, which also runs in silent mode.
WINDOWS_INSTALLER_ARGUMENTS = '/SILENT /SP- /NOICONS /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS'


def feed_url(repo, platform):
    return f'{FEED_BASE.format(repo=repo)}/appcast-{platform}.xml'


def asset_url(repo, tag, name):
    from urllib.parse import quote
    return f'https://github.com/{repo}/releases/download/{quote(tag, safe="")}/{quote(name, safe="")}'


def rfc2822(iso_timestamp):
    value = datetime.fromisoformat(iso_timestamp.replace('Z', '+00:00'))
    if value.tzinfo is None:
        raise ValueError('Release timestamp needs a timezone')
    return format_datetime(value)


def build_appcast(*, platform, repo, tag, version, build_number, archive_name,
                  length, signature, published, url=None):
    """One-item appcast for the release. Deterministic for identical inputs."""
    if platform not in {'macos', 'windows'}:
        raise ValueError('Appcasts exist only for macOS and Windows')
    if not re.fullmatch(r'[1-9][0-9]*', str(build_number)):
        raise ValueError('Appcast build number must be a positive integer')
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError('Appcast signature must be a 64-byte Ed25519 signature')
    release_page = f'https://github.com/{repo}/releases/tag/{tag}'
    attributes = [
        ('url', url or asset_url(repo, tag, archive_name)),
        ('length', str(int(length))),
        ('type', 'application/octet-stream'),
        ('sparkle:edSignature', signature),
    ]
    if platform == 'windows':
        attributes.insert(3, ('sparkle:os', 'windows-x64'))
        attributes.insert(4, ('sparkle:installerArguments', WINDOWS_INSTALLER_ARGUMENTS))
    enclosure = ' '.join(f'{name}={quoteattr(value)}' for name, value in attributes)
    minimum = (f'      <sparkle:minimumSystemVersion>{MIN_SYSTEM[platform]}</sparkle:minimumSystemVersion>\n'
               if platform in MIN_SYSTEM else '')
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        f'<rss version="2.0" xmlns:sparkle="{SPARKLE_NS}">\n'
        '  <channel>\n'
        '    <title>Raft</title>\n'
        f'    <link>https://github.com/{repo}/releases</link>\n'
        '    <description>Raft releases</description>\n'
        '    <language>en</language>\n'
        '    <item>\n'
        f'      <title>Raft {escape(version)}</title>\n'
        f'      <pubDate>{rfc2822(published)}</pubDate>\n'
        f'      <sparkle:version>{build_number}</sparkle:version>\n'
        f'      <sparkle:shortVersionString>{escape(version)}</sparkle:shortVersionString>\n'
        f'{minimum}'
        f'      <sparkle:fullReleaseNotesLink>{escape(release_page)}</sparkle:fullReleaseNotesLink>\n'
        f'      <enclosure {enclosure}/>\n'
        '    </item>\n'
        '  </channel>\n'
        '</rss>\n')


def signed_appcast(*, seed, archive, **fields):
    """Sign `archive` and render the appcast that points at it."""
    signature, length = sign_file(seed, archive)
    return build_appcast(archive_name=Path(archive).name, length=length,
                         signature=base64.b64encode(signature).decode('ascii'), **fields)


# --- Command line (local rehearsals only; CI imports the functions) ------------

def _keygen(args):
    """Throwaway key pair for local update tests. Never use it for a release."""
    import os
    directory = Path(args.out)
    directory.mkdir(parents=True, exist_ok=True)
    seed = os.urandom(32)
    private = directory / 'private-key.txt'
    descriptor = os.open(private, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        stream.write(base64.b64encode(seed).decode('ascii') + '\n')
    print(f'private key written to {private} (mode 600; keep it out of git)')
    print(f'public key: {public_key_text(seed)}')


def _sign(args):
    import os
    secret = os.environ.get(args.key_env, '')
    if not secret.strip():
        raise SystemExit(f'Set {args.key_env} to the base64 private key (it is never printed)')
    xml = signed_appcast(seed=decode_seed(secret), archive=args.archive, platform=args.platform,
                         repo=args.repo, tag=args.tag, version=args.version, build_number=args.build,
                         published=args.published, url=args.url)
    Path(args.output).write_text(xml, encoding='utf-8', newline='\n')
    print(f'wrote {args.output}')


def main(argv=None):
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    keygen = commands.add_parser('keygen', help='create a throwaway test key pair')
    keygen.add_argument('--out', required=True)
    keygen.set_defaults(run=_keygen)
    sign = commands.add_parser('sign', help='sign an archive and write an appcast (key from an environment variable)')
    sign.add_argument('--archive', required=True)
    sign.add_argument('--platform', choices=['macos', 'windows'], required=True)
    sign.add_argument('--repo', default='kevinzhow/raft-flutter')
    sign.add_argument('--tag', required=True)
    sign.add_argument('--version', required=True)
    sign.add_argument('--build', required=True)
    sign.add_argument('--published', required=True, help='ISO 8601 with timezone')
    sign.add_argument('--url', help='override the enclosure URL (local test server)')
    sign.add_argument('--key-env', default='SPARKLE_ED_PRIVATE_KEY')
    sign.add_argument('--output', required=True)
    sign.set_defaults(run=_sign)
    args = parser.parse_args(argv)
    args.run(args)


if __name__ == '__main__':
    main()
