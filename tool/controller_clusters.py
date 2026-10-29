#!/usr/bin/env python3
"""Find the seams inside one big Dart controller class.

For every member (method/getter/setter/constructor/field initializer) of the
class (plus `extension ... on Class` bodies and `part` files) it records which
instance fields the member reads and writes and which sibling members it
touches, then clusters the fields by co-access (weighted modularity community
detection) and reports, per cluster, its members, external callers, realtime
events handled and coupling to other clusters.

  tool/controller_clusters.py                 Markdown report on stdout
  tool/controller_clusters.py --json          machine-readable report
  tool/controller_clusters.py --class X --root path/x.dart --lib dir

Stdlib only and purely lexical (no analyzer): comments and string contents are
blanked, string interpolations stay code. Known approximations, all of which
are visible in the output rather than hidden:
  * locals/parameters that shadow a field name hide that field from the scope
    where the local is visible (heuristic scope: enclosing block);
  * `x.field` counts only when `x` is `this` or a source-controller alias
    (presentationSource, source, _windowReceiver), never for other receivers;
  * zero-argument getters are transparent: a member reading getter `messages`
    is credited with the fields that getter reads;
  * external callers are matched by receiver names declared with the class type
    in the same file (`WorkspaceController w`, `... get controller`,
    `x = WorkspaceController(...)`), so other
    untyped aliases are undercounted and a reused name such as `w` may overcount.
"""
import argparse
import collections
import json
import math
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_ROOT = 'apps/raft_flutter/lib/data/workspace_controller.dart'
DEFAULT_CLASS = 'WorkspaceController'
SOURCE_ALIASES = {'presentationSource', 'source', '_windowReceiver', 'owner'}
KEYWORDS = set('''abstract as assert async await break case catch class const continue covariant default deferred do
dynamic else enum export extends extension external factory false final finally for Function get hide if implements
import in interface is late library mixin new null on operator part required rethrow return sealed set show static super
switch sync this throw true try typedef var void when while with yield int bool double num String List Map Set Future
Stream Object Duration DateTime Iterable Never'''.split())
MUTATORS = ('add', 'addAll', 'remove', 'removeWhere', 'removeAt', 'removeLast', 'clear', 'putIfAbsent', 'insert',
            'insertAll', 'addEntries', 'update', 'updateAll', 'retainWhere', 'removeAll', 'retainAll', 'sort',
            'addFirst', 'addLast', 'removeFirst', 'setAll', 'fillRange', 'replaceRange')
EVENT_RE = re.compile(r"^[a-z][a-z0-9_]*(?::[a-z0-9_\-]+)+$")
BARE_EVENTS = {'connected', 'disconnected', 'heartbeat'}
IDENT = re.compile(r'[A-Za-z_$][A-Za-z0-9_$]*')


# --------------------------------------------------------------------------- lexing

def blank(src):
    """Return (code, strings): `code` has the same length as `src` with comments
    and string contents replaced by spaces (quotes and interpolations kept);
    `strings` maps the offset of each opening quote to its literal value."""
    out = list(src)
    strings = {}
    n = len(src)

    def erase(a, b):
        for k in range(a, b):
            if out[k] != '\n':
                out[k] = ' '

    def code(i, until_brace):
        depth = 0
        while i < n:
            c = src[i]
            nxt = src[i + 1] if i + 1 < n else ''
            if c == '/' and nxt == '/':
                j = src.find('\n', i)
                j = n if j < 0 else j
                erase(i, j)
                i = j
            elif c == '/' and nxt == '*':
                d, j = 1, i + 2
                while j < n and d:
                    if src.startswith('/*', j):
                        d, j = d + 1, j + 2
                    elif src.startswith('*/', j):
                        d, j = d - 1, j + 2
                    else:
                        j += 1
                erase(i, j)
                i = j
            elif c in '\'"':
                raw = i > 0 and src[i - 1] == 'r' and (i < 2 or not (src[i - 2].isalnum() or src[i - 2] == '_'))
                i = string(i, raw)
            elif c == '{':
                depth += 1
                i += 1
            elif c == '}':
                if until_brace and depth == 0:
                    return i
                depth -= 1
                i += 1
            else:
                i += 1
        return i

    def string(i, raw):
        q = src[i]
        triple = src.startswith(q * 3, i)
        start = i
        i += 3 if triple else 1
        value = []
        while i < n:
            c = src[i]
            if not raw and c == '\\':
                value.append(src[i:i + 2])
                erase(i, min(i + 2, n))
                i += 2
            elif (triple and src.startswith(q * 3, i)) or (not triple and c == q):
                i += 3 if triple else 1
                break
            elif not raw and c == '$' and i + 1 < n and src[i + 1] == '{':
                out[i] = ' '
                out[i + 1] = ' '
                end = code(i + 2, True)
                if end < n:
                    out[end] = ' '
                i = end + 1
                value.append('${}')
            elif not raw and c == '$' and i + 1 < n and (src[i + 1].isalpha() or src[i + 1] == '_'):
                out[i] = ' '
                j = i + 1
                while j < n and (src[j].isalnum() or src[j] == '_'):
                    j += 1
                value.append('$')
                i = j
            else:
                value.append(c)
                if c != '\n':
                    out[i] = ' '
                i += 1
        else:
            pass
        strings[start] = ''.join(value)
        return i

    code(0, False)
    return ''.join(out), strings


def bracket_map(code):
    pairs = {'(': ')', '[': ']', '{': '}'}
    stack, match, back = [], {}, {}
    for i, c in enumerate(code):
        if c in pairs:
            stack.append((c, i))
        elif c in ')]}':
            while stack and pairs[stack[-1][0]] != c:
                stack.pop()
            if stack:
                _, j = stack.pop()
                match[j] = i
                back[i] = j
    return match, back


# --------------------------------------------------------------------------- member splitting

class Member:
    def __init__(self, name, kind, start, end, header, body_start, file, static=False):
        self.name, self.kind = name, kind
        self.start, self.end = start, end
        self.header, self.body_start = header, body_start
        self.file, self.static = file, static
        self.kinds = {kind}
        self.reads, self.writes = collections.Counter(), collections.Counter()
        self.uses = collections.Counter()   # sibling members referenced
        self.lines = 0
        self.events = []


class Source:
    def __init__(self, path, text):
        self.path = path
        self.text = text
        self.code, self.strings = blank(text)
        self.match, self.back = bracket_map(self.code)

    def line(self, off):
        return self.text.count('\n', 0, off) + 1


