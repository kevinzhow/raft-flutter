import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/content_target.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;

class _FixtureNotifications extends NativeNotificationService {
  @override
  Future<void> bindAuthenticatedWorkspace(String? scope) async {}

  @override
  Future<void> detachWorkspace(String? account) async {}
}

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('missing native link shows Back at width $width', (
      tester,
    ) async {
      final (workspace, api) = await pageFixture(tester);
      api.routes['GET /servers'] = (_) => [
        {'id': 's1', 'slug': 'fixture'},
      ];
      api.routes['GET /channels/c1'] = (_) => {
        'id': 'c1',
        'serverId': 's1',
        'name': 'test',
        'type': 'channel',
        'joined': true,
      };
      api.routes['GET /messages/context/missing'] = (_) =>
          (404, {'error': 'Fixture missing context'});
      api.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [row('current', 'c1', 1)],
      };
      final coordinator = NativeContentCoordinator(
        notifications: _FixtureNotifications(),
        links: const Stream.empty(),
      );
      await mountPage(tester, workspace, false, width: width);
      final destination = workspace.location.uri;
      await tester.runAsync(() async => coordinator.bindWorkspace(workspace));
      try {
        await tester.runAsync(
          () => coordinator.navigate(
            const ContentTarget(
              serverId: 's1',
              channelId: 'c1',
              messageId: 'missing',
            ),
            externalLink: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('message-link-unavailable')),
          findsOneWidget,
        );
        expect(
          find.text("The link may be wrong, or you don't have access to it."),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('message-link-unavailable-back')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('message-link-unavailable')),
          findsNothing,
        );
        expect(workspace.location.uri, destination);
        expect(paintedMessage(tester, 'current'), isNotNull);
        expect(
          api.calls.where(
            (request) => request.path == '/messages/context/missing',
          ),
          isNotEmpty,
        );
      } finally {
        await tester.runAsync(coordinator.dispose);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    });
  }
}
