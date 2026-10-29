#!/usr/bin/env python3
"""Which looks the checks test, which files belong to a legacy look, and the theme-engine guard.

Owner decision 2026-10-25: the regular checks (tool/check-project, tool/preflight, the pre-gate pass) test the
Raft look only. The legacy looks (Elegant, Brutal; frozen at a57b9dab) have their own on-demand suite,
`tool/theme-suite`. This module is the Python half of that rule; the Dart half is
`packages/raft_ui/lib/test_themes.dart` (RAFT_TEST_LOOKS, RAFT_TEST_MODES, `raftThemeMatrix`, `raftLookSkip`).
The two defaults are compared by tool/tests/test_theme_looks.py.

Files and looks:
  * `@Tags(['look-elegant'])` / `@Tags(['look-brutal'])` before `library;` -- the whole file is about that look.
    The default run does not run it; `tool/theme-suite` runs it for the look.
  * a file that calls `raftThemeMatrix(..., look: ...)` or `raftLookSkip(...)` declares both Raft and legacy
    cases; the default run keeps the Raft ones (the Dart helper drops the rest), the suite runs it with
    RAFT_TEST_LOOKS set to the legacy look.

The guard: `python3 tool/theme_looks.py guard [--base REF]` prints a loud notice when the diff touches a path in
THEME_ENGINE_PATHS (or a file tied to a legacy look). It never fails and never runs the suite. check-project,
preflight and the pre-gate script all call it. THEME_ENGINE_PATHS is the only place that lists those paths.

  python3 tool/theme_looks.py guard [--base REF]
  python3 tool/theme_looks.py skip-legacy FILE...   # prints the files the default run keeps
  python3 tool/theme_looks.py files --look elegant|brutal|all [DIR...]   # the files the suite runs
"""
import argparse
import fnmatch
import os
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent

LOOKS = ('raft', 'elegant', 'brutal')
LEGACY_LOOKS = ('elegant', 'brutal')
DEFAULT_LOOKS = ('raft',)  # packages/raft_ui/lib/test_themes.dart raftDefaultLooks
LOOKS_VARIABLE = 'RAFT_TEST_LOOKS'
MODES_VARIABLE = 'RAFT_TEST_MODES'
ALL_THEMES_VARIABLE = 'RAFT_TEST_ALL_THEMES'
MODES = ('light', 'dark', 'all')
DEFAULT_BASE_REF = 'origin/cindy/integration'
SUITE_COMMAND = 'tool/theme-suite --look all'
NOTICE = f'theme engine touched: run {SUITE_COMMAND} before landing'

# Paths whose change can alter how a legacy look renders or resolves: the theme engine, its packs and
# adapters, the recipes and their binding, the frozen baselines, and this selection machinery. fnmatch
# patterns on repo-relative paths (`*` also crosses `/`). A change to a file tagged for a legacy look is
# caught separately (see `touched`).
THEME_ENGINE_PATHS = (
    'packages/raft_theme/*',  # pack parsing, validation, inheritance, the built-in packs and their JSON
    'packages/raft_ui/lib/src/theme.dart',  # ThemeData built from a pack
    'packages/raft_ui/lib/src/tokens/*',  # RaftTokens and the contract roles
    'packages/raft_ui/lib/src/recipes/*',  # generated recipes
    'packages/raft_ui/lib/src/*recipe*.dart',  # recipe binding and hand-written recipes
    'packages/raft_ui/lib/src/css_recipe_decoration.dart',
    'packages/raft_ui/lib/src/*tokens.dart',
    'packages/raft_ui/lib/test_themes.dart',  # the look selection of the Dart tests
    'tool/theme-adapters/*',  # pack generators and the adapter contracts
    'tool/recipes/*',  # recipe extraction and generation
    'tool/theme-contract/*',
    'tool/theme-baseline/*',
    'tool/theme-baseline-manifest-*.json',
    'tool/parity-themes/*',
    'tool/parity-ext/frozen*',  # the frozen a57b9dab references
    'tool/theme_looks.py',
    'tool/theme-suite',
    'docs/theme-contract/*',
)

TAGS = re.compile(r"^@Tags\(\s*\[([^\]]*)\]\s*\)", re.M)
TAG_NAME = re.compile(r"""['"]([^'"]+)['"]""")
LOOK_MARKER = re.compile(r'\braftLook(?:Skip|Of|Selected)\b')
HEAD_BYTES = 16384  # the annotation sits before the first import


def selected_looks(env=None):
    """The looks a run selects: RAFT_TEST_ALL_THEMES=1 or RAFT_TEST_LOOKS=all is every look, a comma list is
    those looks, unset is DEFAULT_LOOKS. An unknown name raises ValueError."""
    env = os.environ if env is None else env
    if env.get(ALL_THEMES_VARIABLE) == '1':
        return LOOKS
    raw = env.get(LOOKS_VARIABLE, '').strip().lower()
    if not raw:
        return DEFAULT_LOOKS
    if raw == 'all':
        return LOOKS
    names = [part.strip() for part in raw.split(',') if part.strip()]
    unknown = [name for name in names if name not in LOOKS]
    if unknown:
        raise ValueError(f'{LOOKS_VARIABLE} names unknown look(s) {", ".join(unknown)}; use {", ".join(LOOKS)} or all.')
    return tuple(look for look in LOOKS if look in names)


def tag_look(look):
    return f'look-{look}'


def file_tags(path, text=None):
    """The tag names of the `@Tags([...])` annotation at the top of a Dart test file."""
    if text is None:
        try:
            with open(path, encoding='utf-8', errors='replace') as handle:
                text = handle.read(HEAD_BYTES)
        except OSError:
            return ()
    found = []
    for match in TAGS.finditer(text[:HEAD_BYTES]):
        found.extend(TAG_NAME.findall(match.group(1)))
    return tuple(found)


