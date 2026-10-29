"""Behaviour-parity checklists: computed status and Web drift detection.

CLI wrapper: tool/behavior-parity. Rules: docs/development.md ("Behaviour parity").

A domain checklist (docs/behavior-parity/<domain>.md) is a markdown table of
rows keyed by a stable ID (BP-<DOMAIN>-NNN), each anchored to a Web symbol
(`<path rel. to packages/web/src>#<symbol>` or `...#event:<socket event>`).
Nothing in this module needs a TypeScript toolchain: Web sources are read with
a small scanner (comments, strings, template literals and regex literals are
masked, brackets are matched) that is good enough to find declarations and their
extents. It is validated against the TypeScript AST in docs/behavior-parity/VALIDATION.md.
"""
from __future__ import annotations

import argparse
import bisect
import hashlib
import json
import os
import re
import subprocess
import sys
import zlib
from dataclasses import dataclass, field
from fnmatch import fnmatchcase
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC_DIR = Path('docs/behavior-parity')
WEB_SRC = Path('packages/web/src')
COLUMNS = ['ID', 'Web anchor', 'Web behaviour', 'Web ref', 'Flutter ref', 'Audit', 'Test hint', 'Notes']
DECLARED_STATUSES = ('intended-difference', 'n-a')
AUDIT_VALUES = ('aligned', 'missing', 'differs', 'intended-difference', 'in-progress', 'n-a', 'unverified')
ID_RE = re.compile(r'\bBP-[A-Z]+-\d{3,}\b')
IDENT = r'[A-Za-z_$][\w$]*'
KEYWORDS = frozenset(
    'if for while switch catch function return with else do try new typeof void await super import '
    'export default case throw delete in of yield finally class const let var'.split())
REGEX_PREV_WORDS = frozenset('return typeof case in of delete void throw new await yield else do instanceof'.split())


# --------------------------------------------------------------------------
# Source scanning
# --------------------------------------------------------------------------

def mask(text: str):
    """Return (masked, kinds). `kinds[i]` is b'c' code, b's' string/regex, b'm' comment.

    `masked` has the same length as `text`: comment characters and the contents
    of strings, regex literals and template-literal text are replaced by spaces
    (newlines are kept), `${...}` expressions inside templates stay code.
    """
    n = len(text)
    out = list(text)
    kinds = bytearray(b'c' * n)

    def mark(a: int, b: int, kind: int, keep_edges: int = 0):
        for k in range(a, b):
            kinds[k] = kind
            if keep_edges and (k < a + keep_edges or k >= b - keep_edges):
                continue
            if out[k] != '\n':
                out[k] = ' '

    S, M = ord('s'), ord('m')
    brace_stack: list[int] = []  # open `${` expressions: nested brace count
    prev_sig = ''
    i = 0

    def scan_template(j: int):
        start = j
        while j < n:
            ch = text[j]
            if ch == '\\':
                j += 2
                continue
            if ch == '`':
                mark(start, j, S)
                return j + 1, True
            if ch == '$' and j + 1 < n and text[j + 1] == '{':
                mark(start, j, S)
                return j + 2, False
            j += 1
        mark(start, min(j, n), S)
        return n, True

    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ''
        if c == '/' and nxt == '/':
            j = text.find('\n', i)
            j = n if j < 0 else j
            mark(i, j, M)
            i = j
            continue
        if c == '/' and nxt == '*':
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            mark(i, j, M)
            i = j
            continue
        if c == '"' or (c == "'" and not (i > 0 and text[i - 1].isalnum())):
            j = i + 1
            while j < n and text[j] != c and text[j] != '\n':
                j += 2 if text[j] == '\\' else 1
            end = j + 1 if j < n and text[j] == c else min(j, n)
            mark(i, end, S, keep_edges=1 if end - i >= 2 and text[end - 1] == c else 0)
            prev_sig = c
            i = end
            continue
        if c == '`':
            mark(i, i + 1, S, keep_edges=1)
            i, ended = scan_template(i + 1)
            if not ended:
                brace_stack.append(0)
            prev_sig = '`'
            continue
        if c == '/':
            word = ''
            if prev_sig.isalnum() or prev_sig in '_$':
                m = re.search(r'([A-Za-z_$][\w$]*)\s*$', text[max(0, i - 16):i])
                word = m.group(1) if m else ''
            regex_ok = prev_sig == '' or prev_sig in '(,=:[!&|?{};+-*%^~' or word in REGEX_PREV_WORDS
            if regex_ok:
                j, in_class = i + 1, False
                while j < n and text[j] != '\n':
                    ch = text[j]
                    if ch == '\\':
                        j += 2
                        continue
                    if ch == '[':
                        in_class = True
                    elif ch == ']':
                        in_class = False
                    elif ch == '/' and not in_class:
                        break
                    j += 1
                if j < n and text[j] == '/':
                    end = j + 1
                    while end < n and text[end].isalpha():
                        end += 1
                    mark(i, end, S)
                    prev_sig = ')'
                    i = end
                    continue
        if c == '{' and brace_stack:
            brace_stack[-1] += 1
        elif c == '}' and brace_stack:
            if brace_stack[-1] == 0:
                brace_stack.pop()
                i, ended = scan_template(i + 1)
                if not ended:
                    brace_stack.append(0)
                prev_sig = '`'
                continue
            brace_stack[-1] -= 1
        if not c.isspace():
            prev_sig = c
        i += 1
    return ''.join(out), bytes(kinds)


def _is_word(ch: str) -> bool:
    return ch.isalnum() or ch in '_$'


def normalize(text: str, kinds: bytes, start: int, end: int) -> str:
    """Whitespace/comment-insensitive form of text[start:end].

    Comments are dropped, whitespace is dropped except where two word
    characters would fuse, trailing commas before `)]}` and a `;` before `}`
    are dropped, simple single-quoted strings become double-quoted.
    """
    toks: list[tuple[str, str]] = []  # (text, 'c' | 's')
    k = start
    pending_space = False
    while k < end:
        kd = kinds[k]
        ch = text[k]
        if kd == ord('m'):
            pending_space = True
            k += 1
            continue
        if kd == ord('s'):
            j = k
            while j < end and kinds[j] == ord('s'):
                j += 1
            run = text[k:j]
            if len(run) >= 2 and run[0] == "'" and run[-1] == "'" and '"' not in run and '\\' not in run:
                run = '"' + run[1:-1] + '"'
            if pending_space and toks and _is_word(toks[-1][0][-1]) and _is_word(run[0]):
                toks.append((' ', 'c'))
            pending_space = False
            toks.append((run, 's'))
            k = j
            continue
        if ch.isspace():
            pending_space = True
            k += 1
            continue
        if pending_space and toks:
            last = toks[-1][0][-1]
            if (_is_word(last) and _is_word(ch)) or (last in '+-' and ch == last):
                toks.append((' ', 'c'))
        pending_space = False
        if toks and toks[-1][1] == 'c':
            if ch in ')]}' and toks[-1][0] == ',':
                toks.pop()
            elif ch == '}' and toks[-1][0] == ';':
                toks.pop()
        toks.append((ch, 'c'))
        k += 1
    return ''.join(t for t, _ in toks)


