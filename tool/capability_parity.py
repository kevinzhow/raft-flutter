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
# (slackBridgeProvisioningApi.ts takes a `client`; Web 1.24's Raft Desktop sign-in,
# utils/desktopOAuth.ts and desktopPasskeySignIn.ts, takes `deps` whose `post` is `api.post`).
# GET wrappers of `api.get`, with the index of the argument that is the path:
# `getWithRwOverloadRetry(url, config)` (api/overloadRetry.ts, Web 1.21.12) retries once;
# `getRwRead(surface, url, config)` (same file, Web 1.24) also marks the surface stale or fresh.
GET_WRAPPERS: dict[str, int] = {"getWithRwOverloadRetry": 0, "getRwRead": 1}
RECEIVER_RE = re.compile(
    r"(?<![\w.$])(?:(api|client|deps)\s*\.\s*(get|post|put|patch|delete)\b|(" + "|".join(GET_WRAPPERS) + r")\b)")
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
    # Web 1.24 (checked against v1.24.0-source.1).
    # apiArtifactSource's own wrappers (`getBlob(url)`); their call sites are read as path-builder calls.
    ("apps/artifacts/apiArtifactSource.ts", "route(url)"): [],
    ("apps/artifacts/artifactScreenshot.ts", "route"): ["GET /objects/${id}/${id}/files/${id}"],
    # buildThreadParentContextRequest / buildMessageContextRequest / threadRepliesRequest (messageContextRequest.ts,
    # threadRepliesPrefetch.ts, messagePagePrefetch.ts) return { url, config }.
    ("features/thread/useThreadTimeline.ts", "firstRequest.url"): ["/messages/context/${id}", "/messages/channel/${id}"],
    ("features/thread/useThreadParent.ts", "parentContextRequest.url"): ["/messages/context/${id}"],
    ("components/task/TaskConversationDialog.tsx", "request.url"): ["/messages/context/${id}"],
    ("components/message/artifactAttachmentSaved.ts", "request.url"): ["/messages/context/${id}"],
    ("store/heldRead.ts", "request.url"): ["/messages/context/${id}", "/messages/channel/${id}"],
    ("components/layout/besideVisibility.ts", "url"): ["/messages/context/${id}"],
    ("components/message/attachmentPreviewSummaryCache.ts", "url"): ["/attachments/${id}/preview"],
    ("features/computer/othersAgentsApi.ts", "url"): [
        "/servers/${id}/machines/${id}/notify-agent-owners",
        "/me/account/deletion/notify-agent-owners",
    ],
    ("store/inboxStore.ts", "objectActivityRoute(action)"): [
        "/objects/activity/done", "/objects/activity/undone", "/objects/activity/read",
    ],
    # Raft Desktop sign-in: `appPost` is the `deps.post` of desktopOAuth / desktopPasskeySignIn (read as calls).
    ("utils/desktopOAuth.ts", "path"): [],
    ("utils/desktopPasskeySignIn.ts", "path"): [],
    # Raft Desktop "this computer": desktopAttachGrant.ts posts the device-authorization steps through it.
    ("components/machine/localComputer/useLocalComputerHost.ts", "url"): [
        "POST /auth/device/authorize", "POST /auth/device/describe", "POST /auth/device/approve", "POST /auth/device/token",
    ],
}

