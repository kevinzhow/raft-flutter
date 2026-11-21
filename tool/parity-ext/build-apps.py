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
local_apps = settings['routes']['GET /integrations/clients']
local_app = local_apps[0]
local_path = f'/integrations/clients/{local_app["id"]}'
permissions_path = 'GET /integrations/marketplace/market_github/install/app-notifications'
permissions = settings['routes'][permissions_path]


def marketplace_entry(app):
    return {
        'kind': 'app',
        'id': f'app:{app["id"]}',
        'name': app['name'],
        'description': app.get('description'),
        'logoUrl': app.get('logoUrl'),
        'category': app.get('category'),
        'publisherName': app.get('publisherServerName') or app.get('publisherName'),
        'publishedAt': app.get('publishedAt'),
        'installed': app['installedAt'] is not None,
        'app': app,
    }


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
share_link = {
    'id': 'visual-share-link',
    'clientId': local_app['id'],
    'targetServerSlug': 'fixture-team',
    'expiresAt': '2026-07-18T00:00:00.000Z',
    'revokedAt': None,
    'lastUsedAt': None,
    'consumedAt': None,
    'createdAt': local_app['createdAt'],
    'updatedAt': local_app['updatedAt'],
}


def step_up_required(action):
    return {
        '$status': 403,
        '$body': {
            'error': f"Confirm it's you with your second step before {action}.",
            'code': 'second_factor_step_up_required',
            'methods': ['totp', 'backup_code'],
        },
    }


install_with_bot = {
    **marketplace[0],
    'bot': {'offered': True, 'handle': 'slack', 'grant': 'pending'},
    'promptTextRevisionId': 'live',
    'whenToUse': 'Summarize Slack conversations.',
}
installed_with_bot = {
    **marketplace[1],
    'bot': {'offered': True, 'handle': 'issues', 'grant': 'pending'},
}
granted_bot = {'agentId': 'visual-issues-bot', 'handle': 'issues'}
installed_with_granted_bot = {
    **installed_with_bot,
    'bot': {'offered': True, 'grant': 'granted', **granted_bot},
}
installed_with_revoked_bot = {
    **installed_with_bot,
    'bot': {'offered': True, 'grant': 'revoked', 'handle': 'issues'},
}
bot_path = 'POST /integrations/clients/market_github/install/bot'
listing_with_setup = {
    **install_with_bot,
    'setupUrl': 'https://app.example.invalid/setup',
    'setupDescription': 'Choose what Slack Bridge should sync.',
}
install_path = 'POST /integrations/marketplace/market_slack/install'
uninstall_path = 'DELETE /integrations/marketplace/market_github/install'


def after_mutation(path, before, after):
    return {
        '$default': before,
        '$when': [{'after': path, 'answer': after}],
    }


def successful_install(listing):
    installed = {**listing, 'installedAt': local_app['updatedAt']}
    before = [listing, *marketplace[1:]]
    after = [installed, *marketplace[1:]]
    return {
        'GET /integrations/marketplace': after_mutation(install_path, before, after),
        'GET /integrations/marketplace/listings': after_mutation(install_path,
            {'items': [marketplace_entry(app) for app in before], 'total': len(before)},
            {'items': [marketplace_entry(app) for app in after], 'total': len(after)},
        ),
        install_path: {'ok': True, 'botGrant': 'granted'},
    }


