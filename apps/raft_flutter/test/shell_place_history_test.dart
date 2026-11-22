import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';

import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;

void main() {
  for (final width in [856.0, 1280.0]) {
    testWidgets('desktop history skips repeated places at width $width', (
      tester,
    ) async {
      final (workspace, _) = await pageFixture(tester);
      final history = workspace.navigation;
      final members = RaftLocation.at(
        serverSlug: workspace.location.serverSlug,
        route: RaftRoute.members,
      );
      final activity = RaftLocation.at(
        serverSlug: workspace.location.serverSlug,
        route: RaftRoute.activity,
      );
      history.navigate(members);
      history.navigate(activity);
      history.navigate(activity.withQuery({'profile': 'human:alice'}));
      history.navigate(activity, kind: RaftNavigationKind.replace);
      await mountPage(tester, workspace, false, width: width);

      Future<void> step(String direction) async {
        await tester.tap(find.byKey(Key('topbar-$direction')));
        await tester.pumpAndSettle();
      }

      await step('back');
      expect(workspace.location.uri, members.uri);
      await step('forward');
      expect(workspace.location.uri, activity.uri);
      await step('back');
      expect(workspace.location.uri, members.uri);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(workspace.location.uri, activity.uri);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  testWidgets('History menu lists prior conversations only', (tester) async {
    final (workspace, _) = await pageFixture(tester);
    final previous = workspace.channel!;
    workspace.setSection('members');
    await mountPage(tester, workspace, false, width: 1280);
    await tester.tap(find.byKey(const Key('topbar-history')));
    await tester.pumpAndSettle();
    expect(find.text('Recent conversations'), findsOneWidget);
    expect(find.text('No recent conversations yet'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    final menu = find.byKey(const Key('topbar-history-menu'));
    expect(menu, findsNothing);
    await tester.tap(find.byKey(const Key('topbar-history')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1200, 700));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    await tester.tap(find.byKey(const Key('topbar-history')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(menu, findsNothing);

    await tester.runAsync(() => workspace.selectChannel(previous));
    await tester.pumpAndSettle();
    workspace.setSection('members');
    await tester.pumpAndSettle();
    final currentIndex = workspace.navigation.index;
    await tester.tap(find.byKey(const Key('topbar-history')));
    await tester.pumpAndSettle();
    final destination = find.descendant(
      of: menu,
      matching: find.text(previous.name),
    );
    expect(destination, findsOneWidget);
    expect(
      find.descendant(of: menu, matching: find.text('Members')),
      findsNothing,
    );
    await tester.tap(destination);
    await tester.pumpAndSettle();
    expect(workspace.location.route, RaftRoute.channel);
    expect(workspace.location.entityId, previous.id);
    expect(workspace.navigation.index, currentIndex + 1);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
