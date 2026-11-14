#!/usr/bin/env python3
"""Coverage-based test impact selection: run only the test files that execute what a diff changes.

    tool/test-impact build [--package apps/raft_flutter ...] [--jobs 4] [--tier full]
    tool/test-impact select [--base origin/cindy/integration] [--head HEAD] [--worktree] [--format text|files|json]
    tool/test-impact show

`build` runs each package's suite once with the line-coverage probe on (tool/testing/impact_probe.dart,
`RAFT_TEST_IMPACT_DIR`): `flutter test` runs every test file in its own process, so the probe's report
at the end of a file is exactly the library lines that file executed. The reports become one map per
package, `~/.cache/raft-flutter/test-impact/<package>/map.json.gz`: for every (file, line) the test
files that executed it, plus every executable line, stamped with the commit it was built from.

`select` maps `git diff -U0 <merge-base> HEAD` onto the map's commit (`git diff <map commit>
<merge-base>` translates line numbers; a line the two sides both changed widens to the whole hunk) and
picks, with a reason for each:
  - tests that executed a changed or removed executable line;
  - for a changed line that is not executable (a declaration, a const constructor, an inserted line):
    tests that executed the nearest executable lines above and below it, and for a top-level or
    member declaration, the tests that executed the lines that reference the declared name;
  - changed test files themselves, and tests that import a changed test helper the map has no lines of;
  - a Dart file the map has no lines of (new, or never executed): tests that import it through test
    code, plus the import closure (`--absent import-graph`, the default `callers` relies on the changed
    call sites in existing files instead; see `absent_tests`);
  - non-Dart inputs (assets, fixtures, JSON, docs): tests that mention the path, and tests that execute
    library lines that mention it; build inputs (pubspec, analysis options, dart_test.yaml) select all;
  - generator inputs (tool/flutter regenerates the git-ignored *.g.dart files): tests that executed the
    generated file;
  - test files the map does not know (new, or the probe did not report) that import a changed file.
A comment-only or blank-line change selects nothing. A map whose commit is not an ancestor of HEAD or
that is older than 24 hours gets a 'stale map' warning (the line translation still applies).
"""
import argparse
import bisect
import collections
import datetime
import functools
import gzip
import itertools
import json
import os
import pathlib
import posixpath
import re
import shutil
import subprocess
import sys
import time

TOOL = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL))
import affected_tests  # noqa: E402

REPO = TOOL.parent
CACHE = pathlib.Path(os.environ.get('RAFT_TEST_IMPACT_CACHE') or pathlib.Path.home() / '.cache/raft-flutter/test-impact')
DEFAULT_BASE = 'origin/cindy/integration'
DEFAULT_PACKAGES = ('apps/raft_flutter', 'packages/raft_ui')
MAP_VERSION = 1
STALE_HOURS = 24
PROBE_IMPORT = '../../../tool/testing/impact_probe.dart'
TEMP_CONFIG_MARK = '// tool/test-impact: temporary config, removed after the build'
# Inputs every test file depends on: a change selects the whole suite.
GLOBAL_INPUTS = re.compile(r'(^|/)(pubspec\.yaml|pubspec\.lock|analysis_options\.yaml|dart_test\.yaml|l10n\.yaml|'
                           r'build\.yaml|\.fvmrc|flutter_test_config\.dart)$|^tool/(flutter|flutter_launcher\.py|testing/)')
# Git-ignored Dart files that tool/flutter writes before every test run: (generated file, inputs).
GENERATED = (
    ('apps/raft_flutter/test/parity/case_map.g.dart', re.compile(r'^apps/raft_flutter/test/parity/cases/[^/]+\.dart$')),
    ('packages/raft_ui/lib/src/l10n/zh_index.g.dart', re.compile(r'^packages/raft_ui/lib/src/l10n/zh[^/]*\.dart$')),
)
DART_KEYWORDS = frozenset('''abstract as assert async await base break case catch class const continue covariant default
deferred do dynamic else enum export extends extension external factory false final finally for function get hide if
implements import in interface is late library mixin new null of on operator part required rethrow return sealed set show
static super switch sync this throw true try type typedef var void when while with yield'''.split())


def git(args, cwd=REPO, check=True):
    done = subprocess.run(['git', *args], cwd=cwd, text=True, capture_output=True)
    if check and done.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {done.stderr.strip() or done.stdout.strip()}")
    return done.stdout


# ------------------------------------------------------------------ map: build


def package_name(package_dir):
    return posixpath.basename(package_dir.rstrip('/'))


def map_path(package_dir, cache=CACHE):
    return pathlib.Path(cache) / package_name(package_dir) / 'map.json.gz'


def uri_to_path(uri, package_roots, root):
    """Repo-relative path of a script URI from the VM (`package:raft_ui/src/x.dart`, `file:///.../test/a.dart`)."""
    if uri.startswith('package:'):
        name, _, rest = uri[len('package:'):].partition('/')
        base = package_roots.get(name)
        return None if base is None else posixpath.join(base, 'lib', rest)
    if uri.startswith('file://'):
        path = uri[len('file://'):]
        root = str(root).rstrip('/') + '/'
        return path[len(root):] if path.startswith(root) else None
    return None


def repo_relative(path, root):
    path = str(path)
    root = str(root).rstrip('/') + '/'
    return path[len(root):] if path.startswith(root) else path


def assemble(reports, root, package_roots, commit, package_dir, meta=None):
    """The map dict from probe reports (`[{'test', 'hits', 'misses'} | {'test', 'error'}]`).

    Line sets that recur (every line of a function the same tests ran) are stored once in `sets`;
    `lines[file]` is `[[line, set index], ...]` and `coverable[file]` the executable lines as ranges.
    """
    latest = {}
    for report in reports:  # oldest first: a rerun of a file replaces its earlier report
        latest[repo_relative(report.get('test', ''), root)] = report
    reports = list(latest.values())
    tests, errors = [], {}
    hits = collections.defaultdict(lambda: collections.defaultdict(set))
    coverable = collections.defaultdict(set)
    opened = collections.defaultdict(set)
    for report in reports:
        test = repo_relative(report.get('test', ''), root)
        if report.get('error') is not None:
            errors[test] = report['error']
            continue
        index = len(tests)
        tests.append(test)
        for key in ('hits', 'misses'):
            for uri, lines in (report.get(key) or {}).items():
                path = uri_to_path(uri, package_roots, root)
                if path is None:
                    continue
                coverable[path].update(lines)
                if key == 'hits':
                    for line in lines:
                        hits[path][line].add(index)
        for raw in report.get('paths') or ():
            path = opened_path(raw, root, package_roots)
            if path:
                opened[path].add(index)
    sets, set_index = [], {}
    lines_out = {}
    for path in sorted(hits):
        rows = []
        for line in sorted(hits[path]):
            key = tuple(sorted(hits[path][line]))
            if key not in set_index:
                set_index[key] = len(sets)
                sets.append(list(key))
            rows.append([line, set_index[key]])
        lines_out[path] = rows
    return {
        'version': MAP_VERSION, 'package': package_dir, 'commit': commit, **(meta or {}),
        'tests': tests, 'errors': errors, 'sets': sets, 'lines': lines_out,
        'coverable': {path: to_ranges(sorted(lines)) for path, lines in sorted(coverable.items())},
        'paths': {path: sorted(tests_) for path, tests_ in sorted(opened.items())},
    }