def skip_ws(code, i, end):
    while i < end and code[i].isspace():
        i += 1
    return i


def skip_annotations(code, i, end, match):
    while i < end and code[i] == '@':
        m = IDENT.match(code, i + 1)
        if not m:
            break
        j = m.end()
        while j < end and code[j] == '.':
            m2 = IDENT.match(code, j + 1)
            if not m2:
                break
            j = m2.end()
        k = skip_ws(code, j, end)
        if k < end and code[k] == '(' and k in match:
            j = match[k] + 1
        i = skip_ws(code, j, end)
    return i


def split_members(src, lo, hi, cls):
    """Yield members found at brace depth 0 of the class body code[lo:hi]."""
    code, match = src.code, src.match
    i = lo
    result = []
    while True:
        i = skip_ws(code, i, hi)
        i = skip_annotations(code, i, hi, match)
        if i >= hi:
            break
        if code[i] == ';':
            i += 1
            continue
        start = i
        j = i
        init = arrow = False
        body_open = None
        header_end = None
        first_paren = None
        while j < hi:
            c = code[j]
            if c in '([{':
                if c == '(' and first_paren is None and not init and not arrow:
                    first_paren = j
                if c == '{' and not init and not arrow:
                    body_open = j
                    if header_end is None:
                        header_end = j
                    break
                j = match.get(j, hi) + 1
                continue
            if c == ';':
                if header_end is None:
                    header_end = j
                break
            if c == '=' and not init and not arrow:
                nxt = code[j + 1] if j + 1 < hi else ''
                prev = code[j - 1] if j > start else ''
                if nxt == '>':
                    arrow = True
                    header_end = j
                    j += 2
                    continue
                if nxt != '=' and prev not in '=!<>':
                    head = code[start:j]
                    if re.match(r'\s*(?:const\s+|factory\s+)?' + re.escape(cls) + r'\b', head) and ')' in head:
                        j += 1  # constructor initializer list: not a field initializer
                        continue
                    init = True
                    header_end = j
            j += 1
        else:
            header_end = header_end or hi
        end = (match[body_open] + 1) if body_open is not None else min(j + 1, hi)
        header = code[start:header_end if header_end is not None else end]
        member = classify(src, header, start, end, body_open, arrow, init, cls)
        if member:
            result.extend(member)
        i = end
    return result


def classify(src, header, start, end, body_open, arrow, init, cls):
    h = ' '.join(header.split())
    static = bool(re.search(r'\bstatic\b', h))
    cm = re.match(r'(?:const\s+|factory\s+)?' + re.escape(cls) + r'(?:\.(\w+))?\s*\(', h)
    if cm:
        return [Member(cls + ('.' + cm.group(1) if cm.group(1) else ''), 'constructor', start, end, header, body_open or start, src)]
    m = re.search(r'\bget\s+(\w+)\s*$', h)
    if m and '(' not in h.split(' get ')[0].split('=>')[0][-1:]:
        return [Member(m.group(1), 'getter', start, end, header, start, src, static)]
    m = re.search(r'\bset\s+(\w+)\s*\(', h)
    if m:
        return [Member(m.group(1), 'setter', start, end, header, start, src, static)]
    m = re.search(r'\boperator\s*(\S+)\s*\(', h)
    if m:
        return [Member('operator' + m.group(1), 'method', start, end, header, start, src, static)]
    if body_open is not None or arrow or (not init and h.rstrip().endswith(')')):
        name = method_name(src, start, start + len(header))
        return [Member(name, 'method', start, end, header, start, src, static)] if name else []
    # field declaration; take every declarator (`T a = 1, b;`)
    out = []
    for name, init_lo in field_declarators(src, start, end):
        if name in KEYWORDS:
            continue
        member = Member(name, 'field', start, end, header, start, src, static)
        member.initializer = (init_lo, end) if init_lo is not None else None
        out.append(member)
    return out


def method_name(src, lo, hi):
    """Name of the first depth-0 parameter list in code[lo:hi] (skips record return types)."""
    code, match = src.code, src.match
    i = lo
    while i < hi:
        c = code[i]
        if c == '(':
            m = re.search(r'([A-Za-z_]\w*)\s*(?:<[^()]*>)?\s*$', code[lo:i])
            if m and m.group(1) not in ('static', 'Function', 'get', 'set', 'external', 'final', 'const'):
                return m.group(1)
        if c in '([{':
            i = match.get(i, hi) + 1
            continue
        i += 1
    return None


def field_declarators(src, start, end):
    """[(name, initializer_start_or_None)] for a field declaration chunk."""
    code, match = src.code, src.match
    cuts, i = [start], start
    while i < end:
        c = code[i]
        if c in '([{':
            i = match.get(i, end) + 1
            continue
        if c == ',' and re.match(r'\s*[A-Za-z_]\w*\s*(?:=(?![=>])|,|;|$)', code[i + 1:end + 1]):
            cuts.append(i + 1)
        i += 1
    cuts.append(end)
    out = []
    for lo, hi in zip(cuts, cuts[1:]):
        j, eq = lo, None
        while j < hi:
            c = code[j]
            if c in '([{':
                j = match.get(j, hi) + 1
                continue
            if c == '=' and code[j + 1:j + 2] not in ('=', '>') and code[j - 1:j] not in ('=', '!', '<', '>'):
                eq = j
                break
            j += 1
        head = re.sub(r'\bFunction\b\s*(?:<[^()]*>)?\s*\([^)]*\)', 'Function', code[lo:eq if eq is not None else hi])
        ids = IDENT.findall(re.sub(r'\([^()]*\)', ' ', head))
        if ids:
            out.append((ids[-1], eq + 1 if eq is not None else None))
    return out


# --------------------------------------------------------------------------- class discovery

def find_class_body(src, cls):
    m = re.search(r'\bclass\s+' + re.escape(cls) + r'\b[^{;]*\{', src.code)
    if not m:
        return None
    open_ = m.end() - 1
    return open_ + 1, src.match[open_]


def find_extensions(src, cls):
    for m in re.finditer(r'\bextension\s*(?:\w+)?\s*(?:<[^>]*>)?\s+on\s+' + re.escape(cls) + r'\b[^{;]*\{', src.code):
        open_ = m.end() - 1
        yield open_ + 1, src.match[open_]


