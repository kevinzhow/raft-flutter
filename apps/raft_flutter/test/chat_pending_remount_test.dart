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
      '$family/$dark new preview paints accepted same-channel window while context waits',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final accepted = contextRows('accepted'), next = contextRows('target');
        w.ledger.ingest(accepted, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = accepted.map((row) => row['id'] as String).toSet();
        w.setSection('activity');
        w.navigation.navigate(
          w.location.withQuery({'open': 'channel:c1', 'msg': 'target-40'}),
        );
        final started = Completer<void>.sync(),
            response = Completer<Map<String, dynamic>>.sync();
        api.routes['GET /messages/context/target-40'] = (_) {
          started.complete();
          return response.future;
        };
        await tester.runAsync(() async {
          unawaited(w.jumpToMessage('c1', 'target-40', navigate: false));
          await started.future;
        });
        expect(w.channelLoading, true);
        expect(
          w.messages.map((row) => row.id),
          accepted.map((row) => row['id']),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        Rect? acceptedRect;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final rect = paintedMessage(tester, 'accepted-79');
          if (rect != null) {
            acceptedRect ??= rect;
            expect(rect, acceptedRect);
          }
          expect(paintedMessage(tester, 'target-40'), isNull);
        }
        expect(acceptedRect, isNotNull);
        expect(w.channelLoading, true);
        expect(find.text('Loading...'), findsNothing);
        await tester.runAsync(() async {
          response.complete({
            'messages': next,
            'hasOlder': true,
            'hasNewer': true,
          });
          for (var i = 0; i < 40 && w.channelLoading; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(w.channelLoading, false);
        });
        Rect? targetRect;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final rect = paintedMessage(tester, 'target-40');
          if (rect == null) {
            expect(paintedMessage(tester, 'accepted-79'), acceptedRect);
          } else {
            targetRect ??= rect;
            expect(rect, targetRect);
            final row = find
                .byKey(const ValueKey('message-target-40'))
                .evaluate()
                .map((e) => e.findRenderObject())
                .whereType<RenderBox>()
                .firstWhere(
                  (r) =>
                      r.hasSize && r.localToGlobal(Offset.zero).dy == rect.top,
                );
            final viewport = RenderAbstractViewport.maybeOf(row) as RenderBox;
            expect(
              rect.center.dy,
              closeTo(
                viewport.localToGlobal(Offset.zero).dy +
                    viewport.size.height / 2,
                .5,
              ),
            );
          }
        }
        expect(targetRect, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
