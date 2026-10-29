#!/usr/bin/env python3
"""Per-file budget for the Dart test suite, a ratchet like tool/ds-audit-baseline.json.

A test file that declares more than MAX_CASES cases is expensive enough to need a decision. It must either

  * start with `@Tags(['slow'])` (a long scenario the gate runs only when the diff reaches it, see
    tool/check-project), or
  * carry the marker comment `// matrix: nightly-full` (the file cuts its matrix on the gate and the
    nightly runs the whole product, see raftFullMatrix in packages/raft_ui/lib/test_themes.dart), or
  * carry the marker comment `// budget: per-surface` (a registry audit with one case per registered
    surface, such as the text-scale audits: every new @RaftPreviews preview must add its cases there, so
    the file grows by design), or
  * be listed in tool/test-budget-baseline.json, the files that were over the limit when the budget
    started. That list only shrinks: a listed file may not gain cases, and nothing is added to it.

Seconds only warn. A file's run time on the gate depends on what the other shards are doing (one file measured
52 s and 90 s on two gates with no change), so a seconds limit would fail gates at random. A file that runs past
MAX_SECONDS, or a listed file that runs far past its entry, is reported as a warning for the integration owner.

The numbers come from `.local/check-durations.json`, which tool/check-project rewrites after every run; the
gate calls `check()` with the files it just ran, so a new over-budget file fails the gate that first runs it.
By hand:

  tool/test_budget.py --check [--durations .local/check-durations.json]
  tool/test_budget.py --update-baseline    lower the baseline to the current numbers and drop files that no longer need an entry
  tool/test_budget.py --bootstrap CASES    write a first baseline from a {file: {cases, seconds}} JSON (only when none exists)

Feature branches never edit the baseline (parallel branches lowering the same file would conflict); the
integration owner runs --update-baseline after merges, like tool/ds-audit.
"""
import argparse
import json
import pathlib
import posixpath
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import affected_tests  # noqa: E402
import test_events  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASELINE = ROOT / 'tool/test-budget-baseline.json'
DURATIONS = ROOT / '.local/check-durations.json'
MAX_SECONDS = 30.0
MAX_CASES = 60
SECONDS_SLACK = 1.5  # a listed file's run time is noisy (a loaded machine): it may grow 50% + 10 s before it counts
SECONDS_MARGIN = 10.0
SLOW_TAG = re.compile(r"""^@Tags\(\s*\[[^\]]*['"]slow['"]""", re.M)
MARKER = re.compile(r'^\s*//\s*matrix:\s*nightly-full\b', re.M)
PER_SURFACE = re.compile(r'^\s*//\s*budget:\s*per-surface\b', re.M)
HEAD_BYTES = 16384  # the tag precedes the imports


def is_exempt(path):
    """True when the file carries the slow tag (in its head), or the nightly-full or per-surface marker (anywhere)."""
    try:
        text = pathlib.Path(path).read_text(encoding='utf-8', errors='replace')
    except OSError:
        return False
    return bool(SLOW_TAG.search(text[:HEAD_BYTES]) or MARKER.search(text) or PER_SURFACE.search(text))


def measure(durations):
    """`{repo path: {'cases', 'seconds'}}` from the `files` of check-durations.json (run seconds exclude the load)."""
    found = {}
    for name, entry in durations.items():
        if not isinstance(entry, dict) or not entry.get('tests'):
            continue
        found[name] = {'cases': int(entry['tests']), 'seconds': round(max(0.0, entry.get('seconds', 0.0) - entry.get('loadSeconds', 0.0)), 1)}
    return found


def over_limit(entry):
    return entry['cases'] > MAX_CASES or entry['seconds'] > MAX_SECONDS


def over_cases(entry):
    return entry['cases'] > MAX_CASES


def check(measured, baseline, exempt=is_exempt, exists=lambda name: True):
    """{'violations': [...], 'warnings': [...], 'notes': [...]} for the freshly measured files.

    A violation (fails the gate): a file over MAX_CASES that is neither exempt nor listed, or a listed file
    that gained cases. A warning (never a failure): a non-exempt file over MAX_SECONDS, or a listed file that
    ran far longer than its entry. A note: a listed file that no longer needs its entry.
    """
    listed = baseline.get('files', {})
    violations, warnings, notes = [], [], []
    for name, now in sorted(measured.items()):
        entry = listed.get(name)
        if entry is None:
            if exempt(name):
                continue
            if over_cases(now):
                violations.append(
                    f"{name}: {now['cases']} cases (limit {MAX_CASES}). "
                    "Cut the matrix on the gate and mark it `// matrix: nightly-full`, tag it `@Tags(['slow'])` if it is a long "
                    'scenario, or split it.')
            elif now['seconds'] > MAX_SECONDS:
                warnings.append(f"{name}: ran {now['seconds']:.0f} s (limit {MAX_SECONDS:.0f} s).")
            continue
        if exempt(name):
            continue  # tagged or marked since it was listed: the note below says its entry can go
        if now['cases'] > entry['cases']:
            violations.append(f"{name}: grew from {entry['cases']} to {now['cases']} cases; a file listed in tool/test-budget-baseline.json may only shrink.")
        elif now['seconds'] > entry['seconds'] * SECONDS_SLACK + SECONDS_MARGIN:
            warnings.append(f"{name}: ran {now['seconds']:.0f} s, listed at {entry['seconds']:.0f} s.")
    for name in sorted(listed):
        if not exists(name):
            notes.append(f'{name}: listed in the baseline but gone; run tool/test_budget.py --update-baseline')
        elif exempt(name):
            notes.append(f'{name}: now slow-tagged or marked nightly-full; its baseline entry can go (tool/test_budget.py --update-baseline)')
        elif name in measured and not over_limit(measured[name]):
            notes.append(f'{name}: back under the limit; its baseline entry can go (tool/test_budget.py --update-baseline)')
    return {'violations': violations, 'warnings': warnings, 'notes': notes}


