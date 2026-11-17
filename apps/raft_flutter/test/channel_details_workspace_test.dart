import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/private_route_guard.dart';

import 'workspace_channel_settings_identity_test.dart'
    show settingsFixture, mountSettingsWorkspace;

void main() {
  testWidgets(
    'Escape returns from the member picker and roster one at a time',
    (t) async {
      final (w, api) = await settingsFixture(t);
      final channel = RaftChannel({
        ...w.channel!.json,
        'channelCapabilities': {'addChannelMembers': true},
      });
      w.channel = channel;
      w.channels = [channel];
      api.routes['GET /agents'] = (_) => [
        {'id': 'a1', 'name': 'Cindy'},
      ];
      api.routes['GET /servers/s1/members'] = (_) => [];
      await mountSettingsWorkspace(t, w, false, PrivateRouteGuard());
      Finder key(String value) => find.byKey(ValueKey(value));
      await t.tap(key('channel-overflow-members-add-tile'));
      await t.pumpAndSettle();
      expect(key('add-member-back'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(key('add-member-back'), findsNothing);
      expect(key('member-page-back'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(key('member-page-back'), findsNothing);
      expect(key('channel-overflow-members-add-tile'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );

  testWidgets('channel settings opens Details beside the conversation', (
    t,
  ) async {
    final (w, _) = await settingsFixture(t);
    await mountSettingsWorkspace(t, w, false, PrivateRouteGuard());
    expect(find.text('Details'), findsOneWidget);
    expect(find.byKey(const Key('channel-overflow-scrim')), findsNothing);
    expect(find.byKey(const Key('channel-details-close')), findsOneWidget);
    expect(find.byKey(const Key('channel-overflow-trigger')), findsOneWidget);
    await t.tap(find.byKey(const Key('channel-details-close')));
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
}
