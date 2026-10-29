"""Fetch the previously pinned generic amd64 packages, never the amd64v3 variant."""
import hashlib
from pathlib import Path
import urllib.request

SOURCES = {'libmpv2': 'm/mpv', 'libmpv-dev': 'm/mpv', 'libmujs3': 'm/mujs',
           'liblua5.2-0': 'l/lua5.2', 'libsndio7.0': 's/sndio',
           'libsixel1': 'libs/libsixel', 'libxpresent1': 'libx/libxpresent'}


def download_pinned(name, version, expected_sha256, downloads):
    if name not in SOURCES:
        raise ValueError(f'No approved generic source for {name}')
    filename = f'{name}_{version}_amd64.deb'
    path = Path(downloads) / filename
    if path.exists():
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected_sha256:
            raise ValueError(f'Cached pinned package SHA-256 does not match: {name}')
        return path
    url = f'https://archive.ubuntu.com/ubuntu/pool/universe/{SOURCES[name]}/{filename}'
    # Do not save bytes at the final cache path before verifying them.
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != expected_sha256:
        raise ValueError(f'Pinned package SHA-256 does not match: {name}')
    path.write_bytes(data)
    return path
