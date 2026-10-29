#!/usr/bin/env python3
"""Diff coverage: which changed lines did no test execute?

`git diff -U0 base..head` gives the added/modified lines; lcov files (from
`flutter test --coverage`, run on `head`'s tree) say which executable lines were
hit. The report lists the changed executable lines with zero hits.

    tool/diff_coverage.py --lcov app.lcov:apps/raft_flutter --lcov ui.lcov:packages/raft_ui \\
        --base origin/cindy/integration [--head HEAD] [--root DIR] [--fail-under N]

Each `--lcov FILE[:RUN_DIR]` names the directory `flutter test` ran in (relative
to --root, default the root itself): lcov `SF:` paths are relative to it. A run
with `--coverage-package` lists other packages' files as `../../packages/x/lib/...`;
both forms normalize to repo-relative paths. Several files are merged (hits add).

Only lines lcov instruments count; blank lines, comments, imports and
declarations are not executable, so a PR that only touches those reports
"0 executable changed lines". Files that lcov never mentions (no test loaded
them) are reported as `not loaded by any test`, with their changed line count.
"""
import argparse
import collections
import os
import posixpath
import re
import subprocess
import sys

HUNK = re.compile(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@')


def parse_lcov(text):
    """`{file: {line: hits}}` from lcov text; repeated records of a file add up."""
    files = collections.defaultdict(dict)
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith('SF:'):
            current = files[line[3:]]
        elif line.startswith('DA:') and current is not None:
            parts = line[3:].split(',')
            if len(parts) < 2 or not parts[0].isdigit():
                continue
            number, hits = int(parts[0]), parts[1]
            current[number] = current.get(number, 0) + (int(hits) if hits.lstrip('-').isdigit() else 0)
        elif line == 'end_of_record':
            current = None
    return dict(files)


def normalize_path(path, run_dir):
    """Repo-relative posix path of a relative lcov `SF:` entry produced in `run_dir` (repo-relative)."""
    return posixpath.normpath(posixpath.join(run_dir.replace('\\', '/'), path.replace('\\', '/')))


def is_absolute(path):
    return posixpath.isabs(path) or bool(re.match(r'^[A-Za-z]:/', path))


def strip_root(path, root):
    """Make an absolute path repo-relative when it sits under `root`."""
    root = root.replace('\\', '/').rstrip('/') + '/'
    return path[len(root):] if path.startswith(root) else path


def merge_coverage(parts):
    """Sum several `{file: {line: hits}}` maps."""
    merged = collections.defaultdict(dict)
    for part in parts:
        for file, lines in part.items():
            into = merged[file]
            for number, hits in lines.items():
                into[number] = into.get(number, 0) + hits
    return dict(merged)


def load_coverage(specs, root='.'):
    """Parse `FILE[:RUN_DIR]` specs into one repo-relative coverage map."""
    parts = []
    for spec in specs:
        file, _, run_dir = spec.partition(':') if not re.match(r'^[A-Za-z]:[\\/]', spec) else (spec, '', '')
        with open(file, encoding='utf-8', errors='replace') as handle:
            raw = parse_lcov(handle.read())
        absolute_root = os.path.abspath(root).replace('\\', '/')

        def repo_path(name):
            name = name.replace('\\', '/')
            return posixpath.normpath(strip_root(name, absolute_root)) if is_absolute(name) else normalize_path(name, run_dir or '.')

        parts.append({repo_path(name): lines for name, lines in raw.items()})
    return merge_coverage(parts)


def parse_diff(diff):
    """`{file: sorted added/modified line numbers}` from `git diff -U0` text."""
    changed = collections.defaultdict(set)
    current = None
    for line in diff.splitlines():
        if line.startswith('+++ '):
            target = line[4:].strip()
            current = None if target == '/dev/null' else re.sub(r'^b/', '', target)
        elif current is not None:
            match = HUNK.match(line)
            if match:
                start, count = int(match.group(1)), int(match.group(2) if match.group(2) is not None else 1)
                changed[current].update(range(start, start + count))
    return {file: sorted(lines) for file, lines in changed.items() if lines}


def line_ranges(numbers):
    """`[3, 4, 5, 9]` -> `'3-5, 9'`."""
    out, start, prev = [], None, None
    for number in sorted(numbers):
        if start is None:
            start = prev = number
        elif number == prev + 1:
            prev = number
        else:
            out.append((start, prev))
            start = prev = number
    if start is not None:
        out.append((start, prev))
    return ', '.join(str(a) if a == b else f'{a}-{b}' for a, b in out)


def diff_coverage(changed, coverage):
    """Per file: executable changed lines, the unexecuted ones; plus totals.

    Returns `{'files': [{'file','executable','uncovered':[...],'loaded':bool,'changed':n}], 'executable', 'covered'}`.
    """
    files = []
    for file, lines in sorted(changed.items()):
        record = coverage.get(file)
        if record is None:
            files.append({'file': file, 'executable': 0, 'uncovered': [], 'loaded': False, 'changed': len(lines)})
            continue
        executable = [n for n in lines if n in record]
        files.append({'file': file, 'executable': len(executable), 'changed': len(lines), 'loaded': True,
                      'uncovered': [n for n in executable if record[n] <= 0]})
    executable = sum(f['executable'] for f in files)
    covered = executable - sum(len(f['uncovered']) for f in files)
    return {'files': files, 'executable': executable, 'covered': covered}


def percent(covered, executable):
    return 100.0 if executable == 0 else 100.0 * covered / executable


def git_diff(root, base, head, pathspec=('*.dart',)):
    done = subprocess.run(['git', 'diff', '-U0', '--no-color', '--no-ext-diff', f'{base}...{head}', '--', *pathspec],
                          cwd=root, text=True, capture_output=True)
    if done.returncode != 0:
        raise SystemExit(f'git diff {base}...{head} failed: {done.stderr.strip()}')
    return done.stdout


def format_report(result, only_problems=True):
    """Plain-text report: one line per file with executable changes, unexecuted ranges."""
    out = []
    for f in result['files']:
        if not f['loaded']:
            out.append(f"  not loaded by any test  {f['file']}  ({f['changed']} changed lines)")
        elif f['executable'] and (f['uncovered'] or not only_problems):
            hit = f['executable'] - len(f['uncovered'])
            out.append(f"  {hit}/{f['executable']}  {f['file']}" + (f"  unexecuted: {line_ranges(f['uncovered'])}" if f['uncovered'] else ''))
    out.append(f"DIFF COVERAGE {result['covered']}/{result['executable']} = {percent(result['covered'], result['executable']):.1f}%")
    return '\n'.join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--lcov', action='append', required=True, metavar='FILE[:RUN_DIR]')
    parser.add_argument('--base', required=True)
    parser.add_argument('--head', default='HEAD')
    parser.add_argument('--root', default='.')
    parser.add_argument('--fail-under', type=float, default=None)
    args = parser.parse_args(argv)
    result = diff_coverage(parse_diff(git_diff(args.root, args.base, args.head)), load_coverage(args.lcov, args.root))
    print(format_report(result))
    if args.fail_under is not None and percent(result['covered'], result['executable']) < args.fail_under:
        sys.exit(1)


if __name__ == '__main__':
    main()
