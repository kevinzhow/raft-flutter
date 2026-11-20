#!/usr/bin/env python3
"""Settings Applications interactions driven by the same API responses on both clients."""
import json
from copy import deepcopy
from pathlib import Path

from builders import manifest_path


PREFIX = 'components.apps.'
FIXTURES = Path(__file__).resolve().parent / 'fixtures'
settings = json.loads((FIXTURES / 'settings.json').read_text())
marketplace = settings['routes']['GET /integrations/marketplace']
permissions_path = 'GET /integrations/marketplace/market_github/install/app-notifications'
permissions = settings['routes'][permissions_path]
marketplace[1]['permissionApprovalRequired'] = True
permissions.update({
    'approval_required': True,
    'requested_scopes': ['openid', 'profile', 'agent:read'],
    'new_scopes': ['agent:read'],
    'requested_groups': ['server'],
})
prompt_listing = {
    **marketplace[0],
    'promptTextRevisionId': 'live',
    'whenToUse': 'Summarize Slack conversations.',
}
prompt_revisions = {
    'can_review': True,
    'current': {'id': 'live', 'name': prompt_listing['name'],
                'when_to_use': prompt_listing['whenToUse']},
    'pending': {'id': 'submitted', 'name': prompt_listing['name'],
                'when_to_use': 'Summarize Slack conversations for this server.'},
}
slack_path = '/slack-bridge/provisioning'
slack_healthy = {
    'protocolVersion': 1,
    'oauthAuthority': None,
    'snapshot': {
        'stage': 'health',
        'workspaceName': 'Fixture Slack',
        'raftChannels': [{'id': 'r1', 'name': 'general'}],
        'slackChannels': [{'id': 's1', 'name': 'general', 'isMember': True,
                           'privacyClass': 'public'}],
        'channelPairs': [{'raftChannelId': 'r1', 'slackChannelId': 's1',
                          'bindingEpoch': 7}],
        'preflight': None,
        'rawHealth': {
            'install': {'state': 'active', 'epochs': {
                'grant': '2', 'connection': '4', 'scope': '3', 'credential': '5',
            }},
            'credential': {'state': 'active'},
            'bindings': [{'id': 'b1', 'state': 'active', 'bindingEpoch': 7,
                          'stateReason': None, 'recoveryAction': 'none'}],
            'audiences': [{'bindingId': 'b1', 'status': 'matched'}],
            'lastVerifiedAt': '2026-10-08T00:00:00Z',
            'agentMentionSync': None,
            'failingSurface': None,
        },
    },
}
slack_recovery = deepcopy(slack_healthy)
slack_recovery['snapshot']['rawHealth'].update({
    'outboundDeliveries': [{
        'raftChannelId': 'r1', 'bindingId': 'b1', 'bindingEpoch': 7,
        'deliveryId': 'delivery-1', 'providerAttempts': 2,
        'state': 'outcome_unknown', 'retryRequested': False,
    }],
    'inboundIsolated': [{
        'raftChannelId': 'r1', 'bindingId': 'b1', 'bindingEpoch': 7,
        'eventId': 'event-1', 'reason': 'actor_identity_pending',
        'firstFailureAt': None, 'heldAt': None,
    }],
})
routes = {
    **{key: value for key, value in settings['routes'].items()
       if key.startswith('GET /integrations/')},
    'GET /mcp/apps': {'apps': []},
    'GET /integrations/marketplace/listings': {
        'items': [{'kind': 'app', 'id': f'app:{app["id"]}', 'app': app,
                   'installed': app['installedAt'] is not None} for app in marketplace],
        'total': len(marketplace),
    },
    'GET /integrations/permission-updates': {'count': 1, 'needsAdminReview': True},
    'GET /integrations/link-preview-consents': {
        'allowed': [{'app': {'id': 'market_github', 'name': 'GitHub Issues', 'icon': None},
                     'granted_at': marketplace[1]['installedAt']}],
        'declined': [],
    },
}
route_sets = {
    'loading': {'GET /integrations/clients': {'$pending': True}},
    'empty': {'GET /integrations/clients': [], 'GET /integrations/marketplace': [],
              'GET /integrations/overview': [],
              'GET /integrations/permission-updates': {'count': 0, 'needsAdminReview': False}},
    'error': {'GET /integrations/clients': {'$status': 503}},
    'partial': {'GET /mcp/apps': {'$status': 503}},
    'link-previews-loading': {'GET /integrations/link-preview-consents': {'$pending': True}},
    'link-previews-empty': {'GET /integrations/link-preview-consents': {'allowed': [], 'declined': []}},
    'link-previews-error': {'GET /integrations/link-preview-consents': {'$status': 503}},
    'prompt-review': {
        'GET /integrations/marketplace': [prompt_listing, *marketplace[1:]],
        'GET /integrations/marketplace/listings': {
            'items': [{'kind': 'app', 'id': f'app:{app["id"]}', 'app': app,
                       'installed': app['installedAt'] is not None}
                      for app in [prompt_listing, *marketplace[1:]]],
            'total': len(marketplace),
        },
        'GET /integrations/clients/market_slack/prompt-text': prompt_revisions,
    },
    'slack-healthy': {f'GET {slack_path}': slack_healthy},
    'slack-recovery': {f'GET {slack_path}': slack_recovery},
    'slack-unavailable': {f'GET {slack_path}': {
        '$status': 503, '$body': {'ok': False, 'code': 'slack_bridge_provider_unavailable'},
    }},
}
(FIXTURES / 'apps.json').write_text(json.dumps({'routes': routes, 'routeSets': route_sets}, indent=1) + '\n')