stale_prompt_text = 'The text changed while you were looking at it. Review the current text, then try again.'
install_permissions_changed = "This app's permissions just changed. Review the current permissions, then confirm again."
recommended_app = {
    **marketplace[0],
    'id': 'market_stamp',
    'clientId': 'stamp',
    'name': 'Stamp',
    'official': True,
    'marketplaceInstallBadge': {'kind': 'none'},
}
external_bot = {
    'provider': 'slack',
    'appRegistrationId': 'visual-external-app',
    'installId': 'visual-external-install',
    'workspaceId': 'visual-slack-workspace',
    'workspaceName': 'Fixture Slack',
    'externalActorId': 'B000FIXTURE',
    'externalConversationId': 'C000FIXTURE',
    'externalMessageId': 'external-bot-message',
    'actorKind': 'bot',
    'displayName': 'Slack bot · ture',
    'profileDisplayName': 'Deploy Bot',
    'profileAvatarUrl': '/api/external-avatars/visual-deploy-bot.png',
    'appName': 'Deployer',
    'avatarUrl': None,
    'avatarDigest': None,
    'actorProjectionRevision': 1,
}
external_bot_channel = {
    'id': 'channel-home',
    'serverId': 'visual-server',
    'name': '首页专修',
    'type': 'channel',
    'joined': True,
    'description': 'Home shell, server badge, and bottom dock polish',
    'createdAt': local_app['createdAt'],
}
external_bot_message = {
    'id': 'fixture-external-bot-message',
    'seq': 1,
    'serverId': 'visual-server',
    'channelId': 'channel-home',
    'messageType': 'chat',
    'senderType': 'external_projection',
    'senderId': external_bot['externalActorId'],
    'senderName': external_bot['displayName'],
    'content': 'The staging build is ready for review.',
    'createdAt': local_app['createdAt'],
    'externalAuthor': external_bot,
}
login_client = {
    'id': 'fixture-login-app',
    'clientId': 'fixture-login',
    'name': 'Artifact Share',
    'description': 'Shares private artifacts',
    'appType': 'third_party_global',
    'homepageUrl': 'https://app.example.invalid',
    'returnUrl': 'https://app.example.invalid/complete',
    'availability': 'ready',
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
slack_retry_requested = deepcopy(slack_recovery)
slack_retry_requested['snapshot']['rawHealth']['outboundDeliveries'][0]['retryRequested'] = True
slack_replayed = deepcopy(slack_recovery)
slack_replayed['snapshot']['rawHealth']['inboundIsolated'] = []
routes = {
    **{key: value for key, value in settings['routes'].items()
       if key.startswith('GET /integrations/')},
    'GET /machines': [],
    'GET /servers/visual-server/machines': [],
    'GET /mcp/apps': {'apps': []},
    'GET /product-feedback/tickets': settings['routes']['GET /product-feedback/tickets'],
    f'GET {local_path}/app-notifications': {
        'source_installation': None,
        'request_revision': None,
        'current_revision_id': None,
        'current_groups': [],
        'current_events': [],
        'pending_revision': None,
        'webhook': None,
    },
    'GET /integrations/marketplace/listings': {
        'items': [marketplace_entry(app) for app in marketplace],
        'total': len(marketplace),
    },
    'GET /integrations/permission-updates': {'count': 1, 'needsAdminReview': True},
    'GET /integrations/link-preview-consents': {
        'allowed': [{'app': {'id': 'market_github', 'name': 'GitHub Issues', 'icon': None},
                     'granted_at': marketplace[1]['installedAt']}],
        'declined': [],
    },
}
def marketplace_pages(next_page):
    return {
        'GET /integrations/marketplace/listings': {
            '$default': {
                'items': [marketplace_entry(marketplace[0])],
                'total': 2,
                'nextCursor': 'second-page',
            },
            '$when': [{'query': {'cursor': 'second-page'}, 'answer': next_page}],
        },
    }


route_sets = {
    'server-popover': {
        'GET /product-feedback/tickets': {
            'tickets': [], 'next_cursor': None, 'unread_total': 0,
        },
    },
    'loading': {'GET /integrations/clients': {'$pending': True}},
    'empty': {'GET /integrations/clients': [], 'GET /integrations/marketplace': [],
              'GET /integrations/overview': [],
              'GET /integrations/permission-updates': {'count': 0, 'needsAdminReview': False}},
    'error': {'GET /integrations/clients': {'$status': 503}},
    'partial': {'GET /mcp/apps': {'$status': 503}},
    'uninstall-pending': {uninstall_path: {'$pending': True}},
    'uninstall-error': {
        uninstall_path: {
            '$status': 500,
            '$body': {'error': 'Failed to uninstall marketplace app'},
        },
    },
    'uninstall-success': {
        uninstall_path: {'ok': True},
        'GET /integrations/marketplace': after_mutation(
            uninstall_path, marketplace, [marketplace[0]]),
    },
    'link-previews-loading': {'GET /integrations/link-preview-consents': {'$pending': True}},
    'link-previews-empty': {'GET /integrations/link-preview-consents': {'allowed': [], 'declined': []}},
    'link-previews-error': {'GET /integrations/link-preview-consents': {'$status': 503}},
    'marketplace-loading': {'GET /integrations/marketplace/listings': {'$pending': True}},
    'marketplace-empty': {'GET /integrations/marketplace/listings': {'items': [], 'total': 0}},
    'marketplace-error': {'GET /integrations/marketplace/listings': {'$status': 503}},
    'marketplace-paging': marketplace_pages({'$pending': True}),
    'marketplace-more-error': marketplace_pages({'$status': 503}),
    'marketplace-more-loaded': marketplace_pages({
        'items': [marketplace_entry(marketplace[1])],
        'total': 2,
        'nextCursor': None,
    }),
    'private-share': {
        f'GET {local_path}/share-links': {'links': []},
        f'POST {local_path}/share-links': {
            'link': share_link,
            'token': 'visual-fixture-invite',
            'client': {**local_app, 'appType': 'third_party_global'},
        },
        f'DELETE {local_path}/share-links/{share_link["id"]}': {
            **share_link, 'revokedAt': local_app['updatedAt'],
        },
    },
    'external-bot': {
        'GET /channels': [external_bot_channel],
        'GET /channels/channel-home': external_bot_channel,
        'GET /channels/dm': [],
        'GET /servers/visual-server/sidebar-order': {},
        'GET /external-avatars/visual-deploy-bot.png': {
            '$file': 'announcement-picture.png', '$contentType': 'image/png',
        },
        'GET /messages/channel/channel-home': {
            'messages': [external_bot_message],
            'hasMore': False,
            'threadSummariesByParentMessageId': {},
        },
    },
    'login-person': {'GET /oauth/clients/lookup': login_client},
    'login-loading': {'GET /oauth/clients/lookup': {'$pending': True}},
    'login-unavailable': {'GET /oauth/clients/lookup': {'$status': 404}},
    'login-outage': {'GET /oauth/clients/lookup': {'$status': 503}},
    'login-account': {
        'GET /oauth/clients/lookup': {**login_client, 'loginMode': 'account'},
    },
    'login-account-suspended': {
        'GET /oauth/clients/lookup': {
            **login_client, 'loginMode': 'account', 'availability': 'suspended',
        },
    },
    'login-admin-needed': {
        'GET /oauth/clients/lookup': {
            **login_client,
            'availability': 'install_required',
            'marketplace': True,
            'installation': {'serverId': 'visual-server', 'canInstall': False},
        },
    },
    'login-install': {
        'GET /oauth/clients/lookup': {
            **login_client,
            'availability': 'install_required',
            'marketplace': True,
            'installation': {'serverId': 'visual-server', 'canInstall': True},
            'bot': install_with_bot['bot'],
            'promptTextRevisionId': 'live',
            'whenToUse': 'Share a private artifact on request.',
            'allowedScopes': ['openid', 'profile', 'agent:read'],
            'appNotificationGroups': ['server'],
        },
        'POST /feature-flags/evaluate': {
            'evaluations': [{'key': 'app_prompt_text_consent', 'enabled': True}],
        },
    },
    'withdraw-publish': {
        'GET /integrations/clients': [
            {**local_app, 'publishStatus': 'publish_requested'}, *local_apps[1:],
        ],
        f'POST {local_path}/withdraw-publish': local_app,
        f'GET {local_path}/share-links': {'links': []},
    },
    'developer-app-identity': {
        'GET /integrations/clients': [
            {
                **local_app,
                'enableBot': True,
                'bot': {'offered': True, 'handle': 'slack-bridge', 'grant': 'pending'},
            },
            *local_apps[1:],
        ],
        f'GET /integrations/marketplace/{local_app["id"]}/install/app-notifications': {
            '$status': 404,
            '$body': {'error': 'Active app installation not found'},
        },
    },
    'recommended': {'GET /integrations/marketplace': [*marketplace, recommended_app]},
    'prompt-review': {
        'GET /integrations/marketplace': [prompt_listing, *marketplace[1:]],
        'GET /integrations/marketplace/listings': {
            'items': [marketplace_entry(app)
                      for app in [prompt_listing, *marketplace[1:]]],
            'total': len(marketplace),
        },
        'GET /integrations/clients/market_slack/prompt-text': prompt_revisions,
        'POST /integrations/clients/market_slack/prompt-text/review': {
            '$status': 409, '$body': {'code': 'PROMPT_TEXT_REVIEW_STALE'},
        },
    },
    'install-step-up': {
        'GET /integrations/marketplace': [install_with_bot, *marketplace[1:]],
        'GET /integrations/marketplace/listings': {
            'items': [marketplace_entry(app) for app in [install_with_bot, *marketplace[1:]]],
            'total': len(marketplace),
        },
        install_path: step_up_required('installing this app'),
    },
    'install-success': successful_install(install_with_bot),
    'install-setup': {
        **successful_install(listing_with_setup),
        'GET /integrations/clients/market_slack/setup': {
            'status': 'pending', 'revision': 1, 'completedAt': None,
            'canConfigure': True, 'url': listing_with_setup['setupUrl'],
            'description': listing_with_setup['setupDescription'],
        },
    },
    'install-permissions-changed': {
        install_path: {
            '$status': 409,
            '$body': {
                'error': install_permissions_changed,
                'code': 'APP_PERMISSIONS_CHANGED',
                'current_scopes': ['openid', 'profile', 'identity', 'agent:read'],
                'current_groups': ['server'],
                'current_text_revision_id': None,
                'current_text': None,
            },
        },
    },
    'bot-step-up': {
        'GET /integrations/marketplace': [marketplace[0], installed_with_bot, *marketplace[2:]],
        bot_path: step_up_required("adding this app's bot"),
    },
    'bot-granted': {
        'GET /integrations/marketplace': after_mutation(
            bot_path,
            [marketplace[0], installed_with_bot, *marketplace[2:]],
            [marketplace[0], installed_with_granted_bot, *marketplace[2:]],
        ),
        bot_path: {
            'botGrant': 'granted', 'bot': granted_bot,
        },
    },
    'bot-removed': {
        'GET /integrations/marketplace': after_mutation(
            bot_path,
            [marketplace[0], installed_with_granted_bot, *marketplace[2:]],
            [marketplace[0], installed_with_revoked_bot, *marketplace[2:]],
        ),
        bot_path: {
            'botGrant': 'revoked', 'bot': None,
        },
    },
    'slack-healthy': {f'GET {slack_path}': slack_healthy},
    'slack-recovery': {f'GET {slack_path}': slack_recovery},
    'slack-retry-requested': {
        f'GET {slack_path}': slack_recovery,
        f'POST {slack_path}/retry-delivery': slack_retry_requested,
    },
    'slack-replayed': {
        f'GET {slack_path}': slack_recovery,
        f'POST {slack_path}/replay-inbound': slack_replayed,
    },
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
    {'type': 'click', 'target': '[data-testid="connected-app-item-market_github"] [role="button"][aria-label="GitHub Issues"]'},
    {'type': 'tap', 'key': 'connected-app-installed-market_github'},
)
uninstall_dialog = '[role="dialog"]:has([data-testid="connected-app-uninstall-confirm-button"])'
uninstall = (
    {'type': 'click', 'target': '[data-testid="connected-app-item-market_github"] button:has-text("Uninstall")'},
    {'type': 'tap', 'key': 'connected-app-action-market_github'},
)
confirm_uninstall = tap('connected-app-uninstall-confirm-button')
marketplace_uninstall_steps = [
    market,
    (
        {'type': 'click', 'target': 'button:has-text("GitHub Issues") >> nth=0'},
        {'type': 'tap', 'key': 'connected-app-market_github'},
    ),
    tap_text('Uninstall from this server', 'button:has-text("Uninstall from this server")'),
]
manage_previews = tap('link-preview-consents-manage')
review_permissions = tap_text(
    'Review permissions',
    '[data-testid="connected-app-item-market_github"] button:has-text("Review permissions")',
)
revoke_preview = tap_text('Revoke', '[data-testid="link-preview-consents-allowed"] button:has-text("Revoke")')
reject_prompt = tap_text('Reject text update', '[data-testid="app-prompt-text-review"] button:has-text("Reject text update")')
approve_prompt = tap_text('Approve text update', '[data-testid="app-prompt-text-review"] button:has-text("Approve text update")')
install = (
    {'type': 'click', 'target': 'button:has-text("Install to this server")'},
    {'type': 'tap', 'key': 'connected-app-install'},
)
edit_local_app = (
    {'type': 'click', 'target': '[data-testid="connected-apps-my-apps-collection"] button:has-text("Edit")'},
    {'type': 'tap', 'key': 'connected-app-action-client_1'},
)
developer = scope('my-apps', 'myapps')
editor_identity_hint = '[data-testid="connected-app-bot-editor-hint"]'
editor_installed_link = 'connected-app-bot-editor-installed'
editor_identity_steps = (
    developer,
    edit_local_app,
    (
        {'type': 'reveal', 'target': editor_identity_hint},
        {'type': 'reveal', 'key': editor_installed_link},
    ),
)
share_input = 'connected-app-share-target-input'
share_created = 'connected-app-share-created'
share_editor_steps = (
    developer, edit_local_app,
    (
        {'type': 'reveal', 'target': f'[data-testid="{share_input}"]'},
        {'type': 'reveal', 'key': share_input},
    ),
    (
        {'type': 'fill', 'target': f'[data-testid="{share_input}"]', 'value': 'fixture-team'},
        {'type': 'enterText', 'key': share_input, 'text': 'fixture-team'},
    ),
    tap('connected-app-share-create-button'),
)
cases = []


def case(group, state, selector, steps=(), *, route_set='', flags='', tab='integrations',
         verify_text=None, verify_key=None, absent_text=None,
         shell='', role='owner', metadata_selector=None, bot_link=None, capture_key=None,
         login_server=None, login_disclosure=False,
         platforms=('desktop', 'mobile')):
    if not shell and tab == 'integrations' and role != 'guest':
        shell = 'settings/applications'
    web_target = selector
    if shell == 'login':
        capture_key = 'human-login-content'
        if state != 'loading':
            web_target = '[data-testid="apps-login-content-capture"]'
            metadata_selector = '[data-testid="human-login-setup-scroller"] main > section:first-child'
    for platform, width, height in [('desktop', 1280, 900), ('mobile', 390, 844)]:
        if platform not in platforms:
            continue
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
                    'tab': tab, 'role': role, 'extKind': 'apps', 'extFixture': 'apps',
                    'platform': platform, 'parityTheme': theme, 'routeSet': route_set, 'flags': flags,
                    'appsShell': shell,
                    **({'app_bot': bot_link} if bot_link else {}),
                    **({'server': login_server} if login_server else {}),
                    **({'loginDisclosure': True} if login_disclosure else {}),
                    'verifyText': verify_text or '', 'verifyKey': verify_key or '',
                    'absentText': absent_text or '',
                }}],
                'capture': {
                    'selector': web_target,
                    **({'crop': 'element', 'androidKey': capture_key}
                       if capture_key else
                       {'crop': 'viewport', 'contract': 'viewport-with-portal'}),
                    **({'metadataSelector': metadata_selector} if metadata_selector else {}),
                    'interactions': [
                        *([{'type': 'reveal', 'target': '[data-testid="apps-page"]'}]
                          if shell == 'settings/applications' else []),
                        *web_steps(steps, platform),
                        *([{'type': 'reveal', 'target': selector}]
                          if web_target != selector else []),
                    ],
                    'androidInteractions': [
                        {'scroll': 'if-needed', **native}
                        if native['type'] in {'tap', 'tapText', 'reveal'} else native
                        for web, action in steps
                        for native in (
                            [
                                {'type': 'tap', 'key': 'connected-apps-scope-select'},
                                {'type': 'tapText', 'text': {
                                    'installed': 'Installed', 'marketplace': 'Marketplace',
                                    'myapps': 'Developer',
                                }[web['value']]},
                            ]
                            if platform == 'mobile' and web['type'] == 'scope'
                            else [action]
                        )
                        if native is not None
                    ],
                },
                'reactPathHint': (
                    'packages/web/src/pages/HumanLoginSetupPage.tsx' if shell == 'login'
                    else 'packages/web/src/features/apps/IntegrationsSection.tsx'
                ),
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
case('dialog', 'uninstall', uninstall_dialog, [uninstall],
     verify_key='connected-app-uninstall-dialog')
