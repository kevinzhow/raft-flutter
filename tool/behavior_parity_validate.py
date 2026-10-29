#!/usr/bin/env python3
"""Validate tool/behavior-parity drift detection between two Web tags against an AST ground truth.

  python3 tool/behavior_parity_validate.py --old v1.21.0-source.1 --new v1.21.2-source.1 [--out result.json]

For every anchored row of every domain under docs/behavior-parity:
  1. tool:  fingerprint at OLD (compute_fingerprints), then classify against NEW (check_row).
  2. truth: tool/behavior_parity_truth.js resolves the same anchors on the TypeScript AST of
            both tags (independent code path, semantic hash without trivia).
  3. git:   `git diff -U0 OLD NEW -- <file>` hunks overlapping the resolved line ranges.
Prints the confusion matrix plus every disagreement, and the candidates that exist at NEW but not at OLD.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import behavior_parity as bp  # noqa: E402

TAGS = Path('/home/kevinzhow/github/raft-source-tags')
GIT_DIR = TAGS / 'repo.git'
TRUTH = Path(__file__).resolve().parent / 'behavior_parity_truth.js'


def run_truth(root: Path, anchors, elsewhere: bool):
    cmd = ['node', str(TRUTH), str(root)] + (['--elsewhere'] if elsewhere else [])
    out = subprocess.run(cmd, input=json.dumps(anchors), capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def hunks(old: str, new: str, rel: str):
    out = subprocess.run(['git', '-C', str(GIT_DIR), 'diff', '-U0', f'{old}', f'{new}', '--', f'packages/web/src/{rel}'],
                         capture_output=True, text=True, check=True).stdout
    res = []
    for m in re.finditer(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', out, re.M):
        a, b = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
        c, d = int(m.group(3)), int(m.group(4) if m.group(4) is not None else 1)
        res.append((a, b, c, d))
    return res


def overlaps(spans, a, b):
    """True if a hunk side (start line a, b lines; b == 0 is a pure insertion/deletion point after line a)
    touches the interior of one of `spans` [(first, last)]."""
    if b:
        return any(s <= a + b - 1 and a <= e for s, e in spans)
    return any(s <= a < e for s, e in spans)


def tool_lines(src: bp.Source, res: bp.Resolution):
    return [(src.line_of(s.start), src.line_of(s.end - 1)) for s in res.spans]


def truth_class(t_old, t_new):
    if not t_old.get('found'):
        return 'no-baseline', ''
    if t_new.get('found'):
        return ('unchanged' if t_old['hash'] == t_new['hash'] else 'CHANGED'), ''
    el = t_new.get('elsewhere') or []
    if len(el) == 1:
        return 'MOVED', el[0]['path'] + ('' if el[0]['hash'] == t_old['hash'] else ' (body changed)')
    return 'REMOVED', f'{len(el)} other definitions' if el else ''


def candidates(web: bp.WebTree, scope_files):
    syms = set()
    for rel in scope_files:
        for s in bp.list_store_symbols(web, rel):
            syms.add((rel, s['name']))
    return syms


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--old', required=True)
    ap.add_argument('--new', required=True)
    ap.add_argument('--out')
    ap.add_argument('--rename', action='store_true', help='also run rename-candidate search for REMOVED rows')
    args = ap.parse_args()
    repo = Path(__file__).resolve().parents[1]
    old_web, new_web = bp.WebTree(TAGS / args.old), bp.WebTree(TAGS / args.new)
    domains = bp.find_domains(repo)
    rows = [(d, r) for d in domains for r in d.rows if r.has_anchor]

    anchors = [{'id': r.id, 'path': r.path, 'symbol': r.symbol} for _, r in rows]
    t_old = run_truth(TAGS / args.old, anchors, False)
    t_new = run_truth(TAGS / args.new, anchors, True)

    results = []
    rename_cache: dict = {}
    for d in domains:
        entries, bad = bp.compute_fingerprints(d, old_web)
        bad_ids = {i for i, _ in bad}
        for r in d.rows:
            if not r.has_anchor:
                continue
            rec = {'id': r.id, 'domain': d.name, 'anchor': r.anchor}
            to, tn = t_old[r.id], t_new[r.id]
            rec['truthOld'] = to.get('found', False)
            rec['toolOldResolved'] = r.id not in bad_ids
            if r.id in bad_ids:
                rec['tool'] = 'no-baseline'
            else:
                dr = bp.check_row(r, entries.get(r.id), new_web)
                rec['tool'], rec['toolDetail'] = dr.state, dr.detail
                if dr.state == 'REMOVED' and args.rename:
                    cand, sim = bp.find_rename_candidate(r, entries[r.id], new_web, rename_cache)
                    rec['renameCandidate'], rec['renameSimilarity'] = cand, round(sim, 2)
            rec['truth'], rec['truthDetail'] = truth_class(to, tn)
            # git cross-check for symbols present in the same file at both tags
            if rec['truth'] in ('unchanged', 'CHANGED') and rec['tool'] in ('unchanged', 'CHANGED'):
                so, sn = old_web.source(r.path), new_web.source(r.path)
                ro, rn = bp.resolve(so, r.symbol), bp.resolve(sn, r.symbol)
                hs = hunks(args.old, args.new, r.path)
                hit = any(overlaps(tool_lines(so, ro), a, b) or overlaps(tool_lines(sn, rn), c, dd) for a, b, c, dd in hs)
                rec['gitHunkOverlap'] = hit
                # extent agreement of the scanner with the AST, per tag
                rec['extentMatch'] = (sorted(tool_lines(so, ro)) == sorted(tuple(x) for x in to['lines'])) and (sorted(tool_lines(sn, rn)) == sorted(tuple(x) for x in tn['lines']))
            results.append(rec)

    # ---- summaries ----
    def cell(rec):
        return rec['tool'], rec['truth']
    classes = ['unchanged', 'CHANGED', 'MOVED', 'REMOVED']
    matrix = {t: {u: 0 for u in classes + ['no-baseline']} for t in classes + ['no-baseline']}
    for rec in results:
        matrix[rec['tool']][rec['truth']] += 1
    resolved_both = [x for x in results if x['truth'] != 'no-baseline' and x['tool'] != 'no-baseline']
    fn = [x for x in resolved_both if x['tool'] == 'unchanged' and x['truth'] in ('CHANGED', 'MOVED', 'REMOVED')]
    fp = [x for x in resolved_both if x['tool'] == 'CHANGED' and x['truth'] == 'unchanged']
    disagree = [x for x in resolved_both if x['tool'] != x['truth']]
    git_only = [x for x in resolved_both if x.get('gitHunkOverlap') and x['truth'] == 'unchanged']
    git_miss = [x for x in resolved_both if x.get('gitHunkOverlap') is False and x['truth'] == 'CHANGED']
    summary = {
        'old': args.old, 'new': args.new,
        'anchoredRows': len(rows),
        'resolvedAtOld': {'tool': sum(1 for x in results if x['toolOldResolved']), 'truth': sum(1 for x in results if x['truthOld'])},
        'toolCounts': {c: sum(1 for x in results if x['tool'] == c) for c in classes + ['no-baseline']},
        'truthCounts': {c: sum(1 for x in results if x['truth'] == c) for c in classes + ['no-baseline']},
        'matrixToolRowsTruthCols': matrix,
        'falseNegatives': [(x['id'], x['tool'], x['truth']) for x in fn],
        'falsePositives': [(x['id'], x['tool'], x['truth']) for x in fp],
        'disagreements': [(x['id'], x['anchor'], x['tool'], x['toolDetail'] if 'toolDetail' in x else '', x['truth'], x['truthDetail']) for x in disagree],
        'unchangedButGitHunkOverlap(noise-only edits)': [x['id'] for x in git_only],
        'truthChangedButNoGitHunk(should be empty)': [x['id'] for x in git_miss],
        'extentMismatch': [x['id'] for x in results if x.get('extentMatch') is False],
        'extentChecked': sum(1 for x in results if 'extentMatch' in x),
    }

    # ---- candidates new at NEW vs OLD ----
    cand = {}
    for d in domains:
        a, b = candidates(old_web, d.scope), candidates(new_web, d.scope)
        cand[d.name] = {
            'newSymbols(file,name not at old)': sorted(f'{p}#{n}' for p, n in b - a),
            'newNames(name not anywhere in old scope)': sorted(f'{p}#{n}' for p, n in b if n not in {x for _, x in a}),
            'removedSymbols': sorted(f'{p}#{n}' for p, n in a - b),
        }
    ev_old, ev_new = bp.list_events(old_web), bp.list_events(new_web)
    cand['events'] = {'new': sorted(set(ev_new) - set(ev_old)), 'gone': sorted(set(ev_old) - set(ev_new))}
    summary['candidates'] = cand
    full = {'summary': summary, 'rows': results}
    if args.out:
        Path(args.out).write_text(json.dumps(full, indent=1))
    print(json.dumps(summary, indent=1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
