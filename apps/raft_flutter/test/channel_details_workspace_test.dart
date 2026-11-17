import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/private_route_guard.dart';

import 'workspace_channel_settings_identity_test.dart'
    show settingsFixture, mountSettingsWorkspace;

void main() {
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
