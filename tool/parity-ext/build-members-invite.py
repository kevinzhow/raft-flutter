#!/usr/bin/env python3
"""The members page's external-invite surfaces, and the channel preferences block whose read failed.

Run after build-channel-settings.py (ORDER below): every case copies one of its
`components.channelsettings.*` cases, so both providers mount the same drawer, and only the
fixture changes. Idempotent: every `components.members-invite.*` case is replaced, the rest kept.
Writes tool/parity-ext/fixtures/members-invite.json = the channel-settings fixture plus the
external-invite reads, so the channel-settings cases themselves keep their captures.

Ids: components.members-invite.<phone|fold>.<key>.<theme>
React: tool/parity-ext/host/MembersInviteCases.tsx (ParityExtCsView's drawer, sized from the viewport).
Flutter: apps/raft_flutter/test/parity/cases/ext_members_invite.dart (the channel-settings case,
this fixture).

Web (packages/web/src):
  components/channel/ExternalInviteRows.tsx       an invite IS a ChannelMemberRow (Mail tile, state
                                                 after the email, Resend / Withdraw on hover)
  features/channel/ChannelMembers.tsx:729-743     the failed-read notice above the group
  features/channel/ChannelMembers.tsx:1120-1128   MemberPageSection kind="invited", above Humans
  features/channel/ChannelMembers.tsx:1187-1219   the pinned footer: Add member + Invite people outside
  features/channel/ChatPanel.tsx:505-514          the named preference read that failed, and its Retry

Why the invites expire in the past: Playwright freezes the React clock at the fixture instant while the
Flutter case mounts the real app on the real clock. Both ends floor the days left at 1
(externalInviteDaysLeft, external_invite_channel_members.dart), so an expiry that is already past reads
"1 day left" on both, whatever day the capture runs on. Any future date would drift between them.
"""
ORDER = 1010

import copy
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)

THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
PREFIX = 'components.members-invite.'
FIXTURE_NAME = 'members-invite'
SRC = 'packages/web/src/'
# Kevin's screen classes (#raft-flutter:1f51a8b6): a phone and an unfolded foldable, not the
# 1280 desktop the channel-settings family already covers.
SIZES = {'phone': {'width': 412, 'height': 915, 'density': 2},
         'fold': {'width': 1124, 'height': 1240, 'density': 1}}
# The drawer's own platform: the foldable is one window wide enough for the side pane.
PLATFORM = {'phone': 'mobile', 'fold': 'desktop'}
# v1.24 renamed the drawer: the details are a ChannelDetailsSurface column
# (`channel-details`), not the v1.21 OverflowSheet the channel-settings family
# still selects, which is why those cases have no Web capture at this pin.
SHEET = ('[data-testid="channel-details"]', 'channel-overflow-sheet')
PAGE = ('[data-testid="member-page"]', 'member-page')

# ------------------------------------------------------------------ fixture

CS = json.loads((here / 'fixtures' / 'channelsettings.json').read_text())
FIXTURE = copy.deepcopy(CS)
FIXTURE['name'] = 'raft-flutter parity extension: channel members page external invites'
CID = 'channel-cs-owner'
PAST = '2026-01-05T00:00:00.000Z'

# One open invite of every kind the row draws (ExternalInviteRows.tsx:40-53).
INVITES = [
    {'id': 'invite-open', 'email': 'rosa@colvalley.example', 'awaitingApproval': False,
     'connecting': False, 'revocable': True, 'invitedBy': None,
     'createdAt': PAST, 'expiresAt': PAST},
    {'id': 'invite-approval', 'email': 'theo@partners.example', 'awaitingApproval': True,
     'connecting': False, 'revocable': True, 'invitedBy': None,
     'createdAt': PAST, 'expiresAt': PAST},
    {'id': 'invite-connecting', 'email': 'mina@globex.example', 'awaitingApproval': False,
     'connecting': True, 'connectPhase': 'conversion', 'revocable': False, 'invitedBy': None,
     'createdAt': PAST, 'expiresAt': PAST},
]
FIXTURE['routes'][f'GET /channels/{CID}/external-invites'] = {'invites': INVITES, 'slotsLeft': 1}
# The entry reads the free-plan slot before it opens (externalChannelSlot.ts:100-141).
FIXTURE['routes']['GET /channels/external-availability'] = {'freeLimitReached': False}
# Flutter resolves the flag over the API; the React host seeds the same answer into the store.
FIXTURE['routes']['POST /feature-flags/evaluate'] = {
    'evaluations': [{'key': 'external_channels_v1', 'enabled': True}]}

# The group's failed read: nothing cached, so Web draws its warning banner with Retry.
FIXTURE['routeSets']['invites-failed'] = {
    f'GET /channels/{CID}/external-invites': {'$status': 500, '$body': {'error': 'Internal Server Error'}}}

(here / 'fixtures' / f'{FIXTURE_NAME}.json').write_text(json.dumps(FIXTURE, indent=1, ensure_ascii=False) + '\n')

# ------------------------------------------------------------------ cases

# (key, title, base channel-settings state per size, route set)
# The preferences block has no `owner-prefs` case at mobile width, so the phone case takes the
# plain owner drawer, which draws the same preferences group.
CASES = [
    ('invited', 'Invited group and the pinned invite entry',
     {'phone': 'members-page', 'fold': 'members-page'}, None),
    ('invited-failed', 'Invited group: the invite read failed',
     {'phone': 'members-page', 'fold': 'members-page'}, 'invites-failed'),
    ('prefs', 'details preferences block',
     {'phone': 'owner', 'fold': 'owner-prefs'}, None),
]


def cases_for(key, title, states, route_set):
    out = []
    for size, viewport in SIZES.items():
        platform, state = PLATFORM[size], states[size]
        # The members page is its own element on both; the drawer cases capture the whole sheet.
        selector, android_key = PAGE if state == 'members-page' else SHEET
        for suffix, theme in THEMES.items():
            base = BY_ID.get(f'components.channelsettings.{platform}.{state}.{suffix}')
            if base is None:
                continue
            case = copy.deepcopy(base)
            props = case['variants'][0]['props']
            props.update({'extCase': f'{size}.{key}', 'extKind': 'members-invite',
                          'extFixture': FIXTURE_NAME, 'platform': platform,
                          # Only this suite turns the flag on; the drawer cases keep it off.
                          'externalFlag': 'true'})
            if route_set:
                props['routeSet'] = route_set
            else:
                props.pop('routeSet', None)
            case['capture']['selector'] = selector
            case['capture']['androidKey'] = android_key
            case.update({
                'id': f'{PREFIX}{size}.{key}.{suffix}',
                'title': f'Channel {title} ({size}, {theme})',
                'viewport': dict(viewport),
                'surface': 'members-invite',
                'category': 'extension/members-invite',
                'reactPathHint': SRC + ('components/channel/ExternalInviteRows.tsx + '
                                        'features/channel/ChannelMembers.tsx'
                                        if state == 'members-page'
                                        else 'components/channel/ChannelPreferencesSection.tsx'),
                'androidCaseHint': (f"apps/raft_flutter/test/parity/cases/ext_members_invite.dart "
                                    f"'{size}.{key}' (base: {base['id']})"),
            })
            out.append(case)
    return out


path = manifest_path()
manifest = json.loads(path.read_text())
BY_ID = {c['id']: c for c in manifest['cases']}
cases = []
for row in CASES:
    cases += cases_for(*row)
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} members-invite cases appended ({len(manifest["cases"])} total)')
