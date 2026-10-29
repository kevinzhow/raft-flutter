#!/usr/bin/env python3
"""Append the attachment-preview cases to the run-time manifest ($PARITY_EXT_MANIFEST) and write
tool/parity-ext/fixtures/threadattachments.json.

Run after build-cases.py (which regenerates the Computers cases) and the other
builders; idempotent: every `components.thread-ext.attachment.*` case is
replaced, all other cases are kept (append-only for the other families).

Derivation (raft-source 26f77ef, packages/web/src):
  components/ImageLightbox.tsx                    image lightbox (title bar,
                                                   gallery counter / arrows /
                                                   thumbnails, comments aside)
  components/message/DocumentPreviewHost.tsx      document host
  components/message/MediaPreviewHost.tsx         html / video / audio host
  components/message/attachmentPreviewSurfaces.tsx  AttachmentPreviewShell
                                                   (header, comments aside),
                                                   Text/Csv/Xlsx/Markdown panes,
                                                   HtmlPreviewBody
  components/message/AttachmentCommentsPanel.tsx  comments panel
  components/ui/Lightbox.tsx                      full-screen backdrop
Ids: components.thread-ext.attachment.<surface>[.<platform>].<theme>.
Each case mounts the REAL host component with seeded stores (React) / the real
Flutter widget (see test/parity/cases/ext_thread_attachments.dart) and
captures the full-screen lightbox, its header strip or the comments panel.
"""
import base64
import json
import pathlib
import sys
import struct
import zlib

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DESKTOP = {'width': 1280, 'height': 800, 'density': 1}
MOBILE = {'width': 390, 'height': 844, 'density': 3}
PREFIX = 'components.thread-ext.attachment.'
ROOT = "body > div[tabindex='-1']"
HEADER = ROOT + ' > div:first-child'