def discover(root, lib, cls):
    """Root file + part files + any file with `extension on cls`."""
    files = {}
    root = pathlib.Path(root)
    queue = [root]
    seen = set()
    while queue:
        path = queue.pop()
        if path in seen or not path.is_file():
            continue
        seen.add(path)
        src = Source(path, path.read_text(encoding='utf-8'))
        files[path] = src
        for m in re.finditer(r"^\s*part\s+'([^']+)'", src.text, re.M):
            queue.append((path.parent / m.group(1)).resolve())
    if lib:
        for path in sorted(pathlib.Path(lib).rglob('*.dart')):
            path = path.resolve()
            if path in files:
                continue
            text = path.read_text(encoding='utf-8')
            if re.search(r'\bon\s+' + re.escape(cls) + r'\b', text) and re.search(r'\bextension\b', text):
                files[path] = Source(path, text)
    return files


# --------------------------------------------------------------------------- analysis

def params_of(src, member):
    code = src.code
    if member.kind not in ('method', 'setter', 'constructor'):
        return set(), set()
    i = member.header.find('(')
    if i < 0:
        return set(), set()
    open_ = member.start + i
    close = src.match.get(open_)
    if close is None:
        return set(), set()
    names, this_formals = set(), set()
    depth, cur = 0, []
    text = code[open_ + 1:close]
    chunks, buf, d = [], [], 0
    for ch in text:
        if ch in '([{<':
            d += 1
        elif ch in ')]}>':
            d -= 1
        if ch == ',' and d == 0:
            chunks.append(''.join(buf))
            buf = []
        else:
            buf.append(ch)
    chunks.append(''.join(buf))
    for chunk in chunks:
        chunk = chunk.split('=')[0]
        chunk = re.sub(r'[{}\[\]]', ' ', chunk)
        ft = re.sub(r'\bFunction\b\s*(?:<[^()]*>)?\s*\([^)]*\)', 'Function', chunk)
        tf = re.search(r'\bthis\.(\w+)', ft)
        if tf:
            this_formals.add(tf.group(1))
            continue
        ids = [x for x in IDENT.findall(ft) if x not in ('required', 'final', 'covariant', 'Function')]
        if ids:
            names.add(ids[-1])
    return names, this_formals


LOCAL_DECL = [
    re.compile(r'\b(?:final|var|const|late(?:\s+final)?)\s+(?:[A-Za-z_][\w.<>,?\s]*?\s+)?([A-Za-z_]\w*)\s*(?==(?!=)|;|\bin\b|:)'),
    re.compile(r'(?:(?<=[;{}(])|^)\s*(?:[A-Z]\w*(?:\.\w+)?(?:<[^;=(){}]*>)?\??|int|bool|double|num|String|dynamic)\s+([a-z_]\w*)\s*(?==(?!=)|;|\bin\b)'),
]
CLOSURE_PARAMS = re.compile(r'\(([^()]*)\)\s*(?:async\s*\*?\s*)?(=>|\{)')
ARROW_PARAM = re.compile(r'(?<![\w.$])([a-z_]\w*)\s*=>')


def local_scopes(src, member, lo, hi):
    """[(name, scope_start, scope_end)] for locals/closure params in code[lo:hi]."""
    code, match, back = src.code, src.match, src.back
    scopes = []
    seg = code[lo:hi]

    def enclosing(pos, opener):
        best = None
        for o, c in match.items():
            if code[o] == opener and lo <= o < pos < c <= hi:
                if best is None or o > best[0]:
                    best = (o, c)
        return best

    def block_end(pos):
        b = enclosing(pos, '{')
        return b[1] if b else hi

    for rx in LOCAL_DECL:
        for m in rx.finditer(seg):
            name = m.group(1)
            if name in KEYWORDS:
                continue
            pos = lo + m.start(1)
            grp = enclosing(pos, '(')
            if grp and re.search(r'\bfor\s*$', code[lo:grp[0]]):
                k = skip_ws(code, grp[1] + 1, hi)
                if k < hi and code[k] == '{':
                    end = match.get(k, hi)
                else:
                    e = code.find(';', k)
                    end = hi if e < 0 else e
                scopes.append((name, pos, end))
            else:
                scopes.append((name, pos, block_end(pos)))
    for m in CLOSURE_PARAMS.finditer(seg):
        before = code[:lo + m.start()].rstrip()
        prev = re.search(r'([\w$]+|\S)$', before)
        tok = prev.group(1) if prev else ''
        if tok != 'catch' and ((re.match(r'[\w$]+$', tok) and tok not in ('return', 'await', 'async', 'yield')) or tok == '>'):
            continue  # call, declaration or control statement, not a closure
        if m.group(1).strip() == '':
            continue
        pieces = [p for p in re.split(r',(?![^<]*>)', m.group(1)) if p.strip()]
        names = []
        for p in pieces:
            pid = [x for x in IDENT.findall(p.split('=')[0]) if x not in ('required', 'final', 'var')]
            if pid:
                names.append(pid[-1])
        if m.group(2) == '{':
            brace = lo + m.end() - 1
            end = match.get(brace, hi)
        else:
            grp = enclosing(lo + m.start(), '(') or enclosing(lo + m.start(), '[')
            end = grp[1] if grp else hi
        for name in names:
            if name not in KEYWORDS:
                scopes.append((name, lo + m.start(), end))
    for m in ARROW_PARAM.finditer(seg):
        name = m.group(1)
        if name in KEYWORDS or re.search(r'\bget\s+$', seg[:m.start()]):
            continue
        pos = lo + m.start()
        grp = enclosing(pos, '(') or enclosing(pos, '[')
        scopes.append((name, pos, grp[1] if grp else hi))
    return scopes


def receiver_before(code, pos):
    """Return ('none'|'this'|'source'|'other', ...) describing what precedes an identifier at pos."""
    k = pos - 1
    while k >= 0 and code[k].isspace():
        k -= 1
    if k < 0:
        return 'none'
    if code[k] == '.':
        if k > 0 and code[k - 1] == '.':
            return 'other'  # cascade
        k -= 1
        if k >= 0 and code[k] == '?':
            k -= 1
        while k >= 0 and code[k].isspace():
            k -= 1
        m = re.search(r'([A-Za-z_$][\w$]*)$', code[max(0, k - 40):k + 1])
        if m and m.group(1) == 'this':
            return 'this'
        if m and m.group(1) in SOURCE_ALIASES:
            return 'source'
        return 'other'
    return 'none'


