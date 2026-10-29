#!/usr/bin/env python3
"""Extract Raft Web client -> server calls (capability inventory).

Used by docs/capability-parity.json and
apps/raft_flutter/test/capability_parity_guard_test.dart.

    python3 tool/capability_parity.py extract <web-source-root> [--json]
    python3 tool/capability_parity.py keys    <web-source-root>

Besides "METHOD /path" keys, `keys` prints "RAW <file>" (fetch/axios/EventSource
outside the api client) and "SOCKET emit <event>" keys.

<web-source-root> is the raft-source checkout (the directory that contains
packages/web). Output keys look like "POST /channels/:id/members": every path
placeholder becomes ":id" and the query string is dropped.
"""
from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import asdict, dataclass

# Receivers that carry the axios instance (api/client.ts) or an injected one
# (slackBridgeProvisioningApi.ts takes a `client`).
# `getWithRwOverloadRetry(url, config)` (api/overloadRetry.ts, Web 1.21.12) is `api.get` with one retry.
RECEIVER_RE = re.compile(r"(?<![\w.$])(?:(api|client)\s*\.\s*(get|post|put|patch|delete)\b|(getWithRwOverloadRetry)\b)")
# api.request<T>({ method, url, ... }) config form.
REQUEST_RE = re.compile(r"(?<![\w.$])api\s*\.\s*request\b")
SKIP_FILE_RE = re.compile(r"(\.test\.|\.spec\.|\.typecheck\.|/__tests__/|/__mocks__/|\.stories\.)")
SRC_EXT = (".ts", ".tsx")
SKIP_DIRS = {"node_modules", "generated"}
NUL = "\0"

# Calls whose first argument is a function parameter or an object lookup, so the
# literal path lives at the call sites. Keyed by (web-src relative file, first
# argument source text). Add an entry only with the call sites checked by hand.
INDIRECT_PATHS: dict[tuple[str, str], list[str]] = {
    # The wrapper itself only forwards its parameter; real paths are at its call sites.
    ("api/overloadRetry.ts", "url"): [],
    ("components/agent/AgentAppAccessTab.tsx", "path"): [
        "/integrations/requests/${id}/approve",
        "/integrations/requests/${id}/deny",
        "/integrations/grants/${id}/revoke",
    ],
    ("hooks/useRuntimeSelectionCatalog.ts", "path"): [
        "/servers/${id}/machines/${id}/runtime-options",
        "/agents/${id}/runtime-options",
    ],
    ("hooks/useRuntimeFormV2.ts", "url"): [
        "/servers/${id}/machines/${id}/runtime-forms/v2/${id}/option-sources/${id}",
    ],
    ("hooks/useRuntimeFormV2.ts", "agentId ? `/agents/${encodeURIComponent(agentId)}/runtime-form` : base"): [
        "/agents/${id}/runtime-form",
        "/servers/${id}/machines/${id}/runtime-forms/v2/${id}",
    ],
    # A "METHOD " prefix restricts an entry to that HTTP method.
    ("utils/runtimeAccountUsageClient.ts", "url"): [
        "GET /servers/${id}/machines/${id}/runtime-account-usage/${id}",
        "POST /servers/${id}/machines/${id}/runtime-account-usage/${id}/refresh",
    ],
    ("components/message/ThreadPanel.tsx", "focusedReplyRequest.url"): ["/messages/context/${id}"],
    ("components/message/ThreadPanel.tsx", "parentContextRequest.url"): ["/messages/context/${id}"],
    ("components/message/openMediaPreview.ts", "ENDPOINT[kind](attachment.id)"): [
        "/attachments/${id}/html-preview-url",
        "/attachments/${id}/url",
    ],
}

# name -> unfinished pattern (placeholders as NUL-delimited markers), built from
# top-level string constants and `function x(): string { return `...`; }` helpers.
INDEX: dict[str, str] = {}
_CONST_RE = re.compile(
    r"(?:^|\n)[ \t]*(?:export\s+)?(?:const|let)\s+([A-Za-z_$][\w$]*)\s*(?::[^=\n]+)?=\s*"
    r"(`[^`]*`|'[^'\n]*'|\"[^\"\n]*\")\s*;"
)
_FUNC_RE = re.compile(
    r"(?:^|\n)[ \t]*(?:export\s+)?function\s+([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*(?::\s*string)?\s*\{\s*return\s+"
    r"(`[^`]*`|'[^'\n]*'|\"[^\"\n]*\")\s*;"
)


