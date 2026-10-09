import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

List<Map<String, dynamic>> contextRows(String prefix, {int count = 80}) => [
  for (var i = 0; i < count; i++)
    {
      'id': '$prefix-$i',
      'channelId': 'c1',
      'seq': '${i + 1}',
      'senderId': 'alice',
      'content': List.filled(i % 4 + 1, '$prefix message $i').join('\n'),
    },
];

/// Checks current paint ancestry and the real clip, not a mounted lazy-row key.
Rect? paintedMessage(WidgetTester tester, String id) {
  for (final element in find.byKey(ValueKey('message-$id')).evaluate()) {
    var painted = true;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget case Opacity(opacity: 0)) painted = false;
      return true;
    });
    final render = element.findRenderObject();
    if (!painted ||
        render is! RenderBox ||
        !render.attached ||
        !render.hasSize) {
      continue;
    }
    final Object? view = RenderAbstractViewport.maybeOf(render);
    if (view is! RenderBox || !view.hasSize) continue;
    final bounds = render.localToGlobal(Offset.zero) & render.size;
    final clip = view.localToGlobal(Offset.zero) & view.size;
    if (bounds.overlaps(clip)) return bounds;
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
      '$family/$dark context keeps old paint then publishes centered target once',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final old = contextRows('old'), next = contextRows('target');
        w.ledger.ingest(old, expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = old.map((r) => r['id'] as String).toSet();
        final requested = Completer<void>.sync();
        final response = Completer<Map<String, dynamic>>.sync();
        api.routes['GET /messages/context/target-40'] = (_) {
          requested.complete();
          return response.future;
        };
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
          unawaited(w.jumpToMessage('c1', 'target-40'));
          for (var i = 0; i < 40 && !requested.isCompleted; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(requested.isCompleted, true);
        });
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(paintedMessage(tester, 'old-79'), oldRect);
          expect(paintedMessage(tester, 'target-40'), isNull);
          expect(w.messages.map((r) => r.id), old.map((r) => r['id']));
        }
        w.unread['c1'] = 3;
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
        var published = false;
        Rect? firstTarget;
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final target = paintedMessage(tester, 'target-40');
          if (target == null) {
            expect(
              published,
              false,
              reason: 'A published target cannot disappear',
            );
            expect(paintedMessage(tester, 'old-79'), oldRect);
          } else {
            final dynamic state = tester.state(find.byType(RaftChatView));
            final anchor =
                state.focusAnchors['target-40'].currentContext
                        .findRenderObject()
                    as RenderBox;
            final view = RenderAbstractViewport.of(anchor) as RenderBox;
            final clip = view.localToGlobal(Offset.zero) & view.size;
            expect(target.center.dy, closeTo(clip.center.dy, .5));
            firstTarget ??= target;
            expect(
              target,
              firstTarget,
              reason: 'No visible retry or intermediate jump',
            );
            published = true;
          }
        }
        expect(published, true);
        expect(w.highlightedMessageId, 'target-40');
        expect(
          tester
              .widget<RaftMessageTile>(
                find.byKey(const ValueKey('message-target-40')),
              )
              .highlighted,
          true,
        );
        expect(find.text('3 new messages'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1700));
        expect(w.highlightedMessageId, 'target-40');
        await tester.pump(const Duration(milliseconds: 400));
        expect(w.highlightedMessageId, isNull);
        expect(
          tester
              .widget<RaftMessageTile>(
                find.byKey(const ValueKey('message-target-40')),
              )
              .highlighted,
          false,
        );
        expect(paintedMessage(tester, 'target-40'), firstTarget);

        final latestRequested = Completer<void>.sync();
        final latestResponse = Completer<Map<String, dynamic>>.sync();
        api.routes['GET /messages/channel/c1'] = (_) {
          latestRequested.complete();
          return latestResponse.future;
        };
        api.routes['POST /channels/c1/read'] = (_) => {};
        await tester.tap(find.text('3 new messages'));
        for (var i = 0; i < 20 && !latestRequested.isCompleted; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(latestRequested.isCompleted, true);
        await tester.pump(const Duration(milliseconds: 16));
        expect(paintedMessage(tester, 'target-40'), firstTarget);
        expect(w.channelLoading, true);
        await tester.runAsync(() async {
          latestResponse.complete({
            'messages': contextRows('latest', count: 8),
          });
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(w.hasNewer, false);
        expect(paintedMessage(tester, 'latest-7'), isNotNull);
        final dynamic state = tester.state(find.byType(RaftChatView));
        expect(state.viewport.offset, state.viewport.position.maxScrollExtent);
        expect(find.text('Back to bottom'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