def opened_path(raw, root, package_roots):
    """Repo-relative source path of a path a test opened, or None (outside the repo, or a build output).

    `flutter test` serves a package's assets from `<package>/build/unit_test_assets/`; those map back
    to the asset sources (`packages/<name>/...` there is another package's asset).
    """
    path = posixpath.normpath(str(raw))
    root = str(root).rstrip('/')
    if not path.startswith(root + '/'):
        return None
    path = path[len(root) + 1:]
    for package in package_roots.values():
        prefix = f'{package}/build/unit_test_assets/'
        if path.startswith(prefix):
            rest = path[len(prefix):]
            if rest.startswith('packages/'):
                name, _, rest = rest[len('packages/'):].partition('/')
                return posixpath.join(package_roots[name], rest) if name in package_roots else None
            return posixpath.join(package, rest)
    if re.search(r'(^|/)(build|\.dart_tool)/', path):
        return None
    return path


def to_ranges(lines):
    ranges = []
    for line in lines:
        if ranges and ranges[-1][1] == line - 1:
            ranges[-1][1] = line
        else:
            ranges.append([line, line])
    return ranges


def write_map(data, path):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f'.tmp{os.getpid()}')
    with gzip.open(temporary, 'wt', encoding='utf-8') as handle:
        json.dump(data, handle, separators=(',', ':'))
    os.replace(temporary, path)


def read_reports(raw_dir):
    reports = []
    for file in sorted(pathlib.Path(raw_dir).glob('*.json'), key=lambda f: (f.stat().st_mtime, f.name)):
        try:
            reports.append(json.loads(file.read_text(encoding='utf-8')))
        except (OSError, ValueError) as error:
            reports.append({'test': file.name, 'error': f'unreadable report: {error}'})
    return reports


def suite_files(events_path, root):
    """`(test files that loaded, test files with a failure)` from a `--file-reporter json:` stream."""
    suites, tests, failed = {}, {}, set()
    try:
        lines = pathlib.Path(events_path).read_text(errors='replace').splitlines()
    except OSError:
        return set(), set()
    for raw in lines:
        try:
            event = json.loads(raw)
        except ValueError:
            continue
        kind = event.get('type') if isinstance(event, dict) else None
        if kind == 'suite':
            suites[event['suite']['id']] = repo_relative(event['suite'].get('path') or '', root)
        elif kind == 'testStart':
            tests[event['test']['id']] = event['test'].get('suiteID')
        elif kind == 'testDone' and event.get('result') not in ('success', None) and not event.get('skipped'):
            failed.add(suites.get(tests.get(event.get('testID')), ''))
    return set(suites.values()) - {''}, failed - {''}


def package_test_files(root, package_dir):
    """Repo-relative test files of a package that the Raft run executes (legacy-look files are tool/theme-suite's)."""
    import theme_looks
    root = pathlib.Path(root)
    found = sorted(p.relative_to(root).as_posix() for p in (root / package_dir / 'test').rglob('*_test.dart'))
    if package_name(package_dir) == 'raft_theme':
        return found
    return [f for f in found if theme_looks.runs_by_default(str(root / f))]


def impact_filters(root, package_roots):
    return ','.join([f'package:{name}/' for name in sorted(package_roots)] + [f'file://{pathlib.Path(root).resolve()}/'])


def impact_env(env, raw_dir, root, package_roots):
    env = dict(env)
    env['RAFT_TEST_IMPACT_DIR'] = str(raw_dir)
    env['RAFT_TEST_IMPACT_FILTERS'] = impact_filters(root, package_roots)
    return env


def ensure_probe_config(package_path, root):
    """Make the package's test/flutter_test_config.dart call the probe; returns a file to delete afterwards or None.

    The app and raft_ui configs call `recordTestImpact()` themselves; a package without a config gets a
    temporary one (marked, deleted after the build). A config that exists without the call is reported.
    """
    config = pathlib.Path(package_path) / 'test/flutter_test_config.dart'
    if config.is_file():
        text = config.read_text(encoding='utf-8')
        if 'recordTestImpact()' not in text:
            raise RuntimeError(f'{config}: has no recordTestImpact() call; the probe would not run')
        return None
    probe = os.path.relpath(pathlib.Path(root) / 'tool/testing/impact_probe.dart', config.parent).replace(os.sep, '/')
    config.write_text(f"""{TEMP_CONFIG_MARK}
import 'dart:async';

import '{probe}';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {{
  recordTestImpact();
  await testMain();
}}
""", encoding='utf-8')
    return config


def remove_temp_config(config):
    if config and config.is_file() and config.read_text(encoding='utf-8').startswith(TEMP_CONFIG_MARK):
        config.unlink()