@dataclass
class Call:
    method: str
    key_path: str
    raw_path: str
    file: str
    line: int
    enclosing: str
    resolved: bool = True


def _walk(root: str):
    for dp, dns, fns in os.walk(root):
        dns[:] = sorted(d for d in dns if d not in SKIP_DIRS)
        for fn in sorted(fns):
            if fn.endswith(SRC_EXT):
                p = os.path.join(dp, fn)
                rel = os.path.relpath(p, root).replace(os.sep, "/")
                if not SKIP_FILE_RE.search("/" + rel):
                    yield p, rel


def build_index(src_root: str) -> None:
    INDEX.clear()
    for p, _rel in _walk(src_root):
        with open(p, encoding="utf-8") as f:
            text = f.read()
        for rx in (_CONST_RE, _FUNC_RE):
            for m in rx.finditer(text):
                lit = m.group(2)
                body = lit[1:-1]
                if body.startswith("/") or body.startswith("${"):
                    INDEX[m.group(1)] = _unfinished(lit)


def _skip_ws(s: str, i: int) -> int:
    while i < len(s) and s[i].isspace():
        i += 1
    return i


def _skip_generic(s: str, i: int) -> int:
    """If s[i] == '<', skip a balanced generic argument list."""
    if i >= len(s) or s[i] != "<":
        return i
    depth = 0
    j = i
    while j < len(s):
        c = s[j]
        if c == "=" and s[j + 1 : j + 2] == ">":
            j += 2
            continue
        if c == "<":
            depth += 1
        elif c == ">":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return i


def _read_first_arg(s: str, i: int) -> str:
    """s[i] is just after '('. Return the first argument's source text."""
    depth = 0
    j = i
    in_str: str | None = None
    tmpl: list[int] = []
    while j < len(s):
        c = s[j]
        if in_str:
            if c == "\\":
                j += 2
                continue
            if in_str == "`" and c == "$" and s[j + 1 : j + 2] == "{":
                tmpl.append(depth)
                depth += 1
                in_str = None
                j += 2
                continue
            if c == in_str:
                in_str = None
            j += 1
            continue
        if c in "'\"`":
            in_str = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if c == "}" and tmpl and depth - 1 == tmpl[-1]:
                tmpl.pop()
                depth -= 1
                in_str = "`"
                j += 1
                continue
            if depth == 0:
                break
            depth -= 1
        elif c == "," and depth == 0:
            break
        j += 1
    return s[i:j].strip()


def _split_top(raw: str, sep: str) -> list[str]:
    out, depth, cur, in_str = [], 0, "", None
    i = 0
    while i < len(raw):
        c = raw[i]
        if in_str:
            cur += c
            if c == "\\":
                cur += raw[i + 1 : i + 2]
                i += 2
                continue
            if in_str == "`" and c == "$" and raw[i + 1 : i + 2] == "{":
                depth += 1
                cur += "{"
                i += 2
                in_str = None
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if c in "'\"`":
            in_str = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if c == "}" and depth > 0 and "`" in raw[: i]:
                pass
            depth -= 1
        if c == sep and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += c
        i += 1
    out.append(cur)
    return out


def _unwrap_placeholder(expr: str) -> str:
    expr = expr.strip()
    m = re.fullmatch(r"encodeURIComponent\((.*)\)", expr, re.S)
    return m.group(1).strip() if m else expr


def _placeholder(expr: str) -> str:
    m = re.fullmatch(r"([A-Za-z_$][\w$]*)(?:\(.*\))?", expr, re.S)
    if m and m.group(1) in INDEX:
        return INDEX[m.group(1)]
    return NUL + expr + NUL


def _template_to_pattern(t: str) -> str:
    res, i = "", 0
    while i < len(t):
        if t[i] == "$" and t[i + 1 : i + 2] == "{":
            depth, j = 1, i + 2
            while j < len(t) and depth:
                if t[j] == "{":
                    depth += 1
                elif t[j] == "}":
                    depth -= 1
                j += 1
            res += _placeholder(_unwrap_placeholder(t[i + 2 : j - 1]))
            i = j
        else:
            res += t[i]
            i += 1
    return res


def _unfinished(piece: str) -> str:
    piece = piece.strip()
    if len(piece) >= 2 and piece[0] == piece[-1] and piece[0] in "'\"":
        return piece[1:-1]
    return _template_to_pattern(piece[1:-1])