# `handler: name,` / `handler: (x) => ...` / shorthand `handler,` inside a binding object
HANDLER_KEY_RE = re.compile(r'(?<![\w$.])handler\s*(?::\s*(' + IDENT + r')\s*(?=[,}])|:|(?=[,}]))')
TYPE_BODY_RE = re.compile(
    r'(?:void|string|number|boolean|unknown|any|never|null|undefined|object|bigint|symbol)\b(?!\s*[(.])'
    r'|[A-Z][\w$.]*(?:<|\[\]|\s*[;,)}|&]|\s*$)(?!\s*\()')


@dataclass
class Span:
    start: int
    end: int
    kind: str  # func | var | var-fn | member-fn | member | class | event
    name: str = ''
    depth: int = 0
    rank: int = 0


class Source:
    """A TS/TSX/Dart file with masked text and bracket matching."""

    def __init__(self, text: str):
        self.text = text
        self.masked, self.kinds = mask(text)
        self.close_of: dict[int, int] = {}
        self.open_of: dict[int, int] = {}
        self.parent: dict[int, int] = {}
        self.opens: list[int] = []
        self._depth_events: list[tuple[int, int]] = []  # (pos, depth after)
        stack: list[int] = []
        for m in re.finditer(r'[()\[\]{}]', self.masked):
            p, ch = m.start(), m.group()
            if ch in '([{':
                self.parent[p] = stack[-1] if stack else -1
                stack.append(p)
                self.opens.append(p)
            elif stack:
                o = stack.pop()
                self.close_of[o] = p
                self.open_of[p] = o
            self._depth_events.append((p, len(stack)))
        self._depth_pos = [p for p, _ in self._depth_events]
        self._line_starts = [0] + [m.end() for m in re.finditer(r'\n', text)]

    def line_of(self, pos: int) -> int:
        return bisect.bisect_right(self._line_starts, pos)

    def depth_at(self, pos: int) -> int:
        i = bisect.bisect_right(self._depth_pos, pos - 1) - 1
        return self._depth_events[i][1] if i >= 0 else 0

    def enclosing_open(self, pos: int) -> int:
        i = bisect.bisect_left(self.opens, pos) - 1
        while i >= 0:
            o = self.opens[i]
            c = self.close_of.get(o)
            if c is None or c > pos:
                return o
            # o closed before pos: climb to its parent
            p = self.parent.get(o, -1)
            if p < 0:
                return -1
            i = bisect.bisect_left(self.opens, p)
            if i < len(self.opens) and self.opens[i] == p:
                c = self.close_of.get(p)
                if c is None or c > pos:
                    return p
                continue
            return -1
        return -1

    def skip_ws(self, i: int) -> int:
        m = self.masked
        n = len(m)
        while i < n and m[i].isspace():
            i += 1
        return i

    def prev_sig(self, i: int) -> str:
        m = self.masked
        i -= 1
        while i >= 0 and m[i].isspace():
            i -= 1
        return m[i] if i >= 0 else ''

    def skip_group(self, i: int) -> int:
        """If masked[i] opens a bracket, return index after its close, else i."""
        c = self.close_of.get(i)
        return c + 1 if c is not None else i

    def skip_angle(self, i: int) -> int:
        """masked[i] == '<': return the index after the matching '>' (generic parameter/argument list)."""
        m, n = self.masked, len(self.masked)
        depth = 0
        while i < n:
            ch = m[i]
            if ch == '<':
                depth += 1
            elif ch == '>' and m[i - 1] != '=':
                depth -= 1
                if depth == 0:
                    return i + 1
            elif ch in '([{':
                j = self.skip_group(i)
                i = j if j != i else i + 1
                continue
            elif ch in ';)]}':
                return i
            i += 1
        return i

    def scan_type(self, i: int) -> int:
        """Skip a type annotation starting at i; stop before `{` (body), `=`, `;`, `,` or closer at depth 0."""
        m, n = self.masked, len(self.masked)
        while i < n:
            ch = m[i]
            if ch.isspace():
                i += 1
            elif ch == '=' and m[i:i + 2] == '=>':
                i += 2
            elif ch in '([':
                j = self.skip_group(i)
                if j == i:
                    return i
                i = j
            elif ch == '<':
                depth = 0
                while i < n:
                    if m[i] == '<':
                        depth += 1
                    elif m[i] == '>' and m[i - 1] != '=':
                        depth -= 1
                        if depth == 0:
                            i += 1
                            break
                    elif m[i] in '([{':
                        j = self.skip_group(i)
                        i = j if j != i else i + 1
                        continue
                    i += 1
            elif ch == '{':
                prev = self.prev_sig(i)
                if prev in ':|&<,(' or m[:i].rstrip().endswith('=>'):
                    j = self.skip_group(i)
                    if j == i:
                        return i
                    i = j
                else:
                    return i
            elif ch in '=;,)]}':
                return i
            else:
                i += 1
        return i

    def expr_end(self, i: int, stop_comma: bool = True) -> int:
        """End (exclusive) of the expression/statement beginning at i."""
        m, n = self.masked, len(self.masked)
        while i < n:
            ch = m[i]
            if ch in '([{':
                j = self.skip_group(i)
                if j == i:
                    return n
                i = j
                continue
            if ch in ')]}':
                return i
            if ch == ';':
                return i + 1
            if ch == ',' and stop_comma:
                return i
            if ch == '\n':
                prev = self.prev_sig(i)
                nxt = self.skip_ws(i)
                rest = m[nxt:nxt + 12]
                cont = (
                    prev in '=+-*/%&|^?:,.([{!~'
                    or m[:i].rstrip().endswith('=>')
                    or rest[:1] in ('.', '?', ':', ',', ')', ']', '}', '=', '*', '/', '%', '|', '^', '&')
                    or rest[:2] in ('&&', '||', '??', '=>')
                    or re.match(r'(?:\+|-)\s', rest) is not None
                    or re.match(r'(?:instanceof|in|as|satisfies)\b', rest) is not None
                )
                if nxt >= n:
                    return i
                if not cont:
                    return i
            i += 1
        return n

    # ---- definitions -----------------------------------------------------

    def _arrow_after_params(self, i: int):
        """If a function-like value starts at i, return (body_start_idx) of '=>' body, else None."""
        m = self.masked
        i = self.skip_ws(i)
        mm = re.compile(r'(?:async\s+)?').match(m, i)
        i = mm.end()
        if m.startswith('function', i) and not _is_word(m[i + 8:i + 9] or ' '):
            return ('function', i)
        j = i
        if m[j:j + 1] == '<':
            j = self.skip_angle(j)
        if m[j:j + 1] == '(':
            k = self.skip_group(j)
            k = self.skip_ws(k)
            if m[k:k + 1] == ':':
                k = self.scan_type(k + 1)
                k = self.skip_ws(k)
            if m[k:k + 2] == '=>':
                return ('arrow', k + 2)
            return None
        mm = re.compile(IDENT + r'\s*=>').match(m, j)
        if mm:
            return ('arrow', mm.end())
        return None

    def _function_end(self, kind_info) -> int:
        kind, idx = kind_info
        m = self.masked
        if kind == 'arrow':
            k = self.skip_ws(idx)
            if m[k:k + 1] == '{':
                return self.skip_group(k)
            return self.expr_end(k)
        # function expression: function name?(params) {body}
        k = idx + 8
        k = self.skip_ws(k)
        if m[k:k + 1] == '*':
            k = self.skip_ws(k + 1)
        mm = re.compile(IDENT).match(m, k)
        if mm:
            k = self.skip_ws(mm.end())
        return self._params_and_body(k)

    def _params_and_body(self, k: int) -> int:
        """k at '<' or '('; return end of body block, or -1 when there is no body."""
        m = self.masked
        if m[k:k + 1] == '<':
            k = self.skip_angle(k)
            k = self.skip_ws(k)
        if m[k:k + 1] != '(':
            return -1
        k = self.skip_ws(self.skip_group(k))
        if m[k:k + 1] == ':':
            k = self.scan_type(k + 1)
            k = self.skip_ws(k)
        if m[k:k + 1] == '{':
            return self.skip_group(k)
        return -1

    def _in_type_range(self, pos: int, ranges) -> bool:
        i = bisect.bisect_right([a for a, _ in ranges], pos) - 1
        return i >= 0 and ranges[i][0] <= pos < ranges[i][1]

    def _type_ranges(self):
        if hasattr(self, '_tr'):
            return self._tr
        ranges = []
        m = self.masked
        for mm in re.finditer(r'(?<![\w$.])interface\s+' + IDENT, m):
            k = m.find('{', mm.end())
            if k >= 0:
                ranges.append((k, self.skip_group(k)))
        for mm in re.finditer(r'(?<![\w$.])type\s+' + IDENT + r'\s*(?:<|=)', m):
            k = m.find('=', mm.start())
            k = self.skip_ws(k + 1)
            ranges.append((k, self.expr_end(k, stop_comma=False)))
        ranges.sort()
        self._tr = ranges
        return ranges

    def iter_defs(self, only: str | None = None):
        """Yield Span for every declaration in the file (optionally only `only`)."""
        m = self.masked
        nm = (re.escape(only) if only else IDENT)
        ranges = self._type_ranges()
        # function declarations
        for mm in re.finditer(r'(?<![\w$.])(?:export\s+(?:default\s+)?)?(?:declare\s+)?(?:async\s+)?function\s*\*?\s*(?P<name>' + nm + r')\s*[<(]', m):
            k = mm.end() - 1
            end = self._params_and_body(k)
            if end < 0:
                continue
            yield Span(mm.start(), end, 'func', mm.group('name'), self.depth_at(mm.start()), 0)
        # const / let / var
        for mm in re.finditer(r'(?<![\w$.])(?:export\s+)?(?:declare\s+)?(?P<kw>const|let|var)\s+(?P<name>' + nm + r')\s*(?=[:=!])', m):
            k = mm.end()
            if m[k:k + 1] == '!':
                k += 1
            if m[k:k + 1] == ':':
                k = self.scan_type(k + 1)
            k = self.skip_ws(k)
            if m[k:k + 1] != '=' or m[k:k + 2] in ('==', '=>'):
                continue
            k = self.skip_ws(k + 1)
            info = self._arrow_after_params(k)
            if info:
                end = self._function_end(info)
                kind, rank = 'var-fn', 0
            else:
                end = self.expr_end(k, stop_comma=False)
                head = m[k:k + 60]
                kind = 'var'
                rank = 0 if re.match(r'use(?:Callback|Memo|Effect|LayoutEffect)\(|create\(|create<', head) else 1
            yield Span(mm.start(), end, kind, mm.group('name'), self.depth_at(mm.start()), rank)
        # class / interface / enum / type
        for mm in re.finditer(r'(?<![\w$.])(?:export\s+(?:default\s+)?)?(?:declare\s+)?(?:abstract\s+)?(?P<kw>class|interface|enum|type)\s+(?P<name>' + nm + r')\b', m):
            kw = mm.group('kw')
            if kw == 'type':
                k = self.skip_ws(mm.end())
                if m[k:k + 1] not in ('<', '='):
                    continue
                e = m.find('=', mm.end())
                k = self.skip_ws(e + 1)
                end = self.expr_end(k, stop_comma=False)
            else:
                k = m.find('{', mm.end())
                if k < 0:
                    continue
                end = self.skip_group(k)
            yield Span(mm.start(), end, 'class', mm.group('name'), self.depth_at(mm.start()), 1)
        # object/class members
        member_re = re.compile(
            r'(?<![\w$.?])(?P<mods>(?:(?:public|private|protected|static|readonly|abstract|override|async|get|set)\s+)*)\*?\s*(?P<name>' + nm + r')\s*(?P<opt>\?)?\s*(?P<sep>[:(<=])')
        for mm in member_re.finditer(m):
            name = mm.group('name')
            if name in KEYWORDS:
                continue
            start = mm.start('mods') if mm.group('mods') else mm.start('name')
            prev = self.prev_sig(start)
            if prev not in ('{', ',', ';', '}', ''):
                continue
            if self._in_type_range(start, ranges):
                continue
            sep = mm.group('sep')
            if sep == ':':
                if m[mm.end():mm.end() + 1] == ':':
                    continue
                k = self.skip_ws(mm.end())
                info = self._arrow_after_params(k)
                if info and info[0] == 'arrow' and TYPE_BODY_RE.match(m, self.skip_ws(info[1])):
                    continue  # `name: (args) => Type` is a type member, not a function value
                if info:
                    end = self._function_end(info)
                    yield Span(start, end, 'member-fn', name, self.depth_at(start), 0)
                else:
                    end = self.expr_end(k, stop_comma=True)
                    yield Span(start, end, 'member', name, self.depth_at(start), 2)
            elif sep in '(<':
                end = self._params_and_body(mm.end() - 1)
                if end < 0:
                    continue
                yield Span(start, end, 'member-fn', name, self.depth_at(start), 0)
            elif sep == '=':
                if m[mm.end():mm.end() + 1] in ('=', '>'):
                    continue
                o = self.enclosing_open(start)
                if o < 0 or m[o] != '{' or not re.search(r'\bclass\b[^{;]*$', m[max(0, o - 200):o]):
                    continue
                k = self.skip_ws(mm.end())
                info = self._arrow_after_params(k)
                end = self._function_end(info) if info else self.expr_end(k, stop_comma=False)
                yield Span(start, end, 'member-fn' if info else 'member', name, self.depth_at(start), 0 if info else 2)

    def find_defs(self, name: str) -> list[Span]:
        return [s for s in self.iter_defs(only=name)]

    def find_call_statements(self, name: str) -> list[Span]:
        """Top-level `name(...)` call statements (registration side effects), used when nothing is declared."""
        out = []
        for mm in re.finditer(r'(?<![\w$.])' + re.escape(name) + r'\s*\(', self.masked):
            if self.depth_at(mm.start()) != 0 or self.prev_sig(mm.start()) not in (';', '}', ''):
                continue
            out.append(Span(mm.start(), self.expr_end(mm.start(), stop_comma=False), 'call', name, 0, 3))
        return out

    def find_effects(self, ident: str) -> list[Span]:
        """`useEffect(...)` / `useLayoutEffect(...)` calls whose text mentions `ident` as a word."""
        out = []
        word = re.compile(r'(?<![\w$.])' + re.escape(ident) + r'(?![\w$])')
        for mm in re.finditer(r'(?<![\w$.])use(?:Layout)?Effect\s*\(', self.masked):
            end = self.close_of.get(mm.end() - 1)
            if end is not None and word.search(self.masked, mm.start(), end):
                out.append(Span(mm.start(), end + 1, 'effect', ident, self.depth_at(mm.start()), 0))
        return out

    # ---- event registrations --------------------------------------------

    def _handler_defs(self, ident: str) -> list[Span]:
        return best_defs(self.find_defs(ident))

    def find_event(self, event: str) -> list[Span]:
        """Spans of the handler code registered for a socket event string."""
        text, kinds = self.text, self.kinds
        q = re.escape(event)
        spans: list[Span] = []
        seen: set[tuple[int, int]] = set()

        def add(a, b, kind='event'):
            if (a, b) not in seen and b > a:
                seen.add((a, b))
                spans.append(Span(a, b, kind, event))

        def add_ident(ident):
            for d in self._handler_defs(ident):
                add(d.start, d.end, 'event')

        # {event: "X", handler: ...}
        for mm in re.finditer(r'(?<![\w$.])event\s*:\s*(["\'`])' + q + r'\1(?=\s*[,}])', text):
            if kinds[mm.start()] != ord('c'):
                continue
            o = self.enclosing_open(mm.start())
            if o < 0 or text[o] != '{':
                continue
            c = self.close_of.get(o, len(text))
            body = self.masked[o:c]
            hm = re.search(HANDLER_KEY_RE, body + '}')
            if not hm:
                continue  # not a socket binding (internal domain event / log record)
            add(o, c + 1)
            ident = hm.group(1) or (None if ':' in hm.group(0) else 'handler')
            if ident and ident not in ('undefined', 'null'):
                add_ident(ident)
        # socket.on("X", handler) / once / addEventListener
        for mm in re.finditer(r'(?<=[.\w$])(?:on|once|addListener|addEventListener)\s*\(\s*(["\'`])' + q + r'\1\s*,', text):
            if kinds[mm.start()] != ord('c'):
                continue
            open_paren = text.index('(', mm.start())
            close = self.close_of.get(open_paren, len(text))
            arg_start = mm.end()
            # second argument up to depth-0 comma or the closing paren
            k = arg_start
            while k < close:
                ch = self.masked[k]
                if ch in '([{':
                    j = self.skip_group(k)
                    k = j if j != k else k + 1
                    continue
                if ch == ',':
                    break
                k += 1
            arg = text[arg_start:k].strip()
            am = re.fullmatch(IDENT, arg)
            if am:
                add_ident(arg)
            else:
                add(arg_start, k)
        # case "X":
        for mm in re.finditer(r'(?<![\w$.])case\s+(["\'`])' + q + r'\1\s*:', text):
            if kinds[mm.start()] != ord('c'):
                continue
            k = mm.end()
            depth_break = None
            m_ = self.masked
            j = k
            while j < len(m_):
                if m_[j] in '([{':
                    nj = self.skip_group(j)
                    j = nj if nj != j else j + 1
                    continue
                if m_[j] in ')]}':
                    break
                if re.match(r'(?:case\b|default\s*:)', m_[j:j + 9]) and not _is_word(m_[j - 1]):
                    break
                j += 1
            add(mm.start(), j)
        spans.sort(key=lambda s: s.start)
        return spans


