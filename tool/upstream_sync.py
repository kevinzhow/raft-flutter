#!/usr/bin/env python3
"""Compare a Raft Web source release with the baseline raft-flutter is pinned to.

    python3 tool/upstream_sync.py report [--from TAG] [--to TAG] [--out DIR]
    python3 tool/upstream_sync.py latest
    python3 tool/upstream_sync.py status
    python3 tool/upstream_sync.py pins
    python3 tool/upstream_sync.py record-decision --to TAG --decision follow|partial|skip|discuss ...

The upstream repository (https://github.com/botiverse/raft-source) publishes
source snapshots as tags `vX.Y.Z-source.N`. This tool keeps its own bare mirror
(never a checkout somebody else uses), diffs the two tag trees and writes
`report.md` + `report.json`: what changed (API calls, wire fields, UI, strings,
visual cases, styles), what our counterpart is, and a proposed action for each
group. Cindy runs it and proposes; Kevin decides; `record-decision` advances the
pinned baseline in docs/upstream-sync.json only after that. See
docs/upstream-sync.md.

Read-only network use: `git clone --mirror` / `git fetch` of a public repository,
no credentials. Nothing here edits the app, the pinned data of the other parity
tools or the upstream tree.
"""
from __future__ import annotations

import argparse
import collections
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import capability_parity as cp  # noqa: E402  (shared Web call extractor)

DEFAULT_REMOTE = "https://github.com/botiverse/raft-source.git"
DEFAULT_MIRROR = Path("~/.cache/raft-flutter/raft-source-mirror.git").expanduser()
DEFAULT_WORK = Path("~/.cache/raft-flutter/upstream-sync-work").expanduser()
DEFAULT_OUT = Path("/tmp/upstream-sync")
STATE_FILE = "docs/upstream-sync.json"
TAG_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)-source\.(\d+)$")
DECISIONS = ("follow", "partial", "skip", "discuss")
EXTRACT_PATHS = ("packages/web/src",)
EXTRACT_PATHS_NEW = ("packages/web/src", "packages/sync-core", "packages/shared/src")  # + what tool/behavior-parity reads


class UpstreamError(Exception):
    """A failure the operator can act on (network, auth, unknown tag, ...)."""


# --------------------------------------------------------------------------- git

def _git(mirror, *args, check=True, input_bytes=None):
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", LC_ALL="C")
    cmd = ["git", f"--git-dir={mirror}", *args]
    res = subprocess.run(cmd, capture_output=True, input=input_bytes, env=env)
    if check and res.returncode != 0:
        raise UpstreamError(f"git {' '.join(args[:3])} failed: {res.stderr.decode('utf-8', 'replace').strip()}")
    return res.stdout.decode("utf-8", "replace")


def _network_error(stderr: str) -> UpstreamError:
    low = stderr.lower()
    if any(s in low for s in ("authentication failed", "could not read username", "terminal prompts disabled",
                              "permission denied", "repository not found", "invalid credentials")):
        return UpstreamError(
            "git could not read the upstream repository without credentials (authentication failed). "
            "The repository is expected to be public; check the --remote URL or whether upstream made it "
            "private. Nothing was changed.\n" + stderr.strip())
    if any(s in low for s in ("could not resolve host", "unable to access", "timed out", "network is unreachable",
                              "connection refused")):
        return UpstreamError("network failure while reaching upstream; retry later or use --no-fetch with an "
                             "existing mirror.\n" + stderr.strip())
    return UpstreamError("git failed:\n" + stderr.strip())


def ensure_mirror(mirror: Path, remote: str = DEFAULT_REMOTE, fetch: bool = True) -> None:
    """Create the bare mirror when missing, else update it (tags, forced, pruned)."""
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", LC_ALL="C")
    mirror = Path(mirror)
    if not (mirror / "HEAD").exists():
        mirror.parent.mkdir(parents=True, exist_ok=True)
        res = subprocess.run(["git", "clone", "--mirror", "--quiet", remote, str(mirror)],
                             capture_output=True, text=True, env=env)
        if res.returncode != 0:
            shutil.rmtree(mirror, ignore_errors=True)
            raise _network_error(res.stderr)
        return
    if not fetch:
        return
    cur = _git(mirror, "config", "--get", "remote.origin.url", check=False).strip()
    if cur != remote:
        _git(mirror, "remote", "set-url", "origin", remote)
    res = subprocess.run(["git", f"--git-dir={mirror}", "fetch", "--quiet", "--prune", "--tags", "--force", "origin"],
                         capture_output=True, text=True, env=env)
    if res.returncode != 0:
        raise _network_error(res.stderr)


def tag_key(tag: str):
    m = TAG_RE.match(tag)
    return tuple(int(x) for x in m.groups()) if m else None


def list_tags(mirror: Path) -> list[str]:
    out = _git(mirror, "for-each-ref", "--format=%(refname:short)", "refs/tags")
    tags = [t for t in out.split() if TAG_RE.match(t)]
    return sorted(tags, key=tag_key)


def tag_info(mirror: Path, tag: str) -> dict:
    if _git(mirror, "rev-parse", "--verify", "--quiet", f"refs/tags/{tag}", check=False).strip() == "":
        raise UpstreamError(f"tag {tag} is not in the mirror {mirror} (run without --no-fetch, or check the name)")
    commit = _git(mirror, "rev-parse", f"{tag}^{{commit}}").strip()
    meta = _git(mirror, "log", "-1", "--format=%cI%x1f%s%x1f%b", commit).split("\x1f")
    return {"tag": tag, "commit": commit, "date": meta[0].strip(), "subject": meta[1].strip(),
            "body": meta[2].strip() if len(meta) > 2 else ""}


def show(mirror: Path, tag: str, path: str) -> str | None:
    res = subprocess.run(["git", f"--git-dir={mirror}", "show", f"{tag}:{path}"], capture_output=True)
    return res.stdout.decode("utf-8", "replace") if res.returncode == 0 else None


def list_tree(mirror: Path, tag: str, prefix: str = "") -> list[str]:
    args = ["ls-tree", "-r", "--name-only", tag] + ([prefix] if prefix else [])
    return _git(mirror, *args).splitlines()


def extract_tree(mirror: Path, tag: str, dest: Path, paths=EXTRACT_PATHS) -> Path:
    """`git archive` of the given paths into dest (a fresh directory)."""
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    paths = [p for p in paths if _git(mirror, "ls-tree", "--name-only", tag, p).strip()]
    if not paths:
        return dest
    proc = subprocess.Popen(["git", f"--git-dir={mirror}", "archive", tag, *paths], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    with tarfile.open(fileobj=proc.stdout, mode="r|") as tf:
        for member in tf:
            if member.isfile() and ".." not in Path(member.name).parts and not member.name.startswith("/"):
                tf.extract(member, dest, filter="data")
    err = proc.stderr.read().decode("utf-8", "replace")
    proc.stdout.close()
    proc.stderr.close()
    if proc.wait() != 0:
        raise UpstreamError(f"git archive {tag} failed: {err.strip()}")
    return dest


@dataclass
class FileChange:
    path: str
    status: str  # A, M, D
    added: int = 0
    removed: int = 0
    category: str = "other"
    area: str = ""
    binary: bool = False
    old_path: str = ""  # set when upstream renamed / moved the file (status stays M)

    @property
    def lines(self) -> int:
        return self.added + self.removed


NO_DIFF = (":(exclude)packages/server/drizzle", ":(exclude)pnpm-lock.yaml", ":(exclude)*.snap",
           ":(exclude)packages/server/test-shard-manifest.json")


def changed_files(mirror: Path, a: str, b: str) -> list[FileChange]:
    """Changed files between two tag trees (renames of >= 50% similarity are one modified file with old_path)."""
    ta, tb = f"{a}^{{tree}}", f"{b}^{{tree}}"
    toks = _git(mirror, "diff", "--name-status", "-M50%", "-z", ta, tb).split("\0")
    status, old_of = {}, {}
    i = 0
    while i < len(toks) - 1:
        st = toks[i]
        if st[:1] in "RC":
            old_of[toks[i + 2]] = toks[i + 1]
            status[toks[i + 2]] = "M"
            i += 3
        else:
            status[toks[i + 1]] = st[:1]
            i += 2
    toks = _git(mirror, "diff", "--numstat", "-M50%", "-z", ta, tb).split("\0")
    out, i = [], 0
    while i < len(toks):
        rec = toks[i]
        if not rec:
            i += 1
            continue
        add, rem, path = rec.split("\t", 2)
        if path == "":  # rename: next two tokens are old and new path
            path = toks[i + 2]
            i += 2
        i += 1
        fc = FileChange(path=path, status=status.get(path, "M"), old_path=old_of.get(path, ""))
        if add == "-":
            fc.binary = True
        else:
            fc.added, fc.removed = int(add), int(rem)
        fc.category, fc.area = classify(path)
        out.append(fc)
    return sorted(out, key=lambda f: f.path)


def hunks_by_file(mirror: Path, a: str, b: str, paths: list[str] | None = None) -> dict[str, list[str]]:
    """-U0 diff body lines (with +/- prefixes) per file."""
    args = ["diff", "-U0", "-M50%", "--no-color", f"{a}^{{tree}}", f"{b}^{{tree}}", "--"]
    args += list(paths) if paths else ["."] + list(NO_DIFF)
    text = _git(mirror, *args)
    files: dict[str, list[str]] = {}
    cur = None
    for line in text.split("\n"):
        if line.startswith("diff --git "):
            m = re.match(r"diff --git a/(.*) b/(.*)$", line)
            cur = m.group(2) if m else None
            if cur:
                files[cur] = []
        elif cur is not None and line[:1] in "+-" and not line.startswith(("+++", "---")):
            files[cur].append(line)
    return files


# ---------------------------------------------------------------- classification

CATEGORIES = ["web_ui", "server_api", "shared_types", "i18n", "visual_cases", "styles", "docs",
              "server_other", "runtime_other", "tests_infra", "other"]
CATEGORY_TITLES = {
    "web_ui": "Web UI (components / pages / stores / hooks)",
    "server_api": "Server API routes and middleware",
    "shared_types": "Shared types and contracts",
    "i18n": "i18n catalogs (en / zh-cn)",
    "visual_cases": "Visual-testing cases",
    "styles": "Styles / tokens / design system",
    "docs": "Docs / changelog / manual",
    "server_other": "Server internals (services, db, lib)",
    "runtime_other": "Agent runtime, CLI, computer, tracing",
    "tests_infra": "Tests / infra / build (ignored)",
    "other": "Other",
}
_TEST_RE = re.compile(
    r"(^|/)(tests?|__tests__|__mocks__|e2e|test-results|testkit)(/|$)|\.(test|spec|typecheck|stories|testkit)\.|"
    r"(^|/)(test-shard-manifest|e2e-shard-manifest)|^(infra|scripts|\.github)/|/scripts/|drizzle/|"
    r"(^|/)(pnpm-lock|pnpm-workspace)\.|tsconfig|Dockerfile|stryker|\.config\.(m?[jt]s|cjs)$|playwright|vitest|"
    r"^packages/visual-testing/(src|tests|site|docs)/|(^|/)__wrong-patch__/|\.(snap|lock)$|\.d\.ts$")
WEB_ONLY_AREAS = {"analytics", "dev", "devtools", "embed", "workers", "feedback", "pwa", "brand"}


def classify(path: str) -> tuple[str, str]:
    """-> (category, area). The area groups related changes (a Web component directory, a store, ...)."""
    p = path
    if _TEST_RE.search(p):
        return "tests_infra", ""
    if p.endswith(".md") or p.startswith("manual/") or "CHANGELOG" in p:
        return "docs", p.split("/")[0]
    if p.startswith("packages/web/src/i18n/") or p == "packages/shared/src/displayLocales.ts":
        return "i18n", "i18n"
    if p.startswith("packages/web/visual-testing/") or p.startswith("packages/visual-testing/shared/"):
        return "visual_cases", "visual-testing"
    if p.endswith(".css") or p.startswith("packages/web/src/theme/") or "tailwind" in p or p == "packages/web/package.json":
        return "styles", "styles"
    if re.match(r"packages/(shared|sync-core|desktop-contract|raft-sdk|runtime-form)/", p):
        return "shared_types", "shared/" + (p.split("/")[1])
    if re.match(r"packages/server/src/(routes|middleware)/", p) or re.search(r"packages/server/src/.*[sS]ocket", p):
        return "server_api", "server/" + p.split("/")[3]
    if p.startswith("packages/server/"):
        return "server_other", "server/" + (p.split("/")[3] if len(p.split("/")) > 4 else "root")
    if p.startswith("packages/web/src/"):
        parts = p.split("/")[3:]
        if parts[0] == "components":
            return "web_ui", "components/" + (parts[1] if len(parts) > 2 else "(root)")
        return "web_ui", parts[0] if len(parts) > 1 else "(root)"
    if p.startswith("packages/web/"):
        return "tests_infra", ""
    if re.match(r"packages/(daemon|cli|computer|trace-client|trace-upload-worker|raft-event-buffer|ui-inventory)/", p):
        return "runtime_other", p.split("/")[1]
    return "other", p.split("/")[0]


# ------------------------------------------------------------------ our side

DART_ROOTS = ("apps/raft_flutter/lib", "packages")
GENERIC_FIELDS = {"id", "name", "type", "status", "kind", "title", "data", "value", "label", "key", "url", "text",
                  "error", "message", "items", "count", "state", "mode", "role", "createdat", "updatedat", "description"}
_DART_STR_RE = re.compile(
    r"""'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)\"""")
_QUOTED_TOKEN_RE = re.compile(r"""['"]([A-Za-z_][A-Za-z0-9_:\-.]{2,})['"]""")
_TSX_REF_RE = re.compile(r"\b([A-Za-z][A-Za-z0-9]+)\.(tsx?)\b")


def camel_to_snake(name: str) -> str:
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", s)
    return s.lower()


def _decode_dart(s: str) -> str:
    s = re.sub(r"\\u\{([0-9a-fA-F]+)\}", lambda m: chr(int(m.group(1), 16)), s)
    s = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), s)
    table = {"n": "\n", "t": "\t", "r": "\r", "'": "'", '"': '"', "\\": "\\", "$": "$"}
    return re.sub(r"\\(.)", lambda m: table.get(m.group(1), m.group(1)), s)


def parse_dart_catalog(text: str) -> dict[str, str]:
    """`'English': '中文',` maps (adjacent literals concatenate). Comment lines are skipped."""
    text = "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("//"))
    toks = []  # (kind, value)
    pos = 0
    for m in re.finditer(r"""'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)"|([:,])""", text):
        if m.group(3):
            toks.append((m.group(3), ""))
        else:
            toks.append(("s", _decode_dart(m.group(1) if m.group(1) is not None else m.group(2))))
    out: dict[str, str] = {}
    i = 0
    while i < len(toks):
        if toks[i][0] != "s":
            i += 1
            continue
        key = ""
        while i < len(toks) and toks[i][0] == "s":
            key += toks[i][1]
            i += 1
        if i < len(toks) and toks[i][0] == ":":
            i += 1
            val, got = "", False
            while i < len(toks) and toks[i][0] == "s":
                val += toks[i][1]
                got = True
                i += 1
            if got:
                out[key] = val
    return out


