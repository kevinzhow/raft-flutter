#!/usr/bin/env python3
"""Generate the fixed Linux creation guard without overwriting an existing input."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import stat
import sys

SOURCE_SHA256 = 'd473daf57d9ae48a670672b21cbd21258febaf70814c2d2a96f4bd6b10ab3588'
OUTPUT_SHA256 = 'fb7e84ca8d38c0770bef997d86fc94df6cdd548ab5682ab084e93e9a473977f7'
MAX_BYTES = 1024 * 1024
DECLARATION = b'extern "C" bool raft_desktop_window_creation_allowed() __attribute__((weak));\n'
BRANCH = b'  if (strcmp(method, "createWindow") == 0) {'
GUARD = BRANCH + b'''
    if (raft_desktop_window_creation_allowed && !raft_desktop_window_creation_allowed()) {
      fl_method_call_respond_error(method_call, "desktop_app_closing",
          "Application is closing.", nullptr, nullptr);
      return;
    }'''


def identity(value):
    return value.st_dev, value.st_ino


def read_regular(fd, *, single_link=False):
    before = os.fstat(fd)
    if (not stat.S_ISREG(before.st_mode) or before.st_size > MAX_BYTES
            or single_link and (before.st_nlink != 1 or before.st_uid != os.geteuid())):
        raise ValueError('Expected a regular, privately owned single-link output')
    data = bytearray()
    while chunk := os.read(fd, MAX_BYTES + 1 - len(data)):
        data.extend(chunk)
        if len(data) > MAX_BYTES:
            raise ValueError('Creation-control source or output exceeds its bound')
    after = os.fstat(fd)
    for field in ['st_dev', 'st_ino', 'st_size', 'st_mode', 'st_nlink', 'st_mtime_ns', 'st_ctime_ns']:
        if getattr(before, field) != getattr(after, field):
            raise ValueError('Creation-control file changed during verification')
    return bytes(data), after


def adapted_source(source):
    # O_NONBLOCK makes special-file rejection finite; only regular bytes are read.
    fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
    try:
        body, _ = read_regular(fd)
    finally:
        os.close(fd)
    if hashlib.sha256(body).hexdigest() != SOURCE_SHA256 or body.count(BRANCH) != 1:
        raise ValueError('desktop_multi_window control source changed; review the closing gate')
    output = DECLARATION + body.replace(BRANCH, GUARD, 1)
    if hashlib.sha256(output).hexdigest() != OUTPUT_SHA256:
        raise ValueError('The fixed creation guard output changed')
    return output


def parent_fd(path):
    if not path.name or '..' in path.parts:
        raise ValueError('Use an explicit generation path without parent traversal')
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
    fd = os.open(path.anchor, flags)
    try:
        for part in path.parts[1:-1]:
            child = os.open(part, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        return fd
    except BaseException:
        os.close(fd)
        raise


def parent_unchanged(path, fd):
    current = parent_fd(path)
    try:
        if identity(os.fstat(current)) != identity(os.fstat(fd)):
            raise ValueError('Generation parent changed; preserve it and use a new path')
    finally:
        os.close(current)


def existing_output(directory, name, expected):
    try:
        item = os.stat(name, dir_fd=directory, follow_symlinks=False)
    except FileNotFoundError:
        return False
    if not stat.S_ISREG(item.st_mode) or item.st_nlink != 1 or item.st_uid != os.geteuid():
        raise ValueError('Unsafe existing creation-control output; preserve it and use a new path')
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC, dir_fd=directory)
    try:
        data, held = read_regular(fd, single_link=True)
        current = os.stat(name, dir_fd=directory, follow_symlinks=False)
        if identity(item) != identity(held) or identity(current) != identity(held) or current.st_nlink != 1:
            raise ValueError('Generation output changed during verification')
        if data != expected:
            raise ValueError('Existing creation-control output differs; preserve it and use a new path')
        return True
    finally:
        os.close(fd)


def prepare(source, destination):
    output = adapted_source(source)  # Authenticate all source/output bytes before any write.
    path = Path(destination).absolute()
    directory = parent_fd(path)
    temporary = '.raft-window-control-' + secrets.token_hex(16) + '.tmp'
    fd = None
    try:
        if existing_output(directory, path.name, output):
            parent_unchanged(path, directory)
            return {'reused': True, 'sha256': OUTPUT_SHA256}
        parent_unchanged(path, directory)
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                     0o600, dir_fd=directory)
        view = memoryview(output)
        while view:
            count = os.write(fd, view)
            if count <= 0:
                raise OSError('Incomplete creation-control write')
            view = view[count:]
        os.fsync(fd)
        parent_unchanged(path, directory)
        item = os.stat(temporary, dir_fd=directory, follow_symlinks=False)
        if (not stat.S_ISREG(item.st_mode) or item.st_nlink != 1
                or identity(item) != identity(os.fstat(fd))):
            raise ValueError('Private generation temporary changed')
        # linkat publishes the complete private file only if the destination is
        # absent. Unlike rename/replace it cannot overwrite a concurrent output.
        try:
            os.link(temporary, path.name, src_dir_fd=directory, dst_dir_fd=directory, follow_symlinks=False)
        except FileExistsError as error:
            raise ValueError('Generation output appeared; preserve it and use a new path') from error
        os.unlink(temporary, dir_fd=directory)
        os.fsync(directory)
        parent_unchanged(path, directory)
        if not existing_output(directory, path.name, output):
            raise ValueError('Published generation output disappeared')
        return {'reused': False, 'sha256': OUTPUT_SHA256}
    finally:
        if fd is not None:
            try:
                item = os.stat(temporary, dir_fd=directory, follow_symlinks=False)
                if identity(item) == identity(os.fstat(fd)):
                    os.unlink(temporary, dir_fd=directory)
            except FileNotFoundError:
                pass
            os.close(fd)
        os.close(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--destination', required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(prepare(args.source, args.destination)))
    except (OSError, ValueError) as error:
        sys.exit(f'Creation-control generation refused: {error}')


if __name__ == '__main__':
    main()
