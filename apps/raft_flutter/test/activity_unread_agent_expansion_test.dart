import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';

Future<void> drain(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 1180.0]) {
      for (final kind in ['thread', 'channel', 'dm']) {
        for (final unread in [true, false]) {
          testWidgets(
            '${dark ? 'dark' : 'light'} $width/$kind Activity opens ${unread ? 'unread' : 'read'} agent text after the read-all receipt',
            (tester) async {
              SharedPreferences.setMockInitialValues({});
              tester.view.physicalSize = Size(width, 900);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
              addTearDown(w.dispose);
              final scopeId = kind == 'thread'
                  ? 'thread-1'
                  : kind == 'dm'
                  ? 'd1'
                  : 'c1';
              if (kind == 'dm') {
                w.dms = [
                  RaftChannel({
                    'id': 'd1',
                    'name': 'Bob',
                    'type': 'dm',
                    'joined': true,
                  }),
                ];
              }
              w.loading = false;
              w.connected = true;
              w.messageDomain.ledger.switchServer('s1');
              w.section = 'activity';
              w.readState.consumeUpdate(
                {
                  'serverId': 's1',
                  'scopeId': scopeId,
                  'maxReadSeq': unread ? 4 : 5,
                  'readStateVersion': 1,
                },
                serverId: 's1',
                principalId: 'alice',
              );
              final row = activityRow(kind, unread: unread ? 1 : 0);
              row['firstUnreadMessageId'] = unread ? 'm5' : null;
              row['readState'] = {
                'kind': 'present',
                'maxReadSeq': unread ? '4' : '5',
                'readStateVersion': 1,
                'latestActivity': {'messageId': 'm5', 'seq': '5'},
              };
              final reply = {
                'id': 'm5',
                'channelId': scopeId,
                'seq': '5',
                'senderType': 'agent',
                'senderId': 'agent-1',
                'senderName': 'Fixture agent',
                'content': List.generate(
                  36,
                  (i) =>
                      'Paragraph $i. This long agent reply must remain readable.',
                ).join('\n\n'),
              };
              final history = Completer<Map<String, dynamic>>();
              api.routes['GET /channels/inbox'] = (_) => {
                'items': [row],
                'totalCount': 1,
                'totalUnreadCount': unread ? 1 : 0,
                'hasMore': false,
              };
              api.routes['GET /agents'] = (_) => [];
              api.routes['GET /servers/s1/members'] = (_) => [];
              api.routes['GET /channels/unread'] = (_) => {'channels': {}};
              api.routes['GET /channels/c1'] = (_) => w.channels.first.json;
              api.routes['GET /channels/d1'] = (_) => w.dms.first.json;
              api.routes['GET /channels/threads/followed'] = (_) => {
                'threads': [],
              };
              api.routes['GET /channels/thread-1/followers'] = (_) => [];
              api.routes['GET /channels/c1/threads/parent'] = (_) => {
                'threadChannelId': 'thread-1',
              };
              api.routes['GET /messages/context/parent'] = (_) => {
                'messages': [
                  {
                    'id': 'parent',
                    'channelId': 'c1',
                    'seq': '1',
                    'senderType': 'user',
                    'senderId': 'bob',
                    'senderName': 'Bob',
                    'content': 'Parent message',
                  },
                ],
              };
              api.routes['GET /messages/context/m5'] = (_) => history.future;
              api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
              api.routes['GET /messages/channel/$scopeId'] = (_) =>
                  history.future;
              api.routes['POST /channels/$scopeId/read-all'] = (_) => {
                'maxReadSeq': 5,
                'readStateVersion': 2,
              };
              api.routes['POST /channels/$scopeId/read'] = (_) => {
                'maxReadSeq': 5,
                'readStateVersion': 2,
              };
              api.routes['POST /feature-flags/evaluate'] = (_) => {
                'evaluations': [],
              };
              api.routes['GET /servers/s1/setup-projection'] = (_) => {
                'phase': 'complete',
                'surface': 'complete',
                'blocksChat': false,
              };
              await tester.pumpWidget(
                MaterialApp(
                  theme: raftTheme(dark: dark),
                  home: withAppServices(
                    WorkspaceView(
                      controller: w,
                      appearance: RaftAppearance(),
                      onAppearance: (_) async {},
                      onLogout: () async {},
                    ),
                  ),
                ),
              );
              try {
                await tester.pumpAndSettle();
                final card = find.byKey(
                  ValueKey(
                    kind == 'thread'
                        ? 'activity-thread-thread-1'
                        : 'activity-$kind-$scopeId',
                  ),
                );
                expect(card, findsOneWidget);
                await tester.tap(card);
                await drain(tester);
                expect(
                  w.readState.state('s1', 'alice', scopeId)?['maxReadSeq'],
                  5,
                  reason: 'The real Activity action must accept its read-all receipt before history arrives.',
                );
                expect(paintedMessage(tester, 'm5'), isNull);
                history.complete({
                  'messages': [reply],
                  'hasOlder': false,
                  'hasNewer': false,
                });
                await drain(tester);
                expect(paintedMessage(tester, 'm5'), isNotNull);
                final message = find.byKey(const ValueKey('message-m5'));
                final collapse = find.descendant(
                  of: message,
                  matching: find.byType(RaftCollapsible),
                );
                expect(collapse, findsOneWidget);
                final toggle = find.descendant(
                  of: collapse,
                  matching: find.text(unread ? 'Collapse' : 'Show More'),
                );
                expect(
                  toggle,
                  findsOneWidget,
                  reason: unread
                      ? 'A message unread when Activity was opened must start expanded even if opening already advanced its read cursor.'
                      : 'An already-read message must retain the existing collapsed behavior.',
                );
                await tester.ensureVisible(toggle);
                await tester.pumpAndSettle();
                await tester.tap(toggle);
                await tester.pumpAndSettle();
                w.notifyListeners();
                await drain(tester);
                expect(
                  find.descendant(
                    of: collapse,
                    matching: find.text(unread ? 'Show More' : 'Collapse'),
                  ),
                  findsOneWidget,
                  reason:
                      'Manual choice survives the read receipt and a rebuild.',
                );
                expect(tester.takeException(), isNull);
              } finally {
                if (!history.isCompleted) {
                  history.complete({'messages': <dynamic>[]});
                }
                await tester.pumpWidget(const SizedBox.shrink());
                await drain(tester);
              }
            },
          );
        }
      }
    }
  }
}
