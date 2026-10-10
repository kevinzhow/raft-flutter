import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

/// messageStore.ts:2461-2486: a failed target load keeps the displayed rows
/// while the latest page loads, then shows the latest window. Distinguishing
/// "not found" from the plan history limit is a separate product gap (see the
/// L05 defect report), so this proof is intentionally untagged.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark failed target keeps the painted rows until the latest page lands',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final old = contextRows('old');
        w.ledger.ingest(old, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = old.map((r) => r['id'] as String).toSet();
        // The unregistered context route answers the fixture's real 404.
        final latestRequested = Completer<void>.sync();
        final latest = Completer<Map<String, dynamic>>.sync();
        api.routes['GET /messages/channel/c1'] = (_) {
          latestRequested.complete();
          return latest.future;
        };
        api.routes['POST /channels/c1/read'] = (_) => {};
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await tester.pumpAndSettle();
        final oldRect = paintedMessage(tester, 'old-79');
        expect(oldRect, isNotNull);

        await tester.runAsync(() async {
          unawaited(w.jumpToMessage('c1', 'missing-target'));
          for (var i = 0; i < 40 && !latestRequested.isCompleted; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(latestRequested.isCompleted, true);
        });
        // The target failed and the latest page is on its way: nothing that
        // was painted disappears or moves, and no blank loading page appears.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(paintedMessage(tester, 'old-79'), oldRect);
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('Start the conversation'), findsNothing);
          expect(w.messages.map((r) => r.id), old.map((r) => r['id']));
          expect(w.highlightedMessageId, isNull);
        }
        await tester.runAsync(() async {
          latest.complete({'messages': contextRows('latest', count: 8)});
          for (var i = 0; i < 40 && w.channelLoading; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await tester.pumpAndSettle();
        expect(w.channelLoading, false);
        expect(w.hasNewer, false);
        expect(paintedMessage(tester, 'latest-7'), isNotNull);
        expect(find.text('Back to bottom'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