# Path constants and helpers, as unfinished patterns (placeholders as NUL-delimited
# markers), built from top-level string constants, `function x(): string { return `...`; }`
# and `const x = (...) => `...`` helpers, and the members of path-builder objects
# (`export const artifactWebPaths = { viewer: (id) => `/api/artifacts/${id}`, ... }`,
# indexed as "artifactWebPaths.viewer"). Kept per file: a name is looked up in the
# calling file, then in the file it is imported from, and only then across the
# tree, where it must be defined once (Web 1.24 has three different `BASE`s).
FILE_INDEX: dict[str, dict[str, str]] = {}
IMPORTS: dict[str, dict[str, tuple[str, str]]] = {}  # file -> local name -> (source file or SHARED, imported name)
GLOBAL_INDEX: dict[str, set[str]] = {}
BUILDERS: set[str] = set()  # names of path-builder objects
SHARED = "@shared"  # files of packages/shared/src (imported as "@botiverse/raft-shared")
_CUR_FILE = ""
_CONST_RE = re.compile(
    r"(?:^|\n)[ \t]*(?:export\s+)?(?:const|let)\s+([A-Za-z_$][\w$]*)\s*(?::[^=\n]+)?=\s*"
    r"(`[^`]*`|'[^'\n]*'|\"[^\"\n]*\")\s*;"
)
_FUNC_RE = re.compile(
    r"(?:^|\n)[ \t]*(?:export\s+)?function\s+([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*(?::\s*string)?\s*\{\s*return\s+"
    r"(`[^`]*`|'[^'\n]*'|\"[^\"\n]*\")\s*;"
)
_ARROW_RE = re.compile(
    r"(?:^|\n)[ \t]*(?:export\s+)?const\s+([A-Za-z_$][\w$]*)\s*=\s*\([^()]*\)\s*(?::\s*string\s*)?=>\s*"
    r"(`[^`]*`|'[^'\n]*'|\"[^\"\n]*\")\s*;"
)
_OBJECT_RE = re.compile(r"(?:^|\n)[ \t]*(?:export\s+)?const\s+([A-Za-z_$][\w$]*)\s*(?::[^=\n]+)?=\s*\{")
_MEMBER_RE = re.compile(
    r"\s*([A-Za-z_$][\w$]*)\s*:\s*\((?:[^()]|\([^()]*\))*\)\s*(?::\s*string\s*)?=>\s*"
    r"(`[^`]*`|'[^'\n]*'|\"[^\"\n]*\")\s*$", re.S)
_IMPORT_RE = re.compile(r"import\s+(?:type\s+)?\{([^}]*)\}\s*from\s*[\"']([^\"']+)[\"']")
# `${query(options)}`, `${versionQuery(v)}`: a query string, not a path segment.
_QUERY_EXPR_RE = re.compile(r"[A-Za-z_$][\w$]*[Qq]uery[\w$]*\s*\(|query\s*\(")
# `.replace(/^\/api(?=\/)/, "")`: path builders are absolute, the axios base already ends in /api.
_API_PREFIX_REPLACE_RE = re.compile(r"\.replace\(\s*/\^\\/api[^,]*,\s*(?:\"\"|''|``)\s*\)\s*$")


def _lookup(name: str, rel: str | None = None) -> str | None:
    """A constant, helper or builder member by name, as seen from file `rel`."""
    rel = _CUR_FILE if rel is None else rel
    root, dot, rest = name.partition(".")
    local = FILE_INDEX.get(rel, {})
    if name in local:
        return local[name]
    imp = IMPORTS.get(rel, {}).get(root)
    if imp:
        src, orig = imp
        key = orig + dot + rest
        if src == SHARED:
            vals = {FILE_INDEX[f][key] for f in FILE_INDEX if f.startswith(SHARED + "/") and key in FILE_INDEX[f]}
            return vals.pop() if len(vals) == 1 else None
        if key in FILE_INDEX.get(src, {}):
            return FILE_INDEX[src][key]
        if src in FILE_INDEX:
            return None  # imported from a file we read that doesn't define it as a path
        if src is not None:
            return None
        # Imported from a module we don't read: any one definition of that name in the tree.
        vals = GLOBAL_INDEX.get(key, set())
        return next(iter(vals)) if len(vals) == 1 else None
    # Neither defined here nor imported: a parameter or a local of another scope, never
    # another file's constant (Web 1.24 has three different `BASE`s, and `url`/`path`
    # parameters used to pick up whatever top-level `url` the tree had).
    return None


def _resolve_module(rel: str, spec: str, known: set[str]) -> str | None:
    if "raft-shared" in spec:
        return SHARED
    if not spec.startswith("."):
        return None
    base = os.path.normpath(os.path.join(os.path.dirname(rel), spec)).replace(os.sep, "/")
    for cand in (base, base + ".ts", base + ".tsx", base + "/index.ts", base + "/index.tsx"):
        if cand in known:
            return cand
    return None


def _strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"(?m)(^|\s)//.*$", " ", text)