def tap(test_id, key=None):
    return (
        {'type': 'click', 'target': f'[data-testid="{test_id}"]'},
        {'type': 'tap', 'key': key or test_id},
    )


def tap_text(text, target):
    return (
        {'type': 'click', 'target': target},
        {'type': 'tapText', 'text': text},
    )


def scope(tab, value):
    return (
        {'type': 'scope', 'target': f'connected-apps-tab-{tab}', 'value': value},
        {'type': 'tap', 'key': f'connected-apps-tab-{tab}'},
    )


def web_steps(steps, platform):
    for action, _ in steps:
        if action['type'] != 'scope':
            yield action
        elif platform == 'desktop':
            yield {'type': 'click', 'target': f'[data-testid="{action["target"]}"]'}
        else:
            yield {'type': 'click', 'target': '[data-testid="connected-apps-scope-select"]'}
            yield {'type': 'click', 'target': f'[data-testid="connected-apps-scope-select-{action["value"]}"]'}


market = scope('marketplace', 'marketplace')
detail = (
    {'type': 'click', 'target': 'button:has-text("Slack Bridge") >> nth=0'},
    {'type': 'tap', 'key': 'connected-app-market_slack'},
)
installed_detail = (
    {'type': 'click', 'target': '[data-testid="connected-app-item-market_github"] :is(button, [role="button"]):has-text("GitHub Issues")'},
    {'type': 'tap', 'key': 'connected-app-installed-market_github'},
)
manage_previews = tap('link-preview-consents-manage')
review_permissions = tap_text(
    'Review permissions',
    '[data-testid="connected-app-item-market_github"] button:has-text("Review permissions")',
)
revoke_preview = tap_text('Revoke', '[data-testid="link-preview-consents-allowed"] button:has-text("Revoke")')
reject_prompt = tap_text('Reject text update', '[data-testid="app-prompt-text-review"] button:has-text("Reject text update")')
edit_local_app = (
    {'type': 'click', 'target': '[data-testid="connected-apps-my-apps-collection"] button:has-text("Edit")'},
    {'type': 'tap', 'key': 'connected-app-action-client_1'},
)
cases = []


