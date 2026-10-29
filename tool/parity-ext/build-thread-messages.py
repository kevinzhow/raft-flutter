#!/usr/bin/env python3
"""Append the message-surface cases to the run-time manifest ($PARITY_EXT_MANIFEST) and write
tool/parity-ext/fixtures/threadmessages.json.

Run after build-cases.py and the other build-*.py scripts; idempotent: every
`components.thread-ext.message.*` case is replaced, all other cases are kept in
place (append-only for the other families).

Derivation (raft-source 26f77ef, packages/web/src):
  components/message/MessageItem.tsx          row root (hover / popup-open state),
                                              reaction picker portal (PopoverPopup,
                                              seven QUICK_REACTION_EMOJIS buttons)
  components/message/MessageHoverToolbar.tsx  the "riding" toolbar pill (desktop,
                                              fine pointer only)
  components/message/ReactionGlyph.tsx / reactionConstants.ts
  components/message/ForwardedBundleCard.tsx  forwarded-bundle card
  components/mermaid/MermaidDiagram.tsx, MermaidToolbar.tsx, mermaid.css
  components/message/SOSDialog.tsx            DialogCard max-w-sm
  components/message/NotificationActivationBanner.tsx  (Banner info/sm)
Ids: components.thread-ext.message.<surface>[.<platform>].<theme>.
Surfaces whose Web component the Flutter app does not have are listed in
docs / the final report, not added (no builder, no case).
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.thread-ext.message.'

fixture = {
    'name': 'raft-flutter parity extension: message surfaces',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'message': {
        'id': 'msg-parity-ext-hover',
        'content': 'Captured the visual baselines.',
        'createdAt': '2026-06-22T02:30:00.000Z',
    },
    'bundles': {
        'single': {
            'kind': 'forwarded-bundle', 'version': 1,
            'forwardedItems': [
                {'index': 0, 'sourceMessageId': 'msg-fwd-1', 'sourceMessageSeq': 1, 'sourceTargetId': 'channel-design',
                 'sourceAuthorSnapshot': {'type': 'agent', 'id': 'agent-cindy', 'name': 'Cindy', 'uniqueName': 'cindy'},
                 'sourceCreatedAt': '2026-06-22T02:30:00.000Z',
                 'sourceTargetSnapshot': {'id': 'channel-design', 'type': 'channel', 'label': '#design',
                                          'labelVisibility': 'public'},
                 'contentSnapshot': 'Captured the Android visual artifact and queued React parity.',
                 'provenanceState': 'available'},
            ],
        },
        'multi': {
            'kind': 'forwarded-bundle', 'version': 1,
            'forwardedItems': [
                {'index': 0, 'sourceMessageId': 'msg-fwd-1', 'sourceMessageSeq': 1, 'sourceTargetId': 'channel-design',
                 'sourceAuthorSnapshot': {'type': 'agent', 'id': 'agent-cindy', 'name': 'Cindy', 'uniqueName': 'cindy'},
                 'sourceCreatedAt': '2026-06-22T02:30:00.000Z',
                 'sourceTargetSnapshot': {'id': 'channel-design', 'type': 'channel', 'label': '#design',
                                          'labelVisibility': 'public'},
                 'contentSnapshot': 'Release gates are green for the Android capture.',
                 'provenanceState': 'available'},
                {'index': 1, 'sourceMessageId': 'msg-fwd-2', 'sourceMessageSeq': 2, 'sourceTargetId': 'channel-design',
                 'sourceAuthorSnapshot': {'type': 'user', 'id': 'visual-human-owner', 'name': 'Owner',
                                          'uniqueName': 'owner'},
                 'sourceCreatedAt': '2026-06-22T02:31:00.000Z',
                 'sourceTargetSnapshot': {'id': 'channel-design', 'type': 'channel', 'label': '#design',
                                          'labelVisibility': 'public'},
                 'contentSnapshot': 'Please compare the hover toolbar, the reaction picker and the forwarded card '
                                    'against the React baseline before we publish the build. Check all three themes, '
                                    'desktop and mobile, and send me the diff links for anything under ninety-six '
                                    'percent so we can decide together whether it is a real difference or only text '
                                    'anti-aliasing noise that we should leave alone.',
                 'provenanceState': 'available'},
                {'index': 2, 'sourceMessageId': 'msg-fwd-3', 'sourceMessageSeq': 3, 'sourceTargetId': 'channel-design',
                 'sourceAuthorSnapshot': {'type': 'agent', 'id': 'agent-cindy', 'name': 'Cindy', 'uniqueName': 'cindy'},
                 'sourceCreatedAt': '2026-06-22T02:35:00.000Z',
                 'sourceTargetSnapshot': {'id': 'channel-design', 'type': 'channel', 'label': '#design',
                                          'labelVisibility': 'public'},
                 'contentSnapshot': 'Queued. I will post the diff links here when the run finishes, and I will '
                                    'also list every case that stays under the threshold together with the '
                                    'measured difference so the review can start from the real numbers.',
                 'provenanceState': 'available'},
            ],
        },
        'thread': {
            'kind': 'forwarded-bundle', 'version': 1,
            'forwardedItems': [
                {'index': 0, 'sourceMessageId': 'msg-fwd-t1', 'sourceMessageSeq': 1, 'sourceIsThreadParent': True,
                 'sourceTargetId': 'thread-design-1', 'sourceThreadId': 'thread-design-1',
                 'parentChannelId': 'channel-design',
                 'sourceAuthorSnapshot': {'type': 'user', 'id': 'visual-human-owner', 'name': 'Owner',
                                          'uniqueName': 'owner'},
                 'sourceCreatedAt': '2026-06-22T02:30:00.000Z',
                 'sourceTargetSnapshot': {'id': 'thread-design-1', 'type': 'thread', 'label': '#design',
                                          'labelVisibility': 'public'},
                 'contentSnapshot': 'Can we ship the message surfaces today?',
                 'provenanceState': 'available'},
                {'index': 1, 'sourceMessageId': 'msg-fwd-t2', 'sourceMessageSeq': 2, 'sourceIsThreadParent': False,
                 'sourceTargetId': 'thread-design-1', 'sourceThreadId': 'thread-design-1',
                 'parentChannelId': 'channel-design',
                 'sourceAuthorSnapshot': {'type': 'agent', 'id': 'agent-cindy', 'name': 'Cindy', 'uniqueName': 'cindy'},
                 'sourceCreatedAt': '2026-06-22T02:35:00.000Z',
                 'sourceTargetSnapshot': {'id': 'thread-design-1', 'type': 'thread', 'label': '#design',
                                          'labelVisibility': 'public'},
                 'contentSnapshot': 'Yes, once the parity run is green.',
                 'provenanceState': 'available'},
            ],
        },
        'restricted': {
            'kind': 'forwarded-bundle', 'version': 1,
            'forwardedItems': [
                {'index': 0, 'sourceMessageId': 'msg-fwd-r1', 'sourceMessageSeq': 1,
                 'sourceAuthorSnapshot': {'type': 'user', 'id': 'visual-human-owner', 'name': 'Owner'},
                 'sourceCreatedAt': '2026-06-22T02:30:00.000Z',
                 'sourceTargetSnapshot': {'id': None, 'type': 'dm', 'label': 'Direct message',
                                          'labelVisibility': 'restricted'},
                 'contentSnapshot': 'The source conversation is private, so the card shows no source label.',
                 'provenanceState': 'available'},
            ],
        },
    },
    'mermaid': {
        'flow': 'flowchart LR\n  A[Capture] --> B{Match?}\n  B -->|yes| C[Ship]\n  B -->|no| D[Fix]',
    },
    'sos': {'channelName': 'design', 'channelId': 'channel-design',
            'guidance': 'Stop editing the README and re-run the parity suite first.'},
    # Endpoints the mounted components call (both providers answer them).
    'routes': {
        'POST /channels/channel-design/stop-all-agents': {},
        'POST /channels/channel-design/resume-all-agents': {},
    },
}

cases = []


def add(platform, surface, title, *, props, height, width=None, selector=None, android_key=None,
        interactions=(), notes=None):
    viewport = DESKTOP if platform == 'desktop' else MOBILE
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{surface}.{platform}.{suffix}'
        c = {
            'id': cid,
            'title': f'Message {title} {platform} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'thread-message-ext',
            'category': 'extension/thread-message',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': {
                'extCase': f'{surface}.{platform}', 'extKind': 'threadmessage', 'parityTheme': theme,
                'platform': platform, 'boxHeight': height, 'boxWidth': width, **props}}],
            'capture': {'selector': selector or f"[data-visual-case='{cid}']", 'crop': 'element',
                        'contract': 'component-bounds', 'interactions': list(interactions),
                        'androidInteractions': []},
            'reactPathHint': 'packages/web/src/components/message/MessageItem.tsx (+ per-surface component)',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_thread_messages.dart '{surface}.{platform}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if android_key:
            c['capture']['androidKey'] = android_key
        if notes:
            c['notes'] = notes
        cases.append(c)


ROW = '#message-msg-parity-ext-hover'
HOVER_ROW = {'type': 'hover', 'target': ROW}
BTN = lambda name: f'{ROW} [data-message-affordance="{name}"]'

# ---- hover toolbar and reaction picker (desktop; the toolbar is fine-pointer only) ----
add('desktop', 'toolbar', 'hover toolbar on a hovered row', props={'state': 'toolbar'}, height=112,
    interactions=[HOVER_ROW],
    notes='Pointer rests on the row; the pill rides on its top border (MessageHoverToolbar).')
add('desktop', 'toolbar-saved', 'hover toolbar, saved message', props={'state': 'toolbar-saved'}, height=112,
    interactions=[HOVER_ROW])
add('desktop', 'toolbar-thread', 'hover toolbar inside a thread (no reply action)',
    props={'state': 'toolbar-thread'}, height=112, interactions=[HOVER_ROW])
add('desktop', 'toolbar-button-hover', 'hover toolbar, pointer on the reaction button',
    props={'state': 'toolbar-button-hover'}, height=112,
    interactions=[{'type': 'hover', 'target': BTN('reaction')}])
add('desktop', 'picker', 'quick reaction picker open', props={'state': 'picker'}, height=170,
    interactions=[HOVER_ROW, {'type': 'click', 'target': BTN('reaction')}],
    notes='Reaction button clicked; the seven quick reactions open below it.')
add('desktop', 'picker-emoji-hover', 'quick reaction picker, pointer on an emoji',
    props={'state': 'picker-emoji-hover'}, height=170,
    interactions=[HOVER_ROW, {'type': 'click', 'target': BTN('reaction')},
                  {'type': 'hover', 'target': '[data-message-affordance="reaction-picker"] button:nth-child(3)'}])

# ---- forwarded bundle card ----
FWD = '[data-testid="forwarded-bundle-card"]'
TOGGLE = '[data-testid="forwarded-bundle-toggle"]'
add('desktop', 'forward-single', 'forwarded bundle, one message', props={'state': 'forward', 'bundle': 'single'},
    height=None, width=480)
add('desktop', 'forward-multi', 'forwarded bundle, three messages collapsed',
    props={'state': 'forward', 'bundle': 'multi'}, height=None, width=480)
add('desktop', 'forward-expanded', 'forwarded bundle, three messages expanded',
    props={'state': 'forward', 'bundle': 'multi'}, height=None, width=480,
    interactions=[{'type': 'click', 'target': TOGGLE}])
add('desktop', 'forward-thread', 'forwarded bundle from a thread', props={'state': 'forward', 'bundle': 'thread'},
    height=None, width=480)
add('desktop', 'forward-restricted', 'forwarded bundle, restricted source (no source label)',
    props={'state': 'forward', 'bundle': 'restricted'}, height=None, width=480)
add('mobile', 'forward-single', 'forwarded bundle, one message', props={'state': 'forward', 'bundle': 'single'},
    height=None, width=390)
add('mobile', 'forward-multi', 'forwarded bundle, three messages collapsed',
    props={'state': 'forward', 'bundle': 'multi'}, height=None, width=390)

# ---- mermaid chrome ----
MERMAID_TOOLBAR = '[data-testid="mermaid-toolbar"]'
add('desktop', 'mermaid-toolbar', 'mermaid toolbar (diagram view)', props={'state': 'mermaid', 'diagram': 'flow'},
    height=None, width=560, selector=MERMAID_TOOLBAR, android_key='mermaid-toolbar')
add('desktop', 'mermaid-code', 'mermaid card, code view', props={'state': 'mermaid', 'diagram': 'flow'},
    height=None, width=560, selector='[data-visual-case] .r-mermaid-diagram',
    interactions=[{'type': 'click', 'target': f'{MERMAID_TOOLBAR} [aria-label="Code"]'}],
    android_key='mermaid-container')
add('desktop', 'mermaid-diagram', 'mermaid card, diagram view (SVG itself may differ)',
    props={'state': 'mermaid', 'diagram': 'flow'}, height=None, width=560,
    selector='[data-visual-case] .r-mermaid-diagram', android_key='mermaid-container')
add('mobile', 'mermaid-toolbar', 'mermaid toolbar (diagram view)', props={'state': 'mermaid', 'diagram': 'flow'},
    height=None, width=358, selector=MERMAID_TOOLBAR, android_key='mermaid-toolbar')

# ---- notification activation banner ----
add('desktop', 'banner', 'notification activation banner', props={'state': 'banner'}, height=None, width=480,
    notes='Flutter has no production surface (Web Push opt-in); the closest real widgets are mounted.')
add('mobile', 'banner', 'notification activation banner', props={'state': 'banner'}, height=None, width=390,
    notes='Flutter has no production surface (Web Push opt-in); the closest real widgets are mounted.')

# ---- SOS dialog ----
SOS_CARD = '[data-slot="modal-backdrop"] [data-slot="dialog-card"]'
STOP_BTN = '>> role=button[name="Stop"]'
add('desktop', 'sos-confirm', 'SOS dialog, confirm phase', props={'state': 'sos'}, height=None,
    selector=SOS_CARD, android_key='sos-dialog-card')
add('desktop', 'sos-stopped', 'SOS dialog, stopped (guidance form)', props={'state': 'sos'}, height=None,
    selector=SOS_CARD, android_key='sos-dialog-card',
    interactions=[{'type': 'click', 'target': f'{SOS_CARD} {STOP_BTN}'}, {'type': 'wait', 'ms': 250}])
add('desktop', 'sos-guidance', 'SOS dialog, stopped with guidance typed', props={'state': 'sos'}, height=None,
    selector=SOS_CARD, android_key='sos-dialog-card',
    interactions=[{'type': 'click', 'target': f'{SOS_CARD} {STOP_BTN}'}, {'type': 'wait', 'ms': 250},
                  {'type': 'fill', 'target': f'{SOS_CARD} textarea', 'value': fixture['sos']['guidance']}])
add('mobile', 'sos-confirm', 'SOS dialog, confirm phase', props={'state': 'sos'}, height=None,
    selector=SOS_CARD, android_key='sos-dialog-card')

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/threadmessages.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} thread message cases appended -> the run-time manifest ($PARITY_EXT_MANIFEST); '
      'fixture -> tool/parity-ext/fixtures/threadmessages.json')