def best_defs(defs: list[Span]) -> list[Span]:
    """Pick the declaration(s) a name most likely refers to: best kind rank, then shallowest."""
    if not defs:
        return []
    key = min((d.rank, d.depth) for d in defs)
    return [d for d in defs if (d.rank, d.depth) == key]


@dataclass
class Resolution:
    ok: bool
    spans: list[Span] = field(default_factory=list)
    normalized: str = ''
    first_line: int = 0
    last_line: int = 0
    note: str = ''

    @property
    def fingerprint(self) -> str:
        return hashlib.sha256(self.normalized.encode()).hexdigest()[:16]


def resolve(src: Source, symbol: str) -> Resolution:
    if symbol.startswith('event:'):
        spans = src.find_event(symbol[6:])
        what = 'event registration'
    elif symbol.startswith('effect:'):
        spans = src.find_effects(symbol[7:])
        what = 'effect'
    else:
        spans = best_defs(src.find_defs(symbol)) or src.find_call_statements(symbol)
        what = 'declaration'
    if not spans:
        return Resolution(False, note=f'no {what} of {symbol!r}')
    spans = sorted(spans, key=lambda s: s.start)
    norm = '\n'.join(sorted(normalize(src.text, src.kinds, s.start, s.end) for s in spans))  # order-insensitive: moving code within a file is not drift
    note = f'{len(spans)} {what}s' if len(spans) > 1 else ''
    return Resolution(True, spans, norm, src.line_of(spans[0].start), src.line_of(spans[-1].end - 1), note)