def build(root, packages, jobs, tier, raw_root, cache=CACHE, commit=None, log=print, extra_args=(), rerun_failed=False, resume=False):
    """Run each package's suite with the probe on and write its map. Returns `[(package, map path, summary)]`.

    `rerun_failed` runs only the files the existing map lists as failed, adds their new reports to the
    kept probe reports of the first run, and writes the map again (a timed-out test under load leaves
    its file's lines incomplete; the selector distrusts such files until then). `resume` keeps the reports
    of an interrupted build and runs only the test files that have none yet.
    """
    import theme_looks
    root = pathlib.Path(root).resolve()
    package_roots = affected_tests.workspace_packages(root)
    commit = commit or git(['rev-parse', 'HEAD'], cwd=root).strip()
    dirty = [line[3:] for line in git(['status', '--porcelain', '--untracked-files=no'], cwd=root).splitlines()]
    results = []
    for package_dir in packages:
        package_path = root / package_dir
        raw = pathlib.Path(raw_root) / package_name(package_dir)
        events = raw.parent / f'{package_name(package_dir)}.events.json'
        files = ['test/']
        if rerun_failed:
            previous = ImpactMap.load(map_path(package_dir, cache)).data
            files = [os.path.relpath(root / f, package_path) for f in previous.get('failed', []) + previous.get('unreported', [])]
            if not files or not raw.is_dir():
                log(f'test-impact: {package_dir}: nothing to rerun' + ('' if raw.is_dir() else f' (no reports in {raw})'))
                continue
            events = raw.parent / f'{package_name(package_dir)}.rerun.events.json'
            commit = previous['commit']
        elif resume and raw.is_dir():
            done = {repo_relative(r.get('test', ''), root) for r in read_reports(raw)}
            files = [os.path.relpath(root / f, package_path) for f in package_test_files(root, package_dir) if f not in done]
            log(f'test-impact: {package_dir}: resuming, {len(done)} files reported, {len(files)} to run')
            if not files:
                continue
            for n in itertools.count(1):  # keep the interrupted run's events for its failures
                kept = raw.parent / f'{package_name(package_dir)}.events.{n}.json'
                if not kept.exists():
                    if events.exists():
                        events.rename(kept)
                    break
        else:
            shutil.rmtree(raw, ignore_errors=True)
            raw.mkdir(parents=True)
            for old in raw.parent.glob(f'{package_name(package_dir)}.events.*.json'):
                old.unlink()
        events.unlink(missing_ok=True)
        env = impact_env(os.environ, raw, root, package_roots)
        env['RAFT_TEST_LOOKS'] = 'raft'
        env.pop('RAFT_TEST_MODES', None)
        env.pop('RAFT_TEST_ALL_THEMES', None)
        if tier:
            env['RAFT_TEST_TIER'] = tier
        # The map build runs at the lowest priority on a shared machine: a test that waits for CPU past the
        # gate's 60 s bound times out, the rest of its file fails, and its lines are lost. The bound is for
        # hangs on the gate, not for this run.
        env.setdefault('RAFT_TEST_TIMEOUT_SECONDS', '600')
        cmd = [sys.executable, str(root / 'tool/flutter'), 'test', '--no-pub', '-j', str(jobs), '--enable-vmservice', '--no-dds',
               '--reporter', 'failures-only', '--file-reporter', f'json:{events}', *extra_args]
        if package_name(package_dir) != 'raft_theme':  # the engine package runs whole (as in the nightly)
            for look in theme_looks.LEGACY_LOOKS:
                cmd += ['-x', theme_looks.tag_look(look)]
        cmd += files
        temp = ensure_probe_config(package_path, root)
        started = time.monotonic()
        log(f'test-impact: {package_dir}: {" ".join(cmd[1:])}')
        try:
            with open(raw.parent / f'{package_name(package_dir)}.log', 'wb') as out:
                code = subprocess.run(cmd, cwd=package_path, env=env, stdout=out, stderr=subprocess.STDOUT).returncode
        finally:
            remove_temp_config(temp)
        if rerun_failed:
            loaded, still = suite_files(events, root)
            first = previous
            summary = assemble_run(root, package_dir, raw, None, commit, tier, (first.get('seconds') or 0) + time.monotonic() - started, cache,
                                   extra={'jobs': jobs, 'exit_code': code, 'dirty': first.get('dirty', []), 'built': first.get('built'),
                                          'reran': sorted(loaded)}, failed=still, unreported=set(first.get('unreported', [])) - loaded)
        else:
            earlier = sorted(raw.parent.glob(f'{package_name(package_dir)}.events.*.json'))
            summary = assemble_run(root, package_dir, raw, [*earlier, events], commit, tier, time.monotonic() - started, cache,
                                   extra={'jobs': jobs, 'exit_code': code, 'dirty': dirty, 'resumed': len(earlier) or None})
        log(f'test-impact: {package_dir}: {summary}')
        results.append((package_dir, map_path(package_dir, cache), summary))
    return results


def assemble_run(root, package_dir, raw, events, commit=None, tier='full', seconds=None, cache=CACHE, extra=None,
                 failed=None, unreported=None):
    """Write the map of one finished run (probe reports in `raw`) and return a one-line summary."""
    root = pathlib.Path(root).resolve()
    package_roots = affected_tests.workspace_packages(root)
    commit = commit or git(['rev-parse', 'HEAD'], cwd=root).strip()
    loaded, found_failed = set(), set()
    for stream in ([events] if isinstance(events, (str, os.PathLike)) else events or []):
        more_loaded, more_failed = suite_files(stream, root)
        found_failed = (found_failed - more_loaded) | more_failed  # a later run of a file decides
        loaded |= more_loaded
    meta = {'built': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'seconds': None if seconds is None else round(seconds), 'tier': tier or 'default'}
    meta.update({k: v for k, v in (extra or {}).items() if v is not None})
    data = assemble(read_reports(raw), root, package_roots, commit, package_dir, meta=meta)
    failed = found_failed if failed is None else failed
    data['failed'] = sorted(failed)
    data['unreported'] = sorted(unreported) if unreported is not None else sorted(loaded - set(data['tests']) - set(data['errors']))
    path = map_path(package_dir, cache)
    write_map(data, path)
    return (f"{len(data['tests'])} test files mapped, {len(data['errors'])} probe errors, {len(data['unreported'])} unreported, "
            f"{len(failed)} with failures, {len(data['lines'])} files with hits, "
            + (f'{round(seconds)}s, ' if seconds is not None else '') + f'{path.stat().st_size // 1024} KiB')


# ------------------------------------------------------------------ map: read


class ImpactMap:
    """One package's map: which test files executed each (file, line), and each file's executable lines."""

    def __init__(self, data, source=None):
        self.data = data
        self.source = source
        self.package = data.get('package', '')
        self.commit = data.get('commit', '')
        self.tests = data.get('tests', [])
        self.sets = [frozenset(s) for s in data.get('sets', [])]
        self.lines = {path: dict((line, index) for line, index in rows) for path, rows in data.get('lines', {}).items()}
        self.coverable = {path: [n for start, end in ranges for n in range(start, end + 1)]
                          for path, ranges in data.get('coverable', {}).items()}
        self.paths = data.get('paths', {})
        # A file with a failing or timed-out test may have stopped early: its lines are a lower bound.
        self.failed = set(data.get('failed', ()))
        self._file_tests = {}

    @classmethod
    def load(cls, path):
        with gzip.open(path, 'rt', encoding='utf-8') as handle:
            return cls(json.load(handle), source=str(path))

    def knows(self, path):
        return path in self.coverable

    def is_coverable(self, path, line):
        lines = self.coverable.get(path)
        if not lines:
            return False
        index = bisect.bisect_left(lines, line)
        return index < len(lines) and lines[index] == line

    def tests_at(self, path, line):
        index = self.lines.get(path, {}).get(line)
        return set() if index is None else {self.tests[t] for t in self.sets[index]}

    def neighbours(self, path, line):
        """The nearest executable lines at or above and at or below `line` (either may be None)."""
        lines = self.coverable.get(path) or []
        index = bisect.bisect_left(lines, line)
        below = lines[index] if index < len(lines) else None
        above = lines[index] if below == line else (lines[index - 1] if index else None)
        return above, below

    def tests_in_range(self, path, start, end):
        """Tests that ran any line of `path` from `start` to `end`."""
        lines = self.coverable.get(path) or []
        rows = self.lines.get(path, {})
        found = set()
        for line in lines[bisect.bisect_left(lines, start):bisect.bisect_right(lines, end)]:
            index = rows.get(line)
            if index is not None:
                found.update(self.sets[index])
        return {self.tests[t] for t in found}

    def file_tests(self, path):
        if path not in self._file_tests:
            found = set()
            for index in set(self.lines.get(path, {}).values()):
                found.update(self.sets[index])
            self._file_tests[path] = {self.tests[t] for t in found}
        return self._file_tests[path]

    def path_readers(self, path, is_dir):
        """Tests that opened `path`, or a recorded directory above it (a listing), through dart:io."""
        found = set(self.paths.get(path, ()))
        parts = path.split('/')
        for depth in range(3, len(parts)):  # deeper than `apps/<package>/`: the root walk opens those
            prefix = '/'.join(parts[:depth])
            if is_dir(prefix):
                found.update(self.paths.get(prefix, ()))
        return {self.tests[t] for t in found}


