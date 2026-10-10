import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      '[P01] $family/$dark initial accepted channel releases offscreen rows and stays at latest',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, _) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final rows = contextRows('initial', count: 500);
        w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = rows.map((row) => row['id'] as String).toSet();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        Rect? firstLatest;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final latest = paintedMessage(tester, 'initial-499');
          if (latest == null) continue;
          firstLatest ??= latest;
          expect(latest, firstLatest, reason: 'Accepted latest cannot jump');
        }
        expect(firstLatest, isNotNull);
        expect(
          find.byType(RaftMessageTile, skipOffstage: false).evaluate().length,
          lessThan(80),
        );
        final dynamic state = tester.state(find.byType(RaftChatView));
        expect(state.viewport.offset, state.viewport.position.maxScrollExtent);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      '[P01] $family/$dark context focus releases offscreen rows without moving the accepted target',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final old = contextRows('old', count: 8);
        w.ledger.ingest(old, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = old.map((row) => row['id'] as String).toSet();
        final next = contextRows('target', count: 500);
        api.routes['GET /messages/context/target-300'] = (_) => {
          'messages': next,
          'hasOlder': true,
          'hasNewer': true,
        };
        api.routes['POST /channels/c1/read'] = (_) => {};
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => w.jumpToMessage('c1', 'target-300'));
        Rect? firstTarget;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final target = paintedMessage(tester, 'target-300');
          if (target == null) continue;
          final dynamic state = tester.state(find.byType(RaftChatView));
          final anchor =
              state.focusAnchors['target-300'].currentContext.findRenderObject()
                  as RenderBox;
          final clip = RenderAbstractViewport.of(anchor) as RenderBox;
          final bounds = clip.localToGlobal(Offset.zero) & clip.size;
          expect(target.center.dy, closeTo(bounds.center.dy, .5));
          firstTarget ??= target;
          expect(
            target,
            firstTarget,
            reason: 'Releasing the cache must not jump',
          );
        }
        final dynamic diagnostic = tester.state(find.byType(RaftChatView));
        expect(
          firstTarget,
          isNotNull,
          reason:
              '${w.messages.length} rows, ${w.error}, highlight ${w.highlightedMessageId}, staging ${diagnostic.focusStaging}, measured ${diagnostic.measuredContext}, queued ${diagnostic.positionQueued}',
        );
        expect(w.messages.length, 500);
        int mountedRows() =>
            find.byType(RaftMessageTile, skipOffstage: false).evaluate().length;
        expect(
          mountedRows(),
          lessThan(80),
          reason: 'A 500-message context must return to viewport-sized layout',
        );
        final targetState = tester.element(
          find.byKey(const ValueKey('message-target-300')),
        );
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump();
        expect(w.highlightedMessageId, isNull);
        expect(paintedMessage(tester, 'target-300'), firstTarget);
        expect(
          tester.element(find.byKey(const ValueKey('message-target-300'))),
          same(targetState),
        );

        // Native scroll and resize both previously laid out the whole retained
        // context. Bound the mounted product rows at each actual layout.
        final dynamic state = tester.state(find.byType(RaftChatView));
        for (var i = 0; i < 8; i++) {
          await tester.drag(
            find.byKey(const ValueKey('chat-list-channel')),
            const Offset(0, -180),
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(mountedRows(), lessThan(80));
        }
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(900, 600);
        await tester.pump();
        expect(mountedRows(), lessThan(80));
        expect(state.viewport.positions.length, 1);
        expect(state.viewport.position.outOfRange, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