# --------------------------------------------------------------------------
# Similarity sketch (rename detection)
# --------------------------------------------------------------------------

SKETCH_K = 32
RENAME_MIN_SIMILARITY = 0.6  # measured: true renames 0.67-1.0, unrelated best matches 0.08-0.59 (VALIDATION.md)
_TOKEN_RE = re.compile(r'[A-Za-z_$][\w$]*|\d+|"[^"]*"|.', re.S)


def sketch(normalized: str) -> list[int]:
    toks = _TOKEN_RE.findall(normalized)
    if len(toks) < 6:
        return []
    grams = {zlib.crc32(' '.join(toks[i:i + 3]).encode()) for i in range(len(toks) - 2)}
    return sorted(grams)[:SKETCH_K]


def similarity(a: list[int], b: list[int]) -> float:
    if not a or not b:
        return 0.0
    k = min(SKETCH_K, len(a) + len(b))
    union = sorted(set(a) | set(b))[:k]
    sa, sb = set(a), set(b)
    both = sum(1 for h in union if h in sa and h in sb)
    return both / len(union) if union else 0.0


# --------------------------------------------------------------------------
# Web tree access
# --------------------------------------------------------------------------

class WebTree:
    def __init__(self, root: Path):
        self.root = Path(root)
        self.src_root = self.root / WEB_SRC
        if not self.src_root.is_dir():
            raise SystemExit(f'error: {self.src_root} is not a directory (pass the Web checkout root)')
        self._cache: dict[str, Source] = {}
        self._files: list[str] | None = None

    def files(self) -> list[str]:
        if self._files is None:
            out = []
            for dp, dn, fn in os.walk(self.src_root):
                dn[:] = [d for d in dn if d not in ('node_modules', '__tests__', '__mocks__')]
                for f in fn:
                    if f.endswith(('.ts', '.tsx')) and not f.endswith('.d.ts') and '.test.' not in f and '.spec.' not in f:
                        out.append(os.path.relpath(os.path.join(dp, f), self.src_root))
            self._files = sorted(out)
        return self._files

    def read(self, rel: str) -> str | None:
        p = self.src_root / rel
        try:
            return p.read_text(encoding='utf-8')
        except OSError:
            return None

    def source(self, rel: str) -> Source | None:
        if rel not in self._cache:
            text = self.read(rel)
            if text is None:
                return None
            self._cache[rel] = Source(text)
        return self._cache[rel]

    def commit(self) -> str:
        try:
            return subprocess.check_output(['git', '-C', str(self.root), 'rev-parse', 'HEAD'], text=True, stderr=subprocess.DEVNULL).strip()
        except (OSError, subprocess.CalledProcessError):
            return ''

    def tag(self) -> str:
        try:
            return subprocess.check_output(['git', '-C', str(self.root), 'describe', '--tags', '--exact-match'], text=True, stderr=subprocess.DEVNULL).strip()
        except (OSError, subprocess.CalledProcessError):
            return ''

    def find_elsewhere(self, exclude: str, symbol: str) -> list[tuple[str, Resolution]]:
        """Files other than `exclude` that resolve `symbol` (precheck by text, then full resolve)."""
        needle = symbol[6:] if symbol.startswith('event:') else symbol
        hits = []
        for rel in self.files():
            if rel == exclude:
                continue
            text = self.read(rel)
            if text is None or needle not in text:
                continue
            src = self.source(rel)
            res = resolve(src, symbol)
            if not res.ok:
                continue
            if not symbol.startswith('event:') and all(s.rank >= 2 for s in res.spans):
                continue  # bare object properties are not declarations worth reporting as a move
            hits.append((rel, res))
        return hits