case('dialog', 'review-permissions', '[data-testid="connected-app-detail-body"]',
     [review_permissions], verify_key='connected-app-installed-detail', verify_text='Approve update')
case('dialog', 'developer-edit', '[data-testid="connected-app-editor-content"]',
     [scope('my-apps', 'myapps'), edit_local_app], verify_key='connected-app-editor')
case('dialog', 'add-app-menu', '[data-testid="register-app-menu"]',
     [tap('register-app-menu-trigger')], verify_text='Create a Raft app')
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
case('page', 'guest-link-previews-loading', '[data-testid="link-preview-consents-loading"]',
     route_set='link-previews-loading', role='guest', absent_text='Manage')
case('page', 'guest-link-previews-empty', '[data-testid="link-preview-consents-empty"]',
     route_set='link-previews-empty', role='guest', verify_key='link-preview-consents-card')
case('page', 'guest-link-previews-error', '[data-testid="link-preview-consents-row"]',
     route_set='link-previews-error', role='guest', verify_text='Retry')
case('dialog', 'guest-link-previews', '[data-testid="link-preview-manage-dialog"]',
     [manage_previews], role='guest', verify_key='link-preview-consents-dialog')
case('bridge', 'healthy', '[data-testid="slack-bridge-health"]',
     route_set='slack-healthy', flags='bridge', tab='im-bridges')
