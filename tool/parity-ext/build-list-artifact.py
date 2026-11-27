#!/usr/bin/env python3
"""An Artifact opened from an Activity row or a Search hit, in the real workspace (task #380).

Web v1.24 MainLayout (InboxContentRoute / SearchContentRoute > ArtifactContentSlot): from 768px the
viewer shows in the main area beside the list (the list in col 2, its row selected); on a phone the
viewer is a page pushed in place of the list. Flutter: list_detail_slot.dart (openListDetail) and
artifacts/artifact_content_slot.dart.

Ids: components.pages.list-artifact.<size>.<source>.<theme>
  size   desktop (1280x900), phone (390x844), and for Activity the screen-class widths
         fold-841x701, fold-884x1104, tablet-1180x820 (no pane below its minimum width)
  source activity (the Artifact's object row) | search (its Artifacts app hit for "plan")
React: tool/parity-ext/host/ListArtifactCases.tsx (the real MainLayout route).
Flutter: apps/raft_flutter/test/parity/cases/ext_list_artifact.dart (the real WorkspaceView).
Writes tool/parity-ext/fixtures/list-artifact.json, the data both providers answer.
"""
import json
import pathlib

from builders import manifest_path

here = pathlib.Path(__file__).resolve().parent
PREFIX = 'components.pages.list-artifact.'
FIXTURE = 'list-artifact'
THEMES = {'brutal': 'brutal-light', 'elegant-dark': 'elegant-dark'}
SIZES = {
    'desktop': ({'width': 1280, 'height': 900, 'density': 1}, ('activity', 'search')),
    'phone': ({'width': 390, 'height': 844, 'density': 1}, ('activity', 'search')),
    'fold-841x701': ({'width': 841, 'height': 701, 'density': 1}, ('activity',)),
    'fold-884x1104': ({'width': 884, 'height': 1104, 'density': 1}, ('activity',)),
    'tablet-1180x820': ({'width': 1180, 'height': 820, 'density': 1}, ('activity',)),
}

FIRST = 'pt_00000000-0000-4000-8000-000000000001'
SECOND = 'pt_00000000-0000-4000-8000-000000000002'
AT = '2026-06-19T11:20:00.000Z'
ME = {'type': 'user', 'id': 'visual-user', 'name': 'artin', 'displayName': 'artin', 'avatarUrl': None}
CINDY = {'type': 'agent', 'id': 'agent-cindy', 'name': 'Cindy', 'displayName': 'Cindy', 'avatarUrl': None}
HOME = {'kind': 'conversation', 'conversation': {'id': 'channel-design', 'name': 'design', 'type': 'channel'}}
# A text Artifact: both sides draw it themselves. Web v1.24 shows markdown, html and pdf only in a
# sandboxed frame on the content origin (ArtifactContent.tsx ARTIFACT_FRAMED_KINDS), which the render
# host cannot serve ("The preview isn't available right now"), while Flutter without a WebView draws
# markdown natively: a markdown fixture would compare two different content states.
PLAN = ('Launch plan\n\nShip the Android build on Friday after the visual checks pass.\n\n'
        'Freeze the release branch.\nRun the parity suite.\nPublish the notes.\n')


def row(artifact_id, title, actor, preview):
    return {
        'kind': 'object', 'objectKind': 'artifact', 'objectId': artifact_id,
        'summary': {'title': title, 'kind': 'text', 'latestVersion': 1},
        'home': {'kind': 'channel', 'label': 'design', 'channelId': 'channel-design'},
        'latestEvent': {'eventKind': 'comment', 'reason': 'following', 'actor': actor, 'at': AT},
        'preview': {'text': preview, 'truncated': False},
        'target': None, 'unreadCount': 0, 'hasMention': False, 'isFollowing': True,
        'lastActivityAt': AT, 'doneFrontierSeq': '9',
    }


def card(artifact_id, title):
    return {
        'id': artifact_id, 'url': f'/artifacts/{artifact_id}', 'title': title, 'kind': 'text',
        'facts': {'sizeBytes': len(PLAN), 'fileCount': 1}, 'preview': {'kind': 'none'},
        'version': 1, 'latestVersion': 1, 'pinned': False, 'author': CINDY,
        'createdAt': '2026-06-18T14:30:00.000Z', 'updatedAt': AT, 'commentCount': 0, 'home': HOME,
    }