# ---------------------------------------------------------------- fixture data
def png(width, height, pixel):
    """Deterministic RGB PNG; `pixel(x, y)` returns (r, g, b)."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixel(x, y))

    def chunk(kind, data):
        body = kind + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xFFFFFFFF)

    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))


def scene(base, accent, ink):
    """A flat sky/ground scene with a sun disc and a mountain ridge."""
    def pixel(x, y, w=640, h=400):
        sun = (x - int(w * .72)) ** 2 + (y - int(h * .28)) ** 2 <= (h // 9) ** 2
        ridge = int(h * .72 - abs((x % (w // 2)) - w // 4) * .55)
        if sun:
            return accent
        if y >= ridge:
            return ink
        t = y / h
        return tuple(int(base[i] * (1 - t * .25)) for i in range(3))
    return pixel


def data_url(blob):
    return 'data:image/png;base64,' + base64.b64encode(blob).decode()


SCENES = {
    'a': ((253, 224, 71), (244, 114, 182), (24, 24, 27)),
    'b': ((147, 197, 253), (251, 146, 60), (30, 41, 59)),
    'c': ((167, 243, 208), (250, 204, 21), (20, 83, 45)),
}
big = {k: png(640, 400, scene(*v)) for k, v in SCENES.items()}
small = {k: png(48, 48, lambda x, y, p=scene(*v): p(x * 640 // 48, y * 400 // 48)) for k, v in SCENES.items()}

PARENT = {'id': 'msg-att-parent', 'channelId': 'channel-design', 'senderId': 'visual-owner', 'senderType': 'user'}


def att(att_id, filename, mime, size, **extra):
    return {'id': att_id, 'filename': filename, 'mimeType': mime, 'sizeBytes': size, 'commentCount': 0, **extra}


IMAGES = [
    att('att-img-1', 'launch-hero.png', 'image/png', 48211, width=640, height=400,
        thumbnailUrl=data_url(small['a']), url=data_url(big['a'])),
    att('att-img-2', 'review-board-night-shift-with-a-very-long-descriptive-file-name-v2.png', 'image/png', 51122,
        width=640, height=400, thumbnailUrl=data_url(small['b']), url=data_url(big['b'])),
    att('att-img-3', 'checkout-flow.png', 'image/png', 39874, width=640, height=400,
        thumbnailUrl=data_url(small['c']), url=data_url(big['c'])),
]

TEXT = '\n'.join([
    'Release checklist - visual testing gates',
    '',
    '1. Freeze the design tokens before the capture run.',
    '2. Run the web provider once, then every Flutter shard.',
    '3. Compare exact pixels; text anti-aliasing noise is expected on dense crops.',
    '',
    'Owners',
    '  web      Cindy',
    '  flutter  Android-Developer-4',
    '  review   Artea',
    '',
    'A long line that wraps because the preview keeps whole words together and the pane is narrower than this sentence, so it breaks onto a second row.',
    'Done.',
])

CSV_HEADERS = ['Case', 'Surface', 'Owner', 'Status', 'Score']
CSV_ROWS = [
    ['lightbox.single', 'Image', 'Cindy', 'Passing', '98.2'],
    ['lightbox.gallery', 'Image', 'Cindy', 'Passing', '97.1'],
    ['doc.text', 'Document', 'Artea', 'Review', '94.6'],
    ['doc.csv', 'Document', 'Artea', 'Review', '93.9'],
    ['html.loading', 'HTML', 'Android-Developer-4', 'Failing', '88.0'],
    ['comments.list', 'Comments', 'Cindy', 'Passing', '96.4'],
    ['comments.empty', 'Comments', 'Cindy', 'Passing', '99.0'],
    ['comments.blocked', 'Comments', 'Cindy', 'Passing', '98.8'],
]

MARKDOWN = '\n'.join([
    '# Attachment preview review',
    '',
    'The preview keeps the **same shell** for every file type. Open `Comments` to pin a note to a line, a row or a section.',
    '',
    '## Checklist',
    '',
    '- Header: type badge, name, actions',
    '- Body: text, table, rendered markdown',
    '- Comments: anchored cards and a compact composer',
    '',
    '> Anchors survive reloads because they store the heading, not an offset.',
    '',
    '## Notes',
    '',
    'Keep the file name short enough to read, and long names truncate with an ellipsis.',
])

XLSX = {
    'kind': 'xlsx', 'sheetCount': 2,
    'sheets': [
        {'name': 'Summary', 'headers': ['Metric', 'Value'], 'rows': [['Cases', '42'], ['Passing', '31'], ['Mean', '95.1']],
         'rowCount': 3, 'columnCount': 2, 'truncated': False},
        {'name': 'Failing', 'headers': ['Case', 'Score'], 'rows': [['html.loading', '88.0'], ['doc.csv', '93.9']],
         'rowCount': 2, 'columnCount': 2, 'truncated': False},
    ],
}

DOCS = {
    'text': (att('att-doc-text', 'deploy-notes.txt', 'text/plain', 1204, commentCount=3),
             {'kind': 'text', 'text': TEXT}, False),
    'long': (att('att-doc-long', 'quarterly-visual-testing-review-and-release-gates-for-the-android-and-desktop-clients-final-v3.txt',
                 'text/plain', 1204, commentCount=0), {'kind': 'text', 'text': TEXT}, False),
    'csv': (att('att-doc-csv', 'parity-scores.csv', 'text/csv', 2210, commentCount=1),
            {'kind': 'csv', 'headers': CSV_HEADERS, 'rows': CSV_ROWS, 'rowCount': 42, 'columnCount': 5}, False),
    'xlsx': (att('att-doc-xlsx', 'parity-scores.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                 8210, commentCount=0), XLSX, False),
    'markdown': (att('att-doc-md', 'preview-review.md', 'text/markdown', 910, commentCount=2),
                 {'kind': 'markdown', 'markdown': MARKDOWN}, False),
    'pdf': (att('att-doc-pdf', 'Q2-brand-guidelines.pdf', 'application/pdf', 912000, commentCount=0),
            {'kind': 'pdf'}, False),
}
HTML = att('att-html-1', 'dashboard-export.html', 'text/html', 18122, commentCount=2)

SENDERS = {
    'artea': {'senderType': 'user', 'senderId': 'user-artea', 'senderName': 'Artea', 'senderAvatarUrl': None,
              'senderGravatarHash': None},
    'owner': {'senderType': 'user', 'senderId': 'visual-owner', 'senderName': 'Visual Owner',
              'senderAvatarUrl': None, 'senderGravatarHash': None},
    'cindy': {'senderType': 'agent', 'senderId': 'agent-cindy', 'senderName': 'Cindy',
              'senderAvatarUrl': 'pixel:robot', 'senderGravatarHash': None},
}


def comment(cid, who, content, minutes, anchor=None):
    return {'id': cid, 'channelId': 'thread-att-1', **SENDERS[who], 'content': content,
            'createdAt': f'2026-06-19T12:{30 - minutes:02d}:00.000Z', 'reactions': [], 'anchor': anchor}


COMMENTS = [
    comment('c-1', 'owner', 'Can we confirm the file is the final export before the review?', 25),
    comment('c-2', 'artea', 'Line 3 needs a **hard** freeze - see `tokens.json`.', 20,
            {'type': 'lines', 'data': {'start': 3, 'end': 5, 'quote': 'Freeze the design tokens before the capture run.'}}),
    comment('c-3', 'cindy', 'Row 4 is the one that keeps failing in Flutter, the other rows are fine.\n\nI will pair on it after lunch.', 12,
            {'type': 'csv-rows', 'data': {'start': 4, 'end': 4}}),
    comment('c-4', 'artea', 'Section title reads better as a verb.', 5,
            {'type': 'md-section', 'data': {'headingId': 'checklist', 'headingTitle': 'Checklist'}}),
]
VIEWER_OK = {'canComment': True, 'reason': 'ok'}


def comments_body(items, viewer=VIEWER_OK):
    return {'comments': items, 'threadChannelId': 'thread-att-1', 'viewer': viewer}


ATTACHMENT_IDS = [i['id'] for i in IMAGES] + [d[0]['id'] for d in DOCS.values()] + [HTML['id']]
routes = {}
for image in IMAGES:
    routes[f'GET /attachments/{image["id"]}/url'] = {'url': image['url'], 'expiresAt': None}
for aid in ATTACHMENT_IDS:
    routes[f'GET /attachments/{aid}/comments'] = comments_body(COMMENTS)

# Public, identical logical input for both real clients. No preview URL,
# local preview or cached original can conceal the wait for its address.
PENDING_SPINNER = {
    'image': att('att-spinner-address-289', 'waiting-address.png', 'image/png', 48211,
                 width=640, height=400),
    'queryPath': '/attachments/att-spinner-address-289/url',
}

route_sets = {
    'comments-empty': {f'GET /attachments/{aid}/comments': comments_body([]) for aid in ATTACHMENT_IDS},
    'comments-pending': {f'GET /attachments/{aid}/comments': {'$pending': True} for aid in ATTACHMENT_IDS},
    'comments-blocked': {f'GET /attachments/{aid}/comments': comments_body(
        COMMENTS[:2], {'canComment': False, 'reason': 'read_only'}) for aid in ATTACHMENT_IDS},
    'comments-error': {f'GET /attachments/{aid}/comments': {'$status': 500} for aid in ATTACHMENT_IDS},
    'image-pending': {f'GET /attachments/{i["id"]}/url': {'$pending': True} for i in IMAGES},
    'image-error': {f'GET /attachments/{i["id"]}/url': {'$status': 500} for i in IMAGES},
}

fixture = {
    'name': 'raft-flutter parity extension: attachment previews',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'parent': PARENT,
    'images': IMAGES,
    'documents': {k: {'attachment': a, 'preview': p, 'truncated': t} for k, (a, p, t) in DOCS.items()},
    'html': HTML,
    'comments': COMMENTS,
    'routes': routes,
    'routeSets': route_sets,
    'pendingSpinner': PENDING_SPINNER,
}

# ------------------------------------------------------------------- the cases
cases = []


def add(surface, title, props, *, platform='desktop', selector=ROOT, crop='viewport', contract='viewport-with-portal',
        interactions=(), android=(), notes=None, hint='packages/web/src/components/message/attachmentPreviewSurfaces.tsx'):
    viewport = DESKTOP if platform == 'desktop' else MOBILE
    suffix_platform = '' if platform == 'desktop' else '.mobile'
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{surface}{suffix_platform}.{suffix}'
        capture = {'selector': selector.replace('{id}', cid), 'crop': crop, 'contract': contract,
                   'interactions': list(interactions), 'androidInteractions': list(android)}
        c = {
            'id': cid,
            'title': f'Attachment preview {surface} {platform} {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'attachment-preview',
            'category': 'extension/thread-attachments',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': {
                'extCase': f'{surface}{suffix_platform}', 'extKind': 'threadattachment', 'parityTheme': theme,
                'platform': platform, **props}}],
            'capture': capture,
            'reactPathHint': hint,
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_thread_attachments.dart '{surface}{suffix_platform}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if notes:
            c['notes'] = notes
        cases.append(c)


WAIT = {'type': 'wait', 'ms': 600}
OPEN_PREVIEW_COMMENTS = [{'type': 'click', 'target': '[data-message-affordance="attachment-preview-mode"]'}, WAIT]
OPEN_PREVIEW_COMMENTS_ANDROID = [{'type': 'tap', 'key': 'attachment-preview-mode'}, {'type': 'wait', 'ms': 600}]

# image lightbox (ImageLightbox.tsx) -------------------------------------------
IMG = 'packages/web/src/components/ImageLightbox.tsx'
add('image.single', 'single image', {'host': 'image', 'images': '1', 'index': '0'}, hint=IMG)
# Flutter has no previous/next arrows (owner decision 2026-10-13: thumbnails, keys and swipe), so the React page
# hides them (host/ThreadAttachmentCases.tsx hideArrows) and the cases compare counter, strip and stage.
add('image.gallery', 'gallery 2/3: counter and thumbnails, Web arrows hidden', {'host': 'image', 'images': '3', 'index': '1', 'hideArrows': '1'},
    hint=IMG)
add('image.gallery-first', 'gallery 1/3: counter and thumbnails, Web arrows hidden', {'host': 'image', 'images': '3', 'index': '0', 'hideArrows': '1'},
    hint=IMG)
add('image.header', 'title bar, long file name and counter in a gallery', {'host': 'image', 'images': '3', 'index': '1'},
    selector=HEADER, crop='element', contract='component-bounds', hint=IMG)
add('image.loading', 'full image still loading', {'host': 'image', 'images': '1', 'index': '0', 'routeSet': 'image-pending'},
    hint=IMG)
add('image.pending-address-no-preview', 'waiting for the download address, no preview',
    {'host': 'image', 'images': '1', 'index': '0', 'pendingSpinner': '1', 'machineryRev': 'spinner-address-289-v2-qualified-cleanup'}, hint=IMG,
    notes='Actual address query pending, no thumbnail/localPreview/cache. Not image byte transfer. '
          'Current Flutter missing Spinner is a product-state gap, not a successful Spinner capture.')
add('image.error', 'full image failed to load', {'host': 'image', 'images': '1', 'index': '0', 'routeSet': 'image-error'},
    hint=IMG)
add('image.single', 'single image', {'host': 'image', 'images': '1', 'index': '0'}, platform='mobile', hint=IMG)
add('image.gallery', 'gallery 2/3, Web arrows hidden', {'host': 'image', 'images': '3', 'index': '1', 'hideArrows': '1'}, platform='mobile',
    hint=IMG)

# document host (DocumentPreviewHost + AttachmentPreviewShell) -------------------
DOC = 'packages/web/src/components/message/DocumentPreviewHost.tsx + attachmentPreviewSurfaces.tsx'
for kind in ['text', 'csv', 'xlsx', 'markdown']:
    add(f'doc.{kind}', f'{kind} preview', {'host': 'document', 'doc': kind}, hint=DOC)
add('doc.header', 'header, copy action', {'host': 'document', 'doc': 'text'}, selector=HEADER, crop='element',
    contract='component-bounds', hint=DOC)
add('doc.header-long', 'header, long file name', {'host': 'document', 'doc': 'long'}, selector=HEADER, crop='element',
    contract='component-bounds', hint=DOC)
add('doc.header-pdf', 'header, pdf (no copy, no comments)', {'host': 'document', 'doc': 'pdf'}, selector=HEADER,
    crop='element', contract='component-bounds', hint=DOC)
add('doc.comments', 'text preview with the comments panel', {'host': 'document', 'doc': 'text'},
    interactions=OPEN_PREVIEW_COMMENTS, android=OPEN_PREVIEW_COMMENTS_ANDROID, hint=DOC)
add('doc.text', 'text preview', {'host': 'document', 'doc': 'text'}, platform='mobile', hint=DOC)
add('doc.csv', 'csv preview', {'host': 'document', 'doc': 'csv'}, platform='mobile', hint=DOC)

# html host (MediaPreviewHost) --------------------------------------------------
HTML_HINT = 'packages/web/src/components/message/MediaPreviewHost.tsx + attachmentPreviewSurfaces.tsx'
add('html.preparing', 'sandboxed preview still preparing', {'host': 'html'}, hint=HTML_HINT)
add('html.header', 'header with comments toggle', {'host': 'html'}, selector=HEADER, crop='element',
    contract='component-bounds', hint=HTML_HINT)
add('html.preparing', 'sandboxed preview still preparing', {'host': 'html'}, platform='mobile', hint=HTML_HINT)

# comments panel (AttachmentCommentsPanel) -------------------------------------
PANEL = 'packages/web/src/components/message/AttachmentCommentsPanel.tsx'
PANEL_SEL = "[data-visual-case='{id}']"
for state, route_set in [('list', ''), ('empty', 'comments-empty'), ('loading', 'comments-pending'),
                         ('blocked', 'comments-blocked'), ('error', 'comments-error')]:
    add(f'comments.{state}', f'{state} (320px aside column)',
        {'host': 'panel', 'doc': 'text', 'routeSet': route_set}, selector=PANEL_SEL, crop='element',
        contract='component-bounds', hint=PANEL)
add('comments.list', 'list (full-width sheet)', {'host': 'panel', 'doc': 'text', 'routeSet': ''}, platform='mobile',
    selector=PANEL_SEL, crop='element', contract='component-bounds', hint=PANEL)

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/threadattachments.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} thread attachment cases appended -> the run-time manifest ($PARITY_EXT_MANIFEST); '
      'fixture -> tool/parity-ext/fixtures/threadattachments.json')