def _finish(out: str) -> str:
    # A literal "?" (outside placeholders) starts the query string.
    inside = False
    for idx, ch in enumerate(out):
        if ch == NUL:
            inside = not inside
        elif ch == "?" and not inside:
            out = out[:idx]
            break
    out = re.sub(NUL + r"[^" + NUL + r"]*" + NUL, ":id", out)
    if not out.startswith("/"):
        out = "/" + out
    return re.sub(r"(:id)+", ":id", out)


def normalise_path(raw: str) -> str | None:
    """Turn a JS string/template/concatenation into a path pattern, or None."""
    parts: list[str] = []
    for piece in _split_top(raw.strip(), "+"):
        piece = piece.strip()
        if len(piece) >= 2 and piece[0] == piece[-1] and piece[0] in "'\"`":
            parts.append(_unfinished(piece))
        elif parts:
            parts.append(NUL + piece + NUL)
        else:
            return None
    return _finish("".join(parts)) if parts else None


def _branches(expr: str) -> list[str]:
    """`cond ? 'a' : `b`` -> ['a', 'b'] when both sides start with a literal."""
    m = re.search(r"\?\s*(['\"`])", expr)
    if not m or not expr or expr[0] in "'\"`":
        return [expr]
    q = m.start()
    rest = expr[q + 1 :].strip()
    # find the top-level ':' separating the two literals
    parts = _split_top(rest, ":")
    if len(parts) == 2 and parts[1].strip()[:1] in "'\"`":
        return [parts[0].strip(), parts[1].strip()]
    return [expr]


def _enclosing(lines: list[str], idx: int) -> str:
    pats = [
        re.compile(r"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s*\*?\s*([A-Za-z0-9_$]+)"),
        re.compile(r"^\s*(?:export\s+)?(?:const|let)\s+([A-Za-z0-9_$]+)\s*(?::[^=]+)?=\s*(?:async\s*)?(?:\(|[A-Za-z0-9_$]+\s*=>|function|useCallback|React\.)"),
        re.compile(r"^\s*(?:async\s+)?([A-Za-z0-9_$]+)\s*:\s*(?:async\s*)?(?:\(|function)"),
        re.compile(r"^\s*(?:async\s+)?([A-Za-z0-9_$]+)\s*\([^)]*\)\s*(?::[^{]+)?\{\s*$"),
    ]
    for k in range(idx, max(-1, idx - 120), -1):
        for p in pats:
            m = p.match(lines[k])
            if m and m.group(1) not in {"if", "for", "while", "switch", "catch", "return", "then"}:
                return m.group(1)
    return ""


def _resolve_ident(lines: list[str], idx: int, ident: str) -> str | None:
    pat = re.compile(r"\b(?:const|let)\s+" + re.escape(ident) + r"\b\s*(?::[^=]+)?=\s*(.+)")
    for k in range(idx, max(-1, idx - 40), -1):
        m = pat.search(lines[k])
        if m:
            text, kk = m.group(1), k
            while ";" not in text and kk + 1 < len(lines) and kk < idx:
                kk += 1
                text += " " + lines[kk].strip()
            return text.split(";")[0].strip()
    return None


def extract_file(path: str, rel: str) -> list[Call]:
    with open(path, encoding="utf-8") as f:
        src = f.read()
    lines = src.split("\n")
    calls: list[Call] = []
    for m in RECEIVER_RE.finditer(src):
        method = (m.group(2) or "get").upper()
        i = _skip_generic(src, _skip_ws(src, m.end()))
        i = _skip_ws(src, i)
        if i >= len(src) or src[i] != "(":
            continue  # property reference, not a call
        arg = _read_first_arg(src, i + 1)
        line_no = src.count("\n", 0, m.start()) + 1
        enclosing = _enclosing(lines, line_no - 1)
        variants = _branches(arg)
        if (rel, arg) in INDIRECT_PATHS:
            variants = []
            for v in INDIRECT_PATHS[(rel, arg)]:
                head, _, tail = v.partition(" ")
                if head in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
                    if head == method:
                        variants.append("`" + tail + "`")
                else:
                    variants.append("`" + v + "`")
        elif re.fullmatch(r"[A-Za-z_$][\w$]*", arg):
            res = _resolve_ident(lines, line_no - 1, arg)
            if res:
                variants = _branches(res)
        for v in variants:
            norm = _normalise_with_index(v)
            if norm is None:
                calls.append(Call(method, f"UNRESOLVED:{v[:60]}", v, rel, line_no, enclosing, False))
            else:
                calls.append(Call(method, norm, v, rel, line_no, enclosing))
    calls.extend(extract_request_calls(src, lines, rel))
    return calls


