#!/usr/bin/env python3
"""Append the channel / DM settings drawer cases to the run-time manifest ($PARITY_EXT_MANIFEST) and
write tool/parity-ext/fixtures/channelsettings.json.

Run after build-cases.py, build-live-activity.py, build-channel-header.py and
build-announcements.py; idempotent: every `components.channelsettings.*` case is
replaced, all other cases are kept in place (append-only for other families).

Derivation (raft-source 26f77ef, packages/web/src):
  components/message/ChatPanel.tsx          decides which props ChannelOverflowMenu gets
                                             (settings only if joined && (canManageChannels
                                             || canLeave); activityMute / collapse prefs;
                                             stop-all-agents only if joined && controlAgentRuntime)
  components/channel/ChannelOverflowMenu.tsx  drawer: identity header, MembersStrip,
                                             EditChannelDialog panel, DM preferences, unsaved prompt
  components/ui/OverflowSheet.tsx           Drawer shell (544px right sheet, mobile full page)
  components/channel/EditChannelDialog.tsx  Info form, Guest access, preferences, lifecycle zone,
                                             ConfirmDialogs
  components/channel/ChannelPreferencesSection.tsx
  components/ConfirmDialog.tsx              raft-ui Dialog ([data-slot="dialog-content"])
Ids: components.channelsettings.<platform>.<state>.<theme>.

Fixture contract (tool/parity-ext/fixtures/channelsettings.json, read by both providers):
  channels[] / dms[]  the store rows, incl. `channelCapabilities` exactly as GET /channels
                      returns them for the viewer (the 9 channel-management capabilities)
  routes              "METHOD /path" -> JSON body (members, notification-settings,
                      message-display-settings per channel id, thread followers)
  routeSets           per-case overrides selected by props.routeSet
  case props          channel (id), role (viewer's server role: owner/admin/member/guest),
                      guestFlag ('true' = server_guest flag on), pinned ('true' = channel is in
                      sidebarOrder.pinned), routeSet
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
PREFIX = 'components.channelsettings.'
SID = 'visual-server'
CREATED = '2026-06-18T00:00:00.000Z'
ARCHIVED = '2026-06-19T00:00:00.000Z'

SHORT = 'Visual testing release gates'
LONG = ('日语 lost and found 单词 App 结合了 crowded scene 的特性: every channel description that is longer '
        'than the drawer header can show is truncated to one line, so this sentence keeps going with more '
        'release notes, review links, owners, and the reasons the team created the channel in the first '
        'place, until it is far longer than the drawer is wide at any desktop or mobile width.')
NEWLINE = 'line one\nline two'

CAPS = ['editChannelMetadata', 'archiveChannels', 'deleteChannels', 'changeChannelVisibility',
        'manageGuestAccess', 'federateChannels', 'addChannelMembers', 'removeChannelMembers',
        'changeChannelMemberRoles']

# ---------------------------------------------------------------- people
OWNER = {'id': 'visual-user', 'name': 'artin', 'displayName': 'artin', 'description': 'Owner'}
DESIGNER = {'id': 'visual-human-designer', 'name': 'designer', 'displayName': 'Designer', 'description': 'Product design'}
JIACHENG = {'id': 'visual-human-jiacheng', 'name': 'jiacheng', 'displayName': 'Jiacheng', 'description': 'Android'}
MORE_NAMES = ['Ava Chen', 'Ben Ortiz', 'Chloe Park', 'Dmitri Volkov', 'Elena Rossi', 'Farid Haddad', 'Grace Liu',
              'Hiro Tanaka', 'Isla Murphy', 'Jonas Weber', 'Keiko Mori', 'Liam Walsh', 'Maya Patel',
              'Noah Fischer', 'Olivia Santos', 'Pavel Novak', 'Quinn Adams', 'Rhea Kapoor', 'Sven Larsen',
              'Tara Singh', 'Uma Reddy', 'Victor Hugo', 'Wen Zhao', 'Xavier Lopez', 'Yara Haddad', 'Zane Cooper',
              'Amara Okafor', 'Bruno Costa', 'Chiara Bianchi', 'Dev Malhotra']
AGENTS = [
    {'id': 'agent-cindy', 'name': 'Cindy', 'displayName': 'Cindy', 'avatarUrl': 'pixel:robot',
     'description': 'Keeps visual testing release notes aligned.', 'activity': 'working',
     'activityDetail': 'Capturing visual testing baselines'},
    {'id': 'agent-product-ux', 'name': 'Product-UX-Designer', 'displayName': 'Product UX Designer',
     'avatarUrl': 'pixel:robot', 'description': 'Turns product feedback into UX specs.', 'activity': 'online',
     'activityDetail': 'Reviewing screenshots'},
    {'id': 'agent-android-dev-4', 'name': 'Android-Developer-4', 'displayName': 'Android Developer 4',
     'avatarUrl': 'pixel:robot', 'description': 'Implements shared Android/KMP UI fixes.', 'activity': 'working',
     'activityDetail': 'Running Android visual captures'},
    {'id': 'agent-builder', 'name': 'Builder', 'displayName': 'Builder', 'avatarUrl': 'pixel:robot',
     'description': 'File and repo automation', 'activity': 'working', 'activityDetail': 'Automating file workflows'},
]


def human(p, role, viewer_role):
    # The viewer's own row carries the viewer's server role (canUseChannelMemberAction reads it).
    r = viewer_role if p['id'] == OWNER['id'] else role
    return {'id': p['id'], 'serverId': SID, 'name': p['name'], 'displayName': p['displayName'],
            'description': p['description'], 'avatarUrl': None, 'gravatarHash': '', 'role': r, 'serverRole': r,
            'channelRole': 'member', 'effectiveChannelRole': 'admin' if r in ('owner', 'admin') else 'member',
            'channelAdminBasis': 'server_role' if r in ('owner', 'admin') else None,
            'canChangeChannelRole': False}


def agent(a):
    return {'id': a['id'], 'serverId': SID, 'name': a['name'], 'displayName': a['displayName'],
            'avatarUrl': a['avatarUrl'], 'description': a['description'], 'status': 'active',
            'serverRole': 'member', 'channelRole': 'member', 'effectiveChannelRole': 'member',
            'channelAdminBasis': None, 'canChangeChannelRole': False, 'model': 'gpt-5-codex', 'runtime': 'codex',
            'reasoningEffort': 'medium', 'executionMode': 'byoc', 'envVars': {}, 'machineId': 'computer-mbp',
            'sessionId': f"session-{a['id']}", 'runtimeProfile': None, 'creatorType': 'user',
            'creatorId': OWNER['id'], 'creator': None, 'createdAgents': [], 'deletedAt': None, 'createdAt': CREATED,
            'activity': a['activity'], 'activityDetail': a['activityDetail']}


def members(viewer_role, many=False):
    people = [OWNER, DESIGNER, JIACHENG]
    agents = AGENTS[:2]
    if many:
        people += [{'id': f'visual-human-extra-{i:02d}', 'name': n.lower().replace(' ', '.'), 'displayName': n,
                    'description': None} for i, n in enumerate(MORE_NAMES, 1)]
        agents = AGENTS
    return {'agents': [agent(a) for a in agents],
            'humans': [human(p, 'member', viewer_role) for p in people], 'externalMembers': []}


def capabilities(role, *, joined, name, ctype, archived):
    addable = ctype in ('channel', 'private') and name != 'all' and not archived
    if role in ('owner', 'admin'):
        caps = {c: True for c in CAPS}
        caps['addChannelMembers'] = addable
    elif role == 'member':
        caps = {c: False for c in CAPS}
        caps['addChannelMembers'] = addable and joined
    else:
        caps = {c: False for c in CAPS}
    return caps


channels = []
dms = []
routes = {'GET /channels/threads/followers': {'threads': []},
          # Feature-flag evaluation (the host seeds the resolved flags; this keeps a stray read from hanging).
          'POST /feature-flags/evaluate': {'evaluations': []}}
route_sets = {}


def channel(cid, name='colvalley', description=SHORT, *, role='owner', ctype='channel', joined=True, archived=False,
            many=False, mute=False, collapse=True, **extra):
    row = {'id': cid, 'serverId': SID, 'name': name, 'description': description, 'type': ctype,
           'createdAt': CREATED, 'joined': joined,
           # GET /channels carries `activityMuteSupported` (channelTypeSupportsActivityMute);
           # the Web store derives it from the type, the Flutter client reads the wire flag.
           'activityMuteSupported': ctype in ('channel', 'private', 'joint'),
           'channelCapabilities': capabilities(role, joined=joined, name=name, ctype=ctype, archived=archived)}
    if archived:
        row['archivedAt'] = ARCHIVED
    row.update(extra)
    channels.append(row)
    routes[f'GET /channels/{cid}/members'] = members(role, many)
    routes[f'GET /tasks/channel/{cid}'] = []
    if joined:
        routes[f'GET /channels/{cid}/notification-settings'] = {
            'activityMuted': mute, 'muteFromSeq': None, 'activityMuteSupported': True, 'prefsVersion': 0}
        routes[f'GET /channels/{cid}/message-display-settings'] = {'collapseLongMessages': collapse, 'prefsVersion': 0}
    return cid


def dm(cid, peer_type, peer_id, peer_name, peer_display, avatar):
    dms.append({'id': cid, 'serverId': SID, 'name': cid, 'description': None, 'type': 'dm', 'createdAt': CREATED,
                'joined': True, 'peerType': peer_type, 'peerId': peer_id, 'peerName': peer_name,
                'peerDisplayName': peer_display, 'peerAvatarUrl': avatar, 'peerGravatarHash': None
                } if peer_type == 'user' else
               {'id': cid, 'serverId': SID, 'name': cid, 'description': None, 'type': 'dm', 'createdAt': CREATED,
                'joined': True, 'peerType': peer_type, 'peerId': peer_id, 'peerName': peer_name,
                'peerDisplayName': peer_display, 'peerAvatarUrl': avatar})
    routes[f'GET /channels/{cid}/members'] = {'agents': [], 'humans': [], 'externalMembers': []}
    routes[f'GET /tasks/channel/{cid}'] = []
    routes[f'GET /channels/{cid}/message-display-settings'] = {'collapseLongMessages': True, 'prefsVersion': 0}
    return cid


C = {
    'owner': channel('channel-cs-owner'),
    'prefs': channel('channel-cs-prefs', mute=True, collapse=False),
    'newline': channel('channel-cs-newline', description=NEWLINE),
    'nodesc': channel('channel-cs-nodesc', description=None),
    'longdesc': channel('channel-cs-longdesc', description=LONG),
    'guest': channel('channel-cs-guest-access', guestVisible=True, guestJoinable=False),
    'admin': channel('channel-cs-admin', role='admin'),
    'member': channel('channel-cs-member', role='member'),
    'guestrole': channel('channel-cs-guest-role', role='guest', guestJoinable=True),
    'private': channel('channel-cs-private', name='colvalley-private', ctype='private'),
    'archived': channel('channel-cs-archived', archived=True),
    'all': channel('channel-cs-all', name='all', description='Everyone in the server'),
    'notjoined': channel('channel-cs-not-joined', role='member', joined=False),
    'many': channel('channel-cs-many', many=True),
    'loading': channel('channel-cs-loading'),
}
# RFC 075: a joint channel (Web EditChannelDialog `channel-settings-joint-section`): the Connected servers
# list with plan and status badges, Resend Invite (this server has an invitation out), the invitation form,
# and Disconnect Channel in place of Delete Channel.
C['joint'] = channel('channel-cs-joint', name='partners', description='Shared with partner servers', ctype='joint',
                     jointChannelId='joint-cs-1', jointRole='host', jointPeerServerId='server-acme',
                     jointPeerServerName='Acme Partners', jointPeerServerSlug='acme-partners',
                     jointPeerStatus='active',
                     jointServers=[
                         {'serverId': SID, 'serverName': 'Visual Server', 'serverSlug': 'visual-server',
                          'role': 'host', 'status': 'active', 'isCurrentServer': True, 'plan': 'free'},
                         {'serverId': 'server-acme', 'serverName': 'Acme Partners', 'serverSlug': 'acme-partners',
                          'role': 'participant', 'status': 'active', 'isCurrentServer': False, 'plan': 'paid'},
                         {'serverId': 'server-globex', 'serverName': 'Globex', 'serverSlug': 'globex',
                          'role': None, 'status': 'pending', 'plan': 'free'}],
                     jointPendingInvites=[{'id': 'invite-globex', 'jointChannelId': 'joint-cs-1',
                                           'fromServerId': SID, 'toServerId': 'server-globex',
                                           'serverName': 'Globex', 'serverSlug': 'globex', 'status': 'pending'}])
C['dm-agent'] = dm('dm-cs-agent-cindy', 'agent', 'agent-cindy', 'Cindy', 'Cindy', 'pixel:robot')
C['dm-human'] = dm('dm-cs-human-designer', 'user', 'visual-human-designer', 'designer', 'Designer', None)

# Members request stays in flight (loading skeleton tiles, "Loading..." summary, add tile disabled).
route_sets['members-loading'] = {f"GET /channels/{C['loading']}/members": {'$pending': True}}

fixture = {
    'name': 'raft-flutter parity extension: channel / DM settings drawer',
    'scope': 'Public deterministic test data; no credentials.',
    'sourceCommit': '26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6',
    'channels': channels,
    'dms': dms,
    'routes': routes,
    'routeSets': route_sets,
}

# ---------------------------------------------------------------- interactions
OPEN = [{'type': 'click', 'target': '[data-testid="channel-overflow-trigger"]'}, {'type': 'wait', 'ms': 500}]
OPEN_A = [{'type': 'tap', 'key': 'channel-overflow-trigger'}, {'type': 'wait', 'ms': 500}]
FILL = [{'type': 'fill', 'target': '#channel-settings-name', 'value': 'colvalley-renamed'},
        {'type': 'fill', 'target': '#channel-settings-description', 'value': 'Release gates and review links'}]
BLUR = [{'type': 'click', 'target': '[data-testid="channel-settings-manage-group"]'}]
# `scroll: False`: the heading is already on screen (Playwright does not scroll then).
BLUR_A = [{'type': 'tap', 'key': 'channel-settings-manage-group', 'scroll': False}]
FILL_A = [{'type': 'enter', 'key': 'channel-settings-name', 'value': 'colvalley-renamed'},
          {'type': 'enter', 'key': 'channel-settings-description', 'value': 'Release gates and review links'}]


def action(testid):
    return ([{'type': 'click', 'target': f'[data-testid="{testid}"]'}, {'type': 'wait', 'ms': 400}],
            [{'type': 'tap', 'key': testid}, {'type': 'wait', 'ms': 400}])


SHEET = ('[data-testid="channel-overflow-sheet"]', 'channel-overflow-sheet')
CONFIRM = ('[data-slot="dialog-content"]', 'channel-settings-confirm-dialog')
UNSAVED = ('[data-testid="channel-overflow-unsaved-prompt"]', 'channel-overflow-unsaved-prompt')

cases = []


def add(platform, state, title, channel_id, *, role='owner', guest=False, route_set=None, target=SHEET,
        extra=(), extra_android=(), notes=None, height=None, pinned=False):
    viewport = dict(DESKTOP if platform == 'desktop' else MOBILE)
    if height:
        viewport['height'] = height
    selector, android_key = target
    for suffix, theme in THEMES.items():
        cid = f'{PREFIX}{platform}.{state}.{suffix}'
        props = {'extCase': f'{platform}.{state}', 'extKind': 'channelsettings', 'parityTheme': theme,
                 'platform': platform, 'channel': channel_id, 'role': role, 'guestFlag': str(guest).lower()}
        if route_set:
            props['routeSet'] = route_set
        if pinned:
            props['pinned'] = 'true'
        c = {
            'id': cid,
            'title': f'Channel settings drawer {platform} {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'channel-settings',
            'category': 'extension/channel-settings',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': {'selector': selector, 'crop': 'element', 'contract': 'component-bounds',
                        'interactions': [*OPEN, *extra], 'androidInteractions': [*OPEN_A, *extra_android],
                        'androidKey': android_key},
            'reactPathHint': 'packages/web/src/components/channel/ChannelOverflowMenu.tsx + EditChannelDialog.tsx',
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_channel_settings.dart '{platform}.{state}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        }
        if notes:
            c['notes'] = notes
        cases.append(c)


for platform in ['desktop', 'mobile']:
    add(platform, 'owner', 'owner, public channel', C['owner'])
    add(platform, 'member', 'member (Leave only)', C['member'], role='member')
    add(platform, 'private', 'private channel (Make Public)', C['private'])
    add(platform, 'archived', 'archived channel (Unarchive, fields disabled)', C['archived'])
    add(platform, 'dirty', 'edited name and description (Cancel / Save enabled)', C['owner'],
        extra=[*FILL, *BLUR], extra_android=[*FILL_A, *BLUR_A])
    add(platform, 'dm-agent', 'agent DM (preferences only)', C['dm-agent'])
    add(platform, 'dm-human', 'human DM (preferences only)', C['dm-human'])
    delete, delete_a = action('channel-settings-delete-action')
    add(platform, 'confirm-delete', 'delete confirmation', C['owner'], target=CONFIRM,
        extra=delete, extra_android=delete_a)

add('desktop', 'owner-newline', 'description with an authored newline', C['newline'])
add('desktop', 'owner-nodesc', 'no description', C['nodesc'])
add('desktop', 'joint', 'joint channel (connected servers, invitation, Disconnect)', C['joint'], height=1500)
add('desktop', 'owner-longdesc', 'long single-line description', C['longdesc'])
add('desktop', 'owner-prefs', 'pin, mute on, collapse off', C['prefs'], pinned=True)
add('desktop', 'owner-guest', 'Guest access section (server_guest flag on)', C['guest'], guest=True)
add('desktop', 'admin', 'admin', C['admin'], role='admin')
add('desktop', 'guest', 'guest-role viewer', C['guestrole'], role='guest')
add('desktop', 'all', '#all channel', C['all'])
add('desktop', 'not-joined', 'channel not joined (member)', C['notjoined'], role='member')
add('desktop', 'members-overflow', 'many members (+N tile and add tile)', C['many'])
add('desktop', 'members-loading', 'members still loading', C['loading'], route_set='members-loading')

# Tall windows (the sheet is 100dvh) so the sections below the plain-viewport fold are visible.
# Height = lowest content edge measured in the React render + ~50px of drawer bottom padding.
add('desktop', 'owner-full', 'owner, tall window (every section)', C['owner'], height=1080)
add('desktop', 'owner-newline-full', 'newline description, tall window', C['newline'], height=1080)
add('desktop', 'dirty-full', 'edited draft, tall window', C['owner'], height=1080,
    extra=[*FILL, *BLUR], extra_android=[*FILL_A, *BLUR_A])
add('desktop', 'owner-guest-full', 'Guest access, tall window', C['guest'], guest=True, height=1290)
add('desktop', 'admin-full', 'admin, tall window', C['admin'], role='admin', height=1080)
add('desktop', 'private-full', 'private channel, tall window', C['private'], height=1080)
add('desktop', 'archived-full', 'archived channel, tall window', C['archived'], height=880)
add('desktop', 'all-full', '#all channel, tall window', C['all'], height=980)
add('desktop', 'members-overflow-full', 'many members, tall window', C['many'], height=1160)
add('mobile', 'owner-full', 'owner, tall window (every section)', C['owner'], height=1110)
add('mobile', 'private-full', 'private channel, tall window', C['private'], height=1110)
add('mobile', 'archived-full', 'archived channel, tall window', C['archived'], height=890)
add('mobile', 'dirty-full', 'edited draft, tall window', C['owner'], height=1110,
    extra=[*FILL, *BLUR], extra_android=[*FILL_A, *BLUR_A])

# The drawer-internal members page (ChannelMembers presentation="page" mounted `bare` in the OverflowSheet):
# opened from the MembersStrip heading row, or straight into the add view from the dashed + tile.
members_page, members_page_a = action('channel-overflow-members-entry')
members_add, members_add_a = action('channel-overflow-members-add-tile')
PAGE = ('[data-testid="member-page"]', 'member-page')
add('desktop', 'members-page', 'members page (roster)', C['owner'], extra=members_page, extra_android=members_page_a)
add('desktop', 'members-page-add', 'members page, add view', C['owner'], extra=members_add, extra_android=members_add_a)
add('desktop', 'members-page-many', 'members page, 35 members (scrolling roster)', C['many'], extra=members_page,
    extra_android=members_page_a)
add('mobile', 'members-page', 'members page (roster)', C['owner'], target=PAGE, extra=members_page,
    extra_android=members_page_a)

leave, leave_a = action('channel-overflow-leave')
add('desktop', 'confirm-leave', 'leave confirmation', C['member'], role='member', target=CONFIRM,
    extra=leave, extra_android=leave_a)
archive, archive_a = action('channel-settings-archive-action')
add('desktop', 'confirm-archive', 'archive confirmation', C['owner'], target=CONFIRM,
    extra=archive, extra_android=archive_a)
visibility, visibility_a = action('channel-settings-visibility-action')
add('desktop', 'confirm-visibility', 'make private confirmation', C['owner'], target=CONFIRM,
    extra=visibility, extra_android=visibility_a)
add('desktop', 'confirm-hide-all', 'hide #all confirmation', C['all'], target=CONFIRM,
    extra=visibility, extra_android=visibility_a)
add('desktop', 'unsaved-prompt', 'unsaved changes prompt (outside press while dirty)', C['owner'], target=UNSAVED,
    extra=[*FILL, {'type': 'click', 'target': '[data-slot="drawer-viewport"]'}, {'type': 'wait', 'ms': 400}],
    extra_android=[*FILL_A, {'type': 'tap', 'key': 'channel-overflow-scrim'}, {'type': 'wait', 'ms': 400}],
    notes='Desktop hides the X; the guarded close is hit by pressing the scrim (drawer-viewport, centre of the page) left of the drawer.')

manifest_out = manifest_path()
manifest = json.loads(manifest_out.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
manifest_out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
(here / 'fixtures/channelsettings.json').write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} channel settings cases appended -> the run-time manifest ($PARITY_EXT_MANIFEST); '
      'fixture -> tool/parity-ext/fixtures/channelsettings.json')