case('bridge', 'delivery-recovery', '[data-testid="slack-delivery-recovery"]',
     route_set='slack-recovery', flags='bridge', tab='im-bridges',
     verify_text='Retry stalled message')
case('bridge', 'provider-unavailable', '[role="status"]',
     route_set='slack-unavailable', flags='bridge', tab='im-bridges',
     verify_text='The Slack bridge operation failed. No setup state was assumed.')
case('bridge', 'retry-requested',
     '[data-testid="slack-delivery-recovery"] button:has-text("Retry requested")', [
         (
             {'type': 'click', 'target': '[data-testid="slack-delivery-recovery"] button:has-text("Retry stalled message")'},
             {'type': 'tap', 'finder': {'text': 'Retry stalled message'}, 'scroll': False},
         ),
     ], route_set='slack-retry-requested', flags='bridge', tab='im-bridges',
     metadata_selector='[data-testid="slack-bridge-health"]', verify_text='Retry requested')
case('bridge', 'replayed',
     '[data-testid="slack-bridge-health"]:not(:has([data-testid="slack-inbound-isolated"]))', [
         tap_text('Retry message',
                  '[data-testid="slack-inbound-isolated"] button:has-text("Retry message")'),
     ], route_set='slack-replayed', flags='bridge', tab='im-bridges',
     absent_text='Retry message')