def _index_text(rel: str, text: str) -> None:
    global _CUR_FILE
    _CUR_FILE = rel
    entries = FILE_INDEX.setdefault(rel, {})
    for rx in (_CONST_RE, _FUNC_RE, _ARROW_RE):
        for m in rx.finditer(text):
            lit = m.group(2)
            body = lit[1:-1]
            if body.startswith("/") or body.startswith("${"):
                entries[m.group(1)] = _unfinished(lit)
    code = _strip_comments(text)  # comments hold apostrophes ("can't") that read as strings
    for m in _OBJECT_RE.finditer(code):
        start = m.end() - 1
        end = _match_close(code, start)
        if end < 0:
            continue
        members = {}
        body = code[start + 1 : end]
        k = 0
        while k < len(body):
            e = _arg_end(body, k)
            piece, k = body[k:e], e + 1
            mm = _MEMBER_RE.fullmatch(piece)
            if mm and mm.group(2)[1:2] == "/":
                members[f"{m.group(1)}.{mm.group(1)}"] = _unfinished(mm.group(2))
        if members:
            BUILDERS.add(m.group(1))
            entries.update(members)


def _match_close(s: str, i: int) -> int:
    """s[i] is an opening bracket; index of its partner (strings skipped), or -1."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack, j, in_str = [], i, None
    while j < len(s):
        c = s[j]
        if in_str:
            if c == "\\":
                j += 2
                continue
            if c == in_str:
                in_str = None
            j += 1
            continue
        if c in "'\"`":
            in_str = c
        elif c in pairs:
            stack.append(pairs[c])
        elif c in ")]}":
            if not stack or stack.pop() != c:
                return -1
            if not stack:
                return j
        j += 1
    return -1


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


def build_index(src_root: str, shared_root: str | None = None) -> None:
    """Index path constants of the Web tree (and packages/shared/src when given)."""
    global _CUR_FILE
    FILE_INDEX.clear()
    IMPORTS.clear()
    GLOBAL_INDEX.clear()
    BUILDERS.clear()
    texts: dict[str, str] = {}
    for p, rel in _walk(src_root):
        with open(p, encoding="utf-8") as f:
            texts[rel] = f.read()
    if shared_root and os.path.isdir(shared_root):
        for p, rel in _walk(shared_root):
            with open(p, encoding="utf-8") as f:
                texts[f"{SHARED}/{rel}"] = f.read()
    known = set(texts)
    for rel, text in texts.items():
        imports = {}
        for m in _IMPORT_RE.finditer(text):
            src = _resolve_module(rel, m.group(2), known)
            for part in m.group(1).split(","):
                part = re.sub(r"^\s*type\s+", "", part).strip()
                if not part:
                    continue
                orig, _, alias = part.partition(" as ")
                imports[(alias or orig).strip()] = (src, orig.strip())
        IMPORTS[rel] = imports
    # Twice: a constant may be built from one defined later or in another file.
    for _ in range(2):
        for rel, text in texts.items():
            _index_text(rel, text)
        GLOBAL_INDEX.clear()
        for rel, entries in FILE_INDEX.items():
            for name, val in entries.items():
                GLOBAL_INDEX.setdefault(name, set()).add(val)
    _CUR_FILE = ""


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
    return s[i : _arg_end(s, i)].strip()


def _read_arg(s: str, i: int, n: int) -> str:
    """s[i] is just after '('. Return argument `n` (0-based), "" when there are fewer."""
    for _ in range(n):
        j = _arg_end(s, i)
        if s[j : j + 1] != ",":
            return ""
        i = j + 1
    return _read_first_arg(s, i)


def _arg_end(s: str, i: int) -> int:
    """Index of the ',' or ')' that ends the argument starting at s[i]."""
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
    return j


def _split_top(raw: str, sep: str) -> list[str]:
    """Split on `sep` outside brackets, strings and template literals (`${...}` nesting kept)."""
    out, cur_start, depth, in_str, tmpl = [], 0, 0, None, []
    i = 0
    while i < len(raw):
        c = raw[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if in_str == "`" and c == "$" and raw[i + 1 : i + 2] == "{":
                tmpl.append(depth)
                depth += 1
                in_str = None
                i += 2
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
            depth -= 1
            if c == "}" and tmpl and depth == tmpl[-1]:
                tmpl.pop()
                in_str = "`"
        elif c == sep and depth == 0:
            out.append(raw[cur_start:i])
            cur_start = i + 1
        i += 1
    out.append(raw[cur_start:])
    return out


def _unwrap_placeholder(expr: str) -> str:
    expr = expr.strip()
    m = re.fullmatch(r"encodeURIComponent\((.*)\)", expr, re.S)
    return m.group(1).strip() if m else expr


def _placeholder(expr: str) -> str:
    if _QUERY_EXPR_RE.match(expr):
        return "?"
    m = re.fullmatch(r"([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*)(?:\(.*\))?", expr, re.S)
    if m:
        val = _lookup(m.group(1))
        if val is not None:
            return val
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
    """`cond ? 'a' : `b`` -> ['a', 'b'] when both sides start with a literal.

    Nested ternaries expand too; `null` and `""` branches (nothing asked) are
    dropped when another branch is a literal.
    """
    expr = expr.strip()
    m = re.search(r"\?\s*(['\"`]|null\b)", expr)
    if not m or not expr or expr[0] in "'\"`":
        return [expr]
    q = m.start()
    rest = expr[q + 1 :].strip()
    # find the top-level ':' separating the two branches
    parts = _split_top(rest, ":")
    if len(parts) < 2:
        return [expr]
    then, other = parts[0].strip(), ":".join(parts[1:]).strip()
    if then[:1] not in "'\"`" and then != "null":
        return [expr]
    out = [] if then in ("null", '""', "''", "``") else [then]
    if other[:1] in "'\"`":
        if other not in ('""', "''", "``"):
            out.append(other)
    elif other != "null":
        sub = _branches(other)
        if sub == [other]:
            return [expr]
        out.extend(sub)
    return out or [expr]


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


def _in_comment(src: str, pos: int) -> bool:
    """Whether src[pos] is in a // line comment or a /* */ block (a cheap test: line prefix and open blocks)."""
    line_start = src.rfind("\n", 0, pos) + 1
    prefix = src[line_start:pos]
    stripped = prefix.lstrip()
    if stripped.startswith(("//", "*", "/*")):
        return True
    if re.search(r"(?:^|\s)//", prefix) and prefix.count('"') % 2 == 0 and prefix.count("'") % 2 == 0 and prefix.count("`") % 2 == 0:
        return True
    return src.rfind("/*", 0, pos) > src.rfind("*/", 0, pos)


