"""The `impact` test tier of tool/check-project: run the Dart tests a diff touches, plus the guards.

Merge-check policy (Kevin, #raft-flutter 5fab6ad6): a merge check runs every static check and only the
tests the diff touches; the full suite runs nightly and before releases. Per package (a TEST_DIRS
entry of check-project), the tests to run are

  - the files `tool/test-impact select` picks for the diff (coverage maps, see tool/test_impact.py);
  - the guard and cross-cutting files below, which no diff heuristic reaches but which branches kept
    breaking (registries, parity ledgers, shell-wide audits, the raft_ui text-scale audits; the zh
    catalog test when an l10n file changes);
  - the test files the diff changes or adds.

A package falls back to the `gate` tier (all of its files, slow files by the import graph) when the
selector failed, when it has no map, or when the merged selection is more than MAX_SHARE of its files
(then the selection saves little and a core path probably changed). The selector runs once for the whole
diff (`--format json`); its tests are split by package here, which is what `--package` would print.
"""
import json
import pathlib
import re
import subprocess
import sys

MAX_SHARE = 0.5
SELECT_TIMEOUT_SECONDS = 600
# Repo-wide guards (registries, parity ledgers): cheap, and a diff heuristic misses them.
GUARD_GLOBS = (
    'apps/raft_flutter/test/*guard*_test.dart',
    'apps/raft_flutter/test/*registry*_test.dart',
    'apps/raft_flutter/test/*parity_ledger*_test.dart',
    # Shared widgets break the raft_ui text-scale audits from any lane (gate 154).
    'packages/raft_ui/test/text_scale_audit*_test.dart',
)
# Cross-cutting audits and budgets packages kept breaking (gates 127-138, 152, 153; from the pre-gate script).
CROSS_CUTTING = tuple(f'apps/raft_flutter/test/{name}_test.dart' for name in (
    'rate_limit_session', 'rate_limit_scroll_budget', 'edge_to_edge_audit', 'idle_frames',
    'performance_navigation_activity', 'text_scale_audit', 'text_scale_audit_tall', 'first_frame_layout',
    'field_parity_v1_21_23', 'chat_reading_position',
    'close_popups', 'close_panels', 'phone_navigation_placement',
    'statusbar_standard', 'statusbar_standard_part2', 'statusbar_standard_part3', 'tap_target_matrix',
))
L10N_CHANGE = re.compile(r'(^|/)lib/src/l10n/')
L10N_TESTS = ('packages/raft_ui/test/zh_catalog_files_test.dart',)


def package_of(path, packages):
    """The package directory (`apps/raft_flutter`, `packages/raft_ui`) whose test/ holds `path`, else None."""
    best = None
    for package in packages:
        if path.startswith(package.rstrip('/') + '/test/') and (best is None or len(package) > len(best)):
            best = package
    return best


def guard_files(root, changed):
    """Repo-relative guard and cross-cutting test files that exist under `root` (with the zh catalog test
    when `changed` touches an l10n file; `changed` None means unknown, which counts as touched)."""
    root = pathlib.Path(root)
    found = set()
    for pattern in GUARD_GLOBS:
        found.update(path.relative_to(root).as_posix() for path in root.glob(pattern) if path.is_file())
    extra = list(CROSS_CUTTING)
    if changed is None or any(L10N_CHANGE.search(name) for name in changed):
        extra += L10N_TESTS
    found.update(name for name in extra if (root / name).is_file())
    return found


def changed_test_files(changed):
    """The `*_test.dart` files among the changed paths (the caller keeps the ones that still exist)."""
    return {name for name in changed or () if name.endswith('_test.dart')}


def run_selector(root, base, worktree, env=None, timeout=SELECT_TIMEOUT_SECONDS):
    """(selection dict, None) from `tool/test-impact select --format json`, or (None, why it failed)."""
    root = pathlib.Path(root)
    args = [sys.executable, str(root / 'tool/test-impact'), 'select', '--root', str(root), '--base', base, '--format', 'json']
    if worktree:
        args.append('--worktree')
    try:
        done = subprocess.run(args, cwd=root, env=env, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return None, f'tool/test-impact select timed out after {timeout:.0f}s'
    except OSError as error:
        return None, f'tool/test-impact select did not start ({error})'
    if done.returncode != 0:
        last = (done.stderr.strip().splitlines() or done.stdout.strip().splitlines() or ['no output'])[-1]
        return None, f'tool/test-impact select exited {done.returncode}: {last}'
    try:
        selection = json.loads(done.stdout)
    except ValueError:
        return None, 'tool/test-impact select printed no JSON'
    if not isinstance(selection, dict) or not isinstance(selection.get('tests'), dict):
        return None, 'tool/test-impact select printed no test list'
    return selection, None


def plan_packages(candidates, packages, selection, error, guards, changed_tests, max_share=MAX_SHARE):
    """Per-package plan: [{'package', 'total', 'mode' ('impact'|'gate'), 'reason', 'files', 'counts'}].

    `candidates` are the repo-relative test files the run could execute (looks already filtered);
    `selection` is the selector's JSON (None with `error` when it failed). `files` lists a package's
    impact files in candidate order (empty for a package on the gate fallback, which runs them all).
    """
    by_package = {}
    for name in candidates:
        package = package_of(name, packages)
        if package:
            by_package.setdefault(package, []).append(name)
    selected = set((selection or {}).get('tests', {}))
    mapped = set((selection or {}).get('maps', {}))
    select_all = (selection or {}).get('select_all')
    plans = []
    for package in packages:
        files = by_package.get(package, [])
        if not files:
            continue
        total = len(files)
        picks = {'selector': [f for f in files if f in selected], 'guard': [f for f in files if f in guards],
                 'changed': [f for f in files if f in changed_tests]}
        merged = [f for f in files if f in selected or f in guards or f in changed_tests]
        counts = {key: len(value) for key, value in picks.items()}
        if error:
            mode, reason = 'gate', f'selector failed: {error}'
        elif package not in mapped:
            mode, reason = 'gate', 'no impact map for this package'
        elif select_all:
            mode, reason = 'gate', f'the selector selects every test ({select_all})'
        elif len(merged) > max_share * total:
            mode, reason = 'gate', f'selection {len(merged)} is more than {max_share:.0%} of {total}'
        else:
            mode, reason = 'impact', f"selector {counts['selector']}, guards {counts['guard']}, changed tests {counts['changed']}"
        plans.append({'package': package, 'total': total, 'mode': mode, 'reason': reason,
                      'files': merged if mode == 'impact' else [], 'selected': len(merged), 'counts': counts})
    return plans


def summary_lines(plans, warnings=()):
    """One line per package: `selected N of M (reason)`, or the gate fallback and why."""
    lines = [f'test-impact: {warning}' for warning in warnings]
    for plan in plans:
        if plan['mode'] == 'impact':
            lines.append(f"impact {plan['package']}: selected {plan['selected']} of {plan['total']} ({plan['reason']})")
        else:
            lines.append(f"impact {plan['package']}: selected {plan['selected']} of {plan['total']}; gate tier for this package ({plan['reason']})")
    return lines
