import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/private_app_invite.dart';
import 'package:raft_flutter/features/private_app_invite_view.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

Object? _answer(ParityContext ctx, String method, String path) {
  final fx = ctx.fixtures['ext:private-app-invite'] as Map;
  final value =
      (fx['routeSets'] as Map)[ctx.props['routeSet']]['$method $path'];
  if (value is Map && value[r'$pending'] == true) {
    return ScreenFixtureClient.pending;
  }
  if (value is Map && value[r'$status'] != null) {
    final body = Map<String, dynamic>.from(value[r'$body'] as Map);
    throw RaftApiException.response(
      body['error'] as String,
      status: value[r'$status'] as int,
      body: body,
    );
  }
  return value;
}

Widget _page(ParityContext ctx) => ScreenClientHost(
  create: () => ScreenFixtureClient(
    (method, path, _) => _answer(ctx, method, path),
    user: Map<String, dynamic>.from(
      (ctx.fixtures['ext:private-app-invite'] as Map)['user'] as Map,
    ),
  ),
  builder: (_, client) => PrivateAppInviteView(
    client: client,
    link: const PrivateAppInviteLink('parity-private'),
    onClose: () {},
    onSettings: (_, _) async {},
  ),
);

final Map<String, ParityCase> extPrivateAppInviteCases = {
  for (final platform in ['desktop', 'mobile'])
    for (final state in ['review', 'installed', 'no-admin', 'loading', 'error'])
      for (final theme in ['brutal', 'elegant-dark'])
        'components.private-app-invite.$platform.$state.$theme': ParityCase(
          widgets: const [
            'app:PrivateAppInviteView',
            'raft_ui:RaftPrivateAppInvitePage',
          ],
          build: _page,
          notes: 'Real invitation view, shared API answers; native exit action is additional to browser chrome.',
        ),
};
