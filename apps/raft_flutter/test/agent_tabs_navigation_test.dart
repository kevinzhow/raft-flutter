import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';

import 'support/agent_panel_fixture.dart';

const _channelId = '11111111-1111-4111-8111-111111111111';
const _messageId = '22222222-2222-4222-8222-222222222222';
const _permalink =
    'https://app.raft.build/s/dev/channel/$_channelId?msg=$_messageId';

void main() {
  group('Chat tab', () {
    final routes = <String, Object? Function()>{
      '/agents/a/channels': () => {
        'channels': [
          {
            'id': 'c1',
            'name': 'general',
            'type': 'channel',
            'description': 'Everyone',
          },
          {'id': 'c2', 'name': 'design', 'type': 'private'},
        ],
      },
      '/agents/a/agent-dms': () => {
        'dms': [
          {
            'id': 'd1',
            'peerId': 'p1',
            'peerName': 'scout',
            'peerDisplayName': 'Scout',
            'createdAt': '2026-10-20T08:00:00.000Z',
            'lastMessageAt': null,
            'lastMessagePreview': null,
          },
        ],
      },
    };

    testWidgets('a channel row opens that channel', (tester) async {
      final opened = <String>[];
      await pumpAgentPanel(
        tester,
        routes: routes,
        tab: AgentDetailTab.chat,
        actions: AgentDetailActions(onOpenChannel: opened.add),
      );
      await tester.tap(find.text('general'));
      await tester.pump();
      await tester.tap(find.text('design'));
      await tester.pump();
      expect(opened, ['c1', 'c2']);
    });

    testWidgets('an Agent DM is activity only: no navigation', (tester) async {
      final opened = <String>[];
      await pumpAgentPanel(
        tester,
        routes: routes,
        tab: AgentDetailTab.chat,
        actions: AgentDetailActions(onOpenChannel: opened.add),
      );
      expect(find.text('Activity only'), findsOneWidget);
      await tester.tap(find.text('Scout'));
      await tester.pump();
      expect(opened, isEmpty);
    });
  });

  group('Reminders tab', () {
    Map<String, Object? Function()> reminders(
      List<Map<String, dynamic>> rows,
    ) => {
      '/reminders': () => {'reminders': rows},
    };
    final base = {
      'reminderId': 'r1',
      'title': 'Check the release',
      'fireAt': DateTime.now()
          .add(const Duration(hours: 3))
          .toUtc()
          .toIso8601String(),
      'status': 'scheduled',
      'ownerAgentId': 'a',
    };

    testWidgets('the message chip jumps back to the message', (tester) async {
      final opened = <String>[];
      await pumpAgentPanel(
        tester,
        routes: reminders([
          {...base, 'msgRef': '#general:2222', 'msgPermalink': _permalink},
        ]),
        tab: AgentDetailTab.reminders,
        actions: AgentDetailActions(onOpenMessage: opened.add),
      );
      expect(find.text('#general:2222'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-msg-ref')));
      await tester.pump();
      expect(opened, [_permalink]);
    });

    testWidgets('without a permalink the chip is plain text', (tester) async {
      final opened = <String>[];
      await pumpAgentPanel(
        tester,
        routes: reminders([
          {...base, 'msgRef': '#general:2222'},
        ]),
        tab: AgentDetailTab.reminders,
        actions: AgentDetailActions(onOpenMessage: opened.add),
      );
      expect(find.text('#general:2222'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-msg-ref')));
      await tester.pump();
      expect(opened, isEmpty);
    });

    testWidgets('a reminder without a message shows no chip', (tester) async {
      await pumpAgentPanel(
        tester,
        routes: reminders([base]),
        tab: AgentDetailTab.reminders,
      );
      expect(find.text('Check the release'), findsOneWidget);
      expect(find.byKey(const ValueKey('reminder-msg-ref')), findsNothing);
    });
  });

  group('tab order', () {
    Future<void> drag(WidgetTester tester, String from, String onto) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey('panel-tab-$from'))),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(ValueKey('panel-tab-$onto'))),
        timeStamp: const Duration(milliseconds: 100),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    List<String> order(WidgetTester tester) =>
        [
          for (final tab in [
            'profile',
            'activity',
            'chat',
            'reminders',
            'workspace',
            'apps',
            'mcp',
          ])
            if (find.byKey(ValueKey('panel-tab-$tab')).evaluate().isNotEmpty)
              tab,
        ]..sort((a, b) {
          final x = tester.getTopLeft(find.byKey(ValueKey('panel-tab-$a'))).dx;
          final y = tester.getTopLeft(find.byKey(ValueKey('panel-tab-$b'))).dx;
          return x.compareTo(y);
        });

    testWidgets('dragging a tab onto another reorders and saves the order', (
      tester,
    ) async {
      final (w, client) = await pumpAgentPanel(
        tester,
        size: const Size(1400, 900),
      );
      expect(order(tester), [
        'profile',
        'activity',
        'chat',
        'reminders',
        'workspace',
        'apps',
        'mcp',
      ]);
      await drag(tester, 'chat', 'profile');
      expect(order(tester).take(3), ['chat', 'profile', 'activity']);
      // Web's id of the Apps tab is `integrations`.
      expect(client.writes.single.$1, 'PATCH');
      expect(client.writes.single.$2, '/servers/s/sidebar-order');
      expect(w.sidebarOrder['agentPanelTabOrder'], [
        'chat',
        'profile',
        'activity',
        'reminders',
        'workspace',
        'integrations',
        'mcp',
      ]);
    });
  });
}