def named_label(code, pos, end):
    """True when the identifier at pos..end is a named-argument/record label (`name:`)."""
    k = skip_ws(code, end, len(code))
    if k < len(code) and code[k] == ':' and code[k + 1:k + 2] != ':':
        b = pos - 1
        while b >= 0 and code[b].isspace():
            b -= 1
        return b >= 0 and code[b] in '(,'
    return False


def write_kind(code, pos, end):
    """'write' / 'read' for a field identifier occupying code[pos:end]."""
    n = len(code)
    k = skip_ws(code, end, n)
    # index chains: f[a][b] = x
    while k < n and code[k] == '[':
        close = None
        depth = 0
        for q in range(k, n):
            if code[q] == '[':
                depth += 1
            elif code[q] == ']':
                depth -= 1
                if depth == 0:
                    close = q
                    break
        if close is None:
            break
        k = skip_ws(code, close + 1, n)
    tail = code[k:k + 4]
    if re.match(r'(?:\?\?|[-+*/%|&^~]|<<|>>>?)?=(?![=>])', tail) or tail.startswith(('++', '--')):
        return 'write'
    b = pos - 1
    while b >= 0 and code[b].isspace():
        b -= 1
    if code[max(0, b - 1):b + 1] in ('++', '--'):
        return 'write'
    m = re.match(r'\s*\??\.\s*(\w+)\s*[(<]', code[end:end + 60])
    if m and m.group(1) in MUTATORS:
        return 'write'
    return 'read'


def analyze_member(src, member, fields, names, class_name):
    code = src.code
    lo, hi = member.start, member.end
    if member.kind == 'field':
        init = getattr(member, 'initializer', None)
        if not init:
            return
        lo, hi = init
    shadow, this_formals = params_of(src, member)
    scopes = [(n, lo, hi) for n in shadow] + local_scopes(src, member, lo, hi)
    for name in this_formals:
        member.writes[name] += 1
    # sort ident occurrences
    for m in IDENT.finditer(code, lo, hi):
        name = m.group(0)
        if name in KEYWORDS:
            continue
        is_field = name in fields
        is_member = name in names
        if not (is_field or is_member):
            continue
        pos, end = m.start(), m.end()
        rec = receiver_before(code, pos)
        if rec == 'other':
            continue
        if named_label(code, pos, end):
            continue
        if rec == 'none' and any(n == name and s <= pos < e for n, s, e in scopes):
            continue
        if is_field:
            if write_kind(code, pos, end) == 'write':
                member.writes[name] += 1
            else:
                member.reads[name] += 1
        if is_member and name != member.name:
            member.uses[name] += 1


def event_literals(src, lo, hi):
    out = []
    for pos, value in src.strings.items():
        if lo <= pos < hi and (EVENT_RE.match(value) or value in BARE_EVENTS):
            out.append((pos, value))
    return sorted(out)


# --------------------------------------------------------------------------- clustering

def louvain(nodes, weights, resolution=1.0):
    """Deterministic Louvain over an undirected weighted graph.
    weights: {(a, b): w} with a < b. Returns {node: community_id}."""
    adj = {n: collections.defaultdict(float) for n in nodes}
    for (a, b), w in weights.items():
        if a == b:
            continue
        adj[a][b] += w
        adj[b][a] += w
    community = {n: n for n in nodes}
    graph = {n: dict(adj[n]) for n in nodes}
    members = {n: [n] for n in nodes}
    while True:
        comm = {n: n for n in graph}
        degree = {n: sum(graph[n].values()) for n in graph}
        total = sum(degree.values()) / 2
        if total == 0:
            break
        comm_deg = dict(degree)
        improved = True
        moved_any = False
        order = sorted(graph, key=lambda n: (-degree[n], str(n)))
        while improved:
            improved = False
            for n in order:
                cur = comm[n]
                links = collections.defaultdict(float)
                for nb, w in graph[n].items():
                    if nb != n:
                        links[comm[nb]] += w
                comm_deg[cur] -= degree[n]
                best, best_gain = cur, links.get(cur, 0.0) - resolution * comm_deg[cur] * degree[n] / (2 * total)
                for c in sorted(links, key=str):
                    gain = links[c] - resolution * comm_deg[c] * degree[n] / (2 * total)
                    if gain > best_gain + 1e-12:
                        best, best_gain = c, gain
                comm_deg[best] += degree[n]
                if best != cur:
                    comm[n] = best
                    improved = moved_any = True
        if not moved_any:
            break
        # aggregate
        groups = collections.defaultdict(list)
        for n, c in comm.items():
            groups[c].append(n)
        new_graph = {c: collections.defaultdict(float) for c in groups}
        new_members = {c: [] for c in groups}
        for c, ns in groups.items():
            for n in ns:
                new_members[c].extend(members[n])
                for nb, w in graph[n].items():
                    new_graph[c][comm[nb]] += w
        # self loops count twice in this representation; keep them (they carry internal weight)
        graph = {c: dict(v) for c, v in new_graph.items()}
        members = new_members
    result = {}
    for c, ns in members.items():
        for n in ns:
            result[n] = c
    return {n: result.get(n, n) for n in nodes}


# --------------------------------------------------------------------------- orchestration

