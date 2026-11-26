import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import '../parity_harness.dart';

final _fixture = jsonDecode(
  File('../../tool/parity-ext/fixtures/legacy-wave4a.json').readAsStringSync(),
) as Map<String, dynamic>;

Widget _stage(Widget child, {required double width}) => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    return RaftRecipeBox(
      declareSurface: true,
      applyText: false,
      tokens: t.recipeTokens,
      style: RaftSlotStyle(
        {'background-color': CssColor(t.ui.layerCanvas.toARGB32())},
        const {},
        const ['bg-layer-canvas'],
        t.recipeTokens,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: const ValueKey('wave4a-frame'),
            width: width,
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
  },
);

ParityCase _declaredScopes({required bool mobile}) {
  final scopes = List<String>.from(_fixture['declaredScopes'] as List).toSet();
  return ParityCase(
    widgets: const ['raft_ui:RaftDeclaredScopesPicker', 'raft_ui:RaftCheckbox'],
    settle: const Duration(milliseconds: 200),
    build: (_) => _stage(
      RaftDeclaredScopesPicker(
        value: scopes,
        onChanged: (_) {},
        tooltips: const {
          'openid': 'OpenID subject identifier',
          'profile': 'Display name and avatar',
          'identity': 'Verified workspace identity',
          'email': 'Primary email address',
          'agent:event:write': 'Send events to authorized agent',
          'agent:notification:write': 'Send notifications to authorized agent',
        },
        fixedIdentity: const ['openid', 'profile', 'identity'],
        optionalIdentity: const ['email'],
        agentMessaging: const ['agent:event:write', 'agent:notification:write'],
        resourceNote: 'The user chooses the target agent when authorizing.',
      ),
      width: mobile ? 390 : 600,
    ),
  );
}

ParityCase _oauthScopeSummary() {
  final scopes = List<String>.from(_fixture['oauthScopes'] as List);
  return ParityCase(
    widgets: const ['raft_ui:RaftOAuthScopeSummary'],
    settle: const Duration(milliseconds: 200),
    build: (_) => _stage(
      RaftOAuthScopeSummary(
        title: 'Permissions',
        description: 'Effective access granted to this app.',
        scopes: scopes,
        resourceScopes: const {'agent:event:write'},
        initialOpen: true,
      ),
      width: 540,
    ),
  );
}

ParityCase _publicChannelList({required bool empty}) {
  final channels = empty
      ? const <RaftPublicChannel>[]
      : [
          for (final item in (_fixture['publicChannels'] as List).cast<Map>())
            RaftPublicChannel(
              name: item['name'] as String,
              description: item['description'] as String?,
            ),
        ];
  return ParityCase(
    widgets: const ['raft_ui:RaftPublicChannelList'],
    settle: const Duration(milliseconds: 200),
    build: (_) => _stage(RaftPublicChannelList(channels: channels), width: 500),
  );
}

ParityCase _agreementBody({required bool empty}) {
  final source = empty ? '' : _fixture['agreementBody'] as String;
  return ParityCase(
    widgets: const ['raft_ui:RaftAgreementBody', 'raft_ui:RaftCard'],
    settle: const Duration(milliseconds: 200),
    build: (_) => _stage(
      Builder(
        builder: (context) {
          final t = RaftTokens.of(context);
          return RaftCard(
            padding: const EdgeInsets.all(12),
            child: RaftAgreementBody(
              source: source,
              style: raftSettingsBody(
                t,
                size: 14,
                line: 20,
                color: t.ui.foreground,
              ),
            ),
          );
        },
      ),
      width: 500,
    ),
  );
}

final Map<String, ParityCase> extLegacyWave4aCases = {
  for (final theme in ['brutal', 'elegant-dark']) ...{
    'components.legacy-wave4a.declared-scopes.desktop.$theme': _declaredScopes(
      mobile: false,
    ),
    'components.legacy-wave4a.declared-scopes.phone.$theme': _declaredScopes(
      mobile: true,
    ),
    'components.legacy-wave4a.oauth-scope-summary.desktop.$theme':
        _oauthScopeSummary(),
    'components.legacy-wave4a.public-channel-list.desktop.$theme':
        _publicChannelList(empty: false),
    'components.legacy-wave4a.public-channel-list-empty.desktop.$theme':
        _publicChannelList(empty: true),
    'components.legacy-wave4a.agreement-body.desktop.$theme': _agreementBody(
      empty: false,
    ),
    'components.legacy-wave4a.agreement-body-empty.desktop.$theme':
        _agreementBody(empty: true),
  },
};
