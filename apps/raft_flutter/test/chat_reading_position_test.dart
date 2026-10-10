import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show fixture;

/// ChatPanel.tsx:599-640 and messageStore.ts:2043-2108 reading-position rules:
/// off-bottom arrivals only count, an own message follows to the latest end and
/// older pages are prepended without moving the reader. These proofs are
/// intentionally untagged: the downward (`after=`) page of a history window is
/// a product gap, so they cannot claim the whole L07 contract.
List<Map<String, dynamic>> _rows(String prefix, int from, int count) => [
  for (var i = from; i < from + count; i++)
    {
      'id': '$prefix-$i',
      'channelId': 'c1',
      'seq': '${i + 1}',
      'senderId': 'bob',
      'content': List.filled(i % 4 + 1, '$prefix message $i').join('\n'),
    },
];

Future<void> _mount(
  WidgetTester tester,
  WorkspaceController w,
  RaftFamily family,
  bool dark,
) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: Scaffold(body: RaftChatView(controller: w)),
    ),
  );
  await tester.pumpAndSettle();
}

/// The first fully painted row inside the reading area.
(String, Rect)? _anchor(WidgetTester tester, List<Map<String, dynamic>> rows) {
  for (final row in rows.reversed) {
    final rect = paintedMessage(tester, row['id'] as String);
    if (rect != null && rect.top > 150 && rect.bottom < 650) {
      return (row['id'] as String, rect);
    }
  }
  return null;
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark scrolled-up arrivals are counted without moving, an own send follows to the end',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        api.routes['POST /channels/c1/read'] = (_) => {};
        w.ledger.switchServer('s1');
        final rows = _rows('read', 0, 60);
        w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = rows.map((r) => r['id'] as String).toSet();
        await _mount(tester, w, family, dark);
        final dynamic state = tester.state(find.byType(RaftChatView));
        final ScrollController viewport = state.viewport;
        viewport.jumpTo(viewport.offset - 2400);
        await tester.pumpAndSettle();
        final (anchor, before) = _anchor(tester, rows)!;
        expect(find.byType(RaftTimelineBottomButton), findsOneWidget);
        expect(find.text('Back to bottom'), findsOneWidget);

        Future<void> arrive(String id, int seq, String sender) async {
          w.ledger.ingest([
            {
              'id': id,
              'channelId': 'c1',
              'seq': '$seq',
              'senderId': sender,
              'content': 'Arrival $id',
            },
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1']!.add(id);
          w.notifyListeners();
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            // Neither the count nor the new row moves the reader.
            expect(paintedMessage(tester, anchor), before);
          }
        }

        await arrive('other-1', 900, 'bob');
        expect(find.textContaining('1 new message'), findsOneWidget);
        expect(find.text('Back to bottom'), findsNothing);
        await arrive('other-2', 901, 'bob');
        expect(find.textContaining('2 new message'), findsOneWidget);
        expect(state.distanceFromLatest(viewport.position), greaterThan(100));

        // The reader's own send goes back to the latest end, wherever they are.
        api.routes['POST /v2/messages'] = (o) => {
          'message': {
            'id': 'own-1',
            'channelId': 'c1',
            'seq': '902',
            'senderId': 'alice',
            'content': o.data['content'],
            'randomId': o.data['randomId'],
          },
        };
        await tester.enterText(
          find.descendant(
            of: find.byType(RaftComposer),
            matching: find.byType(TextField),
          ),
          'My own message',
        );
        await tester.pump();
        await tester.tap(
          find.byWidgetPredicate(
            (x) => x is RaftComposerAction && x.glyph == RaftGlyph.send,
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(state.distanceFromLatest(viewport.position), 0);
        expect(find.text('My own message'), findsOneWidget);
        expect(find.byType(RaftTimelineBottomButton), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      '$family/$dark loading an older page keeps the reading position',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final rows = _rows('page', 50, 60);
        w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = rows.map((r) => r['id'] as String).toSet();
        w.hasMore = true;
        final requests = <Map<String, dynamic>>[];
        final page = Completer<Map<String, dynamic>>();
        api.routes['GET /messages/channel/c1'] = (o) {
          requests.add(Map.of(o.queryParameters));
          return page.future;
        };
        await _mount(tester, w, family, dark);
        // A real upward drag toward older history arms and triggers paging.
        for (var i = 0; i < 40 && requests.isEmpty; i++) {
          await tester.drag(
            find.byType(RaftMessageTimeline),
            const Offset(0, 300),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(requests, hasLength(1));
        // The request pages from the oldest loaded row.
        expect(requests.single['before'], '51');
        await tester.pumpAndSettle();
        final (anchor, before) = _anchor(tester, rows)!;
        await tester.runAsync(() async {
          page.complete({'messages': _rows('older', 0, 50), 'hasOlder': false});
          await Future<void>.delayed(Duration.zero);
        });
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          // The prepended page sits above the reader: nothing moves.
          expect(paintedMessage(tester, anchor), before);
        }
        await tester.pumpAndSettle();
        expect(w.messages.first.id, 'older-0');
        expect(w.messages.length, 110);
        expect(paintedMessage(tester, anchor), before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