def file_looks(path, text=None):
    """The legacy looks a whole test file is tied to by its tags (empty for an ordinary file)."""
    tags = file_tags(path, text)
    return tuple(look for look in LEGACY_LOOKS if tag_look(look) in tags)


def declares_looks(path, text=None):
    """True for a file that declares per-look cases itself (a look-aware matrix or `skip: raftLookSkip(...)`)."""
    if text is None:
        try:
            text = pathlib.Path(path).read_text(encoding='utf-8', errors='replace')
        except OSError:
            return False
    return bool(LOOK_MARKER.search(text))


def runs_by_default(path, looks=DEFAULT_LOOKS, text=None):
    """False for a file whose tags tie it to a look that `looks` does not select."""
    tied = file_looks(path, text)
    return not tied or all(look in looks for look in tied)


def split_by_looks(paths, looks=DEFAULT_LOOKS, base=None):
    """(kept, skipped) of `paths` (names relative to `base` or absolute): skipped files are tied to a look not in `looks`."""
    kept, skipped = [], []
    for name in paths:
        path = pathlib.Path(name)
        if base is not None and not path.is_absolute():
            path = pathlib.Path(base) / path
        (kept if runs_by_default(path, looks) else skipped).append(name)
    return kept, skipped


def suite_files(paths, looks, base=None):
    """Of `paths`, the test files `tool/theme-suite` runs for `looks` (legacy looks only): the files tied to one of them
    by a tag, and the files that declare per-look cases."""
    wanted = [look for look in looks if look in LEGACY_LOOKS]
    chosen = []
    for name in paths:
        path = pathlib.Path(name)
        if base is not None and not path.is_absolute():
            path = pathlib.Path(base) / path
        try:
            text = path.read_text(encoding='utf-8', errors='replace')
        except OSError:
            continue
        tied = file_looks(path, text)
        if tied and any(look in wanted for look in tied):
            chosen.append(name)
        elif not tied and declares_looks(path, text) and any(re.search(look, text, re.I) for look in wanted):
            chosen.append(name)  # a mixed file runs for a look it mentions; its other cases are skipped by the Dart helper
    return chosen


def matches_engine_path(path):
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in THEME_ENGINE_PATHS)


def touched(changed, base=None):
    """The changed repo-relative paths that make the guard speak: theme-engine paths, and test files tied to a legacy look."""
    base = pathlib.Path(base or root)
    hits = []
    for name in changed:
        if matches_engine_path(name):
            hits.append(name)
        elif name.endswith('_test.dart') and (base / name).is_file() and file_looks(base / name):
            hits.append(name)
    return hits


def notice_lines(hits, limit=8):
    """The loud guard notice for `hits` (empty when nothing was touched)."""
    if not hits:
        return []
    bar = '!' * 78
    shown = [f'  {name}' for name in hits[:limit]]
    if len(hits) > limit:
        shown.append(f'  ... and {len(hits) - limit} more')
    return [bar, f'!!! {NOTICE}', '!!! The default checks test the Raft look only; Elegant and Brutal are not covered by them.',
            '!!! This is a notice, not a failure: nothing was run for the legacy looks.', *shown, bar]


def changed_paths(base_ref=None, cwd=None):
    """Repo-relative paths changed since the merge-base with `base_ref` (committed, staged, unstaged, untracked), or None
    when that cannot be computed."""
    base_ref = base_ref or os.environ.get('RAFT_CHECK_BASE') or DEFAULT_BASE_REF
    cwd = cwd or root

    def git(*args):
        return subprocess.check_output(['git', *args], cwd=cwd, text=True, stderr=subprocess.DEVNULL).strip()

    try:
        merge_base = git('merge-base', 'HEAD', base_ref)
        names = git('-c', 'core.quotepath=off', 'diff', '--name-only', '--no-renames', merge_base).splitlines()
        names += git('-c', 'core.quotepath=off', 'ls-files', '--others', '--exclude-standard').splitlines()
    except (OSError, subprocess.CalledProcessError):
        return None
    return sorted(set(names))


def guard(base_ref=None, cwd=None, changed=None):
    """Notice lines for the current diff (empty when the engine is untouched or the diff cannot be computed)."""
    names = changed if changed is not None else changed_paths(base_ref, cwd)
    if not names:
        return []
    return notice_lines(touched(names, cwd))


def discover(dirs, base=None):
    base = pathlib.Path(base or root)
    found = []
    for directory in dirs:
        found += [p.relative_to(base).as_posix() for p in sorted((base / directory).rglob('*_test.dart'))]
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    g = sub.add_parser('guard', help='print the theme-engine notice when the diff touches the engine (always exits 0)')
    g.add_argument('--base', default=None)
    s = sub.add_parser('skip-legacy', help='print the given test files the default run keeps')
    s.add_argument('files', nargs='*')
    f = sub.add_parser('files', help='list the test files the suite runs for a look')
    f.add_argument('--look', choices=[*LEGACY_LOOKS, 'all'], required=True)
    f.add_argument('dirs', nargs='*')
    args = parser.parse_args(argv)
    if args.command == 'guard':
        for line in guard(args.base):
            print(line)
        return 0
    if args.command == 'skip-legacy':
        kept, _ = split_by_looks(args.files)
        for name in kept:
            print(name)
        return 0
    looks = LEGACY_LOOKS if args.look == 'all' else (args.look,)
    dirs = args.dirs or ['apps/raft_flutter/test', 'packages/raft_ui/test', 'packages/raft_theme/test']
    for name in suite_files(discover(dirs), looks):
        print(name)
    return 0


if __name__ == '__main__':
    sys.exit(main())
