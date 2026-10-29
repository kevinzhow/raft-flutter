"""Guard for docs/: every file is listed in docs/README.md, and no new evidence-style names.

Verification evidence (commands, results, devices, screenshots) belongs in the PR
description. Living docs belong in docs/ and must be listed in docs/README.md, one
bullet per file or directory (`- `path` — what it is — when to read it`); a
directory entry (`dir/`) covers everything under it.

Run directly (`python3 tool/docs_index.py`) or through the host tests that the
full gate runs (tool/tests/test_docs_index.py).
"""
import pathlib
import re
import sys

MESSAGE = 'Verification evidence goes in the PR description, not docs/. Living docs must be listed in docs/README.md.'
FORBIDDEN_NAME = re.compile(r'evidence|audit|investigation|findings|checkpoint', re.IGNORECASE)
# Files that predate the rule and are still referenced by tools or the release
# report. Do not add to this list; delete entries as the files go away.
LEGACY_FLAGGED_NAMES = frozenset({
    'android-background-evidence.md',
    'attachment-evidence.md',
    'desktop-window-evidence.md',
    'html-preview-evidence.md',
    'macos-evidence.md',
    'message-sync-evidence.md',
    'navigation-audit.md',
    'notification-content-evidence.md',
    'release-evidence.md',
    'sharing-evidence.md',
})
IGNORED = {'.DS_Store'}
ENTRY = re.compile(r'^\s*[-*]\s+(.*?)\s+—\s')


def listed_entries(readme_text):
    """Paths named at the start of README bullets (`a.md`, `b.md` — ...)."""
    entries = []
    for line in readme_text.splitlines():
        match = ENTRY.match(line)
        if match:
            entries += re.findall(r'`([^`]+)`', match.group(1))
    return entries


def docs_files(docs):
    return sorted(p.relative_to(docs).as_posix() for p in docs.rglob('*')
                  if p.is_file() and p.name not in IGNORED and p.relative_to(docs).as_posix() != 'README.md')


def check(docs):
    """Return a list of problems for the docs/ directory (empty when fine)."""
    docs = pathlib.Path(docs)
    readme = docs / 'README.md'
    if not readme.is_file():
        return ['docs/README.md is missing.']
    entries = listed_entries(readme.read_text(encoding='utf-8'))
    directories = [e for e in entries if e.endswith('/')]
    files = docs_files(docs)
    problems = []
    for path in files:
        if path not in entries and not any(path.startswith(d) for d in directories):
            problems.append(f'docs/{path} is not listed in docs/README.md.')
        flagged = [part for part in path.split('/') if FORBIDDEN_NAME.search(part)]
        if flagged and pathlib.PurePosixPath(path).name not in LEGACY_FLAGGED_NAMES:
            problems.append(f'docs/{path}: names containing evidence/audit/investigation/findings/checkpoint are not allowed.')
    for entry in entries:
        target = docs / entry
        if not (target.is_dir() if entry.endswith('/') else target.is_file()):
            problems.append(f'docs/README.md lists {entry}, which does not exist.')
    return problems


def stale_legacy_entries(docs):
    """LEGACY_FLAGGED_NAMES entries whose file is gone (the list must shrink, never rot)."""
    names = {pathlib.PurePosixPath(p).name for p in docs_files(pathlib.Path(docs))}
    return [f'LEGACY_FLAGGED_NAMES in tool/docs_index.py still names {n}; remove the entry.'
            for n in sorted(LEGACY_FLAGGED_NAMES) if n not in names]


def main():
    docs = pathlib.Path(__file__).resolve().parent.parent / 'docs'
    problems = check(docs) + stale_legacy_entries(docs)
    if problems:
        print('\n'.join(problems) + '\n' + MESSAGE, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