def normalize_ws(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


@dataclass
class OurIndex:
    repo: Path
    catalog: dict = field(default_factory=dict)         # English -> zh (all zh_*.dart)
    catalog_norm: dict = field(default_factory=dict)    # normalized English -> zh
    tokens: dict = field(default_factory=dict)          # quoted token -> [files] (capped)
    lib_mentions: dict = field(default_factory=dict)    # "Foo" -> {files that cite Foo.tsx}
    doc_mentions: dict = field(default_factory=dict)    # "Foo" -> {docs that cite Foo.tsx}
    cap_by_file: dict = field(default_factory=dict)     # "Foo" -> [(cap id, status, [flutter files])]
    cap_entries: list = field(default_factory=list)
    stems: dict = field(default_factory=dict)           # dart stem -> [rel paths]
    parity_ids: dict = field(default_factory=dict)      # case id -> rel path
    dart_by_path: dict = field(default_factory=dict)    # "/path/:id" -> {dart files with that literal}
    dart_keys: set = field(default_factory=set)         # "METHOD /path/:id" literals found in Flutter code

    def has_text(self, en: str) -> bool:
        return en in self.catalog or normalize_ws(en) in self.catalog_norm


def _walk_files(base: Path, exts, skip_dirs=("build", ".dart_tool", "node_modules")):
    for dp, dns, fns in os.walk(base):
        dns[:] = sorted(d for d in dns if d not in skip_dirs and not d.startswith("."))
        for fn in sorted(fns):
            if fn.endswith(exts):
                yield Path(dp) / fn


def build_our_index(repo: Path) -> OurIndex:
    repo = Path(repo)
    ix = OurIndex(repo)
    l10n = repo / "packages/raft_ui/lib/src/l10n"
    if l10n.is_dir():
        for p in sorted(l10n.glob("zh_*.dart")):
            if p.name.endswith(".g.dart"):
                continue
            ix.catalog.update(parse_dart_catalog(p.read_text(encoding="utf-8")))
    ix.catalog_norm = {normalize_ws(k): v for k, v in ix.catalog.items()}

    def add_token(tok, rel):
        lst = ix.tokens.setdefault(tok, [])
        if len(lst) < 5 and rel not in lst:
            lst.append(rel)

    for base in (repo / "apps/raft_flutter/lib", *sorted((repo / "packages").glob("*/lib"))):
        for p in _walk_files(base, (".dart",)):
            rel = p.relative_to(repo).as_posix()
            ix.stems.setdefault(p.stem, []).append(rel)
            if p.name.endswith(".g.dart"):
                continue
            text = p.read_text(encoding="utf-8", errors="replace")
            for t in set(_QUOTED_TOKEN_RE.findall(text)):
                add_token(t, rel)
            for name, _ext in _TSX_REF_RE.findall(text):
                ix.lib_mentions.setdefault(name, set()).add(rel)
    fx = repo / "apps/raft_flutter/test/fixtures"
    if fx.is_dir():
        for p in _walk_files(fx, (".json", ".dart")):
            rel = p.relative_to(repo).as_posix()
            text = p.read_text(encoding="utf-8", errors="replace")
            for t in set(_QUOTED_TOKEN_RE.findall(text)):
                add_token(t, rel)
    docs = repo / "docs"
    if docs.is_dir():
        for p in sorted(docs.glob("*.md")):
            if p.name.startswith("upstream-sync"):
                continue
            text = p.read_text(encoding="utf-8", errors="replace")
            for name, _ext in _TSX_REF_RE.findall(text):
                ix.doc_mentions.setdefault(name, set()).add(p.relative_to(repo).as_posix())
    capf = repo / "docs/capability-parity.json"
    if capf.exists():
        data = json.loads(capf.read_text(encoding="utf-8"))
        ix.cap_entries = data.get("entries", [])
        for e in ix.cap_entries:
            files = sorted({r["file"] for r in e.get("flutterRefs", [])})
            for name, _ext in _TSX_REF_RE.findall(e.get("webEntry", "")):
                ix.cap_by_file.setdefault(name, []).append((e["id"], e["status"], files))
    pc = repo / "apps/raft_flutter/test/parity"
    id_re = re.compile(r"""['"]([a-z][a-z0-9\-]*(?:\.[a-z0-9\-]+){2,})['"]""")
    for base in (pc, repo / "tool/parity-ext"):
        if not base.is_dir():
            continue
        for p in _walk_files(base, (".dart", ".py", ".tsx", ".json", ".mjs")):
            if p.stat().st_size > 5_000_000:
                continue
            rel = p.relative_to(repo).as_posix()
            for cid in set(id_re.findall(p.read_text(encoding="utf-8", errors="replace"))):
                ix.parity_ids.setdefault(cid, rel)
    segs = {e["id"].split(" ", 1)[1].split("/")[1] for e in ix.cap_entries
            if e["kind"] == "endpoint" and " /" in e["id"] and e["id"].count("/") >= 1}
    if segs:
        for d in cp.extract_flutter(str(repo), segs):
            ix.dart_by_path.setdefault(d.key_path, set()).add(d.file)
            ix.dart_keys.add(f"{d.method} {d.key_path}")
    return ix


def find_counterpart(ix: OurIndex, web_path: str) -> dict:
    """Map a Web source file to our Dart files: documented (comment / capability map) or heuristic."""
    base = Path(web_path).stem
    files, via = [], []
    for f in sorted(ix.lib_mentions.get(base, ())):
        files.append(f)
        via.append("source comment")
    caps = ix.cap_by_file.get(base, [])
    for cid, _st, fl in caps:
        for f in fl:
            if f not in files:
                files.append(f)
                via.append("capability " + cid)
    if files:
        return {"confidence": "documented", "files": files[:4], "via": sorted(set(via))[:3],
                "capabilities": [c[0] for c in caps][:6], "docs": sorted(ix.doc_mentions.get(base, ()))[:3]}
    snake = camel_to_snake(base)
    if snake in ix.stems:
        return {"confidence": "heuristic", "files": ix.stems[snake][:3], "via": ["same name"], "capabilities": [], "docs": []}
    toks = [t for t in snake.split("_") if t]
    core = [t for t in toks if t not in {"panel", "dialog", "view", "page", "section", "tab", "row", "item", "modal",
                                         "content", "list", "card", "menu", "button", "form"}] or toks
    cands = [s for s in ix.stems if all(t in s.split("_") for t in core)] if core and len("".join(core)) >= 4 else []
    if cands and len(cands) <= 3:
        return {"confidence": "heuristic", "files": [ix.stems[c][0] for c in cands], "via": ["name tokens " + "_".join(core)],
                "capabilities": [], "docs": sorted(ix.doc_mentions.get(base, ()))[:3]}
    if ix.doc_mentions.get(base):
        return {"confidence": "doc-only", "files": [], "via": ["mentioned in docs"], "capabilities": [],
                "docs": sorted(ix.doc_mentions[base])[:3]}
    return {"confidence": "none", "files": [], "via": [], "capabilities": [], "docs": []}


# --------------------------------------------------------------------------- TS

def _split_members(body: str) -> list[str]:
    """Split the inside of a TS object type / z.object({...}) into member source texts at depth 0."""
    members, cur, depth = [], [], 0
    i, n = 0, len(body)
    in_str = None
    while i < n:
        c = body[i]
        if in_str:
            cur.append(c)
            if c == "\\":
                cur.append(body[i + 1:i + 2])
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if c in "'\"`":
            in_str = c
            cur.append(c)
        elif c == "/" and body[i + 1:i + 2] == "/":
            j = body.find("\n", i)
            i = n if j < 0 else j
            continue
        elif c == "/" and body[i + 1:i + 2] == "*":
            j = body.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        elif c in "([{<" and not (c == "<" and body[i - 1:i] in (" ", "=")):
            depth += 1
            cur.append(c)
        elif c in ")]}":
            depth -= 1
            cur.append(c)
        elif c == ">" and body[i - 1:i] != "=":
            depth = max(0, depth - 1)
            cur.append(c)
        elif depth == 0 and c in ";,":
            members.append("".join(cur))
            cur = []
        elif depth == 0 and c == "\n":
            text = "".join(cur).strip()
            rest = body[i + 1:].lstrip()
            if text and re.match(r"^(readonly\s+)?(\"[^\"]+\"|'[^']+'|[\w$]+)\??\s*:\s*\S", text) \
                    and not text.endswith(("|", "&", ":", "=>", "=", "?")) and not rest.startswith(("|", "&", "?", ":", ".", ")")):
                members.append(text)
                cur = []
            else:
                cur.append(c)
        else:
            cur.append(c)
        i += 1
    members.append("".join(cur))
    return members


_MEMBER_RE = re.compile(r"""^\s*(?:readonly\s+)?(?:"([^"]+)"|'([^']+)'|([A-Za-z_$][\w$]*))(\?)?\s*:\s*(.*)$""", re.S)
_DECL_RE = re.compile(
    r"(?:^|\n)[ \t]*(?:export\s+)?(?:declare\s+)?(?:interface\s+(\w+)(?:<[^>{]*>)?(?:\s+extends\s+[^{]+)?\s*\{|"
    r"type\s+(\w+)(?:<[^=]*>)?\s*=\s*\{|"
    r"const\s+(\w+)\s*(?::[^=]+)?=\s*(?:\w+\.)?(?:z\.)?(?:strictObject|object)\(\s*\{)")


def _match_brace(text: str, start: int) -> int:
    """text[start] == '{' -> index after the matching '}' (strings / comments aware)."""
    depth, i, n, in_str = 0, start, len(text), None
    while i < n:
        c = text[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == in_str:
                in_str = None
        elif c in "'\"`":
            in_str = c
        elif c == "/" and text[i + 1:i + 2] == "/":
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        elif c == "/" and text[i + 1:i + 2] == "*":
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


def parse_ts_shapes(text: str) -> dict[str, dict[str, str]]:
    """Name -> {field: normalized type text} for interfaces, object type aliases and zod objects."""
    shapes: dict[str, dict[str, str]] = {}
    for m in _DECL_RE.finditer(text):
        name = m.group(1) or m.group(2) or m.group(3)
        brace = m.end() - 1
        end = _match_brace(text, brace)
        flds = shapes.setdefault(name, {})
        for mem in _split_members(text[brace + 1:end - 1]):
            mm = _MEMBER_RE.match(mem.strip())
            if mm and not mem.strip().startswith(("...", "[")):
                key = mm.group(1) or mm.group(2) or mm.group(3)
                flds[key + ("?" if mm.group(4) else "")] = re.sub(r"\s+", " ", mm.group(5)).strip()[:160]
    return shapes


def diff_shapes(old: dict, new: dict) -> dict:
    out = {"added_types": [], "removed_types": [], "changed": {}}
    for name in sorted(set(new) - set(old)):
        out["added_types"].append({"name": name, "fields": sorted(new[name])})
    for name in sorted(set(old) - set(new)):
        out["removed_types"].append({"name": name, "fields": sorted(old[name])})
    for name in sorted(set(old) & set(new)):
        o, n = old[name], new[name]
        on, nn = {k.rstrip("?"): k for k in o}, {k.rstrip("?"): k for k in n}
        added = sorted(set(nn) - set(on))
        removed = sorted(set(on) - set(nn))
        retyped = sorted(k for k in set(on) & set(nn) if o[on[k]] != n[nn[k]] or (on[k] != nn[k]))
        if added or removed or retyped:
            out["changed"][name] = {
                "added": [{"field": k, "type": n[nn[k]]} for k in added],
                "removed": [{"field": k, "type": o[on[k]]} for k in removed],
                "retyped": [{"field": k, "from": f"{on[k]}: {o[on[k]]}", "to": f"{nn[k]}: {n[nn[k]]}"} for k in retyped],
            }
    return out


def parse_i18n_catalog(text: str) -> dict[str, str]:
    """`"id": "ICU message"` entries of web/src/i18n/messages/{en,zh-cn}.ts (values may be on the next line)."""
    out: dict[str, str] = {}
    rx = re.compile(r'''^[ \t]*"([A-Za-z0-9_.\-]+)"\s*:\s*("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`)''', re.M)
    for m in rx.finditer(text):
        raw = m.group(2)
        try:
            val = json.loads(raw) if raw[0] == '"' else raw[1:-1].replace("\\'", "'").replace("\\`", "`")
        except ValueError:
            val = raw[1:-1]
        out[m.group(1)] = val
    return out


SOCKET_EVENT_RE = re.compile(r"""["']([a-z][a-z0-9_]*(?:[:\-][a-z0-9_\-]+)+)["']""")


def socket_events(text: str) -> set[str]:
    return {e for e in SOCKET_EVENT_RE.findall(text) if ":" in e and "/" not in e and not e.startswith(("data:", "http"))}


ROUTE_DEF_RE = re.compile(r"""(?<![\w.$])(?:\w*[rR]outer|app|r)\s*\.\s*(get|post|put|patch|delete)\s*\(\s*(["'`])([^"'`]+)\2""")


def route_defs(text: str) -> set[str]:
    return {f"{m.group(1).upper()} {m.group(3)}" for m in ROUTE_DEF_RE.finditer(text)}


# ------------------------------------------------------------- UI diff summaries

_JSX_TAG_RE = re.compile(r"<([A-Z][A-Za-z0-9]+)\b")
_PROP_RE = re.compile(r"\b([a-z][A-Za-z0-9]+)=\{")
_HOOK_RE = re.compile(r"\b(use[A-Z][A-Za-z0-9]+)\b")
_I18N_ID_RE = re.compile(r'''["']([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9_\-]+){1,})["']''')
_IMPORT_RE = re.compile(r"""from\s+["']([^"']+)["']""")


def summarize_hunk_lines(lines: list[str]) -> dict:
    """Notable identifiers in the added/removed lines of one file."""
    add = [l[1:] for l in lines if l.startswith("+")]
    rem = [l[1:] for l in lines if l.startswith("-")]

    def delta(rx, limit=8):
        a, r = collections.Counter(), collections.Counter()
        for l in add:
            a.update(rx.findall(l))
        for l in rem:
            r.update(rx.findall(l))
        return ([k for k in a if k not in r][:limit], [k for k in r if k not in a][:limit])

    tags_a, tags_r = delta(_JSX_TAG_RE)
    props_a, props_r = delta(_PROP_RE)
    hooks_a, hooks_r = delta(_HOOK_RE)
    ids_a, ids_r = delta(_I18N_ID_RE, 60)
    imp_a, imp_r = delta(_IMPORT_RE)
    return {"added": len(add), "removed": len(rem),
            "jsx_added": tags_a, "jsx_removed": tags_r, "props_added": props_a, "props_removed": props_r,
            "hooks_added": hooks_a, "hooks_removed": hooks_r, "i18n_ids_added": ids_a, "i18n_ids_removed": ids_r,
            "imports_added": imp_a, "imports_removed": imp_r}


def short_summary(s: dict) -> str:
    parts = []
    for key, label in (("jsx_added", "+<>"), ("jsx_removed", "-<>"), ("props_added", "+prop"),
                       ("props_removed", "-prop"), ("hooks_added", "+hook"), ("hooks_removed", "-hook")):
        if s.get(key):
            parts.append(f"{label} " + ", ".join(s[key][:4]))
    if s.get("i18n_ids_added") or s.get("i18n_ids_removed"):
        parts.append(f"ids +{len(s['i18n_ids_added'])}/-{len(s['i18n_ids_removed'])}")
    return "; ".join(parts)


def sizing(lines: int) -> str:
    return "S" if lines <= 150 else ("M" if lines <= 800 else "L")


# ---------------------------------------------------------------------- report

def load_state(repo: Path) -> dict:
    p = Path(repo) / STATE_FILE
    if not p.exists():
        raise UpstreamError(f"{STATE_FILE} is missing; create it with the pinned baseline tag")
    data = json.loads(p.read_text(encoding="utf-8"))
    if not TAG_RE.match(data.get("pinned", "")):
        raise UpstreamError(f"{STATE_FILE}: pinned must look like v1.2.3-source.1")
    return data


def _file_tokens_used(ix: OurIndex, field_name: str) -> list[str]:
    if field_name.lower() in GENERIC_FIELDS or len(field_name) < 4:
        return []
    return ix.tokens.get(field_name, [])


def collect_api(ta: Path, tb: Path, ix: OurIndex, changed: dict[str, FileChange]) -> dict:
    """Web client calls of two extracted trees (see tool/capability_parity.py), checked against the app and the capability JSON."""
    if True:
        def run(root):
            calls = cp.extract_web(str(root))
            other = cp.extract_other(str(root))
            keys = cp.keys(calls, other)
            sites = collections.defaultdict(set)
            raws = collections.defaultdict(set)
            for c in calls:
                sites[f"{c.method} {c.key_path}"].add("packages/web/src/" + c.file)
                raws[f"{c.method} {c.key_path}"].add(re.sub(r"\$\{[^}]*\}", "${}", re.sub(r"\s+", " ", c.raw_path)))
            for o in other:
                if o.startswith("RAW "):
                    sites[o].add("packages/web/src/" + o[4:])
            return set(keys), sites, raws, calls
        ka, sa, ra, _ = run(ta)
        kb, sb, rb, calls_b = run(tb)
    dart_keys = ix.dart_keys | {f"? {p}" for p in ix.dart_by_path}
    dart_paths = set(ix.dart_by_path)
    cap = {e["id"]: e for e in ix.cap_entries if e["kind"] == "endpoint"}

    def ours(key):
        """'yes' (method + path literal in Dart), 'path' (same path, other/unknown method), 'no'."""
        if key.startswith(("RAW ", "SOCKET ")):
            return "yes" if key in cap and cap[key]["status"] in ("covered", "partial") else "no"
        meth, path = key.split(" ", 1)
        if key in dart_keys:
            return "yes"
        return "path" if path in dart_paths else "no"

    def sibling(key):
        if key.startswith(("RAW ", "SOCKET ")):
            return []
        def strip_v(seg):
            return re.sub(r"-v\d+$", "", seg)
        segs = [strip_v(x) for x in key.split(" ", 1)[1].strip("/").split("/")]
        top = min(len(segs), 3)
        low = top if len(segs) >= 3 else 1
        for n in range(top, low - 1, -1):
            pref = "/" + "/".join(segs[:n])
            sibs = []
            for i, e in cap.items():
                if i == key:
                    continue
                other = "/" + "/".join(strip_v(x) for x in i.split(" ", 1)[-1].strip("/").split("/"))
                if other == pref or other.startswith(pref + "/"):
                    sibs.append((i, e["status"]))
            if sibs:
                return sibs[:5]
        return []

    def area_of(key, sites):
        files = sorted(sites.get(key, ()))
        return classify(files[0])[1] if files else ""

    added = []
    for k in sorted(kb - ka):
        e = cap.get(k)
        added.append({"key": k, "files": sorted(sb.get(k, ()))[:3], "area": area_of(k, sb),
                      "recorded": e["status"] if e else None, "ours_calls": ours(k),
                      "siblings": [f"{i} [{s}]" for i, s in sibling(k)]})
    removed = []
    for k in sorted(ka - kb):
        e = cap.get(k)
        removed.append({"key": k, "files": sorted(sa.get(k, ()))[:3], "area": area_of(k, sa),
                        "recorded": e["status"] if e else None, "ours_calls": ours(k)})
    changed_calls = []
    for k in sorted(ka & kb):
        if ra.get(k) != rb.get(k):
            changed_calls.append({"key": k, "files": sorted(sb.get(k, ()))[:3], "area": area_of(k, sb),
                                  "from": sorted(ra.get(k, ()))[:3], "to": sorted(rb.get(k, ()))[:3],
                                  "recorded": cap[k]["status"] if k in cap else None, "ours_calls": ours(k)})
    touched = collections.OrderedDict()
    for k in sorted(ka & kb):
        fs = [f for f in sorted(sb.get(k, ())) if f in changed and changed[f].lines]
        if fs and k not in {c["key"] for c in changed_calls}:
            touched[k] = fs
    return {"added": added, "removed": removed, "changed_path_expr": changed_calls,
            "call_site_files_edited": {k: v for k, v in list(touched.items())[:200]},
            "totals": {"a": len(ka), "b": len(kb)}}


def collect_capabilities(ix: OurIndex, changed_web: dict[str, FileChange]) -> list[dict]:
    """Recorded 'ui:' capabilities whose Web entry file changed upstream."""
    out = []
    by_base = {}
    for p, fc in changed_web.items():
        by_base.setdefault(Path(p).stem, []).append(fc)
    for e in ix.cap_entries:
        hit = []
        for name, _ext in _TSX_REF_RE.findall(e.get("webEntry", "")):
            for fc in by_base.get(name, ()):
                if fc.lines:
                    hit.append(fc)
        if hit:
            out.append({"id": e["id"], "status": e["status"], "capability": e["capability"][:140],
                        "files": sorted({h.path.split("packages/web/src/")[-1] for h in hit})[:3],
                        "areas": sorted({h.area for h in hit}),
                        "lines": sum(h.lines for h in hit)})
    return sorted(out, key=lambda x: -x["lines"])


AGENT_CONTRACT_RE = re.compile(r"packages/shared/src/(agentApi|agentText/|agentOps/|raftCli|agentMessageText|feedback|agentInbox)")


def shape_relevance(path: str, ch: dict) -> str:
    """wire = may be read from server payloads; agent-contract = agent API / CLI only; store-internal = Zustand state."""
    if AGENT_CONTRACT_RE.match(path):
        return "agent-contract"
    if path.startswith("packages/web/src/store/") and all(
            "=>" in i.get("type", i.get("from", i.get("to", ""))) or i.get("type", "").startswith("(")
            for lst in (ch["added"], ch["removed"], ch["retyped"]) for i in lst):
        return "store-internal"
    return "wire"


def collect_shapes(mirror, a, b, files: list[FileChange], ix: OurIndex) -> dict:
    old_of = {f.path: f.old_path or f.path for f in files}
    paths = [f.path for f in files if f.path.endswith((".ts", ".tsx"))
             and (f.path.startswith("packages/shared/src/") or re.match(r"packages/web/src/(store|api|utils|hooks|lib|types)/", f.path)
                  or f.path.startswith("packages/sync-core/src/") or f.path.startswith("packages/desktop-contract/"))
             and f.category in ("shared_types", "web_ui")]
    old_shapes: dict[str, dict] = {}
    new_shapes: dict[str, dict] = {}
    where: dict[str, str] = {}
    for p in paths:
        ta = show(mirror, a, old_of.get(p, p))
        tb = show(mirror, b, p)
        for name, flds in parse_ts_shapes(ta or "").items():
            old_shapes.setdefault(name, {}).update(flds)
        for name, flds in parse_ts_shapes(tb or "").items():
            new_shapes.setdefault(name, {}).update(flds)
            where[name] = p
        for name in parse_ts_shapes(ta or ""):
            where.setdefault(name, p)
    # only compare names whose declaring files changed (others cannot differ)
    d = diff_shapes(old_shapes, new_shapes)
    for name, ch in d["changed"].items():
        ch["file"] = where.get(name, "")
        ch["relevance"] = shape_relevance(ch["file"], ch)
        for lst in (ch["added"], ch["removed"], ch["retyped"]):
            for it in lst:
                it["ours"] = _file_tokens_used(ix, it["field"])
    for t in d["added_types"] + d["removed_types"]:
        t["file"] = where.get(t["name"], "")
        t["ours"] = sorted({f for fld in t["fields"] for f in _file_tokens_used(ix, fld.rstrip("?"))})[:3]
    return d


def collect_wire_candidates(hunks: dict[str, list[str]], files: list[FileChange], ix: OurIndex) -> list[dict]:
    out = []
    key_rx = re.compile(r"^\s*(?:\"([A-Za-z_]\w{3,})\"|([A-Za-z_]\w{3,}))\s*:")
    for f in files:
        if f.category != "server_api" or not f.path.endswith(".ts"):
            continue
        lines = hunks.get(f.path, [])
        add, rem = collections.Counter(), collections.Counter()
        for l in lines:
            m = key_rx.match(l[1:])
            if m:
                (add if l[0] == "+" else rem)[m.group(1) or m.group(2)] += 1
        a_only = [k for k in add if k not in rem and k.lower() not in GENERIC_FIELDS]
        r_only = [k for k in rem if k not in add and k.lower() not in GENERIC_FIELDS]
        if a_only or r_only:
            out.append({"file": f.path.split("packages/server/src/")[-1], "added": a_only[:15], "removed": r_only[:15],
                        "ours_added": {k: ix.tokens[k] for k in a_only if k in ix.tokens and len(k) >= 4},
                        "ours_removed": {k: ix.tokens[k] for k in r_only if k in ix.tokens and len(k) >= 4}})
    return out


def collect_i18n(mirror, a, b, ix: OurIndex) -> dict:
    p_en, p_zh = "packages/web/src/i18n/messages/en.ts", "packages/web/src/i18n/messages/zh-cn.ts"
    en_a, en_b = parse_i18n_catalog(show(mirror, a, p_en) or ""), parse_i18n_catalog(show(mirror, b, p_en) or "")
    zh_a, zh_b = parse_i18n_catalog(show(mirror, a, p_zh) or ""), parse_i18n_catalog(show(mirror, b, p_zh) or "")
    added = sorted(set(en_b) - set(en_a))
    removed = sorted(set(en_a) - set(en_b))
    changed_en = sorted(k for k in set(en_a) & set(en_b) if en_a[k] != en_b[k])
    changed_zh = sorted(k for k in set(zh_a) & set(zh_b) if zh_a[k] != zh_b[k] and k not in changed_en)
    zh_missing = sorted(k for k in added if k not in zh_b)

    def prefix(k):
        return k.split(".")[0]

    def row(k, new_en=None, old_en=None):
        r = {"id": k, "prefix": prefix(k)}
        if new_en is not None:
            r["en"] = new_en[:200]
            r["zh"] = zh_b.get(k, "")[:200]
            r["ours_has_text"] = ix.has_text(new_en)
        if old_en is not None:
            r["old_en"] = old_en[:200]
            r["ours_had_old"] = ix.has_text(old_en)
        return r

    chg = []
    for k in changed_en:
        r = row(k, en_b[k], en_a[k])
        r["old_zh"] = zh_a.get(k, "")[:200]
        r["zh"] = zh_b.get(k, "")[:200]
        chg.append(r)
    zhd = []
    for k in changed_zh:
        r = row(k, en_b[k])
        r["old_zh"] = zh_a.get(k, "")[:200]
        r["ours_zh"] = ix.catalog.get(en_b[k], ix.catalog_norm.get(normalize_ws(en_b[k]), ""))[:200]
        r["drift_in_ours"] = bool(r["ours_zh"]) and r["ours_zh"] != zh_b.get(k, "")
        zhd.append(r)
    return {"_en_b": en_b, "totals": {"en_a": len(en_a), "en_b": len(en_b), "zh_a": len(zh_a), "zh_b": len(zh_b)},
            "added": [row(k, en_b[k]) for k in added], "removed": [row(k, None, en_a[k]) for k in removed],
            "changed_en": chg, "changed_zh": zhd, "zh_missing_for_added": zh_missing}


def collect_visual(mirror, a, b, ix: OurIndex, changed: dict[str, FileChange]) -> dict:
    p = "packages/visual-testing/shared/sharedCases.json"

    def load(tag):
        t = show(mirror, tag, p)
        try:
            return {c["id"]: c for c in json.loads(t)["cases"]} if t else {}
        except (ValueError, KeyError):
            return {}
    ca, cb = load(a), load(b)

    def ours(cid):
        if cid in ix.parity_ids:
            return ix.parity_ids[cid]
        return ""

    def row(cid, c, **kw):
        return {"id": cid, "title": c.get("title", ""), "surface": c.get("surface", ""),
                "baselineStatus": c.get("baselineStatus", ""), "skipped": bool(c.get("skip")),
                "react_path": c.get("reactPathHint", ""), "ours": ours(cid), **kw}
    added = [row(i, cb[i]) for i in sorted(set(cb) - set(ca))]
    removed = [row(i, ca[i]) for i in sorted(set(ca) - set(cb))]
    changed_rows = []
    for i in sorted(set(ca) & set(cb)):
        if ca[i] != cb[i]:
            keys = sorted(k for k in set(ca[i]) | set(cb[i]) if ca[i].get(k) != cb[i].get(k))
            changed_rows.append(row(i, cb[i], changed_keys=keys))
    host_files = [p2 for p2 in changed if changed[p2].category == "visual_cases"]
    return {"totals": {"a": len(ca), "b": len(cb)}, "added": added, "removed": removed, "changed": changed_rows,
            "host_files": [(h, changed[h].added, changed[h].removed) for h in sorted(host_files)]}


_CSS_VAR_RE = re.compile(r"(--[A-Za-z0-9_\-]+)\s*:\s*([^;]+);")


def collect_styles(mirror, a, b, files: list[FileChange]) -> dict:
    css = {}
    for f in files:
        if f.category == "styles" and f.path.endswith(".css"):
            va = dict(_CSS_VAR_RE.findall(show(mirror, a, f.old_path or f.path) or ""))
            vb = dict(_CSS_VAR_RE.findall(show(mirror, b, f.path) or ""))
            css[f.path] = {"added": sorted(set(vb) - set(va))[:40],
                           "removed": sorted(set(va) - set(vb))[:40],
                           "changed": sorted(k for k in set(va) & set(vb) if va[k].strip() != vb[k].strip())[:60],
                           "lines": f.lines}
    deps = {}
    try:
        pa = json.loads(show(mirror, a, "packages/web/package.json") or "{}")
        pb = json.loads(show(mirror, b, "packages/web/package.json") or "{}")
        for sect in ("dependencies", "devDependencies"):
            da, db = pa.get(sect, {}), pb.get(sect, {})
            for k in sorted(set(da) | set(db)):
                if da.get(k) != db.get(k):
                    deps[k] = (da.get(k), db.get(k))
    except ValueError:
        pass
    theme_files = [f.path for f in files if f.category == "styles" and not f.path.endswith(".css") and f.path != "packages/web/package.json"]
    return {"css": css, "dependency_changes": deps, "theme_files": theme_files}


def collect_socket(mirror, a, b, hunks, ix: OurIndex) -> dict:
    ea, eb = set(), set()
    for p in list_tree(mirror, b, "packages/web/src"):
        if re.search(r"socket|Socket", p) and p.endswith((".ts", ".tsx")) and ".test." not in p:
            eb |= socket_events(show(mirror, b, p) or "")
    for p in list_tree(mirror, a, "packages/web/src"):
        if re.search(r"socket|Socket", p) and p.endswith((".ts", ".tsx")) and ".test." not in p:
            ea |= socket_events(show(mirror, a, p) or "")
    return {"added": [{"event": e, "ours": ix.tokens.get(e, [])[:2]} for e in sorted(eb - ea)],
            "removed": [{"event": e, "ours": ix.tokens.get(e, [])[:2]} for e in sorted(ea - eb)]}


def collect_server_routes(mirror, a, b, files: list[FileChange]) -> list[dict]:
    out = []
    for f in files:
        if f.category == "server_api" and f.path.endswith(".ts"):
            ta, tb = show(mirror, a, f.old_path or f.path) or "", show(mirror, b, f.path) or ""
            ra, rb = route_defs(ta), route_defs(tb)
            if ra != rb:
                out.append({"file": f.path.split("packages/server/src/")[-1], "status": f.status,
                            "added": sorted(rb - ra), "removed": sorted(ra - rb), "lines": f.lines})
    return out


def collect_docs(mirror, a, b, files: list[FileChange], commits: list[dict]) -> dict:
    changelog = []
    for f in files:
        if f.category == "docs" and "CHANGELOG" in f.path:
            ta, tb = show(mirror, a, f.old_path or f.path) or "", show(mirror, b, f.path) or ""
            new = tb[:len(tb) - len(ta)] if ta and tb.endswith(ta) else None
            if new is None:
                import difflib
                new = "\n".join(l[2:] for l in difflib.ndiff(ta.splitlines(), tb.splitlines()) if l.startswith("+ "))
            changelog.append({"file": f.path, "added_text": new.strip()[:6000]})
    manual = [{"file": f.path, "status": f.status, "lines": f.lines} for f in files
              if f.category == "docs" and f.path.startswith("manual/")]
    return {"changelog": changelog, "manual": manual, "commits": commits}


# -------------------------------------------------------------- bundles/actions

def propose_file_action(fc: FileChange, cp_: dict, summary: dict) -> tuple[str, str, str, str]:
    """-> (action, reason, size, risk) for one changed web UI file."""
    area_leaf = fc.area.split("/")[-1]
    size = sizing(fc.lines)
    if area_leaf in WEB_ONLY_AREAS:
        return "skip", f"web-only surface ({area_leaf})", "S", "low"
    mapped = cp_["confidence"] in ("documented", "heuristic")
    if fc.status == "A":
        if mapped:
            return "partial", "new Web file that matches an existing counterpart name; extend it", size, "medium"
        return ("discuss", "new Web surface with no counterpart in the app", size, "medium") if fc.lines > 80 else \
            ("follow", "small new helper; port with the feature that uses it", "S", "low")
    if fc.status == "D":
        return ("discuss", "Web removed a file we mirror; decide whether to drop ours", "S", "medium") if mapped else \
            ("skip", "removed upstream, no counterpart", "S", "low")
    if not mapped:
        if fc.lines <= 40:
            return "skip", "small change, no counterpart in the app", "S", "low"
        return "discuss", "changed Web file with no known counterpart; check whether the feature exists in the app", size, "medium"
    if fc.lines <= 30:
        return "follow", "small change to a mirrored surface", "S", "low"
    risk = "high" if fc.area.startswith(("store", "hooks")) and fc.lines > 150 else "medium"
    return "partial", "mirrored surface changed; port contract/copy fixes, review layout/behavior", size, risk


# ------------------------------------------------------- server behaviour changes

BEHAVIOUR_TAGS = {
    "sorting": (re.compile(r"\b(sort|sorted|orderBy|order by|asc\(|desc\(|localeCompare)\b", re.I), 3),
    "filtering": (re.compile(r"\b(where|inArray|notInArray|isNull|isNotNull|having)\b|\.filter\(", re.I), 2),
    "permission": (re.compile(r"(forbidden|\b403\b|isOwner|isAdmin|canManage|\bcan[A-Z]\w+\(|requireRole|requireAdmin|permission|"
                              r"authoriz|\bguest\b|\brole\b|allowed|denied|ownerOnly)", re.I), 3),
    "limits/defaults": (re.compile(r"\b(limit|MAX_\w+|MIN_\w+|DEFAULT_\w+|slice)\b|\?\?\s*\d|\bdefault\w*\s*[:=]|\.(max|min)\(", re.I), 2),
    "rate-limit": (re.compile(r"(rateLimit|limiter|throttle|retry-after|retryAfter|\b429\b|cooldown)", re.I), 3),
    "validation/messages": (re.compile(r"(status\(4\d\d\)|error:\s*[\"'`]|message:\s*[\"'`]|\binvalid\b|safeParse|\.parse\(|\bz\.\w+\()", re.I), 1),
}
BEHAVIOUR_PATH_RE = re.compile(r"^packages/server/src/(routes|services|middleware|lib)/[^/]+\.ts$|^packages/server/src/app\.ts$")
_HUNK_HDR_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@\s?(.*)$")
_ROUTE_LINE_RE = re.compile(r"""(?<![\w.$])(\w+)\s*\.\s*(get|post|put|patch|delete)\s*\(\s*(["'`])([^"'`]+)\3""")
_FUNC_START_RE = re.compile(
    r"^(?:export\s+)?(?:async\s+)?function\s*\*?\s*(\w+)|^(?:export\s+)?const\s+(\w+)\s*(?::[^=]+)?=\s*(?:async\s*)?(?:\(|\w+\s*=>)|"
    r"^  (?:public\s+|private\s+|static\s+)*(?:async\s+)?(\w+)\s*(?:<[^>]*>)?\([^)]*\)\s*(?::[^{]+)?\{\s*$")
_NOT_FUNCS = {"if", "for", "while", "switch", "catch", "return", "constructor"}


def hunks_detail(mirror: Path, a: str, b: str, paths: list[str]) -> dict[str, list[dict]]:
    out: dict[str, list[dict]] = {}
    for i in range(0, len(paths), 150):
        text = _git(mirror, "diff", "-U0", "-M50%", "--no-color", f"{a}^{{tree}}", f"{b}^{{tree}}", "--", *paths[i:i + 150])
        cur = None
        for line in text.split("\n"):
            if line.startswith("diff --git "):
                m = re.match(r"diff --git a/(.*) b/(.*)$", line)
                cur = m.group(2) if m else None
                if cur:
                    out[cur] = []
            elif cur and line.startswith("@@"):
                m = _HUNK_HDR_RE.match(line)
                if m:
                    out[cur].append({"old": int(m.group(1)), "new": int(m.group(3)),
                                     "new_len": int(m.group(4)) if m.group(4) is not None else 1, "ctx": m.group(5), "lines": []})
            elif cur and out[cur] and line[:1] in "+-" and not line.startswith(("+++", "---")):
                out[cur][-1]["lines"].append(line)
    return out


def mount_map(app_ts: str) -> dict[str, list[str]]:
    """routerName -> mounted prefixes (without /api) from `app.use("/api/x", ..., xRouter)`."""
    out: dict[str, list[str]] = collections.defaultdict(list)
    for m in re.finditer(r"""app\.use\(\s*["'](/api[^"']*)["']\s*,([^;]*?)\);""", app_ts, re.S):
        for name in re.findall(r"\b(\w+Router)\b", m.group(2)):
            pref = m.group(1)[4:] or "/"
            if pref not in out[name]:
                out[name].append(pref)
    return out


def norm_endpoint(prefix: str, sub: str) -> str:
    p = (prefix.rstrip("/") + "/" + sub.lstrip("/")).rstrip("/") or "/"
    return re.sub(r":\w+", ":id", p)


def _enclosing_function(lines: list[str], idx: int) -> str:
    for k in range(min(idx, len(lines) - 1), max(-1, idx - 400), -1):
        m = _FUNC_START_RE.match(lines[k])
        if m:
            name = m.group(1) or m.group(2) or m.group(3)
            if name and name not in _NOT_FUNCS:
                return name
    return ""


def collect_behaviour(mirror: Path, a: str, b: str, files: list[FileChange], ix: OurIndex) -> dict:
    targets = [f for f in files if f.status != "D" and f.category in ("server_api", "server_other")
               and BEHAVIOUR_PATH_RE.match(f.path)]
    detail = hunks_detail(mirror, a, b, [f.path for f in targets])
    mounts = mount_map(show(mirror, b, "packages/server/src/app.ts") or "")
    # route index of the new tree: file -> [(line, key)], imports
    route_files = [p for p in list_tree(mirror, b, "packages/server/src/routes")
                   if p.endswith(".ts") and not _TEST_RE.search(p)]
    route_text = {p: show(mirror, b, p) or "" for p in route_files}
    handlers: dict[str, list[tuple[int, str]]] = {}
    for p, text in route_text.items():
        hs = []
        for m in _ROUTE_LINE_RE.finditer(text):
            recv = m.group(1)
            if not (recv.endswith("Router") or recv in ("router", "r")):
                continue
            line = text.count("\n", 0, m.start()) + 1
            for pref in mounts.get(recv, [""]) or [""]:
                hs.append((line, f"{m.group(2).upper()} {norm_endpoint(pref, m.group(4))}"))
        handlers[p] = sorted(hs)
    cap = {e["id"]: e for e in ix.cap_entries if e["kind"] == "endpoint"}

    def feature(key):
        e = cap.get(key)
        path = key.split(" ", 1)[1]
        f = []
        if e and e["status"] in ("covered", "partial"):
            f.append(f"{e['capability'][:90]} [{e['status']}]")
        files_ = sorted(ix.dart_by_path.get(path, ()))
        if files_ and not f:
            f.append("Dart: " + ", ".join(Path(x).name for x in files_[:2]))
        return f

    results = []
    for f in targets:
        hunks = detail.get(f.path, [])
        tags: dict[str, int] = collections.Counter()
        samples: dict[str, list[str]] = collections.defaultdict(list)
        funcs: list[str] = []
        touched_lines: list[int] = []
        text_b = show(mirror, b, f.path) or ""
        lines_b = text_b.split("\n")
        for h in hunks:
            code = [l for l in h["lines"] if l[1:].strip() and not l[1:].strip().startswith(("//", "*", "/*", "import "))]
            hit = False
            for l in code:
                for tag, (rx, _w) in BEHAVIOUR_TAGS.items():
                    if rx.search(l[1:]):
                        tags[tag] += 1
                        hit = True
                        if len(samples[tag]) < 2:
                            samples[tag].append(l[0] + " " + l[1:].strip()[:150])
            if hit:
                touched_lines.append(max(1, h["new"]))
                fn = _enclosing_function(lines_b, h["new"] - 1)
                if fn and fn not in funcs:
                    funcs.append(fn)
        if not tags:
            continue
        score = sum(BEHAVIOUR_TAGS[t][1] * n for t, n in tags.items())
        endpoints: list[str] = []
        coarse = False
        if f.path.startswith("packages/server/src/routes/"):
            hs = handlers.get(f.path, [])
            for ln in touched_lines:
                prior = [k for (l, k) in hs if l <= ln]
                if prior:
                    if prior[-1] not in endpoints:
                        endpoints.append(prior[-1])
                else:
                    coarse = True
            if coarse:
                endpoints += [k for _l, k in hs if k not in endpoints][:6]
        else:
            stem = Path(f.path).stem
            for rp, text in route_text.items():
                if re.search(r"""from\s+["'][^"']*/%s(?:\.js)?["']""" % re.escape(stem), text):
                    hs = handlers[rp]
                    for i, (l, k) in enumerate(hs):
                        tl = text.split("\n")
                        end = hs[i + 1][0] if i + 1 < len(hs) else len(tl) + 1
                        for q in range(l, min(end - 1, l + 400)):
                            if re.match(r"^\}\);?\s*$", tl[q]):
                                end = q + 2
                                break
                        body = "\n".join(tl[l - 1:end - 1])
                        if (funcs and any(re.search(r"\b%s\b" % re.escape(fn), body) for fn in funcs)) or (not funcs and False):
                            if k not in endpoints:
                                endpoints.append(k)
            coarse = not endpoints
        feats = []
        for k in endpoints[:10]:
            for x in feature(k):
                if x not in feats:
                    feats.append(x)
        results.append({"file": f.path.split("packages/server/src/")[-1], "lines": f.lines, "score": score,
                        "tags": dict(tags), "samples": {k: v for k, v in samples.items()}, "functions": funcs[:8],
                        "endpoints": endpoints[:12], "endpoints_coarse": coarse, "flutter": feats[:6]})
    results.sort(key=lambda x: (-bool(x["flutter"]), -x["score"]))
    return {"files": results, "scanned": len(targets)}


# ------------------------------------------------- behaviour-parity checklist drift

def collect_behavior_drift(repo: Path, tree_b: Path) -> dict:
    """Run tool/behavior-parity --web <new tree>: which audited Web behaviours (docs/behavior-parity) changed upstream."""
    script = Path(repo) / "tool/behavior-parity"
    if not script.exists() or not (Path(repo) / "docs/behavior-parity").is_dir():
        return {"available": False, "domains": {}}
    res = subprocess.run([sys.executable, str(script), "--web", str(tree_b), "--json"], capture_output=True, text=True, cwd=str(repo))
    try:
        data = json.loads(res.stdout)
    except ValueError:
        return {"available": False, "error": (res.stderr or res.stdout)[:400], "domains": {}}
    domains = {}
    for name, d in data.get("domains", {}).items():
        rows = []
        for r in d.get("rows", []):
            dr = r.get("drift") or {}
            if dr.get("state") not in (None, "unchanged", "-"):
                rows.append({"id": r["id"], "anchor": r["anchor"], "audit": r.get("audit", ""), "status": r.get("status", ""),
                             "drift": dr.get("state", ""), "detail": dr.get("detail", ""), "newPath": dr.get("newPath", "")})
        unc = d.get("uncovered", {})
        domains[name] = {"total": d.get("total", 0), "baseline": d.get("baseline", {}), "driftCounts": d.get("driftCounts", {}),
                         "changed": rows, "uncovered_events": [e["event"] for e in unc.get("events", [])],
                         "uncovered_symbols": len(unc.get("symbols", [])), "scope": d.get("header", {}).get("scope", "")}
    return {"available": True, "domains": domains, "errors": data.get("errors", [])}


# --------------------------------------------------------------- visual layer

_OFFICIAL_ID_RE = re.compile(r"""["']((?:components|screens|auth|login)\.[a-z0-9\-]+(?:\.[a-z0-9\-]+)+)["']""")
_STARTS_RE = re.compile(r"""startsWith\(\s*["']((?:components|screens|auth|login)\.[a-z0-9.\-]*)["']""")


def parity_ext_hosts(repo: Path) -> list[dict]:
    """Each tool/parity-ext/host/*.tsx: the Web components it renders and the case ids it serves (via its builder)."""
    hosts = []
    host_dir = Path(repo) / "tool/parity-ext/host"
    if not host_dir.is_dir():
        return hosts
    builders = {p.stem: p for p in (Path(repo) / "tool/parity-ext").glob("build-*.py")}
    for h in sorted(host_dir.glob("*.tsx")):
        text = h.read_text(encoding="utf-8", errors="replace")
        tags = {t for t in re.findall(r"<([A-Z][A-Za-z0-9]+)\b", text) if not t.startswith("ParityExt")}
        base = re.sub(r"Cases$", "", h.stem)
        kebab = camel_to_snake(base).replace("_", "-")
        ids = set()
        for stem, bp in builders.items():
            bs = stem[len("build-"):].replace("-cases", "")
            if bs == kebab or bs.rstrip("s") == kebab.rstrip("s"):
                ids |= set(_OFFICIAL_ID_RE.findall(bp.read_text(encoding="utf-8", errors="replace")))
        ids |= set(_OFFICIAL_ID_RE.findall(text))
        prefixes = set(_STARTS_RE.findall(text))
        hosts.append({"host": h.name, "components": sorted(tags), "ids": sorted(ids), "prefixes": sorted(prefixes)})
    return hosts


def glob_of(cid: str) -> str:
    parts = cid.split(".")
    return ".".join(parts[:3]) + ".*" if len(parts) > 3 else cid


def collect_visual_layer(repo: Path, ix: OurIndex, ui_items: list[dict], visual: dict, shared_b: dict) -> dict:
    hosts = parity_ext_hosts(repo)
    official_by_comp: dict[str, set[str]] = collections.defaultdict(set)
    for cid, c in shared_b.items():
        hint = c.get("reactPathHint", "")
        if hint:
            official_by_comp[Path(hint.split("#")[0]).stem].add(cid)
    per_file = []
    for it in ui_items:
        name = Path(it["path"]).stem
        off = sorted(official_by_comp.get(name, ()))
        ext, ext_hosts = set(), []
        for h in hosts:
            if name in h["components"]:
                ext_hosts.append(h["host"])
                ext |= set(h["ids"]) or {p + "*" for p in h["prefixes"]}
        if off or ext:
            per_file.append({"path": it["path"], "official": off, "ext": sorted(ext)[:40], "hosts": ext_hosts, "lines": it["lines"]})
    for v in visual["added"] + visual["changed"]:
        if v["id"] not in {x for p in per_file for x in p["official"]}:
            per_file.append({"path": v.get("react_path", ""), "official": [v["id"]], "ext": [], "hosts": [], "lines": 0})
    official = sorted({i for p in per_file for i in p["official"]})
    ext_ids = sorted({i for p in per_file for i in p["ext"]})
    pe = sorted({glob_of(i) if not i.endswith("*") else i for i in ext_ids})
    po = sorted(set(official))
    cmds = []
    cmds.append("# 1. Prepare the new Web tree once (a private clone, never the shared read-only checkout):")
    cmds.append("git clone --quiet ~/.cache/raft-flutter/raft-source-mirror.git ~/.cache/raft-flutter/raft-source-NEW")
    cmds.append("git -C ~/.cache/raft-flutter/raft-source-NEW checkout --quiet <TO_TAG> && (cd ~/.cache/raft-flutter/raft-source-NEW && pnpm install --frozen-lockfile)")
    if po:
        cmds.append("# 2a. Official cases (React capture is recaptured because the Source commit is part of the cache key):")
        cmds.append("PARITY_RAFT_SOURCE=~/.cache/raft-flutter/raft-source-NEW tool/parity run --cases '" + ",".join(po[:25]) + "'")
    if pe:
        cmds.append("# 2b. Extension cases (add --refresh-react if a cached capture could be stale):")
        cmds.append("PARITY_RAFT_SOURCE=~/.cache/raft-flutter/raft-source-NEW PARITY_EXT_WEB_PORT=4xxx tool/parity-ext/run run --cases '" + ",".join(pe[:25]) + "'")
    cmds.append("# 3. Compare build/parity*/summary.md with the previous run; a drop on a case whose Web component changed means a visual follow-up.")
    return {"per_file": per_file, "official_ids": po, "ext_globs": pe, "ext_ids": len(ext_ids), "commands": cmds,
            "hosts": [h["host"] for h in hosts]}


# ------------------------------------------------------------- decision rows

def i18n_area(prefix: str, second: str, dirs: set[str]) -> str:
    cand = prefix + second[:1].upper() + second[1:]
    if cand in dirs:
        return "components/" + cand
    return ("components/" + prefix) if prefix in dirs else "i18n/" + prefix


def _caps_for_area(r: dict, area: str) -> dict:
    cnt = collections.Counter()
    for c in r["capabilities_touched"]:
        if area in c.get("areas", ()):
            cnt[c["status"]] += 1
    return dict(cnt)


def _cp_summary(items: list[dict]) -> str:
    mapped = [i for i in items if i["cp"]["confidence"] in ("documented", "heuristic")]
    names = []
    for i in mapped[:3]:
        names.append(Path(i["path"]).stem + " -> " + (Path(i["cp"]["files"][0]).name if i["cp"]["files"] else "?"))
    return f"{len(mapped)}/{len(items)} files have a counterpart" + (": " + "; ".join(names) if names else "")


def build_decisions(report: dict) -> list[dict]:
    ui = report["web_ui"]["files"]
    dirs = set(report["i18n"]["component_dirs"])
    rows: list[dict] = []
    feature_of_file: dict[str, dict] = {}
    by_area = collections.defaultdict(list)
    for it in ui:
        by_area[it["area"]].append(it)
    feature_rows, area_rows = [], []
    for area, items in by_area.items():
        leaf = area.split("/")[-1]
        if leaf in WEB_ONLY_AREAS:
            area_rows.append({"kind": "area", "area": area, "title": f"{area} (web-only surface)", "files": items, "mapped": [], "small": items,
                              "removed": [], "feature_files": []})
            continue
        removed = [i for i in items if i["status"] == "D"]
        big_new = [i for i in items if i["status"] == "A" and i["lines"] >= 100 and i["cp"]["confidence"] not in ("documented",)]
        big_unmapped = [i for i in items if i["status"] == "M" and i["lines"] >= 150 and i["cp"]["confidence"] in ("none", "doc-only")]
        feats = big_new + big_unmapped
        rest = [i for i in items if i not in feats and i not in removed]
        mapped = [i for i in rest if i["cp"]["confidence"] in ("documented", "heuristic")]
        area_rows.append({"kind": "area", "area": area, "title": area, "files": rest, "mapped": mapped,
                          "small": [i for i in rest if i not in mapped], "removed": removed, "feature_files": feats})
        for i in feats:
            feature_of_file[i["path"]] = i
        if removed:
            feature_rows.append({"kind": "removed", "area": area, "items": removed})
    # attach contract items to rows
    area_attach = collections.defaultdict(lambda: {"endpoints": [], "removed_endpoints": [], "changed_endpoints": [], "fields": [],
                                                   "i18n_added": 0, "i18n_changed": 0, "visual": [], "flags": []})
    feat_attach = collections.defaultdict(lambda: {"endpoints": [], "i18n": 0})

    def web_path(f):
        return f if f.startswith("packages/") else "packages/web/src/" + f
    for kind, key in (("added", "endpoints"), ("removed", "removed_endpoints"), ("changed_path_expr", "changed_endpoints")):
        for e in report["api"][kind]:
            fp = [web_path(f) for f in e["files"]]
            tgt = next((p for p in fp if p in feature_of_file), None)
            if tgt and kind == "added":
                feat_attach[tgt]["endpoints"].append(e["key"])
            else:
                area_attach[e.get("area") or "api/(unknown)"][key].append(e["key"])
            if kind == "removed" and e["ours_calls"] != "no":
                area_attach[e.get("area") or "api/(unknown)"]["flags"].append("removed endpoint used by the app: " + e["key"])
    for name, ch in report["fields"]["changed"].items():
        if ch.get("relevance") != "wire":
            continue
        fa = classify(ch.get("file", ""))[1] if ch.get("file", "").startswith("packages/web/src/") else "contracts/" + (ch.get("file", "").split("/")[1] if ch.get("file") else "shared")
        area_attach[fa]["fields"].append(name)
        for kind in ("removed", "retyped"):
            for it in ch[kind]:
                if it.get("ours"):
                    area_attach[fa]["flags"].append(f"{kind} field {name}.{it['field']} is read by the app")
    for kind, key in (("added", "i18n_added"), ("changed_en", "i18n_changed")):
        for x in report["i18n"][kind]:
            parts = x["id"].split(".")
            area_attach[i18n_area(parts[0], parts[1] if len(parts) > 2 else "", dirs)][key] += 1
    for kind in ("added", "changed"):
        for v in report["visual"][kind]:
            rp = v.get("react_path", "")
            ar = classify("packages/web/src/" + rp.split("packages/web/src/")[-1].split("#")[0])[1] if "components" in rp else "visual-testing"
            area_attach[ar]["visual"].append(v["id"])
    for ar in list(area_attach):
        if not any(r["area"] == ar for r in area_rows):
            area_rows.append({"kind": "area", "area": ar, "title": ar, "files": [], "mapped": [], "small": [], "removed": [], "feature_files": []})
    # ---- area rows
    for r in area_rows:
        at = area_attach.get(r["area"], area_attach.default_factory())
        mapped_lines = sum(i["lines"] for i in r["mapped"])
        small_lines = sum(i["lines"] for i in r["small"])
        effort = mapped_lines + 40 * len(at["endpoints"]) + 60 * len(at["removed_endpoints"]) + 5 * len(at["fields"]) \
            + 2 * (at["i18n_added"] + at["i18n_changed"])
        what = []
        if r["files"]:
            what.append(f"{len(r['files'])} files, {sum(i['lines'] for i in r['files'])} lines changed ({len(r['mapped'])} mirrored, {len(r['small'])} without counterpart)")
        if at["endpoints"]:
            what.append("+endpoints: " + ", ".join(at["endpoints"][:3]) + (" ..." if len(at["endpoints"]) > 3 else ""))
        if at["removed_endpoints"]:
            what.append("-endpoints: " + ", ".join(at["removed_endpoints"][:3]))
        if at["changed_endpoints"]:
            what.append(f"{len(at['changed_endpoints'])} call expressions changed")
        if at["fields"]:
            what.append("wire types: " + ", ".join(at["fields"][:4]))
        if at["i18n_added"] or at["i18n_changed"]:
            what.append(f"i18n +{at['i18n_added']}/~{at['i18n_changed']}")
        if at["visual"]:
            what.append(f"visual cases: {', '.join(at['visual'][:2])}")
        if r["feature_files"]:
            what.append(f"{len(r['feature_files'])} large new/unmapped files (see feature rows)")
        if not what:
            continue
        if r["removed"]:
            what.append(f"{len(r['removed'])} files removed (see removal rows)")
        caps = _caps_for_area(report, r["area"])
        state = _cp_summary(r["files"]) if r["files"] else "no Web file in this area changed; contract/copy only"
        if caps:
            state += "; capabilities touched: " + ", ".join(f"{v} {k}" for k, v in sorted(caps.items()))
        leaf = r["area"].split("/")[-1]
        if leaf in WEB_ONLY_AREAS:
            action, reason = "skip", "web-only surface (analytics / devtools / embed / feedback SDK / PWA); nothing to mirror"
        elif not r["mapped"] and not (at["endpoints"] or at["removed_endpoints"] or at["fields"] or at["i18n_added"] or at["i18n_changed"] or at["visual"]):
            if small_lines <= 150 and not r["feature_files"] and not r["removed"]:
                action, reason = "skip", "small changes, no counterpart in the app"
            else:
                action, reason = "skip", "nothing mirrored changed here; large new/unmapped files are separate feature rows"
        elif at["flags"]:
            action, reason = "follow", "; ".join(at["flags"][:2])
        elif effort <= 120 and (r["mapped"] or at["i18n_added"]):
            action, reason = "follow", "small change to mirrored code and strings"
        elif not r["mapped"]:
            action, reason = "partial", "contract/copy changes only; adopt together with the UI that uses them"
        else:
            action, reason = "partial", "port contract, copy and bug fixes of the mirrored files; review layout/behavior changes"
        risk = "high" if at["flags"] else ("medium" if mapped_lines > 300 or at["endpoints"] else "low")
        rows.append({"kind": "area", "title": r["title"], "area": r["area"], "what": "; ".join(what), "state": state, "action": action,
                     "reason": reason, "size": sizing(effort), "risk": risk,
                     "top": [f"{Path(i['path']).name} ({i['lines']})" for i in sorted(r["mapped"], key=lambda x: -x["lines"])[:3]],
                     "effort": effort, "ids": [i["id"] for i in r["files"]], "flags": at["flags"]})
    # ---- feature rows (new / unmapped large files)
    i18n_text = report["i18n"].get("_en_b", {})
    for path, it in feature_of_file.items():
        at = feat_attach.get(path, {"endpoints": []})
        hints = [i18n_text[x] for x in it["summary"]["i18n_ids_added"] if x in i18n_text][:3]
        title = Path(path).stem + (" (new)" if it["status"] == "A" else " (changed, no counterpart)")
        what = f"{it['lines']} lines" + (f"; calls {', '.join(at['endpoints'])}" if at["endpoints"] else "") + ("; copy: " + " / ".join(h[:60] for h in hints) if hints else "")
        if it["cp"]["confidence"] == "heuristic":
            state = "similar name in app: " + ", ".join(Path(f).name for f in it["cp"]["files"][:2])
        elif it["cp"]["confidence"] == "doc-only":
            state = "only cited in docs: " + ", ".join(it["cp"]["docs"][:2])
        else:
            state = "no counterpart found"
        sibling = [x for x in by_area[it["area"]] if x["status"] == "M" and x["cp"]["confidence"] in ("documented", "heuristic")]
        if sibling and it["status"] == "A":
            state += "; area has mirrored files that changed (" + Path(sibling[0]["path"]).stem + ")"
        action = "discuss"
        reason = ("new Web feature/extracted component; decide whether the app needs it" if it["status"] == "A"
                  else "large change to a Web file the app does not mirror; confirm whether the feature exists in the app")
        if at["endpoints"]:
            reason += "; brings new API calls"
        rows.append({"kind": "feature", "title": title, "area": it["area"], "what": what, "state": state, "action": action, "reason": reason,
                     "size": sizing(it["lines"] + 40 * len(at["endpoints"])), "risk": "medium" if at["endpoints"] else "low",
                     "top": [], "effort": it["lines"], "ids": [it["id"]], "flags": []})
    for fr in feature_rows:
        items = fr["items"]
        mapped = [i for i in items if i["cp"]["confidence"] in ("documented", "heuristic", "doc-only")]
        lines = sum(i["lines"] for i in items)
        ours = sorted({Path(f).name for i in items for f in i["cp"]["files"]})
        rows.append({"kind": "removal", "title": f"{fr['area']}: {len(items)} Web files removed", "area": fr["area"],
                     "what": ", ".join(Path(i["path"]).stem for i in items[:6]) + (" ..." if len(items) > 6 else "") + f" ({lines} lines deleted)",
                     "state": ("our counterpart: " + ", ".join(ours[:4])) if ours else "no counterpart found",
                     "action": "discuss" if mapped else "skip",
                     "reason": "Web removed what the app mirrors; decide whether to remove/redirect ours too" if mapped else "removed upstream; the app never had it",
                     "size": "S" if not mapped else sizing(lines // 3), "risk": "medium" if mapped else "low", "top": [], "effort": lines,
                     "ids": [i["id"] for i in items], "flags": []})
    # ---- behaviour rows
    for bh in report["behaviour"]["files"][:25]:
        if not bh["flutter"] and bh["score"] < 8:
            continue
        tagtxt = ", ".join(f"{t} x{n}" for t, n in sorted(bh["tags"].items(), key=lambda kv: -kv[1])[:4])
        what = f"{bh['file']}: {tagtxt}" + (f"; functions {', '.join(bh['functions'][:3])}" if bh["functions"] else "")
        ep = ", ".join(bh["endpoints"][:3]) + ("" if bh["endpoints"] and not bh["endpoints_coarse"] else " (coarse)")
        rows.append({"kind": "behaviour", "title": f"server behaviour: {bh['file']}", "area": "server/" + bh["file"].split("/")[0], "what": what + ("; endpoints " + ep if bh["endpoints"] else ""),
                     "state": ("app relies on: " + "; ".join(bh["flutter"][:3])) if bh["flutter"] else "no recorded Flutter feature found for these endpoints",
                     "action": "partial" if bh["flutter"] else "skip",
                     "reason": "same API shape, changed server logic: verify the listed Flutter features against the new server (fixtures + live), adapt if they diverge" if bh["flutter"]
                     else "server-only logic; verify only if a feature is reported broken",
                     "size": "S", "risk": "medium" if any(t in bh["tags"] for t in ("permission", "sorting", "filtering")) else "low",
                     "top": [], "effort": bh["score"], "ids": [], "flags": []})
    for name, d in report["behavior_drift"].get("domains", {}).items():
        n = len(d["changed"])
        if not n:
            continue
        cnt = collections.Counter(c["drift"] for c in d["changed"])
        aud = collections.Counter(c["audit"] for c in d["changed"])
        rows.append({"kind": "drift", "title": f"behaviour checklist drift: {name}", "area": "behavior-parity/" + name,
                     "what": f"{n} of {d['total']} audited Web behaviours changed upstream (" + ", ".join(f"{k} {v}" for k, v in cnt.items())
                     + (f"); new uncovered events: {', '.join(d['uncovered_events'][:4])}" if d["uncovered_events"] else ")"),
                     "state": "checklist audit of those rows: " + ", ".join(f"{k} {v}" for k, v in aud.most_common()) + f" (docs/behavior-parity/{name}.md)",
                     "action": "partial", "reason": "re-audit the CHANGED/REMOVED rows against the new Web source, fix Flutter where the logic diverges, "
                     "then refresh fingerprints; the checklist records the result",
                     "size": "S" if n < 10 else ("M" if n < 30 else "L"), "risk": "medium", "top": [], "effort": n * 20, "ids": [], "flags": []})
    order = {"area": 0, "feature": 1, "removal": 2, "drift": 3, "behaviour": 4}
    prefix = {"area": "A", "feature": "F", "removal": "R", "drift": "G", "behaviour": "B"}
    rows.sort(key=lambda x: (order[x["kind"]], -x["effort"]))
    counters = collections.Counter()
    for x in rows:
        counters[x["kind"]] += 1
        x["id"] = f"{prefix[x['kind']]}{counters[x['kind']]:02d}"
    return rows



def generate_report(mirror: Path, repo: Path, a: str, b: str, work: Path, keep_trees: bool = False) -> dict:
    info_a, info_b = tag_info(mirror, a), tag_info(mirror, b)
    ix = build_our_index(repo)
    files = changed_files(mirror, a, b)
    cat_counts = collections.Counter(f.category for f in files)
    cat_lines = collections.Counter()
    for f in files:
        cat_lines[f.category] += f.lines
    by_path = {f.path: f for f in files}
    hunks = hunks_by_file(mirror, a, b)
    commits = []
    for line in _git(mirror, "log", "--format=%H%x1f%s%x1f%b%x1e", f"{a}..{b}", check=False).split("\x1e"):
        parts = line.strip().split("\x1f")
        if len(parts) >= 2 and parts[0]:
            commits.append({"commit": parts[0], "subject": parts[1], "body": parts[2].strip() if len(parts) > 2 else ""})
    # Web UI
    ui_items = []
    for f in files:
        if f.category != "web_ui":
            continue
        cpt = find_counterpart(ix, f.path)
        summ = summarize_hunk_lines(hunks.get(f.path, []))
        action, reason, size, risk = propose_file_action(f, cpt, summ)
        ui_items.append({"path": f.path, "renamed_from": f.old_path, "status": f.status, "added": f.added, "removed": f.removed, "lines": f.lines,
                         "area": f.area, "cp": cpt, "summary": summ, "action": action, "reason": reason, "size": size,
                         "risk": risk})
    ui_items.sort(key=lambda x: (-x["lines"], x["path"]))
    for i, it in enumerate(ui_items, 1):
        it["id"] = f"UI-{i:03d}"
    web_changed = {f.path: f for f in files if f.category == "web_ui"}
    ta, tb = Path(work) / a, Path(work) / b
    extract_tree(mirror, a, ta)
    extract_tree(mirror, b, tb, EXTRACT_PATHS_NEW)
    try:
        api = collect_api(ta, tb, ix, by_path)
        drift = collect_behavior_drift(repo, tb)
    finally:
        if not keep_trees:
            shutil.rmtree(ta, ignore_errors=True)
            shutil.rmtree(tb, ignore_errors=True)
    for pre, kind in (("API+", "added"), ("API-", "removed"), ("API~", "changed_path_expr")):
        for i, e in enumerate(api[kind], 1):
            e["id"] = f"{pre}{i:02d}"
            e["action"], e["reason"], e["size"], e["risk"] = propose_api_action(kind, e)
    shapes = collect_shapes(mirror, a, b, files, ix)
    for i, name in enumerate(sorted(shapes["changed"]), 1):
        shapes["changed"][name]["id"] = f"FLD-{i:02d}"
        shapes["changed"][name]["name"] = name
        shapes["changed"][name]["action"], shapes["changed"][name]["reason"] = propose_field_action(shapes["changed"][name])
    shapes["changed"] = dict(shapes["changed"])
    i18n = collect_i18n(mirror, a, b, ix)
    comps = {p.split("/")[4] for p in list_tree(mirror, b, "packages/web/src/components") if p.count("/") >= 5}
    i18n["component_dirs"] = sorted(comps)
    visual = collect_visual(mirror, a, b, ix, by_path)
    styles = collect_styles(mirror, a, b, files)
    report = {
        "schema": 1,
        "generated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "from": info_a, "to": info_b,
        "diff": {"files": len(files),
                 "added": sum(1 for f in files if f.status == "A"), "deleted": sum(1 for f in files if f.status == "D"),
                 "modified": sum(1 for f in files if f.status == "M"),
                 "by_category": {c: {"files": cat_counts[c], "lines": cat_lines[c]} for c in CATEGORIES if cat_counts[c]}},
        "web_ui": {"files": ui_items},
        "api": api,
        "server_routes": collect_server_routes(mirror, a, b, files),
        "socket_events": collect_socket(mirror, a, b, hunks, ix),
        "capabilities_touched": collect_capabilities(ix, web_changed),
        "fields": shapes,
        "wire_candidates": collect_wire_candidates(hunks, files, ix),
        "i18n": i18n,
        "visual": visual,
        "styles": styles,
        "docs": collect_docs(mirror, a, b, files, commits),
        "other_changes": {c: [f.path for f in files if f.category == c][:60]
                          for c in ("server_other", "runtime_other", "other") if cat_counts[c]},
    }
    shared_b = {}
    try:
        shared_b = {c["id"]: c for c in json.loads(show(mirror, b, "packages/visual-testing/shared/sharedCases.json") or "{}").get("cases", [])}
    except ValueError:
        pass
    report["behaviour"] = collect_behaviour(mirror, a, b, files, ix)
    report["behavior_drift"] = drift
    report["visual_layer"] = collect_visual_layer(repo, ix, ui_items, visual, shared_b)
    report["decisions"] = build_decisions(report)
    report["i18n"].pop("_en_b", None)
    return report


def propose_api_action(kind: str, e: dict) -> tuple[str, str, str, str]:
    if kind == "added":
        if e["recorded"]:
            return "skip", f"already recorded in capability-parity.json ({e['recorded']})", "S", "low"
        sib = [x for x in e.get("siblings", []) if x.endswith("[covered]") or x.endswith("[partial]")]
        miss = [x for x in e.get("siblings", []) if x.endswith("[missing]")]
        if e["key"].startswith("SOCKET"):
            return "discuss", "new client socket emit", "S", "medium"
        if sib and not miss:
            return "partial", "extends a family the app covers (" + sib[0].split(" [")[0] + "); adopt with the UI that calls it", "S", "low"
        if miss:
            return "discuss", "family the app lacks (" + miss[0].split(" [")[0] + ")", "M", "medium"
        return "discuss", "new endpoint family, no sibling recorded", "M", "medium"
    if kind == "removed":
        if e["ours_calls"] != "no":
            return "follow", "the app calls this and Web stopped; check the server still serves it, migrate if replaced", "S", "high"
        return "skip", "app does not call it; mark the capability entry stale", "S", "low"
    return "partial", "path expression/query of an existing call changed; compare request shape", "S", "medium"


def propose_field_action(ch: dict) -> tuple[str, str]:
    used = [f"{k}.{i['field']}" for k in ("removed", "retyped") for i in ch[k] if i.get("ours")]
    if used:
        return "follow", "removed/retyped fields the app reads: " + ", ".join(used[:4])
    if any(i.get("ours") for i in ch["added"]):
        return "partial", "new field with a name the app already reads elsewhere; check semantics"
    if ch["removed"] or ch["retyped"]:
        return "skip", "the app does not read the removed/retyped fields"
    return "skip", "new fields; adopt with the UI that shows them"


# ------------------------------------------------------------------ markdown

def _esc(s) -> str:
    return str(s).replace("|", "\\|").replace("\n", " ")


def _tbl(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        out.append("| " + " | ".join(_esc(c) for c in r) + " |")
    return "\n".join(out)


def _cp_text(cp_: dict) -> str:
    if cp_["confidence"] == "none":
        return "(none known)"
    files = ", ".join(Path(f).name for f in cp_["files"][:2])
    return f"{files or 'docs only'} [{cp_['confidence']}]"


def highlights(r: dict) -> list[str]:
    """The few things Kevin should read first."""
    out = []
    dec = r["decisions"]
    for x in dec:
        if x["kind"] == "removal" and x["action"] == "discuss":
            out.append(f"**{x['id']} Web removed code the app mirrors**: {x['title']} ({x['what']}). Our side: {x['state']}.")
    for x in dec:
        if x["flags"]:
            out.append(f"**{x['id']} {x['area']}** has a breaking signal: " + "; ".join(x["flags"][:2]) + ".")
    feats = [x for x in dec if x["kind"] == "feature"]
    feats.sort(key=lambda x: -x["effort"])
    if feats:
        out.append("Largest new/unmapped Web features: " + "; ".join(f"{x['id']} {x['title']} ({x['effort']} lines)" for x in feats[:5]) + ".")
    ap = r["api"]
    if ap["added"] or ap["removed"]:
        out.append(f"API: +{len(ap['added'])} / -{len(ap['removed'])} Web calls (" + ", ".join(e["key"] for e in ap["added"][:4]) + ("..." if len(ap["added"]) > 4 else "") + ").")
    sv = r["styles"]["dependency_changes"]
    if "raft-ui" in sv:
        out.append(f"raft-ui (token source for tool/gen-tokens) moved {sv['raft-ui'][0]} -> {sv['raft-ui'][1]}: the app's generated tokens and `tool/design-source` are pinned to the old one.")
    I = r["i18n"]
    out.append(f"Strings: +{len(I['added'])} ids, {len(I['changed_en'])} English rewrites, {len(I['changed_zh'])} zh-only rewrites ({sum(1 for x in I['changed_zh'] if x['drift_in_ours'])} where our zh differs); full sync list in the appendix.")
    bh = [x for x in r["behaviour"]["files"] if x["flutter"]]
    if bh:
        out.append(f"Server behaviour changes that Flutter features rely on: {len(bh)} files (section 服务端行为变化).")
    return out


def render_markdown(r: dict, limit_ui: int = 80) -> str:
    a, b = r["from"], r["to"]
    d = r["diff"]
    L = []
    L.append(f"# Upstream sync report: {a['tag']} -> {b['tag']}")
    L.append("")
    L.append(f"Generated {r['generated']} by `tool/upstream_sync.py`. Baseline `{a['tag']}` ({a['commit'][:9]}, {a['date'][:10]}); "
             f"target `{b['tag']}` ({b['commit'][:9]}, {b['date'][:10]}). Process: docs/upstream-sync.md. "
             "Actions below are heuristic proposals by Cindy; Kevin decides, then `record-decision` advances the pin.")
    L.append("")
    L.append("## 摘要 (Summary)")
    L.append("")
    L.append(f"- {d['files']} files changed ({d['added']} added, {d['modified']} modified, {d['deleted']} deleted).")
    ui = r["web_ui"]["files"]
    api = r["api"]
    fch = r["fields"]["changed"]
    I = r["i18n"]
    V = r["visual"]
    L.append(f"- Web UI files: {len(ui)} ({sum(1 for x in ui if x['cp']['confidence'] in ('documented', 'heuristic'))} with a known counterpart, "
             f"{sum(1 for x in ui if x['cp']['confidence'] not in ('documented', 'heuristic'))} unmapped).")
    L.append(f"- API (Web client calls): +{len(api['added'])} added, -{len(api['removed'])} removed, ~{len(api['changed_path_expr'])} path expression changed "
             f"({api['totals']['a']} -> {api['totals']['b']} keys). Socket events: +{len(r['socket_events']['added'])} / -{len(r['socket_events']['removed'])}.")
    L.append(f"- Shared/store types: {len(fch)} changed, {len(r['fields']['added_types'])} added, {len(r['fields']['removed_types'])} removed.")
    L.append(f"- i18n: +{len(I['added'])} ids, -{len(I['removed'])} ids, {len(I['changed_en'])} en text changes, {len(I['changed_zh'])} zh-only changes "
             f"({I['totals']['en_a']} -> {I['totals']['en_b']} ids).")
    L.append(f"- Visual cases: +{len(V['added'])} added, -{len(V['removed'])} removed, ~{len(V['changed'])} changed ({V['totals']['a']} -> {V['totals']['b']}).")
    S = r["styles"]
    L.append(f"- Styles: {len(S['css'])} CSS files changed; dependency changes: "
             + (", ".join(f"{k} {v[0]} -> {v[1]}" for k, v in S["dependency_changes"].items() if "raft" in k or k in ("tailwindcss",)) or "none of note") + ".")
    L.append("")
    L.append(_tbl(["Category", "Files", "Changed lines"],
                  [[CATEGORY_TITLES[c], v["files"], v["lines"]] for c, v in d["by_category"].items()]))
    L.append("")
    dec = r["decisions"]
    acts = collections.Counter(x["action"] for x in dec)
    L.append(f"Decision rows below: {len(dec)} ("
             + ", ".join(f"{acts[k]} {k}" for k in DECISIONS if acts[k]) + ").")
    L.append("")
    # ---- highlights
    L.append("## 重点 (Highlights)")
    L.append("")
    for h in highlights(r):
        L.append("- " + h)
    L.append("")
    # ---- decision table
    L.append("## 决策表 (Decision table)")
    L.append("")
    L.append("Row kinds: A = feature area (changes to files the app mirrors, plus the API / type / string / visual items that belong to that area); "
             "F = large new or unmapped Web file (a candidate feature); R = Web files removed that the app may still mirror; "
             "G = drift in the audited behaviour checklists (docs/behavior-parity); "
             "B = server behaviour change (same API shape, different logic). Everything in the sections below hangs off these ids. "
             "Answer per row: follow (adopt all), partial (adopt the listed part), skip, discuss. "
             "Size is rough port effort (S <= 150 lines changed, M <= 800, L above; endpoints and strings add weight); "
             "risk is high when a removed/retyped thing is read by the app.")
    L.append("")
    rows = []
    for x in dec:
        top = ("; biggest: " + ", ".join(x["top"])) if x["top"] else ""
        rows.append([x["id"], x["title"], x["what"] + top, x["state"], x["action"], x["reason"], x["size"], x["risk"], ""])
    L.append(_tbl(["ID", "Item", "What changed", "Our current state", "Recommendation", "Reason", "Size", "Risk", "Kevin"], rows))
    L.append("")
    # ---- release notes
    L.append("## 发布说明 (Upstream release notes)")
    L.append("")
    docs = r["docs"]
    for c in docs["commits"]:
        L.append(f"- Release commit {c['commit'][:9]}: {c['subject']}" + (f" ({c['body'].splitlines()[0]})" if c["body"] else ""))
    if not docs["changelog"]:
        L.append("- No product changelog in the tree: the Web app's release notes are served from the server (`releaseNotes` routes), "
                 "not checked in. Source snapshots carry no per-change notes.")
    for ch in docs["changelog"]:
        L.append(f"\n### {ch['file']} (new entries)\n")
        L.append("```text\n" + ch["added_text"][:3000] + ("\n..." if len(ch["added_text"]) > 3000 else "") + "\n```")
    if docs["manual"]:
        L.append("")
        L.append("Agent manual pages changed (`manual/agent-knowledge`, useful as human-readable behavior notes): "
                 + ", ".join(f"{Path(m['file']).name} ({m['status']}{m['lines']})" for m in docs["manual"]))
    L.append("")
    # ---- API
    L.append("## API 与能力对照 (API and capability parity)")
    L.append("")
    L.append(f"Extractor: `tool/capability_parity.py` on both trees (`packages/web/src`); recorded status from docs/capability-parity.json. "
             f"Keys {api['totals']['a']} -> {api['totals']['b']}. `ours` = the app already has a Dart literal for this path (or a covered capability).")
    L.append("")
    for title, kind in (("Added Web calls", "added"), ("Removed Web calls", "removed"), ("Changed path expression", "changed_path_expr")):
        items = api[kind]
        L.append(f"### {title} ({len(items)})")
        L.append("")
        if items:
            L.append(_tbl(["ID", "Call", "Web file", "Area", "Recorded", "Ours", "Proposed", "Why", "Size", "Risk"],
                          [[e["id"], e["key"], ", ".join(Path(f).name for f in e["files"][:2]), e.get("area", ""), e["recorded"] or "unrecorded",
                            e["ours_calls"], e["action"], e["reason"], e["size"], e["risk"]] for e in items]))
        else:
            L.append("None.")
        L.append("")
    if r["server_routes"]:
        L.append("### Server route definitions added / removed")
        L.append("")
        L.append("Route registrations in `packages/server/src/routes` (path relative to the router mount; not all are called by the Web client).")
        L.append("")
        L.append(_tbl(["Route file", "Added", "Removed", "Lines"],
                      [[x["file"], "; ".join(x["added"]) or "-", "; ".join(x["removed"]) or "-", x["lines"]] for x in r["server_routes"]]))
        L.append("")
    se = r["socket_events"]
    L.append("### Socket events (Web socket modules)")
    L.append("")
    L.append("Added: " + (", ".join(f"`{e['event']}`" + (" (ours: yes)" if e["ours"] else "") for e in se["added"]) or "none"))
    L.append("")
    L.append("Removed: " + (", ".join(f"`{e['event']}`" + (" (ours: yes)" if e["ours"] else "") for e in se["removed"]) or "none"))
    L.append("")
    ct = r["capabilities_touched"]
    L.append(f"### Recorded capabilities whose Web entry file changed ({len(ct)})")
    L.append("")
    L.append("From docs/capability-parity.json `ui:` and endpoint entries; the Web file named in `webEntry` has changed lines. "
             "Re-verify each (covered entries may now be partial).")
    L.append("")
    if ct:
        L.append(_tbl(["Capability", "Status", "What", "Web files", "Lines"],
                      [[c["id"], c["status"], c["capability"], ", ".join(Path(f).name for f in c["files"]), c["lines"]] for c in ct[:60]]))
        if len(ct) > 60:
            L.append(f"\n(+{len(ct) - 60} more in report.json)")
    L.append("")
    # ---- behaviour checklist drift
    BD = r["behavior_drift"]
    L.append("## 逻辑漂移 (Behaviour-parity checklist drift)")
    L.append("")
    if not BD.get("available"):
        L.append("`tool/behavior-parity` was not available or failed: " + BD.get("error", "no docs/behavior-parity"))
    else:
        L.append("Output of `tool/behavior-parity --web <new tree>`: each row of docs/behavior-parity/*.md is anchored to a Web symbol or socket event by a source fingerprint. "
                 "CHANGED/MOVED/REMOVED rows must be re-audited; 'audit' is the checklist's current verdict for the Flutter app. Refresh fingerprints only after the re-audit "
                 "(`tool/behavior-parity --web <tree> --update-fingerprints`).")
        L.append("")
        for name, dm in BD["domains"].items():
            L.append(f"### {name} ({len(dm['changed'])} of {dm['total']} anchors drifted; baseline {dm['baseline'].get('tag', '?')})")
            L.append("")
            if dm["changed"]:
                L.append(_tbl(["Row", "Anchor", "Drift", "Where", "Checklist audit", "Status"],
                              [[c["id"], c["anchor"], c["drift"], c["detail"] or c["newPath"], c["audit"], c["status"]] for c in dm["changed"]]))
                L.append("")
            if dm["uncovered_events"]:
                L.append("Socket events in scope that no row anchors: " + ", ".join(f"`{e}`" for e in dm["uncovered_events"]))
                L.append("")
    # ---- behaviour
    BH = r["behaviour"]
    L.append("## 服务端行为变化 (Behaviour changes, same API shape: needs verification)")
    L.append("")
    L.append(f"Heuristic scan of {BH['scanned']} changed non-test files in `packages/server/src/{{routes,services,middleware,lib}}` and `app.ts`: "
             "changed code lines that touch sorting, filtering, permission checks, limits/defaults, rate limits or validation/error messages. "
             "Endpoints come from the changed handler (route files) or the routes whose handler uses the changed function (services; `coarse` = could not narrow). "
             "`Flutter relies on` comes from docs/capability-parity.json and Dart path literals. Needs a human read of the sample lines; it proves nothing by itself.")
    L.append("")
    bh_rows = [[x["file"], x["score"], ", ".join(f"{t} x{n}" for t, n in sorted(x["tags"].items(), key=lambda kv: -kv[1])[:4]),
                ", ".join(x["functions"][:3]), "; ".join(x["endpoints"][:3]) + (" (coarse)" if x["endpoints_coarse"] and x["endpoints"] else "") or "-",
                "; ".join(x["flutter"][:2]) or "-"] for x in BH["files"][:40]]
    if bh_rows:
        L.append(_tbl(["Server file", "Score", "Kinds", "Functions", "Endpoints", "Flutter relies on"], bh_rows))
        L.append("")
        L.append("Sample changed lines (top 12 by score):")
        L.append("")
        for x in BH["files"][:12]:
            L.append(f"- `{x['file']}`")
            for t, smp in x["samples"].items():
                for sm in smp:
                    L.append(f"  - {t}: `{sm.replace('`', chr(39))}`")
        if len(BH["files"]) > 40:
            L.append(f"\n({len(BH['files']) - 40} more files in report.json)")
    else:
        L.append("None found.")
    L.append("")
    # ---- fields
    F = r["fields"]
    L.append("## 字段对照 (Field parity: shared types, stores, zod schemas)")
    L.append("")
    L.append("Parsed from `packages/shared/src`, web `store/api/utils/hooks` (interfaces, object type aliases, zod objects). `ours` lists Dart/fixture files that mention the field name as a quoted key "
             "(generic names like `id`/`name` are never flagged). Compare with docs/field-parity.md and the fixtures under apps/raft_flutter/test/fixtures.")
    L.append("")
    rows = []
    other_rel = collections.defaultdict(list)
    for name, ch in F["changed"].items():
        if ch.get("relevance", "wire") != "wire":
            other_rel[ch["relevance"]].append(name)
            continue
        def fmt(items, sign):
            return ", ".join(f"{sign}{i['field']}" + ("*" if i.get("ours") else "") for i in items[:8]) + (" ..." if len(items) > 8 else "")
        rows.append([ch["id"], name, ch.get("file", "").replace("packages/", ""), fmt(ch["added"], "+"), fmt(ch["removed"], "-"),
                     fmt(ch["retyped"], "~"), ch["action"], ch["reason"]])
    if rows:
        L.append("`*` = a field name the app reads or has in fixtures.")
        L.append("")
        L.append(_tbl(["ID", "Type", "File", "Added", "Removed", "Retyped", "Proposed", "Why"], rows))
    else:
        L.append("No field changes.")
    L.append("")
    for rel, names in other_rel.items():
        L.append(f"Not wire-facing ({rel}; listed for completeness, no action): " + ", ".join(f"`{n}`" for n in names))
        L.append("")
    if F["added_types"] or F["removed_types"]:
        L.append("New types: " + (", ".join(f"`{t['name']}`" for t in F["added_types"][:60]) or "none") + (" ..." if len(F["added_types"]) > 60 else ""))
        L.append("")
        L.append("Removed types: " + (", ".join(f"`{t['name']}`" for t in F["removed_types"][:40]) or "none"))
        L.append("")
    if r["wire_candidates"]:
        L.append("### Server response key candidates (heuristic)")
        L.append("")
        L.append("Property keys added/removed in server route diffs (`key:` lines, so partly request validation, partly response builders). "
                 "Verify against the code before acting; `*` = the app mentions the key.")
        L.append("")
        L.append(_tbl(["Route file", "Added keys", "Removed keys"],
                      [[w["file"], ", ".join(k + ("*" if k in w["ours_added"] else "") for k in w["added"][:12]),
                        ", ".join(k + ("*" if k in w["ours_removed"] else "") for k in w["removed"][:12])] for w in r["wire_candidates"][:80]]))
        L.append("")
    # ---- UI
    L.append("## 界面对照 (Web UI changes and our counterparts)")
    L.append("")
    L.append("Counterpart confidence: documented = cited by a Dart source comment or the capability map; heuristic = same/similar file name; none = unmapped. "
             f"Showing files with >= 20 changed lines, new/deleted files, or a documented counterpart (max {limit_ui}); the rest are in report.json.")
    L.append("")
    shown = [x for x in ui if x["lines"] >= 20 or x["status"] in "AD" or x["cp"]["confidence"] == "documented"][:limit_ui]
    rows = [[x["id"], x["path"].split("packages/web/src/")[-1], x["status"], f"+{x['added']}/-{x['removed']}", _cp_text(x["cp"]),
             short_summary(x["summary"]), x["action"], x["reason"], x["size"], x["risk"]] for x in shown]
    L.append(_tbl(["ID", "Web file", "St", "Lines", "Our counterpart", "Notable changes", "Proposed", "Why", "Size", "Risk"], rows))
    L.append("")
    L.append(f"{len(ui) - len(shown)} further small/unmapped UI files omitted from this table." if len(ui) > len(shown) else "")
    L.append("")
    unmapped_big = [x for x in ui if x["cp"]["confidence"] in ("none", "doc-only") and x["lines"] >= 80]
    L.append(f"### Unmapped Web files with >= 80 changed lines ({len(unmapped_big)})")
    L.append("")
    L.append("These have no counterpart we can find. Either the app lacks the feature (a gap to discuss) or the mapping is missing "
             "(add a `// Source: Foo.tsx` comment or a capability entry so the next run finds it).")
    L.append("")
    L.append(", ".join(f"`{x['path'].split('packages/web/src/')[-1]}` ({x['lines']})" for x in unmapped_big[:60]) or "none")
    L.append("")
    # ---- i18n
    L.append("## 文案对照 (i18n: en / zh-cn)")
    L.append("")
    L.append(f"Catalogs `packages/web/src/i18n/messages/{{en,zh-cn}}.ts`. The app's zh catalog (`packages/raft_ui/lib/src/l10n/zh_*.dart`) is keyed by the English text "
             f"and was written by hand from the pinned Web catalogs (there is no generator; `tool/gen_l10n_index.py` only merges the files). "
             f"`ours` = that English text already exists in our catalog.")
    L.append("")
    L.append(f"- Added ids: {len(I['added'])} (of which our catalog already has the same English text: {sum(1 for x in I['added'] if x['ours_has_text'])}; no zh-cn value yet: {len(I['zh_missing_for_added'])}).")
    L.append(f"- Removed ids: {len(I['removed'])} (their old English text is in our catalog: {sum(1 for x in I['removed'] if x['ours_had_old'])}).")
    L.append(f"- Changed English text: {len(I['changed_en'])} (old text in our catalog: {sum(1 for x in I['changed_en'] if x['ours_had_old'])}).")
    L.append(f"- Changed zh-cn only: {len(I['changed_zh'])} (our zh differs from the new Web zh: {sum(1 for x in I['changed_zh'] if x['drift_in_ours'])}).")
    L.append("")
    by_prefix = collections.Counter(x["prefix"] for x in I["added"])
    L.append("Added ids by namespace: " + ", ".join(f"{k} {v}" for k, v in by_prefix.most_common(25)))
    L.append("")
    if I["changed_en"]:
        L.append("### Changed English text (we may hold the old string)")
        L.append("")
        L.append(_tbl(["Id", "Old en", "New en", "New zh-cn", "Ours had old"],
                      [[x["id"], x["old_en"], x["en"], x["zh"], "yes" if x["ours_had_old"] else "no"] for x in I["changed_en"][:80]]))
        L.append("")
    if I["changed_zh"]:
        L.append("### Changed zh-cn wording (English unchanged)")
        L.append("")
        L.append(_tbl(["Id", "English", "Old zh", "New zh", "Ours zh"],
                      [[x["id"], x["en"], x["old_zh"], x["zh"], x["ours_zh"] or "(not in ours)"] for x in I["changed_zh"][:80]]))
        L.append("")
    if I["removed"]:
        L.append("### Removed ids with text we still carry")
        L.append("")
        L.append(", ".join(f"`{x['id']}`" for x in I["removed"] if x["ours_had_old"])[:3000] or "none")
        L.append("")
    # ---- visual
    L.append("## 视觉用例 (Visual-testing cases)")
    L.append("")
    L.append("From `packages/visual-testing/shared/sharedCases.json`. `ours` = a file under apps/raft_flutter/test/parity or tool/parity-ext that names the case id. "
             "`pending` = upstream has no baseline yet. Host files: " + (", ".join(f"{p.split('/')[-1]} (+{x}/-{y})" for p, x, y in V["host_files"]) or "none") + ".")
    L.append("")
    for title, kind in (("Added", "added"), ("Removed", "removed"), ("Changed", "changed")):
        L.append(f"### {title} ({len(V[kind])})")
        L.append("")
        if V[kind]:
            L.append(_tbl(["Case id", "Title", "Surface", "Baseline", "Changed keys", "React path", "Ours"],
                          [[x["id"], x["title"], x["surface"], x["baselineStatus"] or ("skipped" if x["skipped"] else ""), ", ".join(x.get("changed_keys", [])),
                            x["react_path"].split("/")[-1], x["ours"] or "(no case)"] for x in V[kind]]))
        else:
            L.append("None.")
        L.append("")
    VL = r["visual_layer"]
    L.append("### Parity cases affected by changed Web components, and how to re-run them")
    L.append("")
    L.append(f"Mapping: official cases via `reactPathHint` in sharedCases.json; extension cases via the React hosts in tool/parity-ext/host "
             f"({len(VL['hosts'])} hosts) that render the changed component, with ids from the matching `build-*.py`. "
             f"{len(VL['official_ids'])} official ids and {VL['ext_ids']} extension ids ({len(VL['ext_globs'])} globs) are affected.")
    L.append("")
    if VL["per_file"]:
        L.append(_tbl(["Changed Web file", "Lines", "Official cases", "Extension cases (hosts)"],
                      [[Path(x["path"]).name, x["lines"], ", ".join(x["official"][:4]) + (" ..." if len(x["official"]) > 4 else ""),
                        ", ".join(sorted({glob_of(i) if not i.endswith("*") else i for i in x["ext"]})[:5]) + (" (" + ", ".join(x["hosts"][:2]) + ")" if x["hosts"] else "")]
                       for x in sorted(VL["per_file"], key=lambda z: -z["lines"])[:50]]))
        L.append("")
    L.append("Re-run against the new Web tree (needs a clone with `pnpm install`; the harness reads the Source commit from `git rev-parse HEAD`, "
             "so never point it at the shared read-only checkout):")
    L.append("")
    L.append("```bash\n" + "\n".join(VL["commands"]).replace("<TO_TAG>", r["to"]["tag"]) + "\n```")
    if r.get("visual_run"):
        L.append("")
        L.append(r["visual_run"])
    L.append("")
    # ---- styles
    L.append("## 样式与设计系统 (Styles, tokens, design system)")
    L.append("")
    if S["dependency_changes"]:
        L.append("Web package dependency changes (raft-ui is the token/foundation source for tool/gen-tokens; the app pins raft-ui 0.5.52 in tool/design-source):")
        L.append("")
        L.append(_tbl(["Package", "From", "To"], [[k, v[0], v[1]] for k, v in S["dependency_changes"].items()]))
        L.append("")
    for p, v in S["css"].items():
        L.append(f"- `{p}`: {v['lines']} lines changed; custom properties +{len(v['added'])} / -{len(v['removed'])} / ~{len(v['changed'])}"
                 + (" (changed: " + ", ".join(v["changed"][:12]) + ")" if v["changed"] else ""))
    if S["theme_files"]:
        L.append("- Theme/other style files: " + ", ".join(f"`{Path(p).name}`" for p in S["theme_files"]))
    L.append("")
    # ---- other
    L.append("## 其他变动 (Not app-facing, for awareness)")
    L.append("")
    for c, ps in r["other_changes"].items():
        L.append(f"- {CATEGORY_TITLES[c]}: {d['by_category'][c]['files']} files, {d['by_category'][c]['lines']} lines. e.g. "
                 + ", ".join(f"`{p.split('/', 2)[-1]}`" for p in ps[:5]))
    L.append(f"- {CATEGORY_TITLES['tests_infra']}: {d['by_category'].get('tests_infra', {}).get('files', 0)} files (not analyzed).")
    L.append("")
    # ---- zh sync appendix
    L.append("## 附录: zh 文案同步清单 (zh catalog sync list)")
    L.append("")
    L.append("Everything needed to update `packages/raft_ui/lib/src/l10n/zh_*.dart` (key = English text, value = zh-cn, wording verbatim). "
             "Status: NEW = English text not in our catalog yet; HAVE = same English already there (check the zh); "
             "REWRITE = Web changed the English text (replace our key); REWORD = same English, new zh-cn (replace our value).")
    L.append("")
    rows = []
    for x in I["added"]:
        rows.append([x["id"], "HAVE" if x["ours_has_text"] else "NEW", x["en"], x["zh"]])
    for x in I["changed_en"]:
        rows.append([x["id"], "REWRITE", f"{x['old_en']}  =>  {x['en']}", f"{x['old_zh']}  =>  {x['zh']}"])
    for x in I["changed_zh"]:
        rows.append([x["id"], "REWORD" + (" (ours differs)" if x["drift_in_ours"] else ""), x["en"], f"{x['old_zh']}  =>  {x['zh']}"])
    L.append(_tbl(["Web id", "Status", "English", "zh-cn"], rows))
    L.append("")
    return "\n".join(l for l in L)


def write_report(report: dict, out: Path) -> tuple[Path, Path]:
    out.mkdir(parents=True, exist_ok=True)
    pj, pm = out / "report.json", out / "report.md"
    pj.write_text(json.dumps(report, indent=1, ensure_ascii=False, default=list) + "\n", encoding="utf-8")
    pm.write_text(render_markdown(report) + "\n", encoding="utf-8")
    return pm, pj


# ------------------------------------------------------------------- decisions

def record_decision(repo: Path, to_tag: str, decision: str, note: str = "", report_path: str = "",
                    deferred: list[str] | None = None, decided_by: str = "Kevin", date: str | None = None,
                    mirror: Path | None = None, commit: str = "") -> dict:
    """Advance `pinned` to `to_tag` and append the decision to `history` (docs/upstream-sync.json)."""
    if decision not in DECISIONS:
        raise UpstreamError(f"--decision must be one of {', '.join(DECISIONS)}")
    if not TAG_RE.match(to_tag):
        raise UpstreamError(f"{to_tag} is not a vX.Y.Z-source.N tag")
    state = load_state(repo)
    if tag_key(to_tag) <= tag_key(state["pinned"]):
        raise UpstreamError(f"{to_tag} is not newer than the pinned {state['pinned']}")
    if mirror is not None and not commit:
        commit = tag_info(mirror, to_tag)["commit"]
    entry = {"tag": to_tag, "commit": commit, "from": state["pinned"], "decision": decision,
             "decidedBy": decided_by, "date": date or datetime.date.today().isoformat(), "note": note,
             "report": report_path, "deferred": deferred or []}
    state.setdefault("history", []).append(entry)
    state["pinned"] = to_tag
    if commit:
        state["commit"] = commit
    (Path(repo) / STATE_FILE).write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return entry


def find_pins(repo: Path, state: dict) -> list[str]:
    """Files that still cite the pinned commit/tag; they move only when the work for a decision lands."""
    commit = state.get("commit", "")
    needles = [n for n in (state["pinned"], commit, commit[:7]) if n]
    hits = []
    for rel in ("docs/source-reference.json", "docs/capability-parity.json", "THIRD_PARTY_NOTICES.md",
                "packages/raft_sync/test/fixtures/ts-core-vectors.json", "README.md"):
        p = Path(repo) / rel
        if p.exists() and any(n in p.read_text(encoding="utf-8", errors="replace") for n in needles):
            hits.append(rel)
    return hits


# ------------------------------------------------------------------------ main

def resolve_range(mirror: Path, repo: Path, frm: str | None, to: str | None) -> tuple[str, str]:
    tags = list_tags(mirror)
    if not tags:
        raise UpstreamError("no vX.Y.Z-source.N tags in the mirror")
    a = frm or load_state(repo)["pinned"]
    b = to or tags[-1]
    for t in (a, b):
        if not TAG_RE.match(t):
            raise UpstreamError(f"{t} is not a vX.Y.Z-source.N tag")
    if tag_key(b) <= tag_key(a):
        raise UpstreamError(f"nothing to compare: target {b} is not newer than baseline {a}")
    return a, b


RAFT_UI_PACKAGE = "@botiverse/raft-ui"
RECIPES_DOC = "docs/component-recipes.md"


def web_raft_ui_version(mirror: Path, tag: str) -> str | None:
    """The raft-ui version the Web client depends on at [tag]."""
    text = show(mirror, tag, "packages/web/package.json")
    if not text:
        return None
    deps = json.loads(text)
    for field in ("dependencies", "devDependencies"):
        for name in (RAFT_UI_PACKAGE, "raft-ui"):  # the alias reads "npm:@botiverse/raft-ui@0.7.0"
            spec = (deps.get(field) or {}).get(name)
            if spec:
                return spec.rsplit("@", 1)[-1].lstrip("^~=") if spec.startswith("npm:") else spec.lstrip("^~=")
    return None


def recipes_raft_ui_version(repo: Path) -> str | None:
    """The raft-ui version our generated recipes were built from."""
    path = repo / RECIPES_DOC
    if not path.is_file():
        return None
    m = re.search(r"from raft-ui ([0-9][0-9A-Za-z.+-]*)", path.read_text())
    return m.group(1) if m else None


def design_system_drift(mirror: Path, repo: Path, tag: str) -> str | None:
    """A warning when the Web's raft-ui differs from the one our recipes use.

    The Web can move to a new design-system release without a source change we
    would notice; the recipes then stay on the old look (2026-10-26: Web on
    0.7.0, recipes on 0.5.52). Fix: regenerate with tool/recipes/run.
    """
    web, ours = web_raft_ui_version(mirror, tag), recipes_raft_ui_version(repo)
    if web and ours and web != ours:
        return (f"design system drift: Web {tag} uses raft-ui {web}, our recipes are built from {ours}; "
                f"regenerate with tool/recipes/run (RAFT_UI_SOURCE=<raft-ui {web} package>)")
    return None


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--mirror", default=os.environ.get("RAFT_SOURCE_MIRROR", str(DEFAULT_MIRROR)))
    ap.add_argument("--remote", default=os.environ.get("RAFT_SOURCE_REMOTE", DEFAULT_REMOTE))
    ap.add_argument("--repo", default=str(ROOT), help="raft-flutter checkout (default: this one)")
    ap.add_argument("--no-fetch", action="store_true", help="use the mirror as it is")
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("report", help="diff pinned..latest and write report.md/report.json")
    r.add_argument("--from", dest="frm")
    r.add_argument("--to")
    r.add_argument("--out", default=str(DEFAULT_OUT))
    r.add_argument("--work-dir", default=str(DEFAULT_WORK))
    r.add_argument("--keep-trees", action="store_true")
    r.add_argument("--visual-note", default="", help="text recorded under the visual re-run commands (what was or was not run)")
    sub.add_parser("latest", help="print the newest upstream tag")
    sub.add_parser("status", help="pinned baseline, newest upstream tag, history")
    sub.add_parser("pins", help="files that still cite the pinned revision")
    d = sub.add_parser("record-decision", help="advance the pinned baseline after Kevin decided")
    d.add_argument("--to", required=True)
    d.add_argument("--decision", required=True, choices=DECISIONS)
    d.add_argument("--note", default="")
    d.add_argument("--report", default="", help="path of the committed report (docs/upstream-reports/...)")
    d.add_argument("--defer", action="append", default=[], help="decision-row id still open (repeatable), e.g. D07")
    d.add_argument("--decided-by", default="Kevin")
    d.add_argument("--date")
    args = ap.parse_args(argv)
    mirror, repo = Path(args.mirror).expanduser(), Path(args.repo)
    try:
        ensure_mirror(mirror, args.remote, fetch=not args.no_fetch)
        if args.cmd == "latest":
            print(list_tags(mirror)[-1])
        elif args.cmd == "status":
            st = load_state(repo)
            tags = list_tags(mirror)
            newer = [t for t in tags if tag_key(t) > tag_key(st["pinned"])]
            print(f"pinned: {st['pinned']}\nlatest: {tags[-1]}\nnewer tags: {', '.join(newer) or 'none'}")
            drift = design_system_drift(mirror, repo, tags[-1])
            print(drift or f"design system: recipes match Web raft-ui {recipes_raft_ui_version(repo) or '?'}")
            for h in st.get("history", [])[-5:]:
                print(f"  {h.get('date', '')} {h.get('tag', '')} {h.get('decision', '')} {h.get('note', '')}")
        elif args.cmd == "pins":
            st = load_state(repo)
            print("\n".join(find_pins(repo, st)) or "no pin-bearing files found")
        elif args.cmd == "report":
            a, b = resolve_range(mirror, repo, args.frm, args.to)
            rep = generate_report(mirror, repo, a, b, Path(args.work_dir).expanduser(), args.keep_trees)
            if args.visual_note:
                rep["visual_run"] = args.visual_note
            md, js = write_report(rep, Path(args.out))
            print(f"{a} -> {b}\n{md}\n{js}")
        elif args.cmd == "record-decision":
            entry = record_decision(repo, args.to, args.decision, args.note, args.report, args.defer, args.decided_by,
                                    args.date, mirror)
            print(f"pinned -> {entry['tag']} ({entry['decision']})")
            print("Files that still cite an older revision are updated by the work for this decision, not by this command:\n  "
                  + "\n  ".join(["docs/source-reference.json", "docs/capability-parity.json (webSource)", "THIRD_PARTY_NOTICES.md"]))
    except UpstreamError as e:
        print(f"upstream_sync: {e}", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
