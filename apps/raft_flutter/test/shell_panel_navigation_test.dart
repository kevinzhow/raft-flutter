import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/profile_side_panel.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';

import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;

void main() {
  testWidgets('wide human link opens the shared directory profile slot', (
    tester,
  ) async {
    final (workspace, _) = await pageFixture(tester);
    final direct = RaftLocation.at(
      serverSlug: workspace.location.serverSlug,
      route: RaftRoute.human,
      entityId: 'alice',
    );
    workspace.navigation.navigate(direct);
    await mountPage(tester, workspace, false, width: 1280);
    expect(workspace.location.route, RaftRoute.members);
    expect(workspace.location.profile?.id, 'alice');
    expect(find.byType(DesktopDirectoryView), findsOneWidget);
    expect(find.byType(ProfileSidePanel), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a profile opened on Members stays beside the directory', (
    tester,
  ) async {
    final (workspace, _) = await pageFixture(tester);
    workspace.setSection('members');
    await mountPage(tester, workspace, false, width: 1280);
    workspace.openProfile(RaftProfileKind.human, 'alice');
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSidePanel), findsOneWidget);

    final index = workspace.navigation.index;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSidePanel), findsNothing);
    expect(workspace.location.route, RaftRoute.members);
    expect(workspace.navigation.index, index);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Escape keeps an Activity entity slot open', (tester) async {
    final (workspace, _) = await pageFixture(tester);
    final slot = RaftLocation.at(
      serverSlug: workspace.location.serverSlug,
      route: RaftRoute.activity,
    ).withQuery({'open': 'human:alice'});
    workspace.navigation.navigate(slot);
    await mountPage(tester, workspace, false, width: 1280);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(workspace.location.uri, slot.uri);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Escape closes the conversation profile in place', (
    tester,
  ) async {
    final (workspace, _) = await pageFixture(tester);
    await mountPage(tester, workspace, false, width: 1280);
    final conversation = workspace.location.uri;
    workspace.openProfile(RaftProfileKind.human, 'alice');
    await tester.pumpAndSettle();
    final index = workspace.navigation.index;

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(workspace.location.uri, conversation);
    expect(workspace.navigation.index, index);
    expect(find.byType(ProfileSidePanel), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
