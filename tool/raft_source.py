"""Locate the upstream raft-source checkout that the parity and generator tools read.

Every tool resolves it here (Node scripts through tool/raft_source.mjs, shell through `tool/raft-source path`):

1. `PARITY_RAFT_SOURCE`, when set, is used as given. It is an explicit override: any revision is accepted, and the
   files the caller needs must still exist.
2. Otherwise the commit pinned in docs/source-reference.json selects a checkout under ~/.cache/raft-flutter/:
   `raft-source-<first 12 hex digits of the pin>` (the directory `tool/raft-source prepare` creates), else the first
   other `raft-source-*` directory, by name, whose HEAD is the pin and which has the needed files (for example a
   checkout made by hand before this resolver existed).

`require()` returns the checkout only when its HEAD is the pin (unless overridden) and the needed files exist;
otherwise RaftSourceError names the path, the expected and actual commit, the missing files and the command that
prepares the checkout. There is no fallback to another revision.
"""
import json
import os
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
PIN_FILE = 'docs/source-reference.json'
ENV = 'PARITY_RAFT_SOURCE'
PREPARE = 'tool/raft-source prepare'
SHARED_CASES = 'packages/visual-testing/shared/sharedCases.json'
RAFT_UI = 'packages/web/node_modules/@botiverse/raft-ui/package.json'
WEB_PLAYWRIGHT = 'packages/web/node_modules/@playwright/test/package.json'
SHARP = 'packages/visual-testing/node_modules/sharp/package.json'
NEEDED = (SHARED_CASES, RAFT_UI, WEB_PLAYWRIGHT, SHARP)  # what a prepared checkout has


class RaftSourceError(Exception):
    """The checkout is missing, at the wrong commit or not installed; the message says how to fix it."""


def pinned_commit(root=ROOT):
    return json.loads((pathlib.Path(root) / PIN_FILE).read_text())['commit']


def cache_dir(home=None):
    return pathlib.Path(home or pathlib.Path.home()) / '.cache/raft-flutter'


def canonical_dir(commit, home=None):
    return cache_dir(home) / f'raft-source-{commit[:12]}'


def head_commit(path):
    """HEAD of the checkout at `path`, or None when it is not a git checkout of its own."""
    path = pathlib.Path(path)
    if not (path / '.git').exists():
        return None
    done = subprocess.run(['git', '-C', str(path), 'rev-parse', '--verify', '--quiet', 'HEAD'],
                          capture_output=True, text=True)
    return done.stdout.strip() or None


def missing_files(path, needs=NEEDED):
    return [need for need in needs if not (pathlib.Path(path) / need).exists()]


def overridden(env=None):
    return bool((os.environ if env is None else env).get(ENV))


def raft_source_dir(env=None, *, root=ROOT, home=None, needs=NEEDED):
    """The checkout to use; never raises (validate it with problems() or require() before reading it)."""
    env = os.environ if env is None else env
    if env.get(ENV):
        return pathlib.Path(env[ENV]).expanduser()
    commit = pinned_commit(root)
    canonical = canonical_dir(commit, home)
    if canonical.exists():
        return canonical
    for candidate in sorted(cache_dir(home).glob('raft-source-*')):
        if head_commit(candidate) == commit and not missing_files(candidate, needs):
            return candidate
    return canonical


def problems(path, env=None, *, root=ROOT, needs=NEEDED):
    """Empty when the checkout is usable, else lines that explain why not and how to fix it."""
    path, commit = pathlib.Path(path), pinned_commit(root)
    if not path.is_dir():
        return [f'raft-source checkout not found: {path}', f'  expected commit: {commit} ({PIN_FILE})',
                f'  prepare it with: {PREPARE}   (or set {ENV} to a checkout of that commit)']
    lines = []
    actual = head_commit(path)
    if actual != commit and not overridden(env):
        lines += [f'  expected commit: {commit} ({PIN_FILE})', f'  actual commit:   {actual or "not a git checkout"}']
    lines += [f'  missing: {need}' for need in missing_files(path, needs)]
    if not lines:
        return []
    fix = (f'  {ENV} points here; fix that checkout or unset {ENV}' if overridden(env)
           else f'  prepare it with: {PREPARE}   (creates {canonical_dir(commit)})')
    return [f'raft-source checkout is not usable: {path}', *lines, fix]


def require(env=None, *, root=ROOT, home=None, needs=NEEDED):
    """The validated checkout; raises RaftSourceError with the fix when it cannot be used."""
    path = raft_source_dir(env, root=root, home=home, needs=needs)
    found = problems(path, env, root=root, needs=needs)
    if found:
        raise RaftSourceError('\n'.join(found))
    return path


def describe(env=None, *, root=ROOT, home=None):
    """One line for logs: the resolved checkout, its commit and whether it is usable."""
    path = raft_source_dir(env, root=root, home=home)
    how = f', {ENV} override' if overridden(env) else ''
    state = 'NOT USABLE, see tool/raft-source check' if problems(path, env, root=root) else 'ok'
    return f'raft-source {path} at {head_commit(path) or "no checkout"} (pinned {pinned_commit(root)}{how}): {state}'
