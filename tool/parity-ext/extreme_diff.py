"""The differ of the extreme-theme check (docs/theme-contract.md section 8; docs/parity-ext-quickstart.md).

Two renders of one case, Raft (normal pack) and Raft with the extreme user pack (tool/parity-ext/extreme_pack.py),
with the paint-op record of each (apps/raft_flutter/test/support/paint_ops.dart). Everything the pack can reach
changes colour, radius, stroke, size and font, so what did NOT change did not read the pack:

  * pixel regions: pixels identical in both images, eroded so glyph interiors and hairlines drop out, grouped into
    connected regions above an area threshold. Each region is mapped to the paint op that painted it in the
    extreme render (topmost op whose bounds hold the point and whose colour is the pixel's) and from the op to the
    render object and the widget that created it (file:line of the constructor call). Text, image and vector
    regions are ignored (reported as counts only); harness chrome (test/ files) is reported apart.
  * paint-op findings: the same render object paints the same colour / corner radius / stroke width / font size /
    font family / shadow in both renders although the pack moved every one of them.

Then each finding is classified against the normal Elegant and Brutal renders of the same case (contract 3.3: a
literal is allowed when all three looks share the value, so an unchanged value is only a candidate):
  a  likely defect: the same widget (creation site, op kind) paints a different value in Elegant or Brutal
  b  possible shared form: every look that renders the widget paints the same value; check slot, variant, state
  c  unknown: the widget does not paint that kind of op in the other looks
"""
import difflib
import json
import pathlib
import re

import numpy as np
from PIL import Image

FILL_KINDS = {'rect', 'rrect', 'drrect', 'oval', 'circle', 'arc', 'path', 'color', 'paint', 'line', 'points'}
IGNORED_KINDS = {'text': 'text', 'image': 'image', 'atlas': 'image', 'picture': 'vector', 'vertices': 'vector'}
MIN_REGION_LOGICAL_AREA = 24.0  # logical px^2 (a 5 x 5 box)
MAX_SAMPLES = 7
COLOR_TOLERANCE = 3
TEXT_COLOR_TOLERANCE = 40  # glyph anti-aliasing blends the text colour into the pixel
PILL_MARGIN = 0.75


# ------------------------------------------------------------------------------------------------ ops files
class Ops:
    """One case's paint-op record, indexed."""

    def __init__(self, doc, root=None):
        self.doc = doc
        self.root = str(root) if root else None
        self.nodes = {n[0]: n for n in doc.get('nodes', [])}
        self.objects = {o['id']: o for o in doc.get('objects', [])}
        # The debug overflow indicator (striped gradient, rotated label) is painted by the multi-child layouts of a
        # render tree that overflowed; it is not product paint.
        self.ops = [op for op in doc.get('ops', []) if not self._overflow_indicator(op)]
        self.density = doc.get('density') or 1.0
        self.target = doc.get('target')
        self.by_object = {}
        for index, op in enumerate(self.ops):
            self.by_object.setdefault(op['ro'], []).append(index)
        self.by_path = {o['path']: o['id'] for o in self.objects.values()}

    OVERFLOW_PAINTERS = {'RenderFlex', 'RenderWrap', 'RenderStack', 'RenderIndexedStack', 'RenderListBody', 'RenderFlow',
                         'RenderConstrainedOverflowBox', 'RenderSizedOverflowBox', 'RenderCustomMultiChildLayoutBox'}

    def _overflow_indicator(self, op):
        obj = self.objects.get(op['ro'])
        return bool(obj and obj['type'] in self.OVERFLOW_PAINTERS and (op.get('rot') or op.get('fl', 0) & 1))

    @classmethod
    def load(cls, path, root=None):
        return cls(json.loads(pathlib.Path(path).read_text()), root)

    def rel(self, file):
        """A creation location as a repo-relative path; SDK and pub files keep a `flutter:` / `pub:` prefix."""
        if not file:
            return None
        path = file[len('file://'):] if file.startswith('file://') else file
        if self.root and path.startswith(self.root.rstrip('/') + '/'):
            return path[len(self.root.rstrip('/')) + 1:]
        if '/flutter-sdks/' in path or '/packages/flutter/lib/' in path:
            return 'flutter:' + path.split('/packages/', 1)[-1]
        m = re.search(r'/\.pub-cache/hosted/[^/]+/([^/]+)/lib/(.*)$', path)
        if m:
            return f'pub:{m.group(1)}/{m.group(2)}'
        return 'ext:' + path.rsplit('/', 1)[-1]

    def chain(self, object_id):
        """The widget chain above a render object, nearest first: [(type, repo-relative file or None, line)]."""
        out = []
        node = self.objects[object_id].get('node')
        while node is not None and node in self.nodes:
            _, type_, file, line, parent = self.nodes[node]
            out.append((type_, self.rel(file), line))
            node = parent
        return out


