import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show frames, pageFixture;

void main() {
  testWidgets('an agent DM drops the cached avatar after a reset', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester, section: 'chat');
    final dm = RaftChannel({
      'id': 'reset-dm',
      'type': 'dm',
      'name': 'Agent DM',
      'joined': true,
      'peerType': 'agent',
      'peerId': 'agent1',
      'peerName': 'Cindy',
      'peerDescription': 'Old description from DM discovery',
      'peerAvatarUrl': 'pixel:owl',
    });
    workspace.dms = [dm];
    api.routes['GET /channels/dm'] = (_) => [dm.json];
    api.routes['GET /messages/channel/reset-dm'] = (_) => {'messages': []};
    api.routes['GET /tasks/channel/reset-dm'] = (_) => [];
    api.routes['GET /channels/reset-dm/members'] = (_) => [];
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /announcements/active'] = (_) => null;
    await mountShell(tester, workspace, false);
    final row = find.byKey(const ValueKey('sidebar-channel-reset-dm'));
    final pixel = find.descendant(
      of: row,
      matching: find.byType(RaftPixelAvatar),
    );
    final frame = find.descendant(
      of: row,
      matching: find.byType(RaftMountedAvatarFrame),
    );
    try {
      final sidebar = tester.getRect(
        find.byKey(const Key('workspace-sidebar')),
      );
      final button = tester.getRect(row);
      expect(button.left, sidebar.left);
      expect(button.width, sidebar.width);
      expect(button.height, 34);
      expect(
        find.descendant(
          of: row,
          matching: find.text('Old description from DM discovery'),
        ),
        findsNothing,
      );
      expect(
        tester.widget<RaftMountedAvatarFrame>(frame).presence?.light,
        RaftPresence.offline,
      );
      expect(tester.widget<RaftPixelAvatar>(pixel).avatarKey, 'owl');

      api.routes['GET /agents'] = (_) => [
        {
          'id': 'agent1',
          'name': 'Cindy',
          'description': 'Current agent description',
          'avatarUrl': null,
          'status': 'active',
          'activity': 'working',
        },
      ];
      await tester.runAsync(
        () => workspace.entityDirectory.refresh(WorkspaceEntityKind.agents),
      );
      await frames(tester, () {});
      await tester.pumpAndSettle();
      expect(tester.widget<RaftPixelAvatar>(pixel).avatarKey, 'robot');
      expect(
        find.descendant(
          of: row,
          matching: find.text('Current agent description'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<RaftMountedAvatarFrame>(frame).presence?.light,
        RaftPresence.busy,
      );
      final currentButton = tester.getRect(row);
      final edge = Offset(currentButton.left + 1, currentButton.center.dy);
      await tester.tapAt(edge, kind: PointerDeviceKind.mouse);
      await frames(tester, () {});
      expect(workspace.channel?.id, dm.id);
    } finally {
      await retire(tester);
    }
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
}