case('route', 'installed', '[data-testid="apps-page"]', shell='apps',
     verify_key='apps-page', verify_text='GitHub Issues')
case('route', 'recommended', '[data-testid="apps-recommended-stamp"]',
     shell='apps', route_set='recommended', verify_text='Recommended for you')
case('route', 'recommended-detail', '[data-testid="connected-app-detail-body"]', [
    tap('apps-recommended-stamp', 'connected-app-market_stamp'),
], shell='apps', route_set='recommended', verify_key='connected-app-detail')
case('route', 'loading', '[data-testid="apps-loading-collection"]', [
    ({'type': 'wait', 'ms': 1100}, {'type': 'wait', 'ms': 1100}),
], shell='apps', route_set='loading', verify_key='apps-installed-loading-collection')
case('route', 'empty', '[data-testid="apps-installed-empty"]', shell='apps',
     route_set='empty', verify_text='No apps installed yet')
case('route', 'error', '[data-testid="apps-load-failed"]', shell='apps',
     route_set='error', verify_text='Retry')
case('route', 'partial', '[data-testid="connected-apps-installed-collection"]',
     shell='apps', route_set='partial', verify_text='GitHub Issues')
case('route', 'marketplace', '[data-testid="connected-apps-marketplace-collection"]',
     [market], shell='apps', verify_key='connected-app-market_slack')