# --------------------------------------------------------------------------
# Checklist files
# --------------------------------------------------------------------------

@dataclass
class Row:
    id: str
    anchor: str
    behaviour: str
    web_ref: str
    flutter_ref: str
    audit: str
    test_hint: str
    notes: str
    line: int

    @property
    def path(self) -> str:
        return self.anchor.split('#', 1)[0] if '#' in self.anchor else ''

    @property
    def symbol(self) -> str:
        return self.anchor.split('#', 1)[1] if '#' in self.anchor else ''

    @property
    def has_anchor(self) -> bool:
        return bool(self.path and self.symbol) and not self.anchor.startswith('n/a')


@dataclass
class Domain:
    name: str
    file: Path
    header: dict
    rows: list[Row]
    errors: list[str]
    warnings: list[str] = field(default_factory=list)

    @property
    def sidecar(self) -> Path:
        return self.file.with_suffix('.fingerprints.json')

    @property
    def scope(self) -> list[str]:
        return _split_list(self.header.get('scope', ''))

    @property
    def events(self) -> list[str]:
        return _split_list(self.header.get('events', '*')) or ['*']

    @property
    def ignore(self) -> set[str]:
        return set(_split_list(self.header.get('ignore', '')))


def _split_list(value: str) -> list[str]:
    return [p.strip() for p in re.split(r'[,\n]', value) if p.strip()]


HEADER_RE = re.compile(r'<!--\s*behavior-parity\s*\n(.*?)-->', re.S)


def parse_domain(path: Path) -> Domain:
    text = Path(path).read_text(encoding='utf-8')
    shown = f'{DOC_DIR}/{Path(path).name}'
    errors: list[str] = []
    header: dict[str, str] = {}
    hm = HEADER_RE.search(text)
    if not hm:
        errors.append(f'{shown}: no <!-- behavior-parity ... --> header')
    else:
        key = None
        for line in hm.group(1).splitlines():
            km = re.match(r'^([a-z][a-z0-9-]*):\s*(.*)$', line)
            if km:
                key = km.group(1)
                header[key] = km.group(2).strip()
            elif key and line.strip():
                header[key] += ' ' + line.strip()
        for req in ('domain', 'id-prefix', 'web'):
            if req not in header:
                errors.append(f'{shown}: header missing `{req}:`')
    rows: list[Row] = []
    warnings: list[str] = []
    seen: dict[str, int] = {}
    for ln, line in enumerate(text.splitlines(), 1):
        if not re.match(r'^\|\s*BP-', line):
            continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if len(cells) != len(COLUMNS):
            errors.append(f'{shown}:{ln}: expected {len(COLUMNS)} cells, found {len(cells)}')
            continue
        row = Row(*cells, line=ln)
        if not ID_RE.fullmatch(row.id):
            errors.append(f'{shown}:{ln}: malformed ID {row.id!r}')
        elif header.get('id-prefix') and not row.id.startswith(header['id-prefix'] + '-'):
            errors.append(f'{shown}:{ln}: {row.id} does not start with id-prefix {header["id-prefix"]}')
        if row.id in seen:
            errors.append(f'{shown}:{ln}: duplicate ID {row.id} (first at line {seen[row.id]})')
        seen[row.id] = ln
        if row.audit not in AUDIT_VALUES:
            errors.append(f'{shown}:{ln}: {row.id} Audit {row.audit!r} not one of {", ".join(AUDIT_VALUES)}')
        if row.audit in DECLARED_STATUSES and not re.search(r'\b(?:owner|Kevin)\b.*\b20\d\d-\d\d-\d\d\b|\b20\d\d-\d\d-\d\d\b.*\b(?:owner|Kevin)\b', row.notes, re.I):
            warnings.append(f'{shown}:{ln}: {row.id} is declared {row.audit} but Notes has no owner decision and date (YYYY-MM-DD)')
        if row.anchor and not row.anchor.startswith('n/a') and ('#' not in row.anchor or not row.symbol):
            errors.append(f'{shown}:{ln}: {row.id} anchor {row.anchor!r} is not <path>#<symbol>')
        rows.append(row)
    if not rows:
        errors.append(f'{shown}: no BP rows found')
    name = header.get('domain', Path(path).stem)
    return Domain(name, Path(path), header, rows, errors, warnings)


def find_domains(repo: Path, only: list[str] | None = None) -> list[Domain]:
    d = repo / DOC_DIR
    files = sorted(p for p in d.glob('*.md') if p.name != 'VALIDATION.md' and p.name != 'README.md')
    domains = [parse_domain(p) for p in files]
    domains = [dm for dm in domains if dm.header]
    if only:
        domains = [dm for dm in domains if dm.name in only]
    return domains


