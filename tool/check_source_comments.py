#!/usr/bin/env python3
"""Check tracked // Source: comments against a raft-source checkout."""

import argparse
import re
import subprocess
from pathlib import Path

SOURCE_PREFIXES = ("packages/web/src/", "packages/shared/src/")
FILE_EXTENSION = r"\.(?:tsx?|[mc]?js|css|json)\b"
REFERENCES = re.compile(r"(?<![\w./-])[\w@.-]+(?:/[\w@.-]+)*" + FILE_EXTENSION)
GROUPED_PATHS = re.compile(r"([\w@./-]+/)\{([^{}]+)\}(" + FILE_EXTENSION + r")?")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="checkout containing packages/web/src and packages/shared/src")
    args = parser.parse_args()
    roots = [args.source / "packages" / package / "src" for package in ("web", "shared")]
    if not all(root.is_dir() for root in roots):
        parser.error("source must contain packages/web/src and packages/shared/src")
    paths = {
        file.relative_to(args.source).as_posix()
        for root in roots
        for file in root.rglob("*")
        if file.is_file()
    }
    relative_paths = {path.split("/src/", 1)[1] for path in paths}
    names = {Path(path).name for path in paths}
    comments = subprocess.run(
        ["git", "grep", "-nI", "-E", r"^[[:space:]]*//[[:space:]]*Source:"],
        capture_output=True, text=True, check=False,
    )
    if comments.returncode not in (0, 1):
        raise SystemExit(comments.stderr)
    seen = missing = 0
    files = {}
    for line in comments.stdout.splitlines():
        file, number, line = line.split(":", 2)
        source_lines = files.setdefault(file, [])
        source_lines.append((int(number), line.split("Source:", 1)[1].strip()))
    for file, locations in files.items():
        lines = Path(file).read_text(encoding="utf-8").splitlines()
        for number, first_line in locations:
            text = first_line
            for continuation in lines[number:]:
                match = re.match(r"\s*//\s*(?!/)(.*)", continuation)
                if not match or not match[1].strip() or match[1].startswith("Source:"):
                    break
                text += " " + match[1].strip()
            if not re.search(r"\b(?:Web|raft-source|packages/(?:web|shared)/src)\b", first_line, re.I):
                continue
            if first_line.startswith("raft-source packages/") and not first_line.removeprefix(
                "raft-source "
            ).startswith(SOURCE_PREFIXES):
                continue
            seen_delta, missing_delta = check_references(
                text, f"{file}:{number}", paths, relative_paths, names
            )
            seen += seen_delta
            missing += missing_delta
    print(f"Source comments: {seen} path references, {missing} missing")
    return int(missing > 0)


def check_references(text, location, paths, relative_paths, names):
    text = re.sub(r"(?<=\w/)\s+(?=[\w-])", "", text)
    for group in GROUPED_PATHS.finditer(text):
        expanded = " ".join(group[1] + name.strip() + (group[3] or "") for name in group[2].split(","))
        text = text.replace(group[0], expanded)
    seen = missing = 0
    for path in sorted({match.group() for match in REFERENCES.finditer(text)}):
        if path.startswith(("web/src/", "shared/src/")):
            path = "packages/" + path
        if path.startswith("src/"):
            path = "packages/web/" + path
        if path.startswith(SOURCE_PREFIXES):
            exists = path in paths
        elif path.startswith(("packages/", "dist/", "docs/", "node_modules/")):
            continue
        elif re.match(r"(?:raft-ui-|raft-web-|tailwindcss-)", path):
            continue
        elif "/" in path:
            exists = path in relative_paths
        elif path in names:
            exists = True
        else:
            continue
        seen += 1
        if not exists:
            missing += 1
            print(f"{location} {path}")
    return seen, missing


if __name__ == "__main__":
    raise SystemExit(main())
