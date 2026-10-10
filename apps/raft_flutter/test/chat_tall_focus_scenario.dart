import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

/// Shared mounted product scenario. Native callers provide a constrained host;
/// widget callers simulate the keyboard inset through TestFlutterView.
Future<void> checkTallFocusReceipt(
  WidgetTester tester, {
  required RaftFamily family,
  required bool dark,
  Widget Function(Widget child)? hostBuilder,
  Future<void> Function()? resize,
  Future<void> Function(
    WidgetTester tester,
    Finder row,
    Rect bounds,
    Rect clip,
  )?
  onAccepted,
  Future<void> Function(WidgetTester tester, Finder row)? onComplete,
}) async {
  SharedPreferences.setMockInitialValues({});
  if (hostBuilder == null) {
    tester.view.physicalSize = const Size(411, 935);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 330);
    addTearDown(tester.view.reset);
  }
  final (w, api) = (await tester.runAsync(() => fixture('member')))!;
  addTearDown(w.dispose);
  w.ledger.switchServer('s1');
  final old = contextRows('old', count: 8);
  w.ledger.ingest(old, expectedGeneration: w.ledger.generation);
  w.visibleIds['c1'] = old.map((row) => row['id'] as String).toSet();
  final next = contextRows('target');
  next[40]['content'] = [for (var i = 0; i < 14; i++) 'Tall line $i 中文']
      .join('  \n');
  api.routes['GET /messages/context/target-40'] = (_) => {
    'messages': next,
    'hasOlder': true,
    'hasNewer': true,
  };
  api.routes['POST /channels/c1/read'] = (_) => {};
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: (hostBuilder ?? ((child) => child))(
        Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 244),
              Expanded(child: RaftChatView(controller: w)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(paintedMessage(tester, 'old-7'), isNotNull);
  await tester.runAsync(() => w.jumpToMessage('c1', 'target-40'));

  Rect? firstTarget;
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final visible = paintedMessage(tester, 'target-40');
    if (visible == null) continue;
    firstTarget ??= visible;
    expect(visible, firstTarget, reason: 'Publication must not jump');
  }
  final dynamic state = tester.state(find.byType(RaftChatView));
  final row =
      state.focusAnchors['target-40'].currentContext.findRenderObject()
          as RenderBox;
  final view = RenderAbstractViewport.of(row) as RenderBox;
  final rowRect = row.localToGlobal(Offset.zero) & row.size;
  final clip = view.localToGlobal(Offset.zero) & view.size;
  expect(rowRect.height, greaterThan(clip.height));
  expect(
    rowRect.center.dy,
    closeTo(clip.center.dy, .5),
    reason: 'Keep the real Source scrollIntoView center alignment',
  );
  expect(
    firstTarget,
    isNotNull,
    reason: 'A tall row covering the viewport must exit hidden staging',
  );
  expect(state.focusReceiptVisible('target-40'), true);
  expect(
    find.byType(RaftMessageTile, skipOffstage: false).evaluate().length,
    lessThan(40),
  );
  final acceptedElement = tester.element(
    find.byKey(const ValueKey('message-target-40')),
  );
  final originalOffset = state.viewport.offset as double;
  final press = Offset(rowRect.left + 2, clip.center.dy);
  expect(clip.contains(press), true);
  final hit = tester.hitTestOnBinding(press);
  expect(
    hit.path.any((entry) {
      Object? target = entry.target;
      while (target is RenderObject) {
        if (identical(target, row)) return true;
        target = target.parent;
      }
      return false;
    }),
    true,
    reason: 'Accepted target padding owns the first pointer',
  );
  await onAccepted?.call(
    tester,
    find.byKey(const ValueKey('message-target-40')),
    rowRect,
    clip,
  );

  // Actual layout with just the last or first 25px intersecting cannot
  // count as focus. In particular, an obsolete old row at the viewport
  // bottom must not satisfy the replacement's publication receipt.
  state.viewport.jumpTo(originalOffset + rowRect.bottom - clip.top - 25);
  await tester.pump();
  expect(state.focusReceiptVisible('target-40'), false);
  state.viewport.jumpTo(originalOffset - clip.bottom + 25 + rowRect.top);
  await tester.pump();
  expect(state.focusReceiptVisible('target-40'), false);
  state.viewport.jumpTo(originalOffset);
  await tester.pump();
  expect(paintedMessage(tester, 'target-40'), firstTarget);
  expect(
    tester.element(find.byKey(const ValueKey('message-target-40'))),
    same(acceptedElement),
  );
  await tester.pump(const Duration(milliseconds: 2200));
  await tester.pump();
  expect(w.highlightedMessageId, isNull);
  expect(paintedMessage(tester, 'target-40'), firstTarget);
  expect(
    tester.element(find.byKey(const ValueKey('message-target-40'))),
    same(acceptedElement),
  );
  if (resize != null) {
    await resize();
  } else {
    tester.view.physicalSize = const Size(465, 955);
  }
  await tester.pump();
  expect(
    tester.element(find.byKey(const ValueKey('message-target-40'))),
    same(acceptedElement),
  );
  expect(state.focusReceiptVisible('target-40'), true);
  expect(
    find.byType(RaftMessageTile, skipOffstage: false).evaluate().length,
    lessThan(40),
  );
  expect(tester.takeException(), isNull);
  await onComplete?.call(
    tester,
    find.byKey(const ValueKey('message-target-40')),
  );
  await tester.pumpWidget(const SizedBox());
}
