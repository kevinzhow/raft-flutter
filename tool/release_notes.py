#!/usr/bin/env python3
"""Build the client's `release-notes.json` release asset from docs/release-notes.

One Markdown file per release tag: docs/release-notes/<tag>.md, e.g.
`v0.1.0+5.md`. The asset has the shape of one page of the Web client's
`GET /release-notes` response, so the app's Settings > Release Notes view parses
it with the same rules:

    {"items": [{"releaseId": "<tag>", "tag": "<tag>", "version": "0.1.0",
                "date": "2026-10-13", "state": "published",
                "entries": [{"type": "feature", "text": "...", "emphasis": false}]}],
     "nextCursor": null}

Items are newest first and cover every note in the checkout, so the asset of the
latest release always holds the full history.

File format (see docs/release-ci.md):

    ---
    version: 0.1.0          # optional; defaults to the tag's version
    date: 2026-10-13        # required, YYYY-MM-DD
    state: published        # optional: published (default) or retracted
    ---
    - feature: Text shown to the user.
    - improvement!: A "!" after the type marks the entry as emphasised.
    - fix: ...

Types: feature, improvement, fix, breaking, deprecated. Lines starting with `#`
and blank lines are ignored; any other line is an error.
"""
import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
NOTES_DIR = ROOT / 'docs/release-notes'
TYPES = ('feature', 'improvement', 'fix', 'breaking', 'deprecated')
STATES = ('published', 'retracted')
VERSION = r'[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?'
TAG = re.compile(rf'v({VERSION})(?:\+([0-9]+))?')
ENTRY = re.compile(rf'-\s+({"|".join(TYPES)})(!?):\s*(\S.*)')
MAX_TEXT = 500


def parse_note(tag, text):
    """One release item from a notes file; ValueError names the problem."""
    tag_match = TAG.fullmatch(tag)
    if not tag_match:
        raise ValueError(f'{tag}: release notes file name must be a release tag like v1.2.3+4')
    lines = text.replace('\r\n', '\n').split('\n')
    if not lines or lines[0].strip() != '---':
        raise ValueError(f'{tag}: the file must start with a --- front matter block')
    try:
        end = lines.index('---', 1)
    except ValueError:
        raise ValueError(f'{tag}: the front matter block is not closed with ---') from None
    meta = {}
    for line in lines[1:end]:
        line = line.split('#', 1)[0].strip()
        if not line:
            continue
        key, separator, value = line.partition(':')
        if not separator or key.strip() not in {'version', 'date', 'state'}:
            raise ValueError(f'{tag}: unknown front matter line "{line}"')
        meta[key.strip()] = value.strip()
    version = meta.get('version', tag_match[1])
    if not re.fullmatch(VERSION, version) or version != tag_match[1]:
        raise ValueError(f'{tag}: version "{version}" does not match the tag')
    date = meta.get('date', '')
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', date):
        raise ValueError(f'{tag}: date must be YYYY-MM-DD')
    state = meta.get('state', 'published')
    if state not in STATES:
        raise ValueError(f'{tag}: state must be one of {", ".join(STATES)}')
    entries = []
    for number, line in enumerate(lines[end + 1:], end + 2):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        match = ENTRY.fullmatch(stripped)
        if not match:
            raise ValueError(f'{tag}:{number}: expected "- <{"|".join(TYPES)}>: text", got "{stripped}"')
        entry_text = match[3].strip()
        if len(entry_text) > MAX_TEXT:
            raise ValueError(f'{tag}:{number}: entry is longer than {MAX_TEXT} characters')
        entries.append({'type': match[1], 'text': entry_text, 'emphasis': match[2] == '!'})
    if not entries:
        raise ValueError(f'{tag}: add at least one entry')
    return {'releaseId': tag, 'tag': tag, 'version': version, 'date': date,
            'state': state, 'entries': entries}


def sort_key(item):
    match = TAG.fullmatch(item['tag'])
    core = tuple(int(part) for part in re.split(r'[.-]', match[1].split('-', 1)[0]))
    # A prerelease sorts before its final version.
    return (item['date'], core, '-' not in match[1], int(match[2] or 0))


def build(tag, directory=NOTES_DIR):
    """The asset document for release [tag]: every note, newest first.

    Fails when [tag] has no notes file, so a release cannot ship without notes.
    """
    directory = Path(directory)
    items = []
    for path in sorted(directory.glob('v*.md')):
        items.append(parse_note(path.stem, path.read_text(encoding='utf-8')))
    if tag not in {item['tag'] for item in items}:
        raise ValueError(f'Add release notes for {tag}: docs/release-notes/{tag}.md '
                         '(format: see docs/release-ci.md)')
    items.sort(key=sort_key, reverse=True)
    return {'items': items, 'nextCursor': None}


HEADINGS = (('breaking', 'Breaking changes'), ('feature', 'New'), ('improvement', 'Improved'),
            ('fix', 'Fixed'), ('deprecated', 'Deprecated'))


def markdown(document, tag):
    """The notes of release [tag] as Markdown for the GitHub release page."""
    item = next(i for i in document['items'] if i['tag'] == tag)
    lines = ["## What's new", '']
    for kind, heading in HEADINGS:
        entries = [e for e in item['entries'] if e['type'] == kind]
        if not entries:
            continue
        lines += [f'### {heading}', '']
        lines += [f"- **{e['text']}**" if e['emphasis'] else f"- {e['text']}" for e in entries]
        lines.append('')
    return '\n'.join(lines)


def write(path, tag, directory=NOTES_DIR):
    """Writes the asset with canonical bytes (UTF-8, LF, stable key order)."""
    document = build(tag, directory)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(document, indent=2, ensure_ascii=False) + '\n',
                          encoding='utf-8', newline='\n')
    return document


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('tag', help='release tag, e.g. v0.1.0+6')
    parser.add_argument('--out', default='release-notes.json')
    parser.add_argument('--dir', default=str(NOTES_DIR))
    args = parser.parse_args()
    document = write(args.out, args.tag, args.dir)
    print(f'Wrote {args.out}: {len(document["items"])} releases, newest {document["items"][0]["tag"]}')


if __name__ == '__main__':
    try:
        main()
    except ValueError as error:
        sys.exit(f'Release notes: {error}')