def viewer(artifact_id, title):
    return {
        'card': card(artifact_id, title),
        'files': [{'path': 'plan.txt', 'kind': 'text', 'sizeBytes': len(PLAN), 'entry': True}],
        'versions': [{'number': 1, 'publisher': CINDY, 'createdAt': '2026-06-18T14:30:00.000Z',
                      'note': None, 'changedPaths': ['plan.txt']}],
        'viewer': ME, 'following': True, 'savedFrom': None, 'origin': None,
        'capabilities': {'publish': True, 'comment': True, 'changeHome': True, 'unpublish': False,
                         'narrowHome': False, 'delete': True},
    }


ROUTES = {
    'POST /feature-flags/evaluate': {'evaluations': [{'key': 'workspace_artifacts_v0', 'enabled': True}]},
    'GET /channels/inbox': {
        'items': [row(FIRST, 'Launch plan', CINDY, 'Can we freeze the branch on Thursday?'),
                  row(SECOND, 'Release notes draft', ME, 'Added the Android section.')],
        'hasMore': False, 'totalCount': 2, 'totalUnreadCount': 0, 'objectCount': 2,
    },
    'GET /search': {'groups': [{'app': 'artifacts', 'nextCursor': None, 'items': [
        {'card': {**card(FIRST, 'Launch plan')}, 'matches': []}]}]},
    'GET /messages/search': {'results': [], 'hasMore': False},
}
for artifact_id, title in ((FIRST, 'Launch plan'), (SECOND, 'Release notes draft')):
    ROUTES[f'GET /artifacts/{artifact_id}'] = viewer(artifact_id, title)
    ROUTES[f'GET /artifacts/{artifact_id}/details'] = viewer(artifact_id, title)
    ROUTES[f'GET /artifacts/{artifact_id}/files/plan.txt/content'] = {'kind': 'text', 'content': PLAN}
    ROUTES[f'GET /artifacts/{artifact_id}/comments'] = {'comments': [], 'olderCursor': None}
    ROUTES[f'GET /artifacts/{artifact_id}/will-notify'] = {'recipients': []}
    ROUTES[f'GET /artifacts/{artifact_id}/review/drafts'] = {'drafts': []}
    ROUTES[f'GET /artifacts/{artifact_id}/presence'] = {
        'viewing': [], 'readCurrentVersion': [], 'readOtherVersion': [], 'ownRead': None}

OPEN = {
    'activity': ('[data-testid="inbox-row"]:has-text("Launch plan")', f'activity-object-{FIRST}'),
    'search': ('[data-testid="search-app-hit"]:has-text("Launch plan")', f'app:artifacts:{FIRST}'),
}
HINT = {
    'activity': 'packages/web/src/components/layout/MainLayout.tsx (InboxContentRoute, ArtifactContentSlot)',
    'search': 'packages/web/src/components/layout/MainLayout.tsx (SearchContentRoute, ArtifactContentSlot)',
}


def build_cases():
    for size, (viewport, sources) in SIZES.items():
        for source in sources:
            web_target, flutter_key = OPEN[source]
            for suffix, theme in THEMES.items():
                cid = f'{PREFIX}{size}.{source}.{suffix}'
                yield {
                    'id': cid,
                    'title': f'Artifact opened from {source} ({size}, {theme})',
                    'captureType': 'component-fixture',
                    'surface': 'list-artifact',
                    'category': 'extension/list-artifact',
                    'suite': 'raft-flutter-extension',
                    'viewport': viewport,
                    'theme': theme,
                    'locale': 'en',
                    'variants': [{'id': 'default', 'name': 'Default', 'props': {
                        'extCase': f'{size}.{source}', 'extKind': 'list-artifact', 'extFixture': FIXTURE,
                        'platform': 'mobile' if size == 'phone' else 'desktop',
                        'source': source, 'parityTheme': theme, 'openKey': flutter_key,
                    }}],
                    'capture': {
                        'selector': f'[data-visual-case="{cid}"]:has([data-testid="artifact-viewer"])',
                        'crop': 'element', 'contract': 'component-bounds',
                        'interactions': [
                            {'type': 'wait', 'ms': 1200},
                            {'type': 'click', 'target': web_target},
                            {'type': 'wait', 'ms': 1200},
                        ],
                    },
                    'reactPathHint': HINT[source],
                    'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_list_artifact.dart '{size}.{source}'",
                    'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
                }


def main():
    (here / 'fixtures' / f'{FIXTURE}.json').write_text(
        json.dumps({'name': 'raft-flutter parity extension: an Artifact opened from a list (#380)',
                    'firstId': FIRST, 'routes': ROUTES}, indent=1, ensure_ascii=False) + '\n')
    path = manifest_path()
    manifest = json.loads(path.read_text())
    cases = list(build_cases())
    manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
    print(f'{len(cases)} list-artifact cases appended')


if __name__ == '__main__':
    main()