def is_project(file):
    return bool(file) and not file.startswith(('flutter:', 'pub:', 'ext:'))


def is_harness(file):
    return bool(file) and (file.startswith(('apps/raft_flutter/test/', 'test/')) or '/test/' in file)


def site_of(chain):
    """-> (site, component, harness): the nearest project widget (where the painting widget was written) and the
    nearest ancestor from it up that is declared in the project's own widget classes (class_index)."""
    site = next(((t, f, l) for t, f, l in chain if is_project(f)), None)
    return site


def hex_argb(value):
    return '#%02x%02x%02x' % ((value >> 16) & 255, (value >> 8) & 255, value & 255) + (
        '' if (value >> 24) & 255 == 255 else '/%d%%' % round(((value >> 24) & 255) / 2.55))


# ------------------------------------------------------------------------------------------------ pixels
def unchanged_mask(a, b):
    """True where every channel of two same-size RGB arrays is identical."""
    if a.shape != b.shape:
        raise ValueError(f'image sizes differ: {a.shape} vs {b.shape}')
    return np.all(a == b, axis=2)


def erode(mask, k):
    """Keep the pixels whose k x k neighbourhood (anchored top-left) is entirely set: drops glyph interiors and
    hairlines, keeps real fills."""
    h, w = mask.shape
    if k <= 1:
        return mask.copy()
    pad = np.zeros((h + 1, w + 1), dtype=np.int32)
    pad[1:, 1:] = np.cumsum(np.cumsum(mask.astype(np.int32), axis=0), axis=1)
    out = np.zeros_like(mask)
    hh, ww = h - k + 1, w - k + 1
    if hh <= 0 or ww <= 0:
        return out
    total = pad[k:k + hh, k:k + ww] - pad[0:hh, k:k + ww] - pad[k:k + hh, 0:ww] + pad[0:hh, 0:ww]
    out[:hh, :ww] = total == k * k
    return out


