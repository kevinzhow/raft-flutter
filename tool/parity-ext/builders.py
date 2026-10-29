"""Manifest builders for the parity extension suite.

`tool/parity-ext/run` generates the case manifest at run time instead of
committing it: every tool/parity-ext/build-*.py is discovered automatically and
executed (build-cases.py first, then by the optional `ORDER = n` constant at the
top of the builder, then by file name); each writes to the path in $PARITY_EXT_MANIFEST.
Builders import `manifest_path()` from here instead of hard-coding a path.
"""
import os
import pathlib
import re
import subprocess
import sys

EXT = pathlib.Path(__file__).resolve().parent


def manifest_path():
    """Where a builder reads/writes the manifest (set by the runner)."""
    value = os.environ.get('PARITY_EXT_MANIFEST')
    if not value:
        sys.exit('PARITY_EXT_MANIFEST is not set: builders run through `tool/parity-ext/run`, '
                 'which generates the manifest (it is no longer committed)')
    return pathlib.Path(value)


DEFAULT_ORDER = 1000
FIRST_BUILDER = 'build-cases.py'  # creates the manifest every other builder amends
_ORDER_RE = re.compile(r'^ORDER\s*=\s*(-?\d+)\b', re.M)


def builder_order(path):
    """Optional top-level `ORDER = n` of a builder (read as text, not executed)."""
    m = _ORDER_RE.search(pathlib.Path(path).read_text())
    return int(m.group(1)) if m else DEFAULT_ORDER


def ordered_builders(ext=EXT):
    """-> ordered build-*.py names.

    Discovered automatically (no registry file to edit): sorted by the optional
    top-level `ORDER = n` constant of each builder (default 1000), then by file
    name. build-cases.py always runs first because it creates the manifest; a
    builder that needs an earlier or later slot says so with its own `ORDER`,
    nothing shared is edited."""
    paths = sorted(pathlib.Path(ext).glob('build-*.py'), key=lambda p: p.name)
    first = [p for p in paths if p.name == FIRST_BUILDER]
    rest = sorted((p for p in paths if p.name != FIRST_BUILDER), key=lambda p: (builder_order(p), p.name))
    return [p.name for p in first + rest]


def build_manifest(out, ext=EXT, env=None):
    """Run every builder; returns the manifest path (<out>/cases.json)."""
    ext, out = pathlib.Path(ext), pathlib.Path(out)
    out.mkdir(parents=True, exist_ok=True)
    target = out / 'cases.json'
    target.unlink(missing_ok=True)
    names = ordered_builders(ext)
    run_env = {**os.environ, **(env or {}), 'PARITY_EXT_MANIFEST': str(target)}
    log = out / 'builders.log'
    with open(log, 'w') as sink:
        for name in names:
            r = subprocess.run([sys.executable, str(ext / name)], cwd=ext.parents[1], env=run_env,
                               stdout=sink, stderr=subprocess.STDOUT)
            if r.returncode != 0:
                sys.exit(f'builder {name} failed (exit {r.returncode}); see {log}')
    if not target.is_file():
        sys.exit(f'no builder wrote {target}; see {log}')
    return target