def analyse(root, lib, cls, hub_ratio=0.08, max_fields=25, resolution=2.0, min_cluster=2, force_hubs=()):
    files = discover(root, lib, cls)
    members = []
    class_files = []
    for path, src in files.items():
        bodies = []
        body = find_class_body(src, cls)
        if body:
            bodies.append(body)
        bodies.extend(find_extensions(src, cls))
        for lo, hi in bodies:
            class_files.append(str(path))
            members.extend(split_members(src, lo, hi, cls))
    if not members:
        raise SystemExit(f'class {cls} not found in {root}')
    fields = {m.name for m in members if m.kind == 'field' and not m.static}
    static_fields = {m.name for m in members if m.kind == 'field' and m.static}
    # merge getter/setter pairs and duplicate names (extensions can't clash with class members)
    merged = collections.OrderedDict()
    for m in members:
        if m.kind == 'field':
            continue
        key = m.name
        if key in merged:
            first = merged[key]
            first.kinds.add(m.kind)
            first.extra = getattr(first, 'extra', []) + [m]
        else:
            merged[key] = m
    callable_names = {n for n in merged if merged[n].kind != 'constructor' and not merged[n].static or True}
    callable_names -= {n for n in callable_names if merged[n].kind == 'constructor'}
    field_members = [m for m in members if m.kind == 'field' and not m.static and getattr(m, 'initializer', None)]
    for m in members:
        if m.kind == 'field':
            continue
        analyze_member(m.file, m, fields, callable_names, cls)
    for m in field_members:
        analyze_member(m.file, m, fields, callable_names, cls)
    # fold the extra declaration of a getter/setter pair into the first one
    for key, m in merged.items():
        for extra in getattr(m, 'extra', []):
            m.reads.update(extra.reads)
            m.writes.update(extra.writes)
            m.uses.update(extra.uses)
            m.end_extra = extra.end
        m.lines = sum(src_lines(m.file, mm) for mm in [m] + getattr(m, 'extra', []))
    # initializer pseudo-members
    for fm in field_members:
        if fm.reads or fm.writes or fm.uses:
            pseudo = Member(fm.name + ' (init)', 'init', fm.start, fm.end, '', fm.start, fm.file)
            pseudo.reads, pseudo.writes, pseudo.uses = fm.reads, fm.writes, fm.uses
            pseudo.writes[fm.name] += 1
            pseudo.lines = src_lines(fm.file, fm)
            merged[pseudo.name] = pseudo
    for m in members:
        if m.kind == 'field':
            m.lines = src_lines(m.file, m)
    all_members = merged
    # getter transparency: expand reads of zero-arg getters transitively
    getters = {n: m for n, m in all_members.items() if m.kinds == {'getter'}}

    def expand(name, seen):
        m = all_members[name]
        acc_r, acc_w = collections.Counter(m.reads), collections.Counter(m.writes)
        for callee, count in m.uses.items():
            if callee in getters and callee not in seen and callee != name:
                r, w = expand(callee, seen | {name})
                for f, c in r.items():
                    acc_r[f] += c
                for f, c in w.items():
                    acc_w[f] += c
        return acc_r, acc_w

    effective = {n: expand(n, frozenset()) for n in all_members}
    usage = collections.Counter()
    for n, (r, w) in effective.items():
        for f in set(r) | set(w):
            usage[f] += 1
    n_members = len(all_members)
    hubs = {f for f, c in usage.items() if c >= max(4, hub_ratio * n_members)} | (set(force_hubs) & fields)
    # field weights
    edge = collections.defaultdict(float)
    nodes = set()
    wide = []
    for n, (r, w) in effective.items():
        touched = sorted((set(r) | set(w)) - hubs)
        if len(touched) > max_fields:
            wide.append(n)
            continue
        if len(touched) < 2:
            continue
        weight = 1.0 / (len(touched) - 1)
        for i, a in enumerate(touched):
            for b in touched[i + 1:]:
                edge[(a, b)] += weight
    for a, b in edge:
        nodes.update((a, b))
    comm = louvain(sorted(nodes), edge, resolution) if nodes else {}
    groups = collections.defaultdict(list)
    for f, c in comm.items():
        groups[c].append(f)
    cluster_of_field = {}
    ordered = sorted(groups.values(), key=lambda fs: (-len(fs), sorted(fs)[0]))
    big = [fs for fs in ordered if len(fs) >= min_cluster]
    for idx, fs in enumerate(big, 1):
        for f in fs:
            cluster_of_field[f] = idx
    # member votes
    def votes(name, source):
        r, w = effective[name]
        v = collections.Counter()
        for f, c in r.items():
            if f in cluster_of_field:
                v[cluster_of_field[f]] += 1
        for f, c in w.items():
            if f in cluster_of_field:
                v[cluster_of_field[f]] += 2
        return v

    member_cluster = {}
    member_votes = {}
    for n in all_members:
        v = votes(n, None)
        member_votes[n] = v
        if v:
            member_cluster[n] = sorted(v, key=lambda c: (-v[c], c))[0]
    # fields without a cluster: majority of their members
    leftover = [f for f in fields if f not in cluster_of_field and f not in hubs]
    for _ in range(2):
        for f in leftover:
            if f in cluster_of_field:
                continue
            tally = collections.Counter(member_cluster[n] for n, (r, w) in effective.items()
                                        if (f in r or f in w) and n in member_cluster)
            if tally:
                cluster_of_field[f] = sorted(tally, key=lambda c: (-tally[c], c))[0]
    # fieldless members: follow callees, then callers
    callers = collections.defaultdict(collections.Counter)
    for n, m in all_members.items():
        for callee, c in m.uses.items():
            callers[callee][n] += c
    for _ in range(4):
        for n, m in all_members.items():
            if n in member_cluster:
                continue
            tally = collections.Counter()
            for callee, c in m.uses.items():
                if callee in member_cluster:
                    tally[member_cluster[callee]] += c
            if not tally:
                for caller, c in callers[n].items():
                    if caller in member_cluster:
                        tally[member_cluster[caller]] += c
            if tally:
                member_cluster[n] = sorted(tally, key=lambda c: (-tally[c], c))[0]
    cluster_ids = sorted(set(cluster_of_field.values()))
    # events
    events = event_map(files, all_members, member_cluster, cluster_of_field, hubs, effective)
    return dict(files=sorted(set(class_files)), members=all_members, fields=sorted(fields),
                static_fields=sorted(static_fields), field_members=field_members, usage=usage, hubs=sorted(hubs),
                wide=sorted(wide), cluster_of_field=cluster_of_field, member_cluster=member_cluster,
                member_votes=member_votes, cluster_ids=cluster_ids, effective=effective, events=events,
                callers=callers, n_members=n_members)


def src_lines(src, m):
    return src.text.count('\n', m.start, m.end) + 1


def block_statements(src, lo, hi):
    """Split code[lo:hi] (a block body) into top-level statement ranges."""
    code, match = src.code, src.match
    out = []
    i = skip_ws(code, lo, hi)
    while i < hi:
        start = i
        j = i
        while j < hi:
            c = code[j]
            if c in '([':
                j = match.get(j, hi) + 1
                continue
            if c == '{':
                end = match.get(j, hi) + 1
                k = skip_ws(code, end, hi)
                if re.match(r'else\b', code[k:k + 5]) or re.match(r'(?:catch|on|finally)\b', code[k:k + 8]):
                    j = k
                    continue
                j = end
                break
            if c == ';':
                j += 1
                break
            j += 1
        out.append((start, j))
        i = skip_ws(code, j, hi)
    return out