# --------------------------------------------------------------------------
# Test ID scan (status computation)
# --------------------------------------------------------------------------

_TEST_CALL_RE = re.compile(r'(?<![\w$.])(?P<fn>test\w*)\s*\(\s*')
_STRING_RE = re.compile(r'''(?:r)?(?P<q>'{3}|"{3}|'|")(?P<body>.*?)(?P=q)''', re.S)


def scan_test_file(text: str) -> list[tuple[str, int, bool]]:
    """Return [(id, line, skipped)] for every BP ID in a test()/testWidgets() description."""
    masked, _ = mask(text)
    src_lines = [0] + [m.end() for m in re.finditer(r'\n', text)]
    found = []
    for mm in _TEST_CALL_RE.finditer(masked):
        i = mm.end()
        # first argument may be adjacent string literals; collect to the first depth-0 comma
        open_paren = mm.end() - 1
        while open_paren > 0 and masked[open_paren] != '(':
            open_paren -= 1
        depth = 0
        j = i
        n = len(masked)
        while j < n:
            ch = masked[j]
            if ch in '([{':
                depth += 1
            elif ch in ')]}':
                if depth == 0:
                    break
                depth -= 1
            elif ch == ',' and depth == 0:
                break
            j += 1
        desc = text[i:j]
        ids = ID_RE.findall(desc)
        if not ids:
            continue
        # skipped: `skip:` named argument at depth 1 of the call, value not false/null
        close = j
        d2, k = 0, i
        skipped = False
        while k < n:
            ch = masked[k]
            if ch in '([{':
                d2 += 1
            elif ch in ')]}':
                if d2 == 0:
                    break
                d2 -= 1
            elif d2 == 0 and masked.startswith('skip', k) and re.match(r'skip\s*:(?!\s*(?:false|null)\b)', masked[k:k + 24]) and not _is_word(masked[k - 1]):
                skipped = True
                break
            k += 1
        line = bisect.bisect_right(src_lines, mm.start())
        for tid in ids:
            found.append((tid, line, skipped))
    return found


def collect_test_ids(repo: Path) -> dict[str, list[tuple[str, int, bool]]]:
    out: dict[str, list[tuple[str, int, bool]]] = {}
    roots = [repo / 'apps/raft_flutter/test'] + sorted((repo / 'packages').glob('*/test'))
    for r in roots:
        if not r.is_dir():
            continue
        for p in sorted(r.rglob('*.dart')):
            try:
                text = p.read_text(encoding='utf-8')
            except OSError:
                continue
            if 'BP-' not in text:
                continue
            for tid, line, skipped in scan_test_file(text):
                out.setdefault(tid, []).append((str(p.relative_to(repo)), line, skipped))
    return out


def compute_status(row: Row, tests: dict) -> tuple[str, str]:
    """Return (status, detail). Status: aligned | intended-difference | n-a | open."""
    hits = [t for t in tests.get(row.id, []) if not t[2]]
    if row.audit in DECLARED_STATUSES:
        return row.audit, 'declared'
    if hits:
        return 'aligned', f'{len(hits)} test(s)'
    if tests.get(row.id):
        return 'open', 'only skipped tests'
    return 'open', row.audit


# --------------------------------------------------------------------------
# Fingerprints and drift
# --------------------------------------------------------------------------

def load_sidecar(domain: Domain) -> dict | None:
    if not domain.sidecar.exists():
        return None
    return json.loads(domain.sidecar.read_text(encoding='utf-8'))


def compute_fingerprints(domain: Domain, web: WebTree, with_sketch: bool = True):
    """Return (rows dict, unresolved list[(id, message)])."""
    rows, bad = {}, []
    for row in domain.rows:
        if not row.has_anchor:
            continue
        src = web.source(row.path)
        if src is None:
            bad.append((row.id, f'{row.anchor}: file {row.path} does not exist in the Web checkout'))
            continue
        res = resolve(src, row.symbol)
        if not res.ok:
            bad.append((row.id, f'{row.anchor}: {res.note}'))
            continue
        entry = {'anchor': row.anchor, 'fingerprint': res.fingerprint, 'lines': f'{res.first_line}-{res.last_line}'}
        if res.note:
            entry['note'] = res.note
        if with_sketch:
            entry['sketch'] = sketch(res.normalized)
        rows[row.id] = entry
    return rows, bad


@dataclass
class Drift:
    state: str  # unchanged | CHANGED | MOVED | REMOVED | UNRESOLVED | NEW | STALE | -
    detail: str = ''
    new_path: str = ''
    changed: bool | None = None
    candidate: str = ''
    similarity: float = 0.0


def check_row(row: Row, entry: dict | None, web: WebTree) -> Drift:
    if not row.has_anchor:
        return Drift('-', 'no Web anchor')
    if entry is None:
        return Drift('NEW', 'no baseline fingerprint (run --update-fingerprints)')
    if entry['anchor'] != row.anchor:
        return Drift('STALE', f'sidecar anchor {entry["anchor"]!r} differs from row (run --update-fingerprints)')
    src = web.source(row.path)
    res = resolve(src, row.symbol) if src is not None else Resolution(False, note='file missing')
    if res.ok:
        if res.fingerprint == entry['fingerprint']:
            return Drift('unchanged')
        return Drift('CHANGED', f'lines {res.first_line}-{res.last_line}')
    hits = web.find_elsewhere(row.path, row.symbol)
    if len(hits) == 1:
        rel, r2 = hits[0]
        same = r2.fingerprint == entry['fingerprint']
        return Drift('MOVED', f'now {rel}' + ('' if same else ' (body changed)'), rel, not same)
    d = Drift('REMOVED', res.note + (f'; also defined in {len(hits)} other files' if len(hits) > 1 else ''))
    return d


def find_rename_candidate(row: Row, entry: dict, web: WebTree, cache: dict) -> tuple[str, float]:
    """Best similarity match for a REMOVED symbol among all function-like declarations in the tree."""
    sk = entry.get('sketch') or []
    if not sk:
        return '', 0.0
    if 'defs' not in cache:
        defs = []
        for rel in web.files():
            src = web.source(rel)
            for d in src.iter_defs():
                if d.rank >= 2 or d.kind == 'class':
                    continue
                if d.end - d.start < 80:
                    continue
                s = sketch(normalize(src.text, src.kinds, d.start, d.end))
                if s:
                    defs.append((rel, d.name, s))
        cache['defs'] = defs
    best, best_sim = '', 0.0
    for rel, name, s in cache['defs']:
        sim = similarity(sk, s)
        if sim > best_sim:
            best, best_sim = f'{rel}#{name}', sim
    return best, best_sim


# --------------------------------------------------------------------------
# Uncovered candidates
# --------------------------------------------------------------------------

