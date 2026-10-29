#!/usr/bin/env python3
"""Synthetic drift test for tool/behavior-parity (complements behavior_parity_validate.py).

Real tag pairs rarely contain formatting-only edits or renames inside anchored symbols, so this copies the
Web src of one tag, applies controlled edits to every distinct anchored symbol, and checks the tool against
the AST ground truth (tool/behavior_parity_truth.js) on the mutated copy:

  S  semantic edit inside the symbol        (tool must say CHANGED)
  F  formatting-only edit (comment line, reindent, quote swap, trailing comma, blank lines)  (must stay unchanged)
  R  rename the declaration                 (tool: REMOVED; --rename-candidates should name the new symbol)
  M  move a top-level declaration to another file   (tool: MOVED to the new path)

  python3 tool/behavior_parity_mutation_test.py --tag v1.21.2-source.1 [--out result.json]
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import behavior_parity as bp  # noqa: E402
from behavior_parity_validate import TAGS, run_truth  # noqa: E402

SEMANTIC = [
    (re.compile(r'===') , '!=='),
    (re.compile(r'&&'), '||'),
    (re.compile(r'(?<= )>(?= )'), '>='),
    (re.compile(r'\btrue\b'), 'false'),
    (re.compile(r'\bfalse\b'), 'true'),
    (re.compile(r'\b(\d+)\b'), lambda m: str(int(m.group(1)) + 1)),
    (re.compile(r'\breturn;'), 'return null;'),
    (re.compile(r'\|\|'), '&&'),
    (re.compile(r'"([^":\\\n]+)"'), r'"\1x"'),
]
FORMATS = ['comment', 'reindent', 'quote', 'comma', 'blank']


def apply_semantic(lines, a, b):
    for pat, rep in SEMANTIC:
        for i in range(a - 1, b):
            new, n = pat.subn(rep, lines[i], count=1)
            if n and new != lines[i]:
                lines[i] = new
                return 'S:' + pat.pattern
    return None


def apply_format(lines, a, b, kind):
    if kind == 'comment':
        if b <= a:
            return None
        indent = re.match(r'\s*', lines[a]).group()
        lines.insert(a, f'{indent}// parity-test: harmless comment')
        return 'F:comment'
    if kind == 'reindent':
        for i in range(a - 1, b):
            if lines[i].strip():
                lines[i] = '  ' + lines[i]
        return 'F:reindent'
    if kind == 'quote':
        for i in range(a - 1, b):
            new, n = re.subn(r'"([^"\'\\\n`${}]+)"', r"'\1'", lines[i], count=1)
            if n:
                lines[i] = new
                return 'F:quote'
        return None
    if kind == 'comma':  # drop an existing trailing comma before a closer on its own line
        for i in range(a - 1, b - 1):
            if lines[i].rstrip().endswith(',') and re.fullmatch(r'\s*[)\]}]+\s*[;,)]*', lines[i + 1]):
                lines[i] = lines[i].rstrip()[:-1]
                return 'F:trailing-comma'
        return None
    if kind == 'blank':
        for i in range(a - 1, b - 1):
            if lines[i].rstrip().endswith(';'):
                lines.insert(i + 1, '')
                return 'F:blank-line'
        return None
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tag', default='v1.21.2-source.1')
    ap.add_argument('--out')
    ap.add_argument('--keep', action='store_true', help='keep the mutated copy and print its path')
    args = ap.parse_args()
    repo = Path(__file__).resolve().parents[1]
    base_root = TAGS / args.tag
    domains = bp.find_domains(repo)
    base = bp.WebTree(base_root)

    units = {}
    for d in domains:
        for r in d.rows:
            if r.has_anchor:
                units.setdefault((r.path, r.symbol), []).append(r.id)
    anchors = [{'id': f'{p}#{s}', 'path': p, 'symbol': s} for p, s in units]
    t0 = run_truth(base_root, anchors, False)

    tmp = Path(tempfile.mkdtemp(prefix='bp-mut-'))
    shutil.copytree(base_root / 'packages/web/src', tmp / 'packages/web/src')
    mut = bp.WebTree(tmp)

    # assign classes: R/M to eligible units alternately, the rest S/F alternately
    plan = {}
    elig_m = [k for k in units if t0[f'{k[0]}#{k[1]}'].get('move')]
    elig_r = [k for k in units if t0[f'{k[0]}#{k[1]}'].get('renamable') and k not in elig_m[::2]]
    for i, k in enumerate(elig_m[::2]):
        plan[k] = 'M'
    for k in elig_r[::2]:
        plan.setdefault(k, 'R')
    rest = [k for k in units if k not in plan and t0[f'{k[0]}#{k[1]}'].get('found')]
    fi = 0
    for i, k in enumerate(rest):
        if i % 2 == 0:
            plan[k] = 'S'
        else:
            plan[k] = 'F:' + FORMATS[fi % len(FORMATS)]
            fi += 1

    # apply edits file by file, bottom-up, never touching a region twice
    by_file = {}
    for k, cls in plan.items():
        by_file.setdefault(k[0], []).append((k, cls))
    applied, skipped = {}, {}
    move_dest = {}
    files = base.files()
    for rel, items in by_file.items():
        path = tmp / 'packages/web/src' / rel
        lines = path.read_text(encoding='utf-8').split('\n')
        touched = []
        items.sort(key=lambda it: -t0[f'{it[0][0]}#{it[0][1]}']['lines'][0][0])
        live = {k: [list(x) for x in t0[f'{k[0]}#{k[1]}']['lines']] for k, _ in items}
        live_move = {k: list(t0[f'{k[0]}#{k[1]}']['move']) for k, _ in items if t0[f'{k[0]}#{k[1]}'].get('move')}

        def shift(after, delta):
            for sp in list(live.values()) + list(live_move.values()):
                pairs = sp if sp and isinstance(sp[0], list) else [sp]
                for pr in pairs:
                    if pr[0] > after:
                        pr[0] += delta
                    if pr[1] > after:
                        pr[1] += delta

        for (p, sym), cls in items:
            spans = [tuple(x) for x in live[(p, sym)]]
            if cls == 'M':
                spans = [tuple(live_move[(p, sym)])]
            n_before = len(lines)
            what = None
            for a, b in spans:
                if any(a <= e and s_ <= b for s_, e in touched):
                    continue
                if cls == 'S':
                    what = apply_semantic(lines, a, b)
                elif cls.startswith('F:'):
                    what = apply_format(lines, a, b, cls[2:])
                elif cls == 'R':
                    for i in range(a - 1, b):
                        new, n = re.subn(r'(\b(?:function|const|let|var)\s+)' + re.escape(sym) + r'\b', r'\g<1>' + sym + 'Renamed', lines[i], count=1)
                        if n:
                            lines[i] = new
                            what = 'R'
                            break
                elif cls == 'M':
                    block = lines[a - 1:b]
                    dest_rel = next((f for f in files if f != rel and Path(f).parent == Path(rel).parent and f.endswith('.ts') and (tmp / 'packages/web/src' / f).exists()), None)
                    if dest_rel:
                        del lines[a - 1:b]
                        dest = tmp / 'packages/web/src' / dest_rel
                        dest.write_text(dest.read_text(encoding='utf-8') + '\n' + '\n'.join(block) + '\n', encoding='utf-8')
                        move_dest[(p, sym)] = dest_rel
                        what = 'M'
                if what:
                    delta = len(lines) - n_before
                    if delta:
                        shift(a, delta)
                    touched.append((a, b + max(delta, 0)) if delta >= 0 else (a, a))
                    break
            if what:
                applied[(p, sym)] = what
            else:
                skipped[(p, sym)] = 'no applicable edit'
        path.write_text('\n'.join(lines), encoding='utf-8')

    # tool: fingerprint at base, classify against mutated tree
    entries_by_anchor = {}
    for d in domains:
        entries, _ = bp.compute_fingerprints(d, base)
        for r in d.rows:
            if r.id in entries:
                entries_by_anchor.setdefault((r.path, r.symbol), (r, entries[r.id]))
    t1 = run_truth(tmp, anchors, True)
    rename_cache: dict = {}
    results = []
    for k, what in applied.items():
        r, entry = entries_by_anchor[k]
        key = f'{k[0]}#{k[1]}'
        dr = bp.check_row(r, entry, mut)
        tn, to = t1[key], t0[key]
        if tn.get('parseErrors'):
            results.append({'unit': key, 'edit': what, 'valid': False})
            continue
        if tn.get('found'):
            tclass = 'unchanged' if tn['hash'] == to['hash'] else 'CHANGED'
        else:
            el = tn.get('elsewhere') or []
            tclass = 'MOVED' if len(el) == 1 else 'REMOVED'
        rec = {'unit': key, 'edit': what, 'valid': True, 'tool': dr.state, 'truth': tclass, 'toolDetail': dr.detail}
        if what == 'R':
            cand, sim = bp.find_rename_candidate(r, entry, mut, rename_cache) if dr.state == 'REMOVED' else ('', 0.0)
            rec['renameCandidate'], rec['renameSimilarity'] = cand, round(sim, 2)
            rec['renameCorrect'] = cand == f'{k[0]}#{k[1]}Renamed'
        if what == 'M':
            rec['movedToCorrect'] = dr.new_path == move_dest[k]
        results.append(rec)

    valid = [x for x in results if x['valid']]
    classes = ['unchanged', 'CHANGED', 'MOVED', 'REMOVED']
    matrix = {t: {u: 0 for u in classes} for t in classes}
    for x in valid:
        matrix[x['tool']][x['truth']] += 1
    by_edit = {}
    for x in valid:
        e = x['edit'].split(':')[0] + (':' + x['edit'].split(':')[1] if x['edit'].startswith('F') else '')
        by_edit.setdefault(e, {'n': 0, 'agree': 0})
        by_edit[e]['n'] += 1
        by_edit[e]['agree'] += x['tool'] == x['truth']
    summary = {
        'tag': args.tag, 'units': len(units), 'planned': len(plan), 'applied': len(applied), 'skipped': {f'{a}#{b}': v for (a, b), v in skipped.items()},
        'invalidMutants': sum(1 for x in results if not x['valid']), 'validMutants': len(valid),
        'matrixToolRowsTruthCols': matrix,
        'falseNegatives(tool unchanged, truth changed/moved/removed)': [(x['unit'], x['edit'], x['truth']) for x in valid if x['tool'] == 'unchanged' and x['truth'] != 'unchanged'],
        'falsePositives(tool CHANGED, truth unchanged)': [(x['unit'], x['edit']) for x in valid if x['tool'] == 'CHANGED' and x['truth'] == 'unchanged'],
        'otherDisagreements': [(x['unit'], x['edit'], x['tool'], x['truth']) for x in valid if x['tool'] != x['truth'] and not (x['tool'] == 'unchanged' and x['truth'] != 'unchanged') and not (x['tool'] == 'CHANGED' and x['truth'] == 'unchanged')],
        'byEdit(n, tool==truth)': by_edit,
        'rename': {'n': sum(1 for x in valid if x['edit'] == 'R'), 'toolRemoved': sum(1 for x in valid if x['edit'] == 'R' and x['tool'] == 'REMOVED'),
                   'candidateCorrect': sum(1 for x in valid if x.get('renameCorrect')), 'sims': [(x['unit'], x['renameSimilarity'], x['renameCorrect']) for x in valid if x['edit'] == 'R']},
        'move': {'n': sum(1 for x in valid if x['edit'] == 'M'), 'toolMoved': sum(1 for x in valid if x['edit'] == 'M' and x['tool'] == 'MOVED'),
                 'newPathCorrect': sum(1 for x in valid if x.get('movedToCorrect'))},
    }
    if args.out:
        Path(args.out).write_text(json.dumps({'summary': summary, 'results': results}, indent=1))
    print(json.dumps(summary, indent=1))
    if args.keep:
        print('mutated copy kept at', tmp, file=sys.stderr)
    else:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