def event_map(files, members, member_cluster, cluster_of_field, hubs, effective):
    """event name -> {'handlers': [member], 'clusters': Counter}."""
    result = collections.defaultdict(lambda: dict(handlers=set(), clusters=collections.Counter()))

    def score(src, lo, hi, owner):
        tally = collections.Counter()
        for m in IDENT.finditer(src.code, lo, hi):
            name = m.group(0)
            if name == owner:
                continue
            if name in cluster_of_field and receiver_before(src.code, m.start()) != 'other':
                tally[cluster_of_field[name]] += 1
            elif name in member_cluster and name in members and receiver_before(src.code, m.start()) != 'other':
                tally[member_cluster[name]] += 1
        return tally

    for name, m in members.items():
        if m.kind in ('constructor', 'init'):
            continue
        src = m.file
        lits = event_literals(src, m.start, m.end)
        if not lits:
            continue
        distinct = {v for _, v in lits}
        # only code that compares/dispatches on names, not payload keys
        comp = [(p, v) for p, v in lits if context_is_event(src.code, p)]
        if not comp:
            continue
        brace = src.code.find('{', m.body_start, m.end)
        body_lo = brace + 1 if brace >= 0 and m.kind != 'getter' or brace >= 0 else m.start
        body_hi = src.match.get(brace, m.end) if brace >= 0 else m.end
        # case labels first (switch dispatch)
        cases = [(p, v) for p, v in comp if re.search(r'\bcase\s*$', src.code[max(0, p - 12):p])]
        if cases:
            bounds = sorted({p for p, _ in cases})
            segs = []
            labels = {}
            for p, v in cases:
                labels.setdefault(p, v)
            starts = sorted(labels)
            for idx, p in enumerate(starts):
                nxt = src.code.rfind('case', 0, starts[idx + 1]) if idx + 1 < len(starts) else body_hi
                colon = src.code.find(':', p)
                arrow = src.code.find('=>', p)
                lo = min(x for x in (colon, arrow) if x >= 0) if max(colon, arrow) >= 0 else p
                segs.append((labels[p], lo, nxt))
            pending = []
            for event, lo, hi in segs:
                pending.append(event)
                body = src.code[lo + 1:hi]
                if body.strip():
                    tally = score(src, lo, hi, name)
                    for ev in pending:
                        result[ev]['handlers'].add(name)
                        result[ev]['clusters'].update(tally or {member_cluster.get(name, 0): 0})
                    pending = []
            for ev in pending:
                result[ev]['handlers'].add(name)
                if name in member_cluster:
                    result[ev]['clusters'][member_cluster[name]] += 0
        case_positions = {p for p, _ in cases}
        comp = [(p, v) for p, v in comp if p not in case_positions]
        if not comp:
            continue
        # if/else chains: group by statement
        stmts = block_statements(src, body_lo, body_hi) if body_hi > body_lo else []
        covered = set()
        for lo, hi in stmts:
            here = [(p, v) for p, v in comp if lo <= p < hi]
            if not here:
                continue
            cond_end = src.code.find('{', lo, hi)
            if re.match(r'if\b', src.code[lo:lo + 3]):
                paren = src.code.find('(', lo, hi)
                cond_end = src.match.get(paren, hi)
                cond_lits = [(p, v) for p, v in here if p < cond_end]
                body = (cond_end + 1, hi)
            else:
                cond_lits = here
                body = (lo, hi)
            tally = score(src, body[0], body[1], name)
            for _, ev in cond_lits:
                result[ev]['handlers'].add(name)
                result[ev]['clusters'].update(tally)
                covered.add(ev)
        for _, ev in comp:
            if ev not in covered:
                result[ev]['handlers'].add(name)
                if name in member_cluster:
                    result[ev]['clusters'][member_cluster[name]] += 0
    return {k: dict(handlers=sorted(v['handlers']), clusters=dict(v['clusters'])) for k, v in result.items()}


def context_is_event(code, pos):
    before = code[max(0, pos - 80):pos]
    after = code[pos:pos + 80]
    if re.search(r'(?:name|event|type)\s*(?:==|!=)\s*$', before) or re.search(r'\bcase\s*$', before):
        return True
    if re.search(r'^\W*[^\n]*?[\'"]\s*(?:==|!=)\s*(?:\w+\.)?(?:name|event)\b', after):
        return True
    if re.search(r'(?:\{|,)\s*$', before) and re.search(r'\}\s*\.contains\(\s*(?:\w+\.)?(?:name|event)', code[pos:pos + 400]):
        return True
    if re.search(r'\b(?:name|event\.name)\s*\.\s*(?:startsWith|endsWith)\s*\(\s*$', before):
        return True
    return False


# --------------------------------------------------------------------------- external callers

def external_usage(lib, tests, module_files, names_by_member, cls=DEFAULT_CLASS):
    """{member: {'refs': n, 'files': n, 'test_files': n}} from receiver-typed references."""
    names = set(names_by_member)
    out = {n: dict(refs=0, files=set(), test_files=set()) for n in names}
    rx_decl = re.compile(re.escape(cls) + r'\??\s+(?:get\s+)?([a-z_]\w*)')
    module = {str(p) for p in module_files}
    for kind, base in (('lib', lib), ('test', tests)):
        if not base:
            continue
        for path in sorted(pathlib.Path(base).rglob('*.dart')):
            if str(path.resolve()) in module:
                continue
            text = path.read_text(encoding='utf-8')
            if cls not in text:
                continue
            code, _ = blank(text)
            recv = {m for m in rx_decl.findall(code) if m not in ('get', 'extends')}
            recv |= set(re.findall(r'\b([a-z_]\w*)\s*=\s*(?:await\s+)?' + re.escape(cls) + r'(?:\.\w+)?\s*\(', code))
            if re.search('<' + re.escape(cls) + r'>\s*\(\s*\)', code):
                recv.add('')
            if not recv:
                continue
            named = [r for r in recv if r]
            patterns = []
            if named:
                patterns.append(r'\b(?:' + '|'.join(map(re.escape, sorted(named))) + r')\s*[?!]?\s*\.\s*([A-Za-z_]\w*)')
            if '' in recv:
                patterns.append('<' + re.escape(cls) + r'>\s*\(\s*\)\s*[?!]?\s*\.\s*([A-Za-z_]\w*)')
            seen = collections.Counter()
            for pat in patterns:
                for m in re.finditer(pat, code):
                    if m.group(1) in names:
                        seen[m.group(1)] += 1
            for name, count in seen.items():
                rec = out[name]
                if kind == 'lib':
                    rec['refs'] += count
                    rec['files'].add(str(path.relative_to(lib)))
                else:
                    rec['test_files'].add(str(path.relative_to(tests)))
    return out


