import 'package:flutter/material.dart';
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
        if (width < 1000) {
          await tester.tap(find.byKey(const Key('topbar-history')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Go $direction').last);
        } else {
          await tester.tap(find.byKey(Key('topbar-$direction')));
        }
        await tester.pumpAndSettle();
      }

      await step('back');
      expect(workspace.location.uri, members.uri);
      await step('forward');
      expect(workspace.location.uri, activity.uri);
      await step('back');
      expect(workspace.location.uri, members.uri);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }
}