case('route', 'marketplace-loading', '[data-testid="apps-marketplace-loading-collection"]', [
    market, ({'type': 'wait', 'ms': 1100}, {'type': 'wait', 'ms': 1100}),
], shell='apps', route_set='marketplace-loading',
     verify_key='apps-marketplace-loading-collection', absent_text='Slack Bridge')
case('route', 'marketplace-empty', '[data-testid="apps-marketplace-empty"]',
     [market], shell='apps', route_set='marketplace-empty', verify_text='No apps in the Marketplace yet')
case('route', 'marketplace-error', '[data-testid="apps-marketplace-load-failed"]',
     [market], shell='apps', route_set='marketplace-error', verify_key='apps-marketplace-load-failed')
load_more = tap_text('Load more', '[data-testid="apps-marketplace-load-more"]')
case('route', 'marketplace-paging', '[data-testid="apps-marketplace-load-more"]:disabled',
     [market, load_more], shell='apps', route_set='marketplace-paging',
     verify_text='Loading…')
case('route', 'marketplace-more-error', '[data-testid="apps-marketplace-load-more-failed"]',
     [market, load_more], shell='apps', route_set='marketplace-more-error',
     verify_text="Couldn't load more apps.")
case('route', 'marketplace-more-loaded',
     '[data-testid="connected-apps-marketplace-collection"]:has-text("GitHub Issues")',
     [market, load_more], shell='apps', route_set='marketplace-more-loaded',
     metadata_selector='[data-testid="connected-apps-marketplace-collection"]',
     verify_text='Showing 2 / 2', absent_text='Load more')
case('route', 'developer', '[data-testid="connected-apps-my-apps-collection"]',
     [developer], shell='apps', verify_text='Slack Bridge')
case('route', 'installed-permissions', '[data-testid="connected-app-detail-body"]',
     [installed_detail], shell='apps', verify_key='connected-app-installed-detail')
case('route', 'uninstall', uninstall_dialog, [uninstall], shell='apps',
     verify_key='connected-app-uninstall-dialog')
case('route', 'uninstall-pending', uninstall_dialog, [uninstall, confirm_uninstall],
     shell='apps', route_set='uninstall-pending',
     verify_key='connected-app-uninstall-dialog', verify_text='Uninstalling...')
case('route', 'uninstall-error', '[data-testid="apps-page"]',
     [uninstall, confirm_uninstall], shell='apps', route_set='uninstall-error',
     verify_text='Failed to uninstall marketplace app', absent_text='Uninstall GitHub Issues?')
case('route', 'uninstall-success', '[data-testid="apps-installed-empty"]',
     [uninstall, confirm_uninstall], shell='apps', route_set='uninstall-success',
     absent_text='GitHub Issues')
case('route', 'uninstall-from-marketplace', uninstall_dialog, marketplace_uninstall_steps,
     shell='apps', verify_key='connected-app-uninstall-dialog')
case('route', 'uninstall-from-marketplace-error', '[data-testid="connected-app-detail-body"]',
     [*marketplace_uninstall_steps, confirm_uninstall], shell='apps', route_set='uninstall-error',
     verify_key='connected-app-detail', verify_text='Failed to uninstall marketplace app',
     absent_text='Uninstall GitHub Issues?')
case('route', 'review-permissions', '[data-testid="connected-app-detail-body"]',
     [review_permissions], shell='apps',
     verify_key='connected-app-installed-detail', verify_text='Approve update')
case('route', 'marketplace-detail', '[data-testid="connected-app-detail-body"]',
     [market, detail], shell='apps', verify_key='connected-app-detail')
case('route', 'developer-edit', '[data-testid="connected-app-editor-content"]',
     [developer, edit_local_app], shell='apps',
     verify_key='connected-app-editor')
case('route', 'developer-app-identity', editor_identity_hint,
     editor_identity_steps, shell='apps', route_set='developer-app-identity',
     verify_key=editor_installed_link, verify_text='Post as the app')
case('route', 'developer-app-identity-installed',
     '[data-testid="connected-app-detail-body"]',
     [*editor_identity_steps, (
         {'type': 'click', 'target': f'{editor_identity_hint} :is(button,a)'},
         {'type': 'tap', 'key': editor_installed_link},
     )], shell='apps', route_set='developer-app-identity',
     verify_key='connected-app-installed-detail')
case('route', 'share-created', f'[data-testid="{share_created}"]',
     share_editor_steps, shell='apps', route_set='private-share',
     verify_key=share_created)
case('route', 'share-revoked',
     f'[data-testid="connected-app-private-share-card"]:not(:has([data-testid="{share_created}"]))',
     [*share_editor_steps,
      tap_text('Revoke', '[data-testid="connected-app-share-link-row"] button')],
     shell='apps', route_set='private-share', verify_key='connected-app-share-links',
     absent_text="Link for fixture-team. Copy it now: it's shown only once.")
