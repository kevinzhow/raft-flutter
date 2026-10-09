import 'dart:async';

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
      '[L02] $family/$dark live message during context preparation preserves old paint and first centered target',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final old = contextRows('old', count: 8);
        w.ledger.ingest(old, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = old.map((m) => m['id'] as String).toSet();
        final gate = Completer<Map<String, dynamic>>.sync();
        final requested = Completer<void>.sync();
        api.routes['GET /messages/context/target-40'] = (_) {
          requested.complete();
          return gate.future;
        };
        api.routes['POST /channels/c1/read'] = (_) => {};
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await tester.pumpAndSettle();
        final oldPaint = paintedMessage(tester, 'old-7');
        expect(oldPaint, isNotNull);
        await tester.runAsync(() async {
          unawaited(w.jumpToMessage('c1', 'target-40'));
          for (var n = 0; n < 40 && !requested.isCompleted; n++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(requested.isCompleted, true);
        });
        await tester.pump();
        expect(paintedMessage(tester, 'old-7'), oldPaint);
        await tester.runAsync(() async {
          gate.complete({
            'messages': contextRows('target'),
            'hasOlder': true,
            'hasNewer': false,
          });
          for (var n = 0; n < 40 && w.channelLoading; n++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(w.channelLoading, false);
        });
        // The response has laid out its bounded measurement, but its replacement
        // has not painted. A native socket event can arrive between these frames.
        await tester.pump();
        expect(paintedMessage(tester, 'target-40'), isNull);
        expect(paintedMessage(tester, 'old-7'), oldPaint);
        await tester.runAsync(() async {
          w.ledger.ingest([
            {
              'id': 'live-arrival',
              'channelId': 'c1',
              'seq': '81',
              'senderId': 'bob',
              'content': 'Arrived while the context was preparing',
            },
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1']!.add('live-arrival');
          w.notifyListeners();
          await Future<void>.delayed(Duration.zero);
        });
        Rect? first;
        for (var n = 0; n < 12; n++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
          final paint = paintedMessage(tester, 'target-40');
          if (paint == null) {
            expect(first, isNull, reason: 'Published target cannot disappear');
            expect(paintedMessage(tester, 'old-7'), oldPaint);
          } else {
            final dynamic state = tester.state(find.byType(RaftChatView));
            final row =
                state.focusAnchors['target-40'].currentContext
                        .findRenderObject()
                    as RenderBox;
            final viewport = RenderAbstractViewport.of(row) as RenderBox;
            expect(
              paint.center.dy,
              closeTo(
                viewport.localToGlobal(Offset.zero).dy +
                    viewport.size.height / 2,
                .5,
              ),
            );
            first ??= paint;
            expect(paint, first);
          }
        }
        expect(first, isNotNull);
        expect(w.messages.last.id, 'live-arrival');
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -6000),
        );
        await tester.pumpAndSettle();
        expect(paintedMessage(tester, 'live-arrival'), isNotNull);
        expect(
          find.text('Arrived while the context was preparing'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