def extract_file(path: str, rel: str) -> list[Call]:
    global _CUR_FILE
    _CUR_FILE = rel
    with open(path, encoding="utf-8") as f:
        src = f.read()
    lines = src.split("\n")
    calls: list[Call] = []
    for m in RECEIVER_RE.finditer(src):
        if _in_comment(src, m.start()) or re.search(r"\bfunction\s*$", src[max(0, m.start() - 20) : m.start()]):
            continue  # a comment, or the wrapper's own declaration
        method = (m.group(2) or "get").upper()
        i = _skip_generic(src, _skip_ws(src, m.end()))
        i = _skip_ws(src, i)
        if i >= len(src) or src[i] != "(":
            continue  # property reference, not a call
        arg = _read_arg(src, i + 1, GET_WRAPPERS.get(m.group(3) or "", 0))
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
    calls.extend(extract_builder_calls(src, lines, rel))
    _CUR_FILE = ""
    return calls


_METHODS = ("GET", "POST", "PUT", "PATCH", "DELETE")


def _open_before(s: str, pos: int) -> int:
    """Index of the innermost unclosed '(' or '{' before pos (strings skipped), or -1."""
    depth, j = 0, pos - 1
    while j >= 0:
        c = s[j]
        if c in "'\"`":
            k = j - 1
            while k >= 0 and not (s[k] == c and s[k - 1 : k] != "\\"):
                k -= 1
            j = k - 1
            continue
        if c in ")]}":
            depth += 1
        elif c in "([{":
            if depth == 0:
                return j if c in "({" else -1
            depth -= 1
        elif c == ";" and depth == 0:
            return -1
        j -= 1
    return -1


