import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'chat_focus_receipt_test.dart' show paintedMessage;

void main() {
  testWidgets('macOS retained rich rows survive updates and channel changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    w.messageDomain.ledger.switchServer('s1');
    final channels = [
      for (final id in ['c1', 'c2'])
        RaftChannel({'id': id, 'name': id, 'joined': true}),
    ];
    w.channels = channels;
    final rows = [
      for (final channel in channels)
        for (var i = 0; i < 80; i++)
          <String, dynamic>{
            'id': '${channel.id}-$i',
            'channelId': channel.id,
            'seq': '${i + 1}',
            'senderId': 'alice',
            'senderType': 'user',
            'senderName': 'Alice',
            'content':
                'First paragraph $i with `code` and **bold**.\n\nSecond paragraph.\n\n- List A\n- List B',
          },
    ];
    w.messageDomain.ledger.ingest(
      rows,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    for (final channel in channels) {
      w.messageDomain.visibleIds[channel.id] = rows
          .where((r) => r['channelId'] == channel.id)
          .map((r) => r['id'] as String)
          .toSet();
    }
    Future<void>? selecting;
    for (final channel in channels) {
      api.routes['GET /messages/channel/${channel.id}'] = (_) => {
        'messages': rows.where((r) => r['channelId'] == channel.id).toList(),
      };
      api.routes['GET /tasks/channel/${channel.id}'] = (_) => {'tasks': []};
      api.routes['POST /channels/${channel.id}/read'] = (_) => {};
    }
    Widget host({bool dark = false}) => MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Column(
          children: [
            Row(
              children: [
                for (final channel in channels)
                  TextButton(
                    onPressed: () {
                      selecting = w.selectChannel(channel, autoRead: false);
                    },
                    child: Text('Open ${channel.id}'),
                  ),
              ],
            ),
            Expanded(child: RaftChatView(controller: w)),
          ],
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    for (var turn = 0; turn < 3; turn++) {
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(RaftMessageTimeline),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final latest = scroll.pixels;
      for (final offset in [400.0, 800.0, 1200.0]) {
        scroll.jumpTo(
          (latest - offset).clamp(
            scroll.minScrollExtent,
            scroll.maxScrollExtent,
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(
          ValueKey('message-${w.channel!.id}-79'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(paintedMessage(tester, '${w.channel!.id}-79'), isNull);
      final edited = [
        for (final row in rows.where((r) => r['channelId'] == w.channel!.id))
          {...row, 'content': '${row['content']}\n\nLive update $turn.'},
      ];
      for (final editedRow in edited) {
        final index = rows.indexWhere((r) => r['id'] == editedRow['id']);
        rows[index] = editedRow;
      }
      await tester.runAsync(() async {
        w.messageDomain.ledger.ingest(
          edited,
          expectedGeneration: w.messageDomain.ledger.generation,
        );
        w.notifyListeners();
        await Future<void>.delayed(Duration.zero);
      });
      expect(
        w.messageDomain.messages.last.content,
        contains('Live update $turn.'),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(dark: turn.isEven));
      await tester.pumpAndSettle();
      final refreshed = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(RaftMessageTimeline),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      refreshed.jumpTo(refreshed.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.textContaining('Live update $turn.'), findsWidgets);
      await tester.runAsync(() async {
        await tester.tap(find.text('Open c${(turn + 1) % 2 + 1}'));
        await selecting;
      });
      await tester.pumpAndSettle();
      expect(w.channel!.id, 'c${(turn + 1) % 2 + 1}');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
