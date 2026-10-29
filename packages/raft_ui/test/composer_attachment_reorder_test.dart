// Web MessageInput pending attachments are sortable (dnd-kit): a chip dragged
// onto another takes its place, the others shift while it is dragged, and the
// new order is reported once, when the drag ends.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

RaftComposerAttachment _file(String id) => RaftComposerAttachment(
  id: id,
  name: '$id.pdf',
  mimeType: 'application/pdf',
);

Future<List<List<String>>> _pump(
  WidgetTester tester,
  List<RaftComposerAttachment> items, {
  bool touch = false,
  bool sortable = true,
}) async {
  final orders = <List<String>>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftDensityScope(
          density: touch ? RaftDensity.touch : RaftDensity.desktop,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 420,
              child: RaftComposerAttachments(
                items: items,
                onRemove: (_) {},
                onReorder: sortable ? orders.add : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return orders;
}

Finder _chip(String id) => find.byKey(ValueKey('composer-attachment-$id'));

void main() {
  final items = [_file('a'), _file('b'), _file('c')];

  testWidgets('dragging a chip onto another reports the new order once', (
    tester,
  ) async {
    final orders = await _pump(tester, items);
    final target = tester.getCenter(_chip('c'));
    final gesture = await tester.startGesture(
      tester.getCenter(_chip('a')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    // The others shift while dragging; nothing is reported until the drop.
    expect(orders, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(orders, [
      ['b', 'c', 'a'],
    ]);
  });

  testWidgets('a drag that ends where it began reports nothing', (
    tester,
  ) async {
    final orders = await _pump(tester, items);
    final start = tester.getCenter(_chip('b'));
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveTo(start);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(orders, isEmpty);
  });

  testWidgets('a finger needs a long press first, so a swipe stays a swipe', (
    tester,
  ) async {
    final orders = await _pump(tester, items, touch: true);
    final swipe = await tester.startGesture(tester.getCenter(_chip('a')));
    await swipe.moveTo(tester.getCenter(_chip('c')));
    await swipe.up();
    await tester.pumpAndSettle();
    expect(orders, isEmpty);

    final hold = await tester.startGesture(tester.getCenter(_chip('a')));
    await tester.pump(const Duration(milliseconds: 600));
    await hold.moveTo(tester.getCenter(_chip('b')));
    await tester.pump();
    await hold.up();
    await tester.pumpAndSettle();
    expect(orders, [
      ['b', 'a', 'c'],
    ]);
  });

  testWidgets('without onReorder the chips are fixed', (tester) async {
    final orders = await _pump(tester, items, sortable: false);
    final gesture = await tester.startGesture(
      tester.getCenter(_chip('a')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(tester.getCenter(_chip('c')));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(orders, isEmpty);
  });

  testWidgets('a sortable file chip shows the grab cursor', (tester) async {
    await _pump(tester, items);
    expect(
      find.descendant(
        of: _chip('a'),
        matching: find.byWidgetPredicate(
          (w) => w is MouseRegion && w.cursor == SystemMouseCursors.grab,
        ),
      ),
      findsOneWidget,
    );
    await _pump(tester, items, sortable: false);
    expect(
      find.descendant(
        of: _chip('a'),
        matching: find.byWidgetPredicate(
          (w) => w is MouseRegion && w.cursor == SystemMouseCursors.grab,
        ),
      ),
      findsNothing,
    );
  });
}