case('route', 'publish-withdrawn', '[data-testid="connected-app-private-share-card"]',
     [developer, edit_local_app, tap('connected-app-withdraw-publish-button')],
     shell='apps', route_set='withdraw-publish', verify_key='connected-app-share-links',
     absent_text='Withdraw request')
case('route', 'reject-prompt-text', '[data-testid="app-prompt-text-reject-reason"]',
     [market, detail, reject_prompt], shell='apps', route_set='prompt-review',
     flags='prompt-text', verify_key='app-prompt-text-reject-dialog')
case('route', 'stale-prompt-text',
     f'[data-testid="app-prompt-text-review"]:has-text("{stale_prompt_text}")',
     [market, detail, approve_prompt], shell='apps', route_set='prompt-review',
     metadata_selector='[data-testid="app-prompt-text-review"]',
     flags='prompt-text', verify_text=stale_prompt_text)
case('route', 'install-step-up', '[data-testid="second-factor-step-up-dialog"]',
     [market, detail, install], shell='apps', route_set='install-step-up',
     flags='prompt-text', verify_text="Verify it's you")
case('route', 'install-permissions-changed', '[data-testid="connected-app-detail-body"]',
     [market, detail, install], shell='apps', route_set='install-permissions-changed',
     verify_key='connected-app-detail', verify_text=install_permissions_changed)
case('route', 'install-setup', '[data-testid="app-installation-setup"]',
     [market, detail, install], shell='apps', route_set='install-setup',
     verify_key='connected-app-detail', verify_text='Installed, setup pending')
case('route', 'install-success',
     'body:not(:has([data-testid="connected-app-detail-body"])) [data-testid="connected-apps-marketplace-collection"]',
     [market, detail, install], shell='apps', route_set='install-success',
     verify_key='connected-app-market_slack', absent_text='Install to this server')
case('route', 'bot-step-up', '[data-testid="second-factor-step-up-dialog"]', [
    installed_detail, tap_text('Add @issues', 'button:has-text("Add @issues") >> nth=0'),
], shell='apps', route_set='bot-step-up', verify_text="Verify it's you")
case('route', 'bot-granted', '[data-testid="connected-app-bot-section"][data-bot-grant="granted"]',
     [installed_detail, tap_text('Add @issues', 'button:has-text("Add @issues") >> nth=0')],
     shell='apps', route_set='bot-granted',
     verify_key='connected-app-installed-detail', verify_text='Added to server')
remove_bot = tap_text('Remove', '[data-testid="connected-app-bot-remove"]')
case('route', 'bot-remove', '[data-testid="connected-app-bot-remove-confirm"]',
     [installed_detail, remove_bot], shell='apps', route_set='bot-removed',
     verify_key='connected-app-bot-remove-dialog')
case('route', 'bot-removed', '[data-testid="connected-app-bot-section"][data-bot-grant="revoked"]', [
    installed_detail, remove_bot,
    (
        {'type': 'click', 'target': '[data-testid="connected-app-bot-remove-confirm"]'},
        {'type': 'tap', 'finder': {'text': 'Remove', 'in': 'connected-app-bot-remove-dialog'}},
    ),
], shell='apps', route_set='bot-removed', verify_key='connected-app-installed-detail',
     absent_text='Added to server')
case('route', 'bot-link', '[data-testid="connected-app-bot-section"]',
     shell='apps', route_set='bot-step-up', bot_link=installed_with_bot['clientId'],
     verify_key='connected-app-installed-detail')
case('route', 'bot-link-unavailable', '[data-testid="connected-apps-bot-link-not-installed"]',
     shell='apps', bot_link='unknown-app',
     verify_key='connected-apps-bot-link-not-installed')
case('route', 'link-previews', '[data-testid="link-preview-manage-dialog"]',
     [manage_previews], shell='apps', verify_key='link-preview-consents-dialog')
case('route', 'link-previews-revoke', '[data-testid="link-preview-revoke-dialog"]',
     [manage_previews, revoke_preview], shell='apps',
     verify_key='link-preview-consents-revoke-dialog')
case('route', 'add-app', '[data-testid="register-app-menu"]', [
    tap('register-app-menu-trigger'),
], shell='apps', verify_text='Create a Raft app')
case('route', 'create-raft-app', '[data-testid="connected-app-editor-content"]', [
    tap('register-app-menu-trigger'),
    tap_text('Create a Raft app', '[data-testid="register-app-menu"] [role="menuitem"]:has-text("Create a Raft app")'),
], shell='apps', verify_key='connected-app-editor', verify_text='Create Raft app',
     absent_text='Danger zone')
case('route', 'type-menu', '[role="listbox"]:has-text("Raft apps")', [
    tap('apps-filter-type'),
], shell='apps', metadata_selector='[role="listbox"]', verify_text='Raft apps')
case('route', 'category-menu', '[role="listbox"]:has-text("Communication")', [
    tap('connected-apps-category-filter'),
], shell='apps', metadata_selector='[role="listbox"]', verify_text='Communication')
case('route', 'scope-menu', '[role="listbox"]:has-text("Marketplace")', [
    tap('connected-apps-scope-select'),
], shell='apps', metadata_selector='[role="listbox"]', verify_text='Marketplace',
     platforms=('mobile',))