def check_measured(measured, baseline, exempt=is_exempt, exists=lambda name: True):
    """`check()` for a partial run (preflight): only the baseline entries of the measured files take part,
    so the notes about listed files nobody touched stay out."""
    listed = {name: entry for name, entry in baseline.get('files', {}).items() if name in measured}
    return check(measured, {**baseline, 'files': listed}, exempt, exists)


def lowered(baseline, measured, exempt=is_exempt, exists=lambda name: True):
    """The baseline after `--update-baseline`: entries only get smaller or disappear, none is added."""
    files = {}
    for name, entry in baseline.get('files', {}).items():
        if not exists(name) or exempt(name):
            continue
        now = measured.get(name)
        if now is not None and not over_limit(now):
            continue
        files[name] = {'cases': min(entry['cases'], now['cases']) if now else entry['cases'],
                       'seconds': min(entry['seconds'], now['seconds']) if now else entry['seconds']}
    return {**baseline, 'files': dict(sorted(files.items()))}


def read_json(path):
    try:
        return json.loads(pathlib.Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def load_baseline(path=BASELINE):
    data = read_json(path)
    return data if isinstance(data.get('files'), dict) else {'version': 1, 'files': {}}


def write_baseline(data, path=BASELINE):
    pathlib.Path(path).write_text(json.dumps(data, indent=1, sort_keys=True) + '\n', encoding='utf-8')


def new_baseline(cases):
    """A first baseline: every file of `{name: {cases, seconds}}` that is over the limit and not exempt."""
    about = ('Ratchet for tool/test_budget.py. Files over the budget when it started; entries only shrink or go. Feature '
             'branches never edit this file; the integration owner runs `tool/test_budget.py --update-baseline` after merges.')
    return {'version': 1, 'about': about, 'limits': {'cases': MAX_CASES, 'seconds': MAX_SECONDS},
            'files': {name: dict(entry) for name, entry in sorted(cases.items()) if over_limit(entry) and not is_exempt(ROOT / name)}}


def measure_events(lines, to_repo_path=lambda p: p):
    """`measure()` of a JSON-reporter stream: the cases each file declares, counted as the full check counts them
    (tool/check-project folds the shard streams with the same test_events functions)."""
    return measure(test_events.file_durations(test_events.parse_test_events(lines, to_repo_path)))


def budget_files(changed, sources, package_roots, test_dirs):
    """Test files (repo-relative `*_test.dart` under `test_dirs`) whose case count a change can move.

    A changed `*_test.dart` file counts itself. A suite spread over files with `support/test_parts.dart`
    declares its cases in one registering file and runs them from part files that only import it
    (`image_viewer_part2_test.dart` imports `registerImageViewerTests`): when a changed file is imported
    by a part file, every such part is counted too, since a case added to the registering file moves the
    claims between all the parts. `sources` maps repo path -> Dart text.
    """
    def in_suite(name):
        return name.endswith('_test.dart') and any(name.startswith(d + '/') for d in test_dirs)

    changed = set(changed)
    found = {name for name in changed if in_suite(name)}
    for name, text in sources.items():
        if name in found or not in_suite(name) or 'TestPart' not in text:
            continue
        for uri in affected_tests.directive_targets(text):
            if affected_tests.resolve(uri, name, package_roots) in changed:
                found.add(name)
                break
    return sorted(found)


def report_lines(result, measured_count):
    """The lines both checks print: notes, warnings, `FAIL` lines, then the totals."""
    lines = [f'test-budget: note: {line}' for line in result['notes']]
    lines += [f'test-budget: warning: {line}' for line in result['warnings']]
    lines += [f'test-budget: FAIL {line}' for line in result['violations']]
    lines.append(f"test-budget: {measured_count} files measured, {len(result['violations'])} over budget, {len(result['warnings'])} slow warnings.")
    return lines


def run_check(durations_path, baseline_path=BASELINE):
    measured = measure(read_json(durations_path).get('files', {}))
    result = check(measured, load_baseline(baseline_path), lambda name: is_exempt(ROOT / name), lambda name: (ROOT / name).is_file())
    for line in report_lines(result, len(measured)):
        print(line)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--durations', default=str(DURATIONS))
    parser.add_argument('--baseline', default=str(BASELINE))
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--check', action='store_true', help='the default')
    group.add_argument('--update-baseline', action='store_true')
    group.add_argument('--bootstrap', metavar='CASES_JSON')
    args = parser.parse_args(argv)
    baseline_path = pathlib.Path(args.baseline)
    if args.bootstrap:
        if baseline_path.exists():
            raise SystemExit(f'{baseline_path} exists; the baseline only shrinks, edit it with --update-baseline.')
        write_baseline(new_baseline(read_json(args.bootstrap)), baseline_path)
        print(f'wrote {baseline_path}')
        return 0
    if args.update_baseline:
        measured = measure(read_json(args.durations).get('files', {}))
        write_baseline(lowered(load_baseline(baseline_path), measured, lambda name: is_exempt(ROOT / name), lambda name: (ROOT / name).is_file()), baseline_path)
        print(f'updated {baseline_path}')
        return 0
    return 1 if run_check(args.durations, baseline_path)['violations'] else 0


if __name__ == '__main__':
    sys.exit(main())
