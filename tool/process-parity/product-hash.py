#!/usr/bin/env python3
"""Bind actual host product bytes before compiling the native test."""
import hashlib
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
paths = subprocess.check_output(['git', 'ls-files', '-z', '--', 'apps/raft_flutter/lib', 'packages', 'pubspec.yaml', 'pubspec.lock'], cwd=ROOT).decode().split('\0')
hash_ = hashlib.sha256()
for path in sorted(p for p in paths if p):
    hash_.update((path + '\0').encode())
    hash_.update((ROOT/path).read_bytes())
print(hash_.hexdigest())