# --------------------------------------------------------------------------- report

def label_for(fields, usage):
    top = sorted(fields, key=lambda f: (-usage[f], f))[:3]
    return ', '.join(top)


def build_report(result, ext, args):
    members = result['members']
    mc = result['member_cluster']
    cf = result['cluster_of_field']
    effective = result['effective']
    clusters = []
    for cid in result['cluster_ids']:
        fields = sorted(f for f, c in cf.items() if c == cid)
        ms = sorted(n for n, c in mc.items() if c == cid)
        rows = []
        for n in ms:
            m = members[n]
            r, w = effective[n]
            rows.append(dict(name=n, kind='/'.join(sorted(m.kinds)), lines=m.lines,
                             public=not n.startswith('_'), reads=sum(r.values()), writes=sum(w.values())))
        lines = sum(r['lines'] for r in rows) + sum(1 for f in result['field_members'] if f.name in fields)
        public = [r['name'] for r in rows if r['public'] and r['name'] in ext] + [f for f in fields if f in ext]
        refs = sum(ext[n]['refs'] for n in public)
        files = set()
        tests = set()
        for n in public:
            files |= ext[n]['files']
            tests |= ext[n]['test_files']
        used_pub = [n for n in public if ext[n]['refs']]
        events = {}
        for ev, info in result['events'].items():
            clusters_for = info['clusters']
            if not clusters_for:
                continue
            best = max(clusters_for.items(), key=lambda kv: (kv[1], -kv[0]))
            if best[0] == cid:
                events[ev] = sorted(c for c in clusters_for if c != cid)
        notifies = sum(1 for n in ms if 'notifyListeners' in members[n].file.code[members[n].start:members[n].end])
        mine = set(ms)
        leaks = collections.Counter()
        deps = collections.Counter()
        hubs_used = collections.Counter()
        for n, m in members.items():
            direct = set(m.reads) | set(m.writes)
            if n in mine:
                for f in direct:
                    if f in result['hubs']:
                        hubs_used[f] += 1
                    elif cf.get(f) not in (None, cid):
                        deps[cf[f]] += 1
            else:
                for f in direct:
                    if cf.get(f) == cid:
                        leaks[f] += 1
        clusters.append(dict(id=cid, leaks=dict(leaks.most_common()), depends_on=dict(deps.most_common()),
                             hubs_used=dict(hubs_used.most_common()), label=label_for(fields, result['usage']), fields=fields, members=rows,
                             member_lines=lines, external=dict(refs=refs, files=len(files), members_used=len(used_pub),
                                                                top_members=sorted(used_pub, key=lambda n: -ext[n]['refs'])[:8],
                                                                test_files=len(tests)),
                             events=events, notifies=notifies))
    # coupling
    calls = collections.defaultdict(int)
    shared = collections.defaultdict(list)
    for n, m in members.items():
        a = mc.get(n)
        if a is None:
            continue
        for callee, c in m.uses.items():
            b = mc.get(callee)
            if b is not None and b != a:
                calls[(a, b)] += c
        v = result['member_votes'][n]
        if len(v) > 1:
            top = sorted(v, key=lambda c: -v[c])
            for other in top:
                if other != a:
                    shared[(a, other)].append(n)
    for c in clusters:
        cid = c['id']
        coupling = []
        for other in result['cluster_ids']:
            if other == cid:
                continue
            out_calls, in_calls = calls.get((cid, other), 0), calls.get((other, cid), 0)
            sh = len(set(shared.get((cid, other), [])) | set(shared.get((other, cid), [])))
            if out_calls or in_calls or sh:
                coupling.append(dict(cluster=other, calls_out=out_calls, calls_in=in_calls, shared_members=sh))
        coupling.sort(key=lambda d: -(d['calls_out'] + d['calls_in'] + d['shared_members']))
        c['coupling'] = coupling
    unassigned = sorted(n for n in members if n not in mc)
    cross = []
    for n, v in result['member_votes'].items():
        if len(v) >= args.cross_clusters:
            m = members[n]
            cross.append(dict(name=n, lines=m.lines, clusters=sorted(v), home=mc.get(n)))
    cross.sort(key=lambda d: (-len(d['clusters']), -d['lines'], d['name']))
    events = {ev: dict(handlers=info['handlers'], clusters=sorted(info['clusters']),
                       primary=(max(info['clusters'].items(), key=lambda kv: (kv[1], -kv[0]))[0] if info['clusters'] else None))
              for ev, info in sorted(result['events'].items())}
    hubs = [dict(field=f, members=result['usage'][f]) for f in sorted(result['hubs'], key=lambda f: -result['usage'][f])]
    return dict(class_name=args.cls, files=[str(pathlib.Path(f).relative_to(ROOT)) if str(f).startswith(str(ROOT)) else str(f)
                                           for f in result['files']],
                totals=dict(members=result['n_members'], fields=len(result['fields']), static_fields=len(result['static_fields']),
                            hub_fields=len(hubs), clusters=len(clusters), cross_cutting=len(cross),
                            unassigned_members=len(unassigned)),
                cross_threshold=args.cross_clusters, hubs=hubs, wide_members=result['wide'], cross_cutting=cross, events=events, clusters=clusters, unassigned_members=unassigned,
                unclustered_fields=sorted(f for f in result['fields'] if f not in cf and f not in result['hubs']))