def case(group, state, selector, steps=(), *, route_set='', flags='', tab='integrations',
         verify_text=None, verify_key=None, absent_text=None):
    for platform, width, height in [('desktop', 1280, 900), ('mobile', 390, 844)]:
        for suffix, theme in [('raft', 'raft-light'), ('raft-dark', 'raft-dark')]:
            case_id = f'{PREFIX}{group}.{state}.{platform}.{suffix}'
            cases.append({
                'id': case_id,
                'title': f'Applications {state}, {platform} ({theme})',
                'captureType': 'real-screen',
                'surface': f'apps-{group}',
                'category': 'extension/apps',
                'suite': 'raft-flutter-extension',
                'viewport': {'width': width, 'height': height, 'density': 1},
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': {
                    'tab': tab, 'extKind': 'apps', 'extFixture': 'apps',
                    'platform': platform, 'parityTheme': theme, 'routeSet': route_set, 'flags': flags,
                    'verifyText': verify_text or '', 'verifyKey': verify_key or '',
                    'absentText': absent_text or '',
                }}],
                'capture': {
                    'selector': selector, 'crop': 'viewport', 'contract': 'viewport-with-portal',
                    'interactions': list(web_steps(steps, platform)),
                    'androidInteractions': [native for _, native in steps],
                },
                'reactPathHint': 'packages/web/src/features/apps/IntegrationsSection.tsx',
                'androidCaseHint': 'apps/raft_flutter/test/parity/cases/ext_apps.dart',
                'tolerance': {'pixelRatio': 0.04, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })


case('page', 'installed', '[data-testid="connected-apps-installed-collection"]',
     verify_text='GitHub Issues')
case('page', 'loading', '[data-testid="apps-loading"]', route_set='loading')
case('page', 'empty', '[data-testid="apps-installed-empty"]', route_set='empty')
case('page', 'error', '[data-testid="apps-load-failed"]', route_set='error')
case('page', 'partial', '[data-testid="connected-apps-installed-collection"]',
     route_set='partial', verify_text='GitHub Issues')
case('page', 'marketplace', '[data-testid="connected-apps-marketplace-collection"]', [market],
     verify_key='connected-app-market_slack')
case('page', 'my-apps', '[data-testid="connected-apps-my-apps-collection"]',
     [scope('my-apps', 'myapps')], verify_text='Slack Bridge')
case('dialog', 'marketplace-detail', '[data-testid="connected-app-detail-body"]', [market, detail],
     verify_key='connected-app-detail')
case('dialog', 'installed-permissions', '[data-testid="connected-app-detail-body"]',
     [installed_detail], verify_key='connected-app-installed-detail')
case('dialog', 'review-permissions', '[data-testid="connected-app-detail-body"]',
     [review_permissions], verify_key='connected-app-installed-detail', verify_text='Approve update')
case('dialog', 'developer-edit', '[data-testid="connected-app-editor-content"]',
     [scope('my-apps', 'myapps'), edit_local_app], verify_key='connected-app-editor')
case('dialog', 'reject-prompt-text', '[data-testid="app-prompt-text-reject-reason"]',
     [market, detail, reject_prompt], route_set='prompt-review', flags='prompt-text',
     verify_key='app-prompt-text-reject-dialog')
case('dialog', 'link-previews', '[data-testid="link-preview-manage-dialog"]', [manage_previews],
     verify_key='link-preview-consents-dialog')
case('dialog', 'link-previews-revoke', '[data-testid="link-preview-revoke-dialog"]',
     [manage_previews, revoke_preview], verify_key='link-preview-consents-revoke-dialog')
case('page', 'link-previews-loading', '[data-testid="connected-apps-installed-collection"]',
     route_set='link-previews-loading', absent_text='Link previews')
case('page', 'link-previews-empty', '[data-testid="connected-apps-installed-collection"]',
     route_set='link-previews-empty', absent_text='Link previews')
case('page', 'link-previews-error', '[data-testid="link-preview-consents-row"]',
     route_set='link-previews-error')
case('bridge', 'healthy', '[data-testid="slack-bridge-health"]',
     route_set='slack-healthy', flags='bridge', tab='im-bridges')
case('bridge', 'delivery-recovery', '[data-testid="slack-delivery-recovery"]',
     route_set='slack-recovery', flags='bridge', tab='im-bridges',
     verify_text='Retry stalled message')
case('bridge', 'provider-unavailable', '[role="status"]:has-text("The Slack bridge operation failed")',
     route_set='slack-unavailable', flags='bridge', tab='im-bridges')

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [entry for entry in manifest['cases'] if not entry['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1) + '\n')
print(f'{len(cases)} Apps cases appended')
