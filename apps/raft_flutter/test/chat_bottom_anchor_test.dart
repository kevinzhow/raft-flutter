import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[P04] $family/$dark channel opens at its latest row with one screen laid out',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, _) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final rows = contextRows('open', count: 500);
        w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = rows.map((r) => r['id'] as String).toSet();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        // The newest row is painted after the first few frames, and only rows
        // near the viewport were ever laid out.
        Rect? latest;
        for (var i = 0; i < 6 && latest == null; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          latest = paintedMessage(tester, 'open-499');
        }
        expect(latest, isNotNull);
        expect(
          find.byType(RaftMessageTile, skipOffstage: false).evaluate().length,
          lessThan(40),
        );
        final dynamic state = tester.state(find.byType(RaftChatView));
        expect(state.distanceFromLatest(state.viewport.position), 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '[P04] $family/$dark arrival while scrolled up keeps the reading position',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        api.routes['POST /channels/c1/read'] = (_) => {};
        w.ledger.switchServer('s1');
        final rows = contextRows('read', count: 60);
        w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = rows.map((r) => r['id'] as String).toSet();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byType(RaftChatView));
        final ScrollController viewport = state.viewport;
        // Toward older history (top).
        viewport.jumpTo(viewport.offset - 2400);
        await tester.pumpAndSettle();
        // Pick a fully painted row in the middle of the viewport.
        String? anchor;
        Rect? before;
        for (final row in rows.reversed) {
          final rect = paintedMessage(tester, row['id'] as String);
          if (rect != null && rect.top > 200 && rect.bottom < 700) {
            anchor = row['id'] as String;
            before = rect;
            break;
          }
        }
        expect(anchor, isNotNull);
        await tester.runAsync(() async {
          w.ledger.ingest([
            {
              'id': 'read-arrival',
              'channelId': 'c1',
              'seq': '999',
              'senderId': 'bob',
              'content': 'A new message while reading history',
            },
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1']!.add('read-arrival');
          w.notifyListeners();
          await Future<void>.delayed(Duration.zero);
        });
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          // The inserted row is absorbed in the same frame, including when
          // the list replaces an estimated extent with the real one.
          expect(paintedMessage(tester, anchor!), before);
        }
        expect(find.textContaining('new message'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
