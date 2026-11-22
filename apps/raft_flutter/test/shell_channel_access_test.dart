import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/channel_access_loss.dart';
import 'package:raft_flutter/data/raft_location.dart';

import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('losing the open channel offers Home at width $width', (
      tester,
    ) async {
      final (workspace, _) = await pageFixture(tester);
      final channel = workspace.channel!;
      await mountPage(tester, workspace, false, width: width);
      final title = find.text("You're no longer in this channel");
      expect(title, findsNothing);

      ChannelAccessLoss.of(workspace.client).noteReadError(
        channel.id,
        RaftApiException.response(
          'Access denied',
          status: 403,
          body: {'error': 'Access denied'},
        ),
      );
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      final index = workspace.navigation.index;
      await tester.tap(find.text('Back to channels'));
      await tester.pumpAndSettle();
      expect(workspace.location.route, RaftRoute.home);
      expect(workspace.navigation.index, index);
      expect(title, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  testWidgets('a refused link returns to the phone conversation list', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    final target = RaftLocation.at(
      serverSlug: workspace.location.serverSlug,
      route: RaftRoute.channel,
      entityId: 'refused',
    );
    api.routes['GET /channels/refused'] = (_) =>
        (404, {'error': 'Channel not found or not visible'});
    workspace.navigation.navigate(target);
    await mountPage(tester, workspace, false, width: 390);
    await tester.runAsync(
      () => workspace.resolveConversationChannel('refused'),
    );
    await tester.pumpAndSettle();
    final title = find.text("This conversation isn't available to you");
    expect(title, findsOneWidget);
    await tester.tap(find.text('Back to conversations'));
    await tester.pumpAndSettle();
    expect(workspace.location.route, RaftRoute.home);
    expect(title, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a refused Activity conversation hides the previous chat', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    final slot = RaftLocation.at(
      serverSlug: workspace.location.serverSlug,
      route: RaftRoute.activity,
    ).withQuery({'open': 'channel:refused'});
    api.routes['GET /channels/refused'] = (_) =>
        (404, {'error': 'Channel not found or not visible'});
    workspace.navigation.navigate(slot);
    await mountPage(tester, workspace, false, width: 1280);
    await tester.runAsync(
      () => workspace.jumpToMessage('refused', null, navigate: false),
    );
    await tester.pumpAndSettle();
    final title = find.text("This conversation isn't available to you");
    expect(title, findsOneWidget);
    expect(find.byTooltip('Close Detail'), findsNothing);
    await tester.tap(find.text('Back to channels'));
    await tester.pumpAndSettle();
    expect(workspace.location.route, RaftRoute.home);
    expect(title, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