def extract_request_calls(src: str, lines: list[str], rel: str) -> list[Call]:
    out: list[Call] = []
    for m in REQUEST_RE.finditer(src):
        i = _skip_ws(src, _skip_generic(src, _skip_ws(src, m.end())))
        if src[i : i + 1] != "(":
            continue
        j = _skip_ws(src, i + 1)
        if src[j : j + 1] != "{":
            continue
        # object literal body
        depth, k = 0, j
        while k < len(src):
            if src[k] == "{":
                depth += 1
            elif src[k] == "}":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        body = src[j : k + 1]
        mm = re.search(r"method:\s*([^,\n]+)", body)
        uu = re.search(r"url:\s*(`[^`]*`|'[^'\n]*'|\"[^\"\n]*\")", body)
        if not mm or not uu:
            continue
        methods = [x.upper() for x in re.findall(r"[\"'](get|post|put|patch|delete)[\"']", mm.group(1), re.I)]
        line_no = src.count("\n", 0, m.start()) + 1
        norm = normalise_path(uu.group(1))
        for meth in methods:
            out.append(Call(meth, norm or "UNRESOLVED", uu.group(1), rel, line_no, _enclosing(lines, line_no - 1), norm is not None))
    return out


def _normalise_with_index(v: str) -> str | None:
    v = v.strip()
    m = re.fullmatch(r"([A-Za-z_$][\w$]*)(?:\(.*\))?", v, re.S)
    if m and m.group(1) in INDEX:
        return _finish(INDEX[m.group(1)])
    return normalise_path(v)


def extract_web(root: str) -> list[Call]:
    web_src = os.path.join(root, "packages", "web", "src")
    if not os.path.isdir(web_src):
        raise SystemExit(f"not a raft-source checkout (missing packages/web/src): {root}")
    build_index(web_src)
    calls: list[Call] = []
    for p, rel in _walk(web_src):
        calls.extend(extract_file(p, rel))
    return calls


# ---------------------------------------------------------------------------
# Flutter side: string literals that look like API paths.

DART_DIRS = ("apps/raft_flutter/lib", "packages/raft_client/lib")
_DART_METHOD_BEFORE = [
    re.compile(r"request\(\s*['\"](GET|POST|PUT|PATCH|DELETE)['\"]\s*,\s*$", re.S),
    re.compile(r"\.(get|post|put|patch|delete)\s*(?:<[^>]*>)?\(\s*$", re.S),
    re.compile(r"\b(getForServer)\s*\(\s*[^,]*,\s*$", re.S),
    re.compile(r"\b(_?(?:get|post|put|patch|delete))\s*\(\s*$", re.S),
]


@dataclass
class DartPath:
    method: str  # GET/POST/... or "?" when not visible next to the literal
    key_path: str
    file: str
    line: int


def _dart_strings(src: str):
    """Yield (start, end, [alternative decoded strings]) for each string literal.

    Interpolations become NUL-delimited markers; ternaries of two literals inside
    an interpolation expand into both alternatives.
    """
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and src[i + 1 : i + 2] == "/":
            i = src.find("\n", i)
            if i < 0:
                return
            continue
        if c == "/" and src[i + 1 : i + 2] == "*":
            i = src.find("*/", i + 2)
            if i < 0:
                return
            i += 2
            continue
        raw = False
        j = i
        if c == "r" and src[i + 1 : i + 2] in "'\"" and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == "_")):
            raw, j = True, i + 1
            c = src[j]
        if c in "'\"":
            q = c
            triple = src[j : j + 3] == q * 3
            k = j + (3 if triple else 1)
            alts = [""]
            while k < n:
                ch = src[k]
                if not raw and ch == "\\":
                    k += 2
                    continue
                if triple and src[k : k + 3] == q * 3:
                    k += 3
                    break
                if not triple and ch == q:
                    k += 1
                    break
                if not triple and ch == "\n":
                    break
                if not raw and ch == "$":
                    if src[k + 1 : k + 2] == "{":
                        depth, m = 1, k + 2
                        while m < n and depth:
                            if src[m] in "'\"":
                                qq = src[m]
                                m += 1
                                while m < n and src[m] != qq:
                                    m += 2 if src[m] == "\\" else 1
                            elif src[m] == "{":
                                depth += 1
                            elif src[m] == "}":
                                depth -= 1
                            m += 1
                        expr = src[k + 2 : m - 1]
                        lits = re.findall(r"^[^?]*\?\s*(['\"])([^'\"]*)\1\s*:\s*(['\"])([^'\"]*)\3\s*$", expr, re.S)
                        if lits:
                            alts = [a + x for a in alts for x in (lits[0][1], lits[0][3])]
                        else:
                            alts = [a + NUL + "e" + NUL for a in alts]
                        k = m
                        continue
                    m2 = re.match(r"\$[A-Za-z_]\w*", src[k:])
                    if m2:
                        alts = [a + NUL + "e" + NUL for a in alts]
                        k += m2.end()
                        continue
                alts = [a + ch for a in alts]
                k += 1
            yield i, k, alts
            i = k
            continue
        i += 1


