import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'history_load_once_test.dart' show historyFixture, idle, land;

/// The timeline scrollbar's thumb, from its painter's own hit test.
Rect? thumbRect(WidgetTester tester) {
  for (final e
      in find
          .descendant(
            of: find.byType(RaftChatView),
            matching: find.byType(CustomPaint),
          )
          .evaluate()) {
    final painter = (e.widget as CustomPaint).foregroundPainter;
    final box = e.renderObject! as RenderBox;
    if (painter is! ScrollbarPainter || box.size.height < 300) continue;
    double? top, bottom;
    for (var y = 0.0; y < box.size.height; y += .5) {
      final local = Offset(box.size.width - 4, y);
      if (painter.hitTestOnlyThumbInteractive(local, PointerDeviceKind.mouse)) {
        top ??= y;
        bottom = y;
      }
    }
    if (top == null) return null;
    final origin = box.localToGlobal(Offset.zero);
    return Rect.fromLTRB(
      origin.dx + box.size.width - 8,
      origin.dy + top,
      origin.dx + box.size.width,
      origin.dy + bottom! + .5,
    );
  }
  return null;
}

/// Index of the topmost painted message row (`h-<index>`).
int? topRow(WidgetTester tester) {
  int? best;
  double? bestTop;
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('message-h-'),
          )
          .evaluate()) {
    final render = e.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) continue;
    final Object? view = RenderAbstractViewport.maybeOf(render);
    if (view is! RenderBox) continue;
    final rect = render.localToGlobal(Offset.zero) & render.size;
    final clip = view.localToGlobal(Offset.zero) & view.size;
    if (!rect.overlaps(clip)) continue;
    if (bestTop == null || rect.top < bestTop) {
      bestTop = rect.top;
      best = int.parse(
        (e.widget.key! as ValueKey<String>).value.substring(
          'message-h-'.length,
        ),
      );
    }
  }
  return best;
}

/// Dragging the timeline's scrollbar thumb: the thumb stays under the
/// pointer, each frame builds only about a screen of rows (a far target is
/// re-centered instead of laying out the distance), the content moves
/// monotonically, and holding the thumb at the top loads one older page.
void main() {
  for (final thread in [false, true]) {
    testWidgets(
      '${thread ? 'thread' : 'channel'}: scrollbar thumb drag bottom to top',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, older) = await historyFixture(
          tester,
          thread: thread,
          first: 300,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: RaftChatView(controller: w, thread: thread),
            ),
          ),
        );
        await idle(tester, 30);
        final dynamic state = tester.state(find.byType(RaftChatView));
        final ScrollController scroll = state.viewport;
        // Start at the latest end (threads open at their head).
        scroll.jumpTo(scroll.position.maxScrollExtent);
        // Show the bar.
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(find.byType(RaftChatView)),
            scrollDelta: const Offset(0, -10),
          ),
        );
        await idle(tester, 10);
        final start = thumbRect(tester)!;
        final grabDy = 10.0;
        var pointer = Offset(start.center.dx, start.top + grabDy);
        final gesture = await tester.startGesture(
          pointer,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 16));
        const frames = 12;
        final travel = start.top - 4;
        final log = <String>[];
        var maxBuilt = 0;
        int? lastTop = topRow(tester);
        for (var i = 0; i < frames; i++) {
          final before = RaftMessageTimeline.debugRowBuilds;
          pointer = pointer.translate(0, -travel / frames);
          await gesture.moveTo(pointer);
          await tester.pump(const Duration(milliseconds: 16));
          final built = RaftMessageTimeline.debugRowBuilds - before;
          final thumb = thumbRect(tester)!;
          final row = topRow(tester);
          log.add(
            '$i built=$built thumbTop=${thumb.top} pointer=${pointer.dy} '
            'row=$row',
          );
          if (built > maxBuilt) maxBuilt = built;
          // The thumb is where the pointer holds it.
          expect(
            (thumb.top + grabDy - pointer.dy).abs(),
            lessThanOrEqualTo(2),
            reason: log.join('\n'),
          );
          // Toward older only.
          expect(row, isNotNull, reason: log.join('\n'));
          if (lastTop != null) {
            expect(row, lessThanOrEqualTo(lastTop), reason: log.join('\n'));
          }
          lastTop = row;
        }
        // About a screen of rows per frame (walking ~2800 px per step built
        // 27-35 rows a frame before).
        expect(maxBuilt, lessThanOrEqualTo(24), reason: log.join('\n'));
        expect(older, isEmpty);
        // Hold at the top: one page, landing never re-triggers.
        for (var i = 0; i < 6; i++) {
          pointer = pointer.translate(0, -2);
          await gesture.moveTo(pointer);
          await tester.pump(const Duration(milliseconds: 16));
        }
        // The oldest loaded row (rows h-700 on) is at the top.
        expect(topRow(tester), 700, reason: log.join('\n'));
        expect(older, hasLength(1));
        await land(tester, w, older, thread: thread);
        // The row that was at the top stays put while the pointer keeps
        // reaching up: the landed page is not jumped into.
        final held = paintedMessage(tester, 'h-700');
        expect(held, isNotNull);
        for (var i = 0; i < 20; i++) {
          pointer = pointer.translate(0, -2);
          await gesture.moveTo(pointer);
          await tester.pump(const Duration(milliseconds: 16));
          expect(paintedMessage(tester, 'h-700'), held, reason: 'hold $i');
        }
        expect(older, hasLength(1), reason: 'landing re-triggered a load');
        await gesture.up();
        await idle(tester, 30);
        expect(older, hasLength(1));
        // After release the thumb reflects the grown range: not at the top.
        expect(thumbRect(tester)!.top, greaterThan(start.top * .05));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}