EVENT_NAME_RE = re.compile(r'^(?:[a-z][a-z0-9_]*(?::[a-z0-9_*-]+)+|connect|disconnect|connect_error|heartbeat|error|reconnect\w*)$')


def list_events(web: WebTree) -> dict[str, list[str]]:
    """Socket event names the Web registers, derived from the code: event -> [files].

    Sources: `event: "x"` binding objects, `.on/.once("x"` calls, and string
    arrays named *EVENT_NAMES* (only counted when the file also registers handlers).
    """
    out: dict[str, set[str]] = {}
    pats = [
        re.compile(r'(?<![\w$.])event\s*:\s*(["\'])([^"\']+)\1(?=\s*[,}])'),
        re.compile(r'(?<=[.\w$])(?:on|once)\s*\(\s*(["\'])([^"\']+)\1\s*,'),
    ]
    for rel in web.files():
        text = web.read(rel)
        if text is None or ('event' not in text and '.on(' not in text and '.once(' not in text):
            continue
        src = web.source(rel)
        for pi, pat in enumerate(pats):
            for mm in pat.finditer(text):
                if src.kinds[mm.start()] != ord('c'):
                    continue
                if pi == 0:
                    o = src.enclosing_open(mm.start())
                    if o < 0 or text[o] != '{' or not re.search(HANDLER_KEY_RE, src.masked[o:src.close_of.get(o, o)] + '}'):
                        continue
                name = mm.group(2)
                if EVENT_NAME_RE.match(name):
                    out.setdefault(name, set()).add(rel)
    return {k: sorted(v) for k, v in sorted(out.items())}


def list_store_symbols(web: WebTree, rel: str) -> list[dict]:
    """Exported function-like declarations and zustand store actions of one file."""
    src = web.source(rel)
    if src is None:
        return []
    m = src.masked
    out: dict[str, dict] = {}
    for d in src.iter_defs():
        if d.rank != 0 or d.kind == 'class':
            continue
        head = m[d.start:d.start + 24]
        if d.kind == 'var' and re.match(r'create\b', m[m.find('=', d.start) + 1:].lstrip()):
            continue  # the store hook itself
        if 'ForTests' in d.name:
            continue
        if d.kind in ('func', 'var-fn', 'var') and d.depth == 0 and head.startswith('export'):
            out.setdefault(d.name, {'name': d.name, 'kind': 'export', 'line': src.line_of(d.start)})
    # store actions: members of the object returned by the (set, get) => ({...}) initializer
    for cm in re.finditer(r'(?<![\w$.])create\b', m):
        sm = re.compile(r'\(\s*set\b[^)]*\)\s*=>\s*').search(m, cm.end(), cm.end() + 400)
        if not sm:
            continue
        k = sm.end()
        if m[k:k + 1] == '(':
            k = src.skip_ws(k + 1)
        if m[k:k + 1] != '{':
            rm = re.compile(r'return\s*\{').search(m, k)
            if not rm:
                continue
            k = rm.end() - 1
        end = src.close_of.get(k)
        if end is None:
            continue
        depth = src.depth_at(k) + 1
        for d in src.iter_defs():
            if d.kind in ('member-fn',) and k < d.start < end and d.depth == depth:
                out.setdefault(d.name, {'name': d.name, 'kind': 'store-action', 'line': src.line_of(d.start)})
    return sorted(out.values(), key=lambda e: e['line'])


def uncovered(domain: Domain, web: WebTree, events: dict[str, list[str]] | None = None, all_domains: list[Domain] | None = None):
    """Web candidates (events, scope symbols) that no row of any loaded domain anchors."""
    rows = [r for d in (all_domains or [domain]) for r in d.rows if r.has_anchor]
    anchored = {(r.path, r.symbol) for r in rows}
    anchored_events = {r.symbol[6:] for r in rows if r.symbol.startswith('event:')}
    ignore = domain.ignore

    def ignored(key: str) -> bool:
        return any(fnmatchcase(key, pat) for pat in ignore)

    ev = events if events is not None else list_events(web)
    ev_unc = []
    for name, files in ev.items():
        if name in anchored_events or ignored(f'event:{name}'):
            continue
        if not any(fnmatchcase(name, pat) for pat in domain.events):
            continue
        ev_unc.append({'event': name, 'files': files})
    sym_unc = []
    for rel in domain.scope:
        for s in list_store_symbols(web, rel):
            key = f'{rel}#{s["name"]}'
            if (rel, s['name']) in anchored or ignored(key):
                continue
            sym_unc.append({'path': rel, **s})
    return {'events': ev_unc, 'symbols': sym_unc}


# --------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------

def build_report(repo: Path, domains: list[Domain], web: WebTree | None, rename: bool = False, with_uncovered: bool = True, all_domains: list[Domain] | None = None):
    tests = collect_test_ids(repo)
    all_ids = {r.id for d in domains for r in d.rows}
    report = {'domains': {}, 'errors': [], 'warnings': [], 'unknownTestIds': sorted(i for i in tests if i not in all_ids and any(i.startswith(d.header.get('id-prefix', '#') + '-') for d in domains))}
    events = list_events(web) if web and with_uncovered else None
    rename_cache: dict = {}
    for d in domains:
        report['errors'].extend(d.errors)
        report['warnings'].extend(d.warnings)
        sidecar = load_sidecar(d) if web else None
        entries = (sidecar or {}).get('rows', {})
        rows_out = []
        counts: dict[str, int] = {}
        open_by_audit: dict[str, int] = {}
        drift_counts: dict[str, int] = {}
        for row in d.rows:
            status, detail = compute_status(row, tests)
            counts[status] = counts.get(status, 0) + 1
            if status == 'open':
                open_by_audit[row.audit] = open_by_audit.get(row.audit, 0) + 1
            rec = {'id': row.id, 'anchor': row.anchor, 'audit': row.audit, 'status': status, 'detail': detail,
                   'tests': [f'{p}:{ln}' for p, ln, sk in tests.get(row.id, []) if not sk]}
            if web:
                dr = check_row(row, entries.get(row.id), web)
                if dr.state == 'REMOVED' and rename and row.id in entries:
                    cand, sim = find_rename_candidate(row, entries[row.id], web, rename_cache)
                    if sim >= RENAME_MIN_SIMILARITY:
                        dr.candidate, dr.similarity = cand, round(sim, 2)
                rec['drift'] = {'state': dr.state, 'detail': dr.detail, 'newPath': dr.new_path, 'changed': dr.changed,
                                'candidate': dr.candidate, 'similarity': dr.similarity}
                drift_counts[dr.state] = drift_counts.get(dr.state, 0) + 1
                if dr.state in ('NEW', 'STALE'):
                    report['errors'].append(f'{d.name}: {row.id}: {dr.detail}')
            rows_out.append(rec)
        dom = {'file': str(d.file), 'header': d.header, 'counts': counts, 'openByAudit': open_by_audit, 'rows': rows_out,
               'total': len(d.rows)}
        if web:
            if sidecar is None:
                report['errors'].append(f'{d.name}: no sidecar {d.sidecar} (run --update-fingerprints --web ...)')
            else:
                sw = sidecar.get('web', {})
                hw = d.header.get('web', '').split()
                if hw and sw.get('commit') and len(hw) > 1 and not (sw['commit'].startswith(hw[1]) or hw[1].startswith(sw['commit'])):
                    report['errors'].append(f'{d.name}: header web {hw[1][:12]} differs from sidecar web {sw["commit"][:12]}')
                dom['baseline'] = sw
            dom['driftCounts'] = drift_counts
            dom['webCommit'] = web.commit()
            if with_uncovered:
                dom['uncovered'] = uncovered(d, web, events, all_domains or domains)
        report['domains'][d.name] = dom
    return report