case('route', 'rail-entry', '[data-testid="apps-page"]', [
    tap('left-rail-tab-apps', 'rail-apps'),
], shell='tasks', platforms=('desktop',), verify_key='apps-page')
server_popover = (
    'body:has([data-testid="mobile-tab-bar"] [aria-label="Tasks"][data-selected="true"]) '
    '[data-testid="mobile-server-tab-popover"]'
    ':has([data-testid="apps-attention-dot"])'
    ':not(:has([data-testid="computers-attention-dot"], [data-testid="settings-attention-dot"]))'
    ':not(:has([data-slot="mobile-nav-server-popover-destination"]'
    ':is(:hover, :focus-visible, [aria-current="page"], [data-selected="true"])))'
)
case('route', 'server-popover', server_popover, [
    tap('mobile-tab-server'),
], shell='tasks', route_set='server-popover', platforms=('mobile',), verify_key='mobile-server-tab-apps',
     verify_text='4 channel tasks',
     absent_text='Could not complete that. Try again.')
case('route', 'server-popover-surface', server_popover, [
    tap('mobile-tab-server'),
], shell='tasks', route_set='server-popover', platforms=('mobile',), verify_key='mobile-server-tab-apps',
     capture_key='mobile-server-tab-popover', verify_text='4 channel tasks')
case('route', 'server-popover-entry', '[data-testid="apps-page"]', [
    tap('mobile-tab-server'),
    tap('mobile-server-tab-apps'),
], shell='tasks', platforms=('mobile',), verify_key='apps-page')
case('profile', 'external-bot', '[data-testid="external-identity-header"]', [
    (
        {'type': 'click', 'target': '#message-fixture-external-bot-message button[data-avatar-kind="external"]'},
        {'type': 'tap', 'key': 'sender-avatar-fixture-external-bot-message'},
    ),
], shell='channel/channel-home', route_set='external-bot',
     verify_key='external-identity-header', verify_text='Posted as Slack bot · ture')
case('login', 'person', '[data-testid="human-login-setup-scroller"] main > section:has(button:has-text("Login with Raft"))',
     shell='login', route_set='login-person', verify_key='human-login-continue')
case('login', 'loading', '[data-testid="login-lookup-skeleton"][data-shown="true"]',
     shell='login', route_set='login-loading', verify_key='human-login-sheet',
     verify_text='Loading…')
case('login', 'unavailable', '[data-testid="app-not-available"]',
     shell='login', route_set='login-unavailable',
     verify_key='human-login-not-accessible', verify_text="This app isn't available to you")
case('login', 'outage', '[data-testid="human-login-setup-scroller"] main > section:has-text("Installation status could not be loaded.")',
     shell='login', route_set='login-outage',
     verify_key='human-login-error',
     verify_text='Installation status could not be loaded. Reload this page to try again.')
case('login', 'account', '[data-testid="account-login-panel"]',
     shell='login', route_set='login-account', verify_key='human-login-continue',
     verify_text='Artifact Share wants to use your Raft account')
case('login', 'account-identity-expanded', '[data-testid="account-login-panel"]', [
    (
        {'type': 'click', 'target': '[data-testid="login-with-raft-requested-scopes"] details > summary'},
        None,
    ),
], shell='login', route_set='login-account', login_disclosure=True,
     verify_key='human-login-continue', verify_text='openid')
case('login', 'install', '[data-testid="human-login-setup-scroller"] main > section:has([data-testid="marketplace-login-commit"])',
     shell='login', route_set='login-install', flags='prompt-text',
     verify_key='human-login-continue', verify_text='Install and continue')
case('login', 'account-suspended', '[data-testid="account-login-panel"]:has([data-testid="account-login-refusal"])',
     shell='login', route_set='login-account-suspended',
     verify_key='human-login-account-refusal',
     verify_text="This app's installations on your Servers are suspended. Ask a Server owner or admin to restore it.")
case('login', 'account-server-issuer', '[data-testid="account-login-panel"]:has([data-testid="account-login-refusal"])',
     shell='login', route_set='login-account', login_server='visual-server',
     verify_key='human-login-account-refusal',
     verify_text="This app is set up to sign in through a Server-specific address, which it can't use. Ask the app's developer to use Raft's main sign-in address.")
case('login', 'admin-needed', '[data-testid="human-login-setup-scroller"] main > section:has([data-testid="marketplace-login-commit-zone"]:has-text("Find a server admin"))',
     shell='login', route_set='login-admin-needed', role='member',
     verify_key='human-login-find-admin', verify_text='Find a server admin')

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [entry for entry in manifest['cases'] if not entry['id'].startswith(PREFIX)] + cases
path.write_text(json.dumps(manifest, indent=1) + '\n')
print(f'{len(cases)} Apps cases appended')