def label(mask):
    """4-connected components of a boolean mask -> (labels int32 array, count). Row-run union-find."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    parent = [0]

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    prev_runs = []
    next_id = 1
    for y in range(h):
        row = mask[y]
        if not row.any():
            prev_runs = []
            continue
        padded = np.concatenate(([0], row.view(np.int8), [0]))
        diff = np.diff(padded)
        starts, ends = np.flatnonzero(diff == 1), np.flatnonzero(diff == -1)
        runs = []
        for s, e in zip(starts, ends):
            ids = [lab for (ps, pe, lab) in prev_runs if ps < e and pe > s]
            if not ids:
                lab = next_id
                parent.append(lab)
                next_id += 1
            else:
                lab = find(ids[0])
                for other in ids[1:]:
                    parent[find(other)] = lab
            labels[y, s:e] = lab
            runs.append((s, e, lab))
        prev_runs = runs
    if next_id == 1:
        return labels, 0
    roots = np.array([find(i) for i in range(next_id)], dtype=np.int32)
    labels = roots[labels]
    uniq, inverse = np.unique(labels, return_inverse=True)
    labels = inverse.reshape(labels.shape).astype(np.int32)
    labels[mask == 0] = 0
    if uniq[0] == 0:
        return labels, len(uniq) - 1
    return labels + 1, len(uniq)


def regions(mask, density, min_logical_area=MIN_REGION_LOGICAL_AREA):
    """Connected regions of the unchanged mask above the area threshold -> list of dicts with device-pixel
    coordinates: area (device px of the eroded core), bbox (x0, y0, x1, y1), samples [(x, y)]."""
    k = int(round(2 * density)) + 1
    core = erode(mask, k)
    labels, count = label(core)
    if not count:
        return []
    out = []
    min_area = min_logical_area * density * density
    order = np.argsort(labels.ravel(), kind='stable')
    flat = labels.ravel()[order]
    bounds = np.searchsorted(flat, np.arange(1, count + 2))
    width = labels.shape[1]
    for lab in range(1, count + 1):
        idx = order[bounds[lab - 1]:bounds[lab]]
        # the eroded core lost (k - 1) px on each side: estimate the region it came from
        grown = len(idx) + 2 * (k - 1) * len(idx) ** 0.5 + (k - 1) ** 2
        if grown < min_area:
            continue
        ys, xs = idx // width, idx % width
        step = max(1, len(idx) // MAX_SAMPLES)
        picks = list(range(len(idx) // (2 * MAX_SAMPLES), len(idx), step))[:MAX_SAMPLES] or [0]
        cx, cy = xs.mean(), ys.mean()
        nearest = int(np.argmin((xs - cx) ** 2 + (ys - cy) ** 2))
        picks = [nearest] + [p for p in picks if p != nearest]
        out.append({
            'area': int(grown),
            'bbox': (int(xs.min()), int(ys.min()), int(xs.max()) + k, int(ys.max()) + k),
            'samples': [(int(xs[p]), int(ys[p])) for p in picks[:MAX_SAMPLES]],
        })
    return out


# ------------------------------------------------------------------------------------------------ attribution
def inside_rounded(x, y, b, r):
    """Point in the rounded rectangle b = [l, t, r, b] with corner radii r (8 numbers: tlx tly trx try brx bry blx bly)."""
    l, t, rr, bb = b
    if not (l <= x <= rr and t <= y <= bb):
        return False
    corners = ((l + r[0], t + r[1], r[0], r[1], -1, -1), (rr - r[2], t + r[3], r[2], r[3], 1, -1),
               (rr - r[4], bb - r[5], r[4], r[5], 1, 1), (l + r[6], bb - r[7], r[6], r[7], -1, 1))
    for cx, cy, rx, ry, sx, sy in corners:
        if rx > 0 and ry > 0 and (x - cx) * sx > 0 and (y - cy) * sy > 0:
            return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1
    return True


def covers(op, x, y):
    b = op['b']
    if not (b[0] <= x <= b[2] and b[1] <= y <= b[3]):
        return False
    kind = op['k']
    if kind == 'rrect' and 'r' in op and not op.get('st'):
        return inside_rounded(x, y, b, op['r'])
    if kind == 'drrect':
        if not inside_rounded(x, y, b, op['r']):
            return False
        ins = op['ins']
        inner = [b[0] + ins[0], b[1] + ins[1], b[2] - ins[2], b[3] - ins[3]]
        return not (inner[0] < x < inner[2] and inner[1] < y < inner[3])
    if kind in ('oval', 'circle', 'arc') and not op.get('st'):
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        rx, ry = max((b[2] - b[0]) / 2, 1e-6), max((b[3] - b[1]) / 2, 1e-6)
        return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1
    if kind in ('line', 'points') or op.get('st'):
        return False  # a stroke is thin: it does not explain a filled region
    return True


def close(argb, rgb, tol):
    return (abs(((argb >> 16) & 255) - rgb[0]) <= tol and abs(((argb >> 8) & 255) - rgb[1]) <= tol
            and abs((argb & 255) - rgb[2]) <= tol)


def attribute(ops, x, y, rgb):
    """The topmost op that explains the pixel at logical (x, y) with colour rgb -> op index, or None."""
    for index in range(len(ops.ops) - 1, -1, -1):
        op = ops.ops[index]
        kind = op['k']
        if kind == 'clipRRect' or not covers(op, x, y):
            continue
        if kind == 'text':
            col = ops.objects[op['ro']].get('col')
            if col is not None and close(col, rgb, TEXT_COLOR_TOLERANCE):
                return index
            continue
        if kind in IGNORED_KINDS:
            return index
        if op.get('fl', 0) & (1 | 8) or op.get('bm'):  # shader / image filter / blend mode: colour is not the pixel's
            return index
        c = op.get('c')
        if c is None:
            return index
        alpha = (c >> 24) & 255
        if alpha < 250 or op.get('ba', 1) < 0.99:
            return index  # translucent: the pixel is a blend, trust the geometry
        if close(c, rgb, COLOR_TOLERANCE):
            return index
    return None


def describe_op(ops, index):
    """Facts of one op for the report: kind, colour, shape, widget chain, site."""
    op = ops.ops[index]
    obj = ops.objects[op['ro']]
    chain = ops.chain(op['ro'])
    site = site_of(chain)
    out = {
        'op': op['k'], 'painter': obj['type'], 'path': obj['path'],
        'site': None if site is None else {'type': site[0], 'file': site[1], 'line': site[2]},
        'chain': [{'type': t, 'file': f, 'line': l} for t, f, l in chain if is_project(f)][:10],
    }
    if 'c' in op:
        out['color'] = hex_argb(op['c'])
    if 'r' in op:
        out['radii'] = op['r']
    if op.get('st'):
        out['strokeWidth'] = op.get('sw')
    return out


def analyse_regions(normal_img, extreme_img, extreme_ops, normal_ops=None, include_all=False):
    """Pixel half of the differ -> dict(regions=[...], ignored={text, image, vector, harness}, unattributed, stats)."""
    a = np.asarray(Image.open(normal_img).convert('RGB'))
    b = np.asarray(Image.open(extreme_img).convert('RGB'))
    density = extreme_ops.density
    mask = unchanged_mask(a, b)
    target = (normal_ops or extreme_ops).target
    if target and not include_all:
        t = [int(round(v * density)) for v in target]
        keep = np.zeros_like(mask)
        keep[max(t[1], 0):t[3], max(t[0], 0):t[2]] = True
        mask &= keep
    found = regions(mask, density)
    ignored = {'text': 0, 'image': 0, 'vector': 0, 'harness': 0}
    unattributed = []
    out = []
    for r in found:
        votes = {}
        for sx, sy in r['samples']:
            rgb = tuple(int(v) for v in b[sy, sx])
            index = attribute(extreme_ops, (sx + 0.5) / density, (sy + 0.5) / density, rgb)
            votes.setdefault(index, []).append((sx, sy))
        index = max(votes, key=lambda i: len(votes[i]))
        logical = [round(v / density, 1) for v in r['bbox']]
        area = round(r['area'] / (density * density), 1)
        if index is None:
            unattributed.append({'bbox': logical, 'area': area})
            continue
        op = extreme_ops.ops[index]
        if op['k'] in IGNORED_KINDS:
            ignored[IGNORED_KINDS[op['k']]] += 1
            continue
        facts = describe_op(extreme_ops, index)
        site = facts['site']
        if site is None or is_harness(site['file']):
            ignored['harness'] += 1
            continue
        px = tuple(int(v) for v in b[r['samples'][0][1], r['samples'][0][0]])
        out.append({'bbox': logical, 'area': area, 'agree': len(votes[index]), 'samples': len(r['samples']),
                    'pixel': '#%02x%02x%02x' % px, **facts})
    return {'regions': out, 'ignored': ignored, 'unattributed': unattributed,
            'unchangedFraction': round(float(mask.mean()), 4)}


# ------------------------------------------------------------------------------------------------ paint-op findings
def is_pill(op, tol=PILL_MARGIN):
    b, r = op['b'], op.get('r')
    if not r:
        return False
    half = min(b[2] - b[0], b[3] - b[1]) / 2
    return min(r[0], r[1]) >= half - tol


def op_values(ops, index):
    """The comparable attributes of one op: {attribute: value}."""
    op = ops.ops[index]
    kind = op['k']
    values = {}
    if kind in FILL_KINDS and 'c' in op and not (op.get('fl', 0) & (1 | 8)) and ((op['c'] >> 24) & 255) > 0:
        values['color' if not op.get('st') else 'strokeColor'] = op['c']
    if kind in ('rrect', 'drrect', 'clipRRect') and 'r' in op and max(op['r']) > 0 and not is_pill(op):
        values['radius'] = tuple(op['r'])
    if op.get('st') and op.get('sw', 0) > 0:
        values['stroke'] = op['sw']
    if kind == 'drrect':
        ins = op['ins']
        if max(ins) > 0:
            values['border'] = tuple(ins)
    if kind in ('shadow',) or (op.get('fl', 0) & 2):
        values['shadow'] = op.get('c', 0)
    return values


def object_text_values(obj):
    values = {}
    if obj.get('fs') is not None and obj.get('txt', '').strip():
        values['fontSize'] = obj['fs']
    fam = obj.get('fam')
    # the extreme pack's families are Space Mono, so mono-role text cannot show a change
    if fam and not re.search(r'space ?mono|icon|symbol|emoji', fam, re.I):
        values['fontFamily'] = fam
    if obj.get('col') is not None and obj.get('txt', '').strip():
        values['textColor'] = obj['col']
    return values


def paint_findings(normal, extreme, extreme_img=None, density=1.0):
    """Same render object, same attribute value in both renders -> list of findings (one per op / text object)."""
    findings = []
    shown = None
    if extreme_img is not None:
        shown = np.asarray(Image.open(extreme_img).convert('RGB'))
    for path, nid in normal.by_path.items():
        eid = extreme.by_path.get(path)
        if eid is None:
            continue
        n_idx, e_idx = normal.by_object.get(nid, []), extreme.by_object.get(eid, [])
        n_obj, e_obj = normal.objects[nid], extreme.objects[eid]
        # text facts of the render object
        if n_idx and e_idx and any(normal.ops[i]['k'] == 'text' for i in n_idx):
            if n_obj.get('txt') == e_obj.get('txt'):
                nv, ev = object_text_values(n_obj), object_text_values(e_obj)
                for attr, value in nv.items():
                    if ev.get(attr) == value:
                        findings.append(_finding(extreme, e_idx[0], attr, _fmt(attr, value), n_obj.get('txt')))
        kinds_n = [normal.ops[i]['k'] for i in n_idx]
        kinds_e = [extreme.ops[i]['k'] for i in e_idx]
        matcher = difflib.SequenceMatcher(a=kinds_n, b=kinds_e, autojunk=False)
        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag != 'equal':
                continue
            for off in range(i2 - i1):
                ni, ei = n_idx[i1 + off], e_idx[j1 + off]
                nv, ev = op_values(normal, ni), op_values(extreme, ei)
                for attr, value in nv.items():
                    if ev.get(attr) == value:
                        f = _finding(extreme, ei, attr, _fmt(attr, value))
                        if f and attr == 'color' and shown is not None:
                            f['visible'] = _visible(extreme.ops[ei], shown, density)
                        findings.append(f)
    return [f for f in findings if f]


def _fmt(attr, value):
    if attr in ('color', 'strokeColor', 'textColor', 'shadow'):
        return hex_argb(value)
    if attr == 'radius':
        return '/'.join(f'{v:g}' for v in value[::2])
    if attr == 'border':
        return '/'.join(f'{v:g}' for v in value)
    return f'{value:g}' if isinstance(value, (int, float)) else str(value)


def _finding(ops, index, attr, value, text=None):
    facts = describe_op(ops, index)
    site = facts['site']
    if site is None or is_harness(site['file']):
        return None
    f = {'attr': attr, 'value': value, 'op': facts['op'], 'painter': facts['painter'], 'site': site,
         'chain': facts['chain'], 'bbox': ops.ops[index]['b']}
    if text:
        f['text'] = text
    return f


def _visible(op, shown, density):
    """Does the op's own colour show at the middle of its bounds in the extreme image?"""
    b = op['b']
    x, y = int((b[0] + b[2]) / 2 * density), int((b[1] + b[3]) / 2 * density)
    if not (0 <= y < shown.shape[0] and 0 <= x < shown.shape[1]):
        return False
    return close(op['c'], tuple(int(v) for v in shown[y, x]), COLOR_TOLERANCE)