def _callee_before(s: str, open_paren: int) -> str:
    """`api.get<T>(` -> "api.get"; "" for a bare parenthesis."""
    j = open_paren - 1
    while j >= 0 and s[j].isspace():
        j -= 1
    if j >= 0 and s[j] == ">":
        depth = 0
        while j >= 0:
            if s[j] == ">" and s[j - 1 : j] != "=":
                depth += 1
            elif s[j] == "<":
                depth -= 1
                if depth == 0:
                    j -= 1
                    break
            j -= 1
    end = j + 1
    while j >= 0 and (s[j].isalnum() or s[j] in "_$."):
        j -= 1
    return s[j + 1 : end]


def _methods_for_ref(s: str, pos: int) -> list[str]:
    """The HTTP methods a path built at s[pos] is sent with, read from the calls around it.

    A literal method among the call's earlier arguments (`send("POST", path)`), a
    `method:` in an enclosing config object (`call({ method: "GET", url: path })`),
    or the callee's name (`get(path)`, `getBlob(path)`, `api.post(path)`); a
    pass-through call (`route(path)`) is looked through. [] when none says.
    """
    j = pos
    for _ in range(4):
        o = _open_before(s, j)
        if o < 0:
            return []
        if s[o] == "{":
            close = _match_close(s, o)
            body = s[o : close + 1 if close > 0 else len(s)]
            mm = re.search(r"\bmethod:\s*([^,\n}]+)", body)
            if mm:
                return sorted({x.upper() for x in re.findall(r"[\"'](get|post|put|patch|delete)[\"']", mm.group(1), re.I)})
            j = o
            continue
        lits = re.findall(r"[\"'](GET|POST|PUT|PATCH|DELETE)[\"']", s[o + 1 : pos])
        if lits:
            return sorted(set(lits))
        last = _callee_before(s, o).split(".")[-1]
        low = last.lower()
        for meth in _METHODS:
            if low == meth.lower() or (meth == "GET" and low.startswith("get") and last[3:4].isupper()):
                return [meth]
        if last in GET_WRAPPERS:
            return ["GET"]
        j = o
    return []


def extract_builder_calls(src: str, lines: list[str], rel: str) -> list[Call]:
    """Calls whose path comes from a path-builder object (`artifactWebPaths.viewer(id)`).

    Web 1.24 builds every Artifacts, objects and mention-audience address with the
    shared contracts' builders and sends them through small local wrappers
    (apps/artifacts/apiArtifactSource.ts `get` / `send` / `call`), so the method is
    read around the reference (see _methods_for_ref). A reference with no visible
    method (a link, a cache key) is not a call and is left out.
    """
    if not BUILDERS:
        return []
    out: list[Call] = []
    rx = re.compile(r"(?<![\w$.])(" + "|".join(sorted(map(re.escape, BUILDERS))) + r")\.([A-Za-z_$][\w$]*)\s*\(")
    for m in rx.finditer(src):
        if _in_comment(src, m.start()):
            continue
        name = f"{m.group(1)}.{m.group(2)}"
        val = _lookup(name, rel)
        if val is None:
            continue
        line_no = src.count("\n", 0, m.start()) + 1
        for meth in _methods_for_ref(src, m.start()):
            out.append(Call(meth, _web_key(_finish(val)), name + "()", rel, line_no, _enclosing(lines, line_no - 1)))
    return out


def _web_key(path: str) -> str:
    """The axios base ends in /api: an absolute `/api/...` builder path is the same route."""
    return re.sub(r"^/api(?=/)", "", path)


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
    v = _API_PREFIX_REPLACE_RE.sub("", v.strip())
    m = re.fullmatch(r"([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*)(?:\((.*)\))?", v, re.S)
    if m:
        val = _lookup(m.group(1))
        if val is not None:
            return _web_key(_finish(val))
        inner = (m.group(2) or "").strip()
        if inner and len(_split_top(inner, ",")) == 1 and m.group(1) not in BUILDERS:
            # A pass-through (`route(path)`): the path is its one argument.
            got = _normalise_with_index(inner)
            if got is not None:
                return got
    norm = normalise_path(v)
    return _web_key(norm) if norm is not None else None


def extract_web(root: str) -> list[Call]:
    web_src = os.path.join(root, "packages", "web", "src")
    if not os.path.isdir(web_src):
        raise SystemExit(f"not a raft-source checkout (missing packages/web/src): {root}")
    build_index(web_src, os.path.join(root, "packages", "shared", "src"))
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