def render_markdown(rep, top):
    out = []
    t = rep['totals']
    out.append(f"# {rep['class_name']} clusters\n")
    out.append(f"Source files: {', '.join('`%s`' % f for f in rep['files'])}\n")
    out.append(f"{t['members']} members, {t['fields']} instance fields ({t['static_fields']} static skipped), "
               f"{t['hub_fields']} hub fields, {t['clusters']} clusters, {t['cross_cutting']} cross-cutting members, "
               f"{t['unassigned_members']} members without a cluster.\n")
    out.append('| # | Fields | Members | Lines | Ext. refs (files) | Events | Top fields |')
    out.append('|---|---:|---:|---:|---:|---:|---|')
    for c in rep['clusters']:
        e = c['external']
        out.append(f"| {c['id']} | {len(c['fields'])} | {len(c['members'])} | {c['member_lines']} | "
                   f"{e['refs']} ({e['files']}) | {len(c['events'])} | {c['label']} |")
    out.append('')

    def cut(items):
        items = list(items)
        return ', '.join(f'`{i}`' for i in items[:top]) + (f' (+{len(items) - top} more)' if len(items) > top else '')

    tiny = [c for c in rep['clusters'] if len(c['fields']) <= 3 and len(c['members']) <= 2]
    for c in [c for c in rep['clusters'] if c not in tiny]:
        e = c['external']
        out.append(f"## Cluster {c['id']}: {c['label']}\n")
        out.append(f"- Fields ({len(c['fields'])}): {cut(c['fields'])}")
        mem = sorted(c['members'], key=lambda r: -r['lines'])
        out.append(f"- Members ({len(mem)}, {c['member_lines']} lines, {c['notifies']} call notifyListeners): "
                   f"{cut(r['name'] for r in mem)}")
        out.append(f"- External callers: {e['refs']} references in {e['files']} lib files across "
                   f"{e['members_used']} public members; {e['test_files']} test files. Top: {cut(e['top_members'])}")
        if c['events']:
            out.append(f"- Realtime events ({len(c['events'])}): {cut(sorted(c['events']))}")
        else:
            out.append('- Realtime events: none')
        if c['leaks']:
            out.append('- Fields touched by members of other clusters (field: foreign members): ' +
                       cut(f'{f}: {n}' for f, n in c['leaks'].items()))
        if c['hubs_used']:
            out.append('- Hub fields used: ' + cut(f'{f}: {n}' for f, n in c['hubs_used'].items()))
        if c['coupling']:
            parts = [f"#{k['cluster']} (calls out {k['calls_out']}, in {k['calls_in']}, shared {k['shared_members']})"
                     for k in c['coupling'][:top]]
            out.append('- Coupling: ' + '; '.join(parts))
        out.append('')
    if tiny:
        out.append('## Tiny clusters (at most 3 fields and 2 members)\n')
        for c in tiny:
            e = c['external']
            out.append(f"- {c['id']}: fields {cut(c['fields'])}; members {cut(r['name'] for r in c['members'])}; "
                       f"{e['refs']} external refs; coupling " + (', '.join(
                           f"#{k['cluster']} ({k['calls_out']}/{k['calls_in']}/{k['shared_members']})" for k in c['coupling'][:4]) or 'none'))
        out.append('')
    if rep['cross_cutting']:
        out.append(f"## Cross-cutting members (touch {rep['cross_threshold']}+ clusters)\n")
        out.append('| Member | Lines | Clusters touched | Home |')
        out.append('|---|---:|---|---:|')
        for d in rep['cross_cutting'][:top * 2]:
            out.append(f"| `{d['name']}` | {d['lines']} | {', '.join('#%d' % c for c in d['clusters'])} | #{d['home']} |")
        out.append('')
    if rep['events']:
        out.append('## Realtime events\n')
        out.append('| Event | Handler | Primary cluster | All clusters touched |')
        out.append('|---|---|---:|---|')
        for ev, info in rep['events'].items():
            out.append(f"| `{ev}` | {', '.join('`%s`' % h for h in info['handlers'])} | "
                       f"{'#%d' % info['primary'] if info['primary'] else '-'} | "
                       f"{', '.join('#%d' % c for c in info['clusters'])} |")
        out.append('')
    out.append('## Hub fields (used by many members; excluded from clustering)\n')
    out.append(', '.join(f"`{h['field']}` ({h['members']})" for h in rep['hubs']) or 'none')
    out.append('')
    if rep['wide_members']:
        out.append(f"## Orchestrators (touch more fields than the cap; excluded from weights)\n")
        out.append(cut(rep['wide_members']))
        out.append('')
    if rep['unclustered_fields']:
        out.append('## Unclustered fields\n')
        out.append(cut(rep['unclustered_fields']))
        out.append('')
    if rep['unassigned_members']:
        out.append('## Members without any cluster signal\n')
        out.append(cut(rep['unassigned_members']))
        out.append('')
    return '\n'.join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--class', dest='cls', default=DEFAULT_CLASS)
    ap.add_argument('--root', default=str(ROOT / DEFAULT_ROOT))
    ap.add_argument('--lib', default=str(ROOT / 'apps/raft_flutter/lib'))
    ap.add_argument('--tests', default=str(ROOT / 'apps/raft_flutter/test'))
    ap.add_argument('--json', action='store_true', help='emit JSON (adds the full member table)')
    ap.add_argument('--hub-ratio', type=float, default=0.08, help='fields used by >= this share of members are hubs')
    ap.add_argument('--hub', action='append', default=[], help='force a field to be a hub (repeatable)')
    ap.add_argument('--max-fields', type=int, default=25, help='members touching more non-hub fields are orchestrators')
    ap.add_argument('--resolution', type=float, default=2.0, help='Louvain resolution; higher gives more clusters')
    ap.add_argument('--cross-clusters', type=int, default=5, help='members touching this many clusters are cross-cutting')
    ap.add_argument('--top', type=int, default=14, help='items shown per Markdown list')
    args = ap.parse_args(argv)
    result = analyse(args.root, args.lib, args.cls, args.hub_ratio, args.max_fields, args.resolution, force_hubs=args.hub)
    public = [n for n in list(result['members']) + result['fields'] if not n.startswith('_')]
    ext = external_usage(args.lib, args.tests, result['files'], public, args.cls)
    rep = build_report(result, ext, args)
    if args.json:
        rep['member_table'] = {
            n: dict(kind='/'.join(sorted(m.kinds)), lines=m.lines, cluster=result['member_cluster'].get(n),
                    reads=sorted(result['effective'][n][0]), writes=sorted(result['effective'][n][1]),
                    uses=sorted(m.uses), external_refs=ext.get(n, {}).get('refs', 0),
                    external_files=sorted(ext.get(n, {}).get('files', [])),
                    test_files=sorted(ext.get(n, {}).get('test_files', [])))
            for n, m in sorted(result['members'].items())}
        rep['field_table'] = {f: dict(cluster=result['cluster_of_field'].get(f), hub=f in result['hubs'],
                                       members=result['usage'][f]) for f in result['fields']}
        json.dump(rep, sys.stdout, indent=1, sort_keys=True)
        print()
    else:
        print(render_markdown(rep, args.top))
    return 0


if __name__ == '__main__':
    sys.exit(main())