# ------------------------------------------------------------------------------------------------ classification
def context_of(chain):
    """-> (site key, parent key): the nearest project widget that painted, and the nearest project widget above it
    that was written on another line (the instance that used a shared widget). Both are (type, file, line)."""
    project = [(c['type'], c['file'], c['line']) for c in chain if is_project(c['file'])]
    if not project:
        return None
    site = project[0]
    parent = next((p for p in project[1:] if p[1:] != site[1:]), None)
    return (site, parent)


def look_values(ops):
    """{(context key, attribute): set of values} over every op / text object of one look's render."""
    values = {}
    for index in range(len(ops.ops)):
        op = ops.ops[index]
        key = context_of([{'type': t, 'file': f, 'line': l} for t, f, l in ops.chain(op['ro'])])
        if key is None:
            continue
        for attr, value in op_values(ops, index).items():
            values.setdefault((key, attr), set()).add(_fmt(attr, value))
        if op['k'] == 'text':
            for attr, value in object_text_values(ops.objects[op['ro']]).items():
                values.setdefault((key, attr), set()).add(_fmt(attr, value))
    return values


def classify(finding, others):
    """finding vs the other looks' value tables ({look: look_values()}) -> (class, evidence dict).

    The same widget is matched by creation site AND the site of the instance that used it, so a shared box that
    paints another colour for another caller is not mistaken for a look difference."""
    key = context_of(finding.get('chain') or [{'type': finding['site']['type'], 'file': finding['site']['file'],
                                              'line': finding['site']['line']}])
    evidence = {}
    differs = same = 0
    for look, table in others.items():
        seen = table.get((key, finding['attr']))
        if not seen:
            evidence[look] = None
            continue
        evidence[look] = sorted(seen)
        if finding['value'] in seen:
            same += 1
        else:
            differs += 1
    if differs:
        return 'a', evidence
    if same:
        return 'b', evidence
    return 'c', evidence


def region_as_finding(region):
    return {'attr': 'color', 'value': region['color'] if 'color' in region else region['pixel'], 'op': region['op'],
            'site': region['site']}