def _table(headers, rows):
    widths = [len(h) for h in headers]
    for r in rows:
        for i, c in enumerate(r):
            widths[i] = max(widths[i], len(c))
    fmt = '  '.join('{:<%d}' % w for w in widths)
    lines = [fmt.format(*headers), fmt.format(*['-' * w for w in widths])]
    lines += [fmt.format(*r).rstrip() for r in rows]
    return '\n'.join(lines)


def render_text(report: dict, show_rows: bool = True) -> str:
    out = []
    for name, d in report['domains'].items():
        c = d['counts']
        out.append(f'== {name}  ({d["total"]} rows)  web {d["header"].get("web", "?")}')
        out.append('status: ' + ', '.join(f'{k} {c.get(k, 0)}' for k in ('aligned', 'intended-difference', 'n-a', 'open')))
        if d['openByAudit']:
            out.append('open by audit: ' + ', '.join(f'{k} {v}' for k, v in sorted(d['openByAudit'].items())))
        if 'driftCounts' in d:
            dc = d['driftCounts']
            out.append(f'drift vs {d["webCommit"][:10] or "checkout"}: ' + ', '.join(f'{k} {v}' for k, v in sorted(dc.items())))
        if show_rows:
            has_drift = 'driftCounts' in d
            hdr = ['ID', 'status', 'audit'] + (['drift', 'detail'] if has_drift else []) + ['anchor']
            rows = []
            for r in d['rows']:
                line = [r['id'], r['status'], r['audit']]
                if has_drift:
                    dr = r['drift']
                    det = dr['detail']
                    if dr['candidate']:
                        det += f' renamed? {dr["candidate"]} ({dr["similarity"]})'
                    line += [dr['state'], det]
                line.append(r['anchor'])
                rows.append(line)
            out.append(_table(hdr, rows))
        unc = d.get('uncovered')
        if unc:
            out.append(f'UNCOVERED events ({len(unc["events"])}): ' + (', '.join(e['event'] for e in unc['events']) or 'none'))
            out.append(f'UNCOVERED symbols ({len(unc["symbols"])}): ' + (', '.join(f'{s["path"]}#{s["name"]}' for s in unc['symbols']) or 'none'))
        out.append('')
    if report['unknownTestIds']:
        out.append('tests reference unknown IDs: ' + ', '.join(report['unknownTestIds']))
    if report.get('warnings'):
        out.append(f'WARNINGS ({len(report["warnings"])}):')
        out += [f'  {w}' for w in report['warnings'][:10]]
        if len(report['warnings']) > 10:
            out.append(f'  ... {len(report["warnings"]) - 10} more (--json lists all)')
    if report['errors']:
        out.append('ERRORS:')
        out += [f'  {e}' for e in report['errors']]
    return '\n'.join(out)


def dump_sidecar(data: dict) -> str:
    """One line per row so a re-audit produces a readable diff."""
    rows = ',\n'.join(f'  {json.dumps(k)}: {json.dumps(v)}' for k, v in data['rows'].items())
    return '{\n "web": ' + json.dumps(data['web']) + ',\n "rows": {\n' + rows + '\n }\n}\n'


def update_fingerprints(domains: list[Domain], web: WebTree) -> int:
    rc = 0
    commit, tag = web.commit(), web.tag()
    for d in domains:
        rows, bad = compute_fingerprints(d, web)
        if bad:
            rc = 1
            for rid, msg in bad:
                print(f'{d.name}: {rid}: unresolved anchor: {msg}', file=sys.stderr)
            print(f'{d.name}: not written (fix the anchors above: audit error at the checkout)', file=sys.stderr)
            continue
        hw = d.header.get('web', '').split()
        if len(hw) > 1 and commit and not commit.startswith(hw[1]) and not hw[1].startswith(commit):
            print(f'{d.name}: warning: header says web {hw[1][:12]} but the checkout is {commit[:12]}; update the header', file=sys.stderr)
        data = {'web': {'tag': tag or (hw[0] if hw else ''), 'commit': commit}, 'rows': rows}
        d.sidecar.write_text(dump_sidecar(data), encoding='utf-8')
        print(f'{d.name}: wrote {d.sidecar} ({len(rows)} rows)')
    return rc


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog='behavior-parity', description=__doc__.split('\n\n')[0])
    ap.add_argument('--web', metavar='ROOT', help='Web checkout root (contains packages/web/src): enables drift detection')
    ap.add_argument('--domain', action='append', help='only this domain (repeatable)')
    ap.add_argument('--json', action='store_true', help='machine-readable report')
    ap.add_argument('--summary', action='store_true', help='counts only, no per-row table')
    ap.add_argument('--update-fingerprints', action='store_true', help='rewrite the sidecar fingerprints from --web (after a re-audit)')
    ap.add_argument('--rename-candidates', action='store_true', help='for REMOVED rows, search for a similar body (slower)')
    ap.add_argument('--no-uncovered', action='store_true', help='skip the UNCOVERED scan')
    ap.add_argument('--fail-on-drift', action='store_true', help='exit 2 when any row is CHANGED, MOVED or REMOVED')
    ap.add_argument('--repo', default=str(ROOT), help=argparse.SUPPRESS)
    args = ap.parse_args(argv)
    repo = Path(args.repo)
    all_domains = find_domains(repo)
    domains = [d for d in all_domains if not args.domain or d.name in args.domain]
    if not domains:
        print('error: no checklist domains found under docs/behavior-parity', file=sys.stderr)
        return 1
    web = WebTree(Path(args.web)) if args.web else None
    if args.update_fingerprints:
        if not web:
            print('error: --update-fingerprints needs --web', file=sys.stderr)
            return 1
        return update_fingerprints(domains, web)
    report = build_report(repo, domains, web, rename=args.rename_candidates, with_uncovered=not args.no_uncovered, all_domains=all_domains)
    if args.json:
        print(json.dumps(report, indent=1))
    else:
        print(render_text(report, show_rows=not args.summary))
    if report['errors']:
        return 1
    if args.fail_on_drift and web:
        for d in report['domains'].values():
            if any(r['drift']['state'] in ('CHANGED', 'MOVED', 'REMOVED') for r in d['rows']):
                return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