def extract_flutter(repo_root: str, segments: set[str]) -> list[DartPath]:
    out: list[DartPath] = []
    for d in DART_DIRS:
        base = os.path.join(repo_root, d)
        for dp, dns, fns in os.walk(base):
            dns.sort()
            for fn in sorted(fns):
                if not fn.endswith(".dart") or fn.endswith((".g.dart", ".freezed.dart")):
                    continue
                p = os.path.join(dp, fn)
                rel = os.path.relpath(p, repo_root).replace(os.sep, "/")
                with open(p, encoding="utf-8") as f:
                    src = f.read()
                for start, _end, alts in _dart_strings(src):
                    for alt in alts:
                        if not alt.startswith("/") or alt.startswith("//"):
                            continue
                        first = alt.split(NUL)[0].split("/")[1].split("?")[0].split(":")[0] if len(alt) > 1 else ""
                        first = first.split("$")[0]
                        if first not in segments and not any(alt.startswith("/" + sg) for sg in segments):
                            continue
                        before = src[max(0, start - 160) : start]
                        method = "?"
                        for rx in _DART_METHOD_BEFORE:
                            mm = rx.search(before)
                            if mm:
                                method = mm.group(1).upper().lstrip("_")
                                if method == "GETFORSERVER":
                                    method = "GET"
                                break
                        line = src.count("\n", 0, start) + 1
                        out.append(DartPath(method, _finish(alt), rel, line))
    return out


RAW_NETWORK_RE = re.compile(r"(?<![\w.$])(fetch\s*\(|fetchImpl\s*\(|getFetch\(\)\s*\(|axios\s*\.\s*(?:get|post|put|patch|delete|request)\b|new\s+EventSource\b|new\s+WebSocket\b|navigator\s*\.\s*sendBeacon\b)")
SOCKET_EMIT_RE = re.compile(r"\b(?:socket|getSocket\(\))\s*(?:\?)?\.\s*emit\(\s*[\"']([^\"']+)[\"']")


def extract_other(root: str) -> list[str]:
    """Network use that bypasses the axios `api` client, as per-file / per-event keys."""
    web_src = os.path.join(root, "packages", "web", "src")
    out: set[str] = set()
    for p, rel in _walk(web_src):
        if rel == "api/client.ts":
            continue
        with open(p, encoding="utf-8") as f:
            src = f.read()
        code = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
        code = re.sub(r"(?m)(^|\s)//.*$", "", code)
        if RAW_NETWORK_RE.search(code):
            out.add(f"RAW {rel}")
        for m in SOCKET_EMIT_RE.finditer(src):
            out.add(f"SOCKET emit {m.group(1)}")
    return sorted(out)


def keys(calls: list[Call], other: list[str] | None = None) -> list[str]:
    return sorted({f"{c.method} {c.key_path}" for c in calls} | set(other or []))


def main(argv: list[str]) -> int:
    if len(argv) < 3 or argv[1] not in {"extract", "keys", "flutter"}:
        print(__doc__)
        return 2
    if argv[1] == "flutter":
        # flutter <repo-root> <web-source-root>
        segs = {c.key_path.split("/")[1] for c in extract_web(argv[3])}
        for d in extract_flutter(argv[2], segs):
            print(f"{d.method:6} {d.key_path}  {d.file}:{d.line}")
        return 0
    calls = extract_web(argv[2])
    if argv[1] == "keys":
        print("\n".join(keys(calls, extract_other(argv[2]))))
    elif "--json" in argv:
        print(json.dumps([asdict(c) for c in calls], indent=1))
    else:
        for c in calls:
            print(f"{c.method:6} {c.key_path}  {c.file}:{c.line} {c.enclosing}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
