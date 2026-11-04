"""Private authenticated GStreamer build headers/PC/runtime needed by upstream checks."""
import json
import os
from pathlib import Path
import re
import shutil

from .prepare_source import sha256

NAMES = ('libgstreamer-plugins-bad1.0-dev', 'libgstreamer-plugins-bad1.0-0')


def merge_tree(source, destination):
    """Merge two fixed package trees without installing them or overwriting conflicts."""
    source, destination = Path(source), Path(destination)
    for parent, directories, files in os.walk(source, followlinks=False):
        for name in directories + files:
            original = Path(parent) / name
            target = destination / original.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            if original.is_symlink():
                link = os.readlink(original)
                if Path(link).is_absolute():
                    raise ValueError('Private build package contains an absolute symlink')
                if os.path.lexists(target):
                    if not target.is_symlink() or os.readlink(target) != link:
                        raise ValueError('Private build package link collision')
                else:
                    target.symlink_to(link)
            elif original.is_dir():
                target.mkdir(exist_ok=True)
            elif original.is_file():
                if os.path.lexists(target):
                    if target.is_symlink() or sha256(target) != sha256(original):
                        raise ValueError('Private build package byte collision')
                else:
                    shutil.copy2(original, target)
            else:
                raise ValueError('Unexpected private build package file type')
    for path in destination.rglob('*'):
        if path.is_symlink() and not path.resolve().is_relative_to(destination.resolve()):
            raise ValueError('Private build package link leaves its prefix')


def prepare(store, work):
    work = Path(work)
    destination = work / 'gstreamer-build-deps'
    destination.mkdir()
    records, versions = [], set()
    for name in NAMES:
        matches = [key for key in store.records if key[0] == name and key[2] == 'amd64']
        if len(matches) != 1:
            raise ValueError('Need one authenticated exact GStreamer build package: ' + name)
        key = matches[0]
        versions.add(key[1])
        merge_tree(store.extract(key), destination)
        records.append({k: v for k, v in store.records[key].items() if k != 'archive'})
    if len(versions) != 1:
        raise ValueError('GStreamer build/runtime package versions differ')
    pc_directory = destination / 'usr/lib/x86_64-linux-gnu/pkgconfig'
    for pc in pc_directory.glob('*.pc'):
        text = pc.read_text()
        if not re.search(r'^prefix=/usr$', text, re.M):
            raise ValueError('Unexpected GStreamer build pkg-config prefix')
        pc.write_text(re.sub(r'^prefix=/usr$', 'prefix=${pcfiledir}/../../..', text, flags=re.M))
    inventory = {p.relative_to(destination).as_posix():
                 {'link': os.readlink(p)} if p.is_symlink() else {'sha256': sha256(p)}
                 for p in destination.rglob('*') if p.is_file() or p.is_symlink()}
    record = {'scope': 'Private build-only GStreamer package extraction, no Ubuntu/OpenCV installation. '
                       'Runtime staging still follows actual ELF DT_NEEDED and must authenticate every copied file.',
              'packages': records, 'files': inventory}
    receipt = work / 'private-build-deps.json'
    receipt.write_text(json.dumps(record, sort_keys=True, indent=2) + '\n')
    return {**os.environ, 'PKG_CONFIG_PATH': str(pc_directory)
            + (os.pathsep + os.environ['PKG_CONFIG_PATH'] if os.environ.get('PKG_CONFIG_PATH') else '')}
