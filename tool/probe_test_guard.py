#!/usr/bin/env python3
"""Which staged test files are abandoned scratch, not real tests.

The pre-commit hook refuses a commit that adds one of these, because throwaway
probe tests kept reaching review: they are written to check a hypothesis for two
minutes, then forgotten, and afterwards nobody can tell them from a real test.

The rule is deliberately narrow so it cannot block genuine work:

  * the file must be NEW in this commit -- modifying an existing test is always
    allowed -- and
  * its name must start with `_`.

Only the leading underscore, because the obvious second signal is unsafe: "probe"
appears in eight real tests in this repository (video frame probing, MP4 header
parsing, provider probing), so matching on it would reject future edits to them.
Meanwhile no test here has ever started with `_`, and every probe that actually
reached review did.

A real test that genuinely wants a leading underscore is caught too, which is why
the message tells the author how to rename it rather than only refusing.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def is_probe_test(path: str) -> bool:
    """True when `path` is a newly added, underscore-prefixed test file.

    Kept as a pure function so it can be tested without a git repository.
    """
    name = Path(path).name
    if not name.endswith('_test.dart') or not name.startswith('_'):
        return False
    return '/test/' in f'/{path}' or path.startswith('test/')


def staged_new_files(root: Path) -> list[str]:
    """Paths added (A) in the index, relative to `root`."""
    out = subprocess.run(
        ['git', 'diff', '--cached', '--name-only', '--diff-filter=A'],
        cwd=root, capture_output=True, text=True, check=False)
    if out.returncode != 0:
        return []
    return [line.strip() for line in out.stdout.splitlines() if line.strip()]


def offending(paths: list[str]) -> list[str]:
    return [p for p in paths if is_probe_test(p)]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='.', help='repository root')
    parser.add_argument('paths', nargs='*',
                        help='candidate paths; defaults to the staged additions')
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    paths = args.paths or staged_new_files(root)
    bad = offending(paths)
    if not bad:
        return 0

    print('pre-commit: refusing to add what looks like a throwaway probe test:',
          file=sys.stderr)
    for path in bad:
        print(f'  {path}', file=sys.stderr)
    print('', file=sys.stderr)
    print('  Probes belong outside the repository: write them to /tmp/<your-name>/',
          file=sys.stderr)
    print('  and run them from there. If this really is a lasting test, rename it',
          file=sys.stderr)
    print('  without the leading underscore.', file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main())