def load_maps(cache=CACHE):
    maps = []
    for path in sorted(pathlib.Path(cache).glob('*/map.json.gz')):
        try:
            loaded = ImpactMap.load(path)
        except (OSError, ValueError, EOFError) as error:
            print(f'test-impact: skipping unreadable map {path}: {error}', file=sys.stderr)
            continue
        if loaded.data.get('version') == MAP_VERSION:
            maps.append(loaded)
    return maps


# ------------------------------------------------------------------ diffs


HUNK = re.compile(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@')


class FileDiff:
    def __init__(self, old, new, status):
        self.old, self.new, self.status = old, new, status
        self.hunks = []  # [old_start, old_count, new_start, new_count, removed lines, added lines]
        self.binary = False

    @property
    def path(self):
        return self.new if self.status != 'D' else self.old


def parse_diff(text):
    """`[FileDiff]` from `git diff -U0 -M` output (paths from the `diff --git` / rename headers)."""
    files, current = [], None
    for raw in text.splitlines():
        if raw.startswith('diff --git '):
            match = re.match(r'^diff --git a/(.*) b/(.*)$', raw)
            current = FileDiff(match.group(1), match.group(2), 'M') if match else FileDiff('?', '?', 'M')
            files.append(current)
        elif current is None:
            continue
        elif raw.startswith('new file mode'):
            current.status, current.old = 'A', None
        elif raw.startswith('deleted file mode'):
            current.status, current.new = 'D', None
        elif raw.startswith('rename from '):
            current.status, current.old = 'R', raw[len('rename from '):]
        elif raw.startswith('rename to '):
            current.new = raw[len('rename to '):]
        elif raw.startswith('Binary files '):
            current.binary = True
        elif raw.startswith('@@'):
            match = HUNK.match(raw)
            if match:
                old_start, old_count, new_start, new_count = match.groups()
                current.hunks.append([int(old_start), 1 if old_count is None else int(old_count),
                                      int(new_start), 1 if new_count is None else int(new_count), [], []])
        elif current.hunks and raw.startswith('-') and not raw.startswith('--- '):
            current.hunks[-1][4].append(raw[1:])
        elif current.hunks and raw.startswith('+') and not raw.startswith('+++ '):
            current.hunks[-1][5].append(raw[1:])
    return files


class LineTranslator:
    """Maps line numbers of one commit's file onto another commit's file through `git diff -U0 -M <to> <from>`.

    A line the diff did not touch moves by the size difference of the hunks above it; a line inside a
    changed hunk maps to every line of the hunk on the other side (conservative); a file added since has no lines.
    """

    def __init__(self, diffs):
        self.by_new = {d.new: d for d in diffs if d.new}

    def path(self, path):
        diff = self.by_new.get(path)
        if diff is None:
            return path
        return None if diff.status == 'A' else diff.old

    def lines(self, path, line):
        diff = self.by_new.get(path)
        if diff is None:
            return [line]
        if diff.status == 'A':
            return []
        shift = 0
        for old_start, old_count, new_start, new_count, _, _ in diff.hunks:
            new_end = new_start + new_count - 1
            if new_count and new_start <= line <= new_end:
                return list(range(old_start, old_start + old_count)) or [old_start, old_start + 1]
            if (new_count and new_end < line) or (not new_count and new_start < line):
                shift += old_count - new_count
            else:
                break
        return [line + shift]


IDENTITY = LineTranslator([])


# ------------------------------------------------------------------ dart text


BLOCK_COMMENT = re.compile(r'^\s*(/\*.*|\*.*|.*\*/)\s*$')
DIRECTIVE_LINE = re.compile(r'^\s*(import|export|part|library)\b')
DECLARATIONS = (
    re.compile(r'^(?:(?:abstract|sealed|base|final|interface|mixin)\s+)*(?:class|mixin|enum|extension\s+type|extension|typedef)\s+(\w+)'),
    re.compile(r'^(?:(?:static|late|external|covariant|abstract)\s+)*(?:const|final|var)\s+(?:[\w<>?,. ]+?\s+)?(\w+)\s*(?:=|;|,|$)'),
    re.compile(r'^(?:(?:static|late|external|covariant)\s+)*[A-Z_a-z][\w<>?,. ]*?[\w>?]\s+(?:get\s+|set\s+)?(\w+)\s*(?:=|;|\(|=>|$)'),
    re.compile(r'^(?:const\s+|factory\s+|external\s+)*([A-Za-z_]\w*)(?:\.\w+)?\s*\('),
    re.compile(r'^([a-z]\w*)\s*(?:,|;)?$'),  # an enum value
)


TYPE_HEADER = DECLARATIONS[0]


FIELD_INITIALIZER = re.compile(r'^(?:late\s+)?(?:final\s+|var\s+)?(?:[\w<>?,. ]+?\s+)?\w+\s*=(?!>)')


def reaches_existing_callers(added):
    """Can class-level code inserted into an existing class run without a changed caller?

    An override (`@override`, or `==` / `hashCode` / `toString` / `noSuchMethod`) runs wherever the class is
    used, and an instance field initializer on every construction. A new method, getter or constructor runs
    only when something calls it, and that call is a changed line.
    """
    member = min(indent(t) for t in added)
    for text in added:
        stripped = text.strip()
        if '@override' in stripped or re.search(r'\b(operator\s*==|hashCode|toString|noSuchMethod)\b', stripped):
            return True
        if indent(text) == member and not stripped.startswith(('static ', 'const ', 'factory ')) and FIELD_INITIALIZER.match(stripped):
            return True
    return False


def enclosing_header(imap, path, lines, line, declaration, level, inserted):
    """The executable line that opens the innermost block around `line` inside the function at `declaration`.

    Walks up from `line` to the first code line indented less than `level` (the changed or inserted code);
    a line that is not executable (`} else {`, `try {`, a `case` label) hands over to the one above it at
    its own indentation. Returns None when the walk reaches the function's own declaration (the body's
    top level: the whole function is the unit) or the code is not formatted in blocks.
    """
    if level is None or level <= indent(lines[declaration - 1]) + 2:
        return None
    start = line if inserted else line - 1
    for number in range(start, declaration, -1):
        text = lines[number - 1]
        if not is_code(text) or indent(text) >= level:
            continue
        if imap.is_coverable(path, number) and not text.lstrip().startswith('}'):
            return number
        level = indent(text) + (1 if text.lstrip().startswith('}') else 0)
        if level <= indent(lines[declaration - 1]) + 2:
            return None
    return None


def declaration_end(lines, number):
    """Last line of the declaration starting at `number`: the line before the next code line at its indentation
    or less (its closing `}` included)."""
    level = indent(lines[number - 1])
    for index in range(number, len(lines)):
        text = lines[index]
        if is_code(text) and indent(text) <= level:
            return index + 1 if text.lstrip()[:1] in ')]}' else index
    return len(lines)


def is_function_declaration(lines, number):
    """True when the declaration at `number` has a body (a function, method, getter or constructor with code).

    Reads ahead to the first `{`, `=>` or `;` outside parentheses: `=>`, or `{` right after `)` / `async` /
    `get name`, is a body; `;` (a field, a const constructor) or any other `{` (class, enum, map literal) is not.
    """
    depth, text = 0, ''
    for line in lines[number - 1:number + 15]:
        code = re.sub(r"'[^']*'|\"[^\"]*\"", "''", line.split('//')[0])
        for index, char in enumerate(code):
            if char in '([':
                depth += 1
            elif char in ')]':
                depth -= 1
            elif depth == 0 and char == ';':
                return False
            elif depth == 0 and code.startswith('=>', index):
                return True
            elif depth == 0 and char == ':' and (text + code[:index]).rstrip().endswith(')'):
                # an initializer list: runtime code, unless the constructor is const (the VM reports no lines for those)
                return not lines[number - 1].lstrip().startswith('const ')
            elif depth == 0 and char == '{':
                before = (text + code[:index]).rstrip()
                return bool(re.search(r'(\)|\basync\*?|\bsync\*|\bget\s+\w+)$', before))
        text += code + ' '
    return False


def is_code(text):
    stripped = text.strip()
    return bool(stripped) and not stripped.startswith('//') and not BLOCK_COMMENT.match(text)


def code_lines(lines):
    """`[(index, text)]` of the lines that are code: no comments, blank lines or (multi-line) directives."""
    found, in_directive = [], False
    for index, text in enumerate(lines):
        if in_directive or is_directive(text):
            in_directive = ';' not in text.split('//')[0]
            continue
        if is_code(text):
            found.append((index, text))
    return found


def is_directive(text):
    return bool(DIRECTIVE_LINE.match(text))


def indent(text):
    return len(text) - len(text.lstrip(' '))


def declared_names(text):
    """Names a top-level or member declaration line declares (`const kGap = 4;` -> kGap)."""
    if indent(text) > 2:
        return []
    stripped = text.strip()
    stripped = re.sub(r'^@\w+(\([^)]*\))?\s*', '', stripped)
    names = []
    # `Type name = value,` / `Type name,` at this indentation is a parameter of a top-level function
    # (or an argument), not a declaration; an enum value (`name,`) is the only declaration ending in `,`.
    patterns = DECLARATIONS[-1:] if stripped.endswith(',') else DECLARATIONS
    for pattern in patterns:
        match = pattern.match(stripped)
        if match:
            names.append(match.group(1))
    return [n for n in dict.fromkeys(names) if n not in DART_KEYWORDS and n != 'main' and len(n.lstrip('_')) > 1]


# ------------------------------------------------------------------ selection


class Selection:
    def __init__(self):
        self.tests = collections.defaultdict(list)  # test file -> reasons
        self.notes = []
        self.warnings = []
        self.select_all = None
        self.unexecuted = set()  # changed lines in functions no test runs

    def add(self, tests, reason):
        for test in tests:
            reasons = self.tests[test]
            if reason not in reasons and len(reasons) < 6:
                reasons.append(reason)


REF_LIMIT = 150
DECL_DEPTH = 3


class Selector:
    """Builds a `Selection` for the diff `merge-base..head` (or the working tree) from the maps."""

    def __init__(self, root, maps, base, head='HEAD', worktree=False, absent='callers', now=None):
        self.root = pathlib.Path(root)
        self.maps = maps
        self.head = head
        self.worktree = worktree
        self.absent = absent
        self.now = now or time.time()
        self.merge_base = git(['merge-base', base, head], cwd=self.root).strip()
        self.selection = Selection()
        self._show = {}
        self._refs = {}
        self._graph = None
        self._translators = {}
        self._package_roots = None
        # Files the maps know completely; the rest go through the import graph (unmapped_tests).
        self.map_tests = set(t for m in maps for t in m.tests if t not in m.failed)

    # git helpers
    def diff(self):
        args = ['diff', '-U0', '-M', '--no-color', '--no-ext-diff', self.merge_base]
        if not self.worktree:
            args.append(self.head)
        files = parse_diff(git(args, cwd=self.root))
        if self.worktree:
            for path in git(['ls-files', '--others', '--exclude-standard'], cwd=self.root).splitlines():
                files.append(FileDiff(None, path, 'A'))
        return files

    def translator(self, commit):
        if commit == self.merge_base:
            return IDENTITY
        if commit not in self._translators:
            self._translators[commit] = LineTranslator(parse_diff(git(['diff', '-U0', '-M', '--no-color', '--no-ext-diff', commit, self.merge_base], cwd=self.root)))
        return self._translators[commit]

    def text_at(self, commit, path):
        key = (commit, path)
        if key not in self._show:
            done = subprocess.run(['git', 'show', f'{commit}:{path}'], cwd=self.root, capture_output=True)
            text = done.stdout.decode('utf-8', 'replace') if done.returncode == 0 else None
            if text is None and (self.root / path).is_file() and not self.tracked(path):
                text = (self.root / path).read_text(encoding='utf-8', errors='replace')  # a git-ignored generated file
            self._show[key] = text.splitlines() if text is not None else []
        return self._show[key]

    @functools.lru_cache(maxsize=None)
    def tracked(self, path):
        return subprocess.run(['git', 'ls-files', '--error-unmatch', path], cwd=self.root, capture_output=True).returncode == 0

    def is_dir(self, path):
        return (self.root / path).is_dir()

    def package_roots(self):
        if self._package_roots is None:
            self._package_roots = affected_tests.workspace_packages(self.root)
        return self._package_roots

    def graph(self):
        if self._graph is None:
            sources = affected_tests.tracked_dart_sources(self.root)
            if self.worktree:
                for path in git(['ls-files', '--others', '--exclude-standard', '--', '*.dart'], cwd=self.root).splitlines():
                    sources[path] = (self.root / path).read_text(encoding='utf-8', errors='replace')
            for generated, _ in GENERATED:
                if (self.root / generated).is_file():
                    sources[generated] = (self.root / generated).read_text(encoding='utf-8', errors='replace')
            self._graph = affected_tests.build_graph(sources, self.package_roots())
        return self._graph

    def importers(self, paths, through_tests_only=False):
        """Test files that reach `paths` by imports (only through test-directory files when asked)."""
        reverse = affected_tests.reverse_graph(self.graph())
        seen, stack = set(paths), list(paths)
        while stack:
            for parent in reverse.get(stack.pop(), ()):
                if parent in seen or (through_tests_only and not is_test_code(parent)):
                    continue
                seen.add(parent)
                stack.append(parent)
        return {f for f in seen if affected_tests.is_test_file(f)}

    def references(self, commit, name):
        """`[(path, line, text)]` of whole-word mentions of `name` in Dart files at `commit` (plus generated files)."""
        key = (commit, name)
        if key not in self._refs:
            done = subprocess.run(['git', 'grep', '-n', '-w', '-F', '-I', '-e', name, commit, '--', '*.dart'], cwd=self.root,
                                  capture_output=True, text=True, errors='replace')
            found = []
            for raw in done.stdout.splitlines():
                _, _, rest = raw.partition(':')
                path, _, rest = rest.partition(':')
                number, _, text = rest.partition(':')
                if number.isdigit():
                    found.append((path, int(number), text))
            for generated, _ in GENERATED:
                for number, text in enumerate(self.text_at(commit, generated) if not self.tracked(generated) else [], 1):
                    if re.search(rf'\b{re.escape(name)}\b', text):
                        found.append((generated, number, text))
            self._refs[key] = found
        return self._refs[key]

    # line-level
    def line_tests(self, imap, path, line, reason, depth=0):
        """Tests for one map line: those that ran it, or (not executable) those that ran what contains it."""
        if imap.is_coverable(path, line):
            self.selection.add(imap.tests_at(path, line), reason)
            return
        text_lines = self.text_at(imap.commit, path)
        text = text_lines[line - 1] if 0 < line <= len(text_lines) else ''
        if text and not is_code(text):
            return
        self.context_tests(imap, path, line, reason, depth, inserted=False, level=indent(text) if text else None)

    def context_tests(self, imap, path, line, reason, depth, inserted, level=None, added=()):
        """A line no test can execute by itself (a declaration, a const, an `else`) or the point new code goes in.

        Inside a function: every test that ran any line of the function (a test that reaches the line must
        enter the function; the neighbouring lines are not enough, a new `case` runs where a `default` did).
        At class level (a new override, a field): every test that ran any line of the class. A constant,
        field or const constructor: the tests that run the lines that use the name.
        """
        text_lines = self.text_at(imap.commit, path)
        if inserted and level is not None:
            declaration = self.enclosing_declaration_above(text_lines, line, level)
        else:
            declaration = self.enclosing_declaration(text_lines, line)
        if declaration is None:
            if not inserted:
                self.selection.add(imap.file_tests(path), f'{reason} (tests that ran {path})')
            return  # new top-level code: only changed code can call it
        number, names = declaration
        if is_function_declaration(text_lines, number):
            header = enclosing_header(imap, path, text_lines, line, number, level, inserted)
            if header is not None:
                # inside a block: a test reaches the line only through the block's own executable header
                self.selection.add(imap.tests_at(path, header), f'{reason} (tests that ran its block {path}:{header})')
                return
            end = declaration_end(text_lines, number)
            tests = imap.tests_in_range(path, number, end)
            if tests:
                self.selection.add(tests, f'{reason} (tests that ran {path}:{number}-{end})')
            else:
                self.selection.unexecuted.add(f'{path}:{number}')  # a function no test runs
            return
        if TYPE_HEADER.match(text_lines[number - 1].strip()):
            if inserted and added and not reaches_existing_callers(added):
                self.selection.notes.append(f'{reason}: new members only (no override, no field initializer); reached through changed code')
                return
            end = declaration_end(text_lines, number)
            tests = imap.tests_in_range(path, number, end)
            self.selection.add(tests, f'{reason} (tests that ran {path}:{number}-{end})')
            if tests and (inserted or line != number):
                return
        if depth >= DECL_DEPTH or not names:
            self.selection.add(imap.file_tests(path), f'{reason} (declaration; tests that ran {path})')
            return
        for name in names:
            self.declaration_tests(imap, path, name, reason, depth)

    def declaration_tests(self, imap, path, name, reason, depth):
        refs = [r for r in self.references(imap.commit, name) if is_code(r[2]) and not is_directive(r[2])
                and (not name.startswith('_') or r[0] == path)]  # a private name is the library's own
        if len(refs) > REF_LIMIT:
            # Too many to follow line by line. The tests that ran the declaring file stand in for its users;
            # a file nothing executes (constants only) hands over to the tests that ran the files using the name.
            tests = set().union(*(m.file_tests(path) for m in self.maps))
            label = f'{reason} (`{name}` has {len(refs)} references; tests that ran {path})'
            if not tests:
                users = {ref_path for ref_path, _, _ in refs if ref_path != path}
                tests = set().union(set(), *(m.file_tests(u) for m in self.maps for u in users))
                tests |= {u for u in users if affected_tests.is_test_file(u)}
                label = f'{reason} (`{name}` has {len(refs)} references; tests that ran the {len(users)} files using it)'
            self.selection.add(tests, label)
            return
        for ref_path, number, text in refs:
            label = f'{reason} (`{name}` used at {ref_path}:{number})'
            if affected_tests.is_test_file(ref_path):
                self.selection.add([ref_path], label)
            if ref_path == path and number in self._decl_lines(imap, path, name):
                continue
            for other in self.maps:
                if other.knows(ref_path):
                    self.line_tests(other, ref_path, number, label, depth + 1)

    def _decl_lines(self, imap, path, name):
        lines = self.text_at(imap.commit, path)
        return {i for i, text in enumerate(lines, 1) if name in declared_names(text)}

    @staticmethod
    def enclosing_declaration_above(lines, line, level):
        """For code inserted after `line` at indentation `level`: the declaration it goes into, or None (top level)."""
        for number in range(min(line, len(lines)), 0, -1):
            candidate = lines[number - 1]
            if not is_code(candidate) or indent(candidate) >= level or candidate.lstrip()[:1] in ')]}':
                continue
            if indent(candidate) <= 2:
                names = declared_names(candidate)
                if names:
                    return number, names
            level = indent(candidate)
            if level == 0:
                return None
        return None

    @staticmethod
    def enclosing_declaration(lines, line):
        """`(line, names)` of the top-level or member declaration that contains `line`, or None."""
        if not 0 < line <= len(lines):
            return None
        text = lines[line - 1]
        level = indent(text) if is_code(text) else 99
        if level <= 2:
            names = declared_names(text)
            if names:
                return line, names
        for number in range(line - 1, max(0, line - 3000), -1):
            candidate = lines[number - 1]
            if not is_code(candidate) or indent(candidate) >= level or candidate.lstrip()[:1] in ')]}':
                continue  # deeper, or the closing part of a parameter list (`}) : x = y {`)
            level = indent(candidate)
            if level <= 2:
                names = declared_names(candidate)
                if names:
                    return number, names
            if level == 0:
                return None
        return None

    def hunk_tests(self, file_diff, path):
        """Line-level selection for one changed Dart file that the maps know."""
        known = [m for m in self.maps if m.knows(self.translator(m.commit).path(path) or '')]
        for imap in known:
            translate = self.translator(imap.commit)
            map_path_ = translate.path(path)
            for old_start, old_count, new_start, new_count, removed, added in file_diff.hunks:
                code_removed = [(old_start + i, text) for i, text in code_lines(removed)]
                code_added = [text for _, text in code_lines(added)]
                for number, _ in code_removed:
                    for line in translate.lines(path, number):
                        self.line_tests(imap, map_path_, line, f'changes {path}:{number}')
                if code_added and not code_removed:
                    # inserted after `old_start` (or in place of comments): what contains the insertion point
                    anchor = old_start if old_count == 0 else old_start - 1
                    level = min(indent(text) for text in code_added)
                    for line in translate.lines(path, max(anchor, 1)):
                        self.context_tests(imap, map_path_, line, f'inserts code at {path}:{new_start}', 0, inserted=True, level=level,
                                           added=code_added)
        return bool(known)

    # file-level rules
    def absent_tests(self, file_diff, path):
        """A Dart file no map has lines of: new, or no test ever executed it."""
        if affected_tests.is_test_file(path):
            return  # a changed test file is selected itself
        if file_diff.status == 'M' and not any(code_lines(h[4]) or code_lines(h[5]) for h in file_diff.hunks):
            self.selection.notes.append(f'{path}: only import/export lines or comments changed (compile effects are `flutter analyze`\'s)')
            return
        if file_diff.status != 'A':
            # existing, never executed: its declarations may still be used (constants, catalogs)
            commit = self.maps[0].commit if self.maps else self.merge_base
            before = self.text_at(commit, path)
            names = sorted({n for text in before for n in declared_names(text) if indent(text) == 0})
            for imap in self.maps[:1]:
                for name in names[:40]:
                    self.declaration_tests(imap, path, name, f'changes {path} (no test executes it; uses of `{name}`)', 1)
        tests = self.importers({path}, through_tests_only=True)
        self.selection.add(tests, f'imports {path} (new or never executed) through test code')
        if self.absent == 'import-graph':
            self.selection.add(self.importers({path}), f'reaches {path} by imports (new or never executed)')
        elif file_diff.status == 'A' and not is_test_code(path):
            self.selection.notes.append(f'{path}: new file; covered through the changed lines that call it (--absent import-graph adds its import closure)')

    def path_tests(self, path):
        """Tests that open `path` through dart:io or mention it in their source; lib lines that mention it."""
        for imap in self.maps:
            self.selection.add(imap.path_readers(path, self.is_dir), f'opens {path} (recorded file access)')
        needles = {path}
        for package in self.package_roots().values():
            if path.startswith(package + '/'):
                needles.add(path[len(package) + 1:])
        base = posixpath.basename(path)
        if len(base) >= 8 and '.' in base and not base.endswith('.dart'):
            needles.add(base)
        args = ['grep', '-n', '-F', '-I']
        for needle in sorted(needles):
            args += ['-e', needle]
        done = subprocess.run(['git', *args, '--', '*.dart'], cwd=self.root, capture_output=True, text=True, errors='replace')
        for raw in done.stdout.splitlines():
            ref_path, _, rest = raw.partition(':')
            number, _, text = rest.partition(':')
            if not number.isdigit() or ref_path == path:
                continue
            label = f'mentions {path} ({ref_path}:{number})'
            if affected_tests.is_test_file(ref_path):
                self.selection.add([ref_path], label)
            for imap in self.maps:
                if imap.knows(ref_path):
                    self.line_tests(imap, ref_path, int(number), label, DECL_DEPTH - 1)

    def run(self):
        sel = self.selection
        self.check_maps()
        diffs = self.diff()
        changed_dart = set()
        for file_diff in diffs:
            path = file_diff.path
            if GLOBAL_INPUTS.search(path):
                if only_adds_dependencies(file_diff):
                    sel.notes.append(f'{path}: only adds packages; nothing unchanged imports them, so no test is selected for it')
                else:
                    sel.select_all = f'{path} is an input of every test file'
                continue
            if path.endswith('.dart'):
                if file_diff.status != 'M' or any(code_lines(h[4]) or code_lines(h[5]) for h in file_diff.hunks):
                    changed_dart.add(path)
                if path.startswith('tool/') and not path.startswith('tool/testing/'):
                    sel.notes.append(f'{path}: tool code, not part of the flutter suites')
                    continue
                if re.search(r'(^|/)integration_test/', path):
                    sel.notes.append(f'{path}: integration_test runs on a device, not selected here')
                    continue
                if affected_tests.is_test_file(path) and file_diff.status != 'D':
                    sel.add([path], 'changed test file')
                for generated, inputs in GENERATED:
                    # the generated index lists its inputs: it changes when one is added, removed or renamed
                    if file_diff.status in 'ADR' and (inputs.match(path) or (file_diff.old and inputs.match(file_diff.old))):
                        for imap in self.maps:
                            sel.add(imap.file_tests(generated), f'{path} feeds the generated {generated}')
                if file_diff.status == 'D' or self.hunk_tests(file_diff, file_diff.old if file_diff.status == 'R' else path):
                    if file_diff.status == 'D':
                        for imap in self.maps:
                            sel.add(imap.file_tests(self.translator(imap.commit).path(path) or path), f'deletes {path}')
                else:
                    self.absent_tests(file_diff, path)
            elif path.startswith('tool/') and path.endswith('.py'):
                sel.notes.append(f'{path}: tool script (tool/tests), not part of the flutter suites')
            self.path_tests(path)
        self.unmapped_tests(changed_dart)
        return sel

    def unmapped_tests(self, changed_dart):
        """Test files the maps do not know (probe failed, package without a map) that import a changed file."""
        import theme_looks
        existing = set(all_test_files(self.root))
        if self.worktree:
            existing |= {f for f in git(['ls-files', '--others', '--exclude-standard', '--', '*_test.dart'], cwd=self.root).splitlines()
                         if affected_tests.is_test_file(f)}
        unknown = existing - self.map_tests
        legacy = {f for f in unknown if not theme_looks.runs_by_default(str(self.root / f))}
        unknown -= legacy
        if not unknown:
            return
        reach = self.importers(changed_dart) & unknown
        self.selection.add(reach, 'not in the map; reaches a changed file by imports')
        if unknown:
            failed = sum(1 for f in unknown if any(f in m.failed for m in self.maps))
            self.selection.notes.append(f'{len(unknown)} test files are not in any map or failed while it was built'
                                        f' ({failed} failed; import-graph fallback for them)'
                                        + (f'; {len(legacy)} legacy-look files left to tool/theme-suite' if legacy else ''))

    def check_maps(self):
        if not self.maps:
            self.selection.warnings.append('no impact map: run `tool/test-impact build` (the nightly refreshes it)')
            self.selection.select_all = 'no impact map'
            return
        for imap in self.maps:
            commit = imap.commit
            resolved = subprocess.run(['git', 'rev-parse', '--verify', '-q', f'{commit}^{{commit}}'], cwd=self.root, capture_output=True, text=True)
            if resolved.returncode != 0:
                self.selection.warnings.append(f'stale map {imap.package}: commit {commit[:12]} is not in this clone (fetch, or rebuild)')
                self.selection.select_all = f'map commit {commit[:12]} unknown'
                continue
            imap.commit = resolved.stdout.strip()
            if subprocess.run(['git', 'merge-base', '--is-ancestor', imap.commit, self.head], cwd=self.root).returncode != 0:
                self.selection.warnings.append(f'stale map {imap.package}: {imap.commit[:12]} is not an ancestor of {self.head}; lines are translated through the diff')
            built = imap.data.get('built')
            if built:
                age = self.now - datetime.datetime.strptime(built, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()
                if age > STALE_HOURS * 3600:
                    self.selection.warnings.append(f'stale map {imap.package}: built {age / 3600:.0f}h ago ({built})')


def only_adds_dependencies(file_diff):
    """True for a pubspec.yaml / pubspec.lock edit that adds lines and changes or removes none (new packages)."""
    if posixpath.basename(file_diff.path) not in ('pubspec.yaml', 'pubspec.lock') or file_diff.status != 'M' or not file_diff.hunks:
        return False
    return all(not removed for _, _, _, _, removed, _ in file_diff.hunks)


def is_test_code(path):
    return bool(re.search(r'(^|/)(test|test_driver)/', path))


def all_test_files(root):
    return sorted(f for f in git(['ls-files', '--', '*_test.dart'], cwd=root).splitlines() if affected_tests.is_test_file(f))


def render(selection, root, maps, merge_base, fmt='text', package=None):
    import theme_looks
    if selection.select_all:
        tests = {t: [f'all: {selection.select_all}'] for t in all_test_files(root)}
    else:
        tests = selection.tests
    tests = {t: r for t, r in tests.items() if (pathlib.Path(root) / t).is_file() and theme_looks.runs_by_default(str(pathlib.Path(root) / t))}
    if package:
        prefix = package.rstrip('/') + '/'
        tests = {t[len(prefix):]: r for t, r in tests.items() if t.startswith(prefix)}
    if fmt == 'files':
        return '\n'.join(sorted(tests)) + ('\n' if tests else '')
    if fmt == 'json':
        return json.dumps({'merge_base': merge_base, 'maps': {m.package: m.commit for m in maps}, 'select_all': selection.select_all, 'unexecuted': sorted(selection.unexecuted),
                           'tests': {t: r for t, r in sorted(tests.items())}, 'warnings': selection.warnings, 'notes': selection.notes},
                          ensure_ascii=False, indent=1) + '\n'
    out = []
    for warning in selection.warnings:
        out.append(f'WARNING: {warning}')
    by_package = collections.Counter(t.split('/test/')[0] for t in tests)
    out.append(f"test-impact: {len(tests)} test files selected (merge-base {merge_base[:10]}; maps: "
               + ', '.join(f'{m.package}@{m.commit[:10]}' for m in maps) + ')')
    for name, count in sorted(by_package.items()):
        out.append(f'  {name}: {count}')
    if selection.select_all:
        out.append(f'  all test files: {selection.select_all}')
    for test, reasons in sorted(tests.items()):
        out.append(f'{test}')
        for reason in reasons[:3]:
            out.append(f'    {reason}')
    if selection.unexecuted:
        shown = sorted(selection.unexecuted)
        out.append(f"note: {len(shown)} changed declarations are in functions no test runs (no test can select them): "
                   + ', '.join(shown[:8]) + (' ...' if len(shown) > 8 else ''))
    for note in selection.notes:
        out.append(f'note: {note}')
    return '\n'.join(out) + '\n'


# ------------------------------------------------------------------ command line


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    b = sub.add_parser('build', help='run the suites with the coverage probe and write the maps')
    b.add_argument('--root', default=str(REPO))
    b.add_argument('--package', action='append', dest='packages', metavar='DIR', help=f'repeatable; default {" ".join(DEFAULT_PACKAGES)}')
    b.add_argument('--jobs', type=int, default=4)
    b.add_argument('--tier', default='full', help="RAFT_TEST_TIER for the run (default full: a superset of the gate's cases)")
    b.add_argument('--raw-dir', default=None, help='probe reports (default $TMPDIR/test-impact-raw)')
    b.add_argument('--cache', default=str(CACHE))
    b.add_argument('--commit', default=None, help='commit to stamp (default HEAD of --root)')
    b.add_argument('--rerun-failed', action='store_true', help="rerun only the map's failed / unreported files and rewrite the map")
    b.add_argument('--resume', action='store_true', help='keep the reports of an interrupted build; run only the files without one')
    a = sub.add_parser('assemble', help='write a map from probe reports of a run that already happened (the nightly)')
    a.add_argument('--root', default=str(REPO))
    a.add_argument('--package', required=True, metavar='DIR')
    a.add_argument('--raw-dir', required=True, help="the run's RAFT_TEST_IMPACT_DIR")
    a.add_argument('--events', default=None, help="the run's --file-reporter json: file (failed / unreported files)")
    a.add_argument('--commit', default=None)
    a.add_argument('--tier', default='full')
    a.add_argument('--seconds', type=float, default=None)
    a.add_argument('--cache', default=str(CACHE))
    s = sub.add_parser('select', help='the test files a diff touches, with reasons')
    s.add_argument('--root', default=None, help='repository (default: the current git worktree)')
    s.add_argument('--base', default=DEFAULT_BASE)
    s.add_argument('--head', default='HEAD')
    s.add_argument('--worktree', action='store_true', help='diff the working tree (uncommitted and untracked files) instead of HEAD')
    s.add_argument('--absent', choices=('callers', 'import-graph'), default='callers',
                   help='new / never executed Dart files: rely on their changed call sites (default) or add their whole import closure')
    s.add_argument('--format', choices=('text', 'files', 'json'), default='text')
    s.add_argument('--package', default=None, help='only this package\'s tests, as paths relative to it (for `flutter test`)')
    s.add_argument('--cache', default=str(CACHE))
    sub.add_parser('show', help='the maps in the cache').add_argument('--cache', default=str(CACHE))
    args = parser.parse_args(argv)
    if args.command == 'select':
        root = args.root or git(['rev-parse', '--show-toplevel'], cwd=os.getcwd()).strip()
        maps = load_maps(args.cache)
        selector = Selector(root, maps, args.base, args.head, args.worktree, args.absent)
        selection = selector.run()
        sys.stdout.write(render(selection, root, maps, selector.merge_base, args.format, args.package))
        for warning in selection.warnings if args.format == 'files' else ():
            print(f'test-impact: WARNING: {warning}', file=sys.stderr)
        return 0
    if args.command == 'show':
        for imap in load_maps(args.cache):
            d = imap.data
            print(f"{imap.package}: commit {imap.commit[:12]}, built {d.get('built')}, {len(imap.tests)} tests, "
                  f"{len(imap.lines)} files, {d.get('seconds')}s, tier {d.get('tier')}, {imap.source}")
        return 0
    if args.command == 'assemble':
        print(assemble_run(args.root, args.package, args.raw_dir, args.events, args.commit, args.tier, args.seconds, args.cache))
        return 0
    if args.command == 'build':
        raw = args.raw_dir or os.path.join(os.environ.get('TMPDIR') or '/tmp', 'test-impact-raw')
        build(args.root, args.packages or list(DEFAULT_PACKAGES), args.jobs, args.tier, raw, args.cache, args.commit,
              rerun_failed=args.rerun_failed, resume=args.resume)
        return 0
    return 2


if __name__ == '__main__':
    sys.exit(main())
