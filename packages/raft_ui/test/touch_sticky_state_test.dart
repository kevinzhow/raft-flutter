import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Touch-only phones must never keep a desktop-style selected / hover look
/// after the finger has left. These cases drive real touch gestures.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [child, const SizedBox(height: 2000)]),
      ),
    ),
  );

  Future<void> pumpMessages(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            RaftMessageTile(
              key: Key('first'),
              author: 'Alice',
              content: 'First message body text for selection',
              body: RaftMessageBody(
                content: 'First message body text for selection',
              ),
              timestamp: '08:00 AM',
            ),
            RaftMessageTile(
              key: Key('second'),
              author: 'Bob',
              content: 'Second message body text for selection',
              body: RaftMessageBody(
                content: 'Second message body text for selection',
              ),
              timestamp: '08:01 AM',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool selecting(WidgetTester tester, Key tile) {
    final region = find.descendant(
      of: find.byKey(tile),
      matching: find.byType(SelectableRegion),
    );
    final state = tester.state<SelectableRegionState>(region);
    return state.selectionOverlay != null;
  }

  testWidgets('touch long-press selection is cleared by a tap outside', (
    tester,
  ) async {
    await pumpMessages(tester);
    final text = find.descendant(
      of: find.byKey(const Key('first')),
      matching: find.textContaining('First message'),
    );
    await tester.longPressAt(tester.getCenter(text));
    await tester.pump(const Duration(milliseconds: 300));
    expect(selecting(tester, const Key('first')), isTrue);
    // Tap the other message's padding / author line: outside the first region.
    await tester.tapAt(tester.getCenter(find.text('Bob')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(selecting(tester, const Key('first')), isFalse);
  });

  testWidgets('mouse drag selection is not dismissed by an outside tap', (
    tester,
  ) async {
    await pumpMessages(tester);
    final text = find.descendant(
      of: find.byKey(const Key('first')),
      matching: find.textContaining('First message'),
    );
    final rect = tester.getRect(text);
    final mouse = await tester.startGesture(
      rect.centerLeft + const Offset(4, 0),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveTo(rect.centerLeft + const Offset(120, 0));
    await mouse.up();
    await tester.pump();
    // Desktop keeps Flutter's behaviour: unchanged by the touch fix.
    final before = selecting(tester, const Key('first'));
    await tester.tapAt(
      tester.getCenter(find.text('Bob')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(selecting(tester, const Key('first')), before);
  });

  /// The control's pressed look: the elegant theme scales it on press.
  double controlScale(WidgetTester tester, Finder control) {
    final box = find
        .descendant(of: control, matching: find.byType(AnimatedContainer))
        .first;
    return tester.widget<AnimatedContainer>(box).transform?.storage[0] ?? 1;
  }

  testWidgets('control pressed look ends when a scroll takes the touch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ListView(
            children: [
              RaftControl(
                key: const Key('control'),
                onPressed: () {},
                child: const Text('Open'),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    final control = find.byKey(const Key('control'));
    final idle = controlScale(tester, control);
    final finger = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controlScale(tester, control), isNot(idle));
    await finger.moveBy(const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 300));
    await finger.up();
    await tester.pumpAndSettle();
    expect(controlScale(tester, control), idle);
  });

  testWidgets('a finger crossing a message row never gives it the hover fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ListView(
            children: [
              RaftMessageRow(
                key: const Key('row'),
                author: 'Alice',
                timestamp: '08:00',
                coarsePointer: true,
                content: const Text('Body'),
                toolbar: RaftMessageToolbar(
                  children: [
                    RaftMessageToolbarAction(
                      key: const Key('toolbar-action'),
                      label: 'Reply',
                      icon: const SizedBox(),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    final row = find.byKey(const Key('row'));
    Color? rowFill() {
      final box = find
          .descendant(of: row, matching: find.byType(DecoratedBox))
          .evaluate()
          .map((e) => (e.widget as DecoratedBox).decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .whereType<Color>()
          .where((c) => c.a > 0);
      return box.isEmpty ? null : box.first;
    }

    final finger = await tester.startGesture(
      tester.getCenter(find.text('Body')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(rowFill(), isNull);
    await finger.moveBy(const Offset(0, -60));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(rowFill(), isNull);
    expect(find.byKey(const Key('toolbar-action')), findsNothing);
  });

  testWidgets('touch after a key press returns focus highlights to touch', (
    tester,
  ) async {
    // Flutter's automatic strategy: traditional only after real keyboard
    // input, touch again on the next finger. The app must not pin either.
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Center(
            child: RaftControl(
              key: const Key('control'),
              onPressed: () {},
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    expect(
      FocusManager.instance.highlightStrategy,
      FocusHighlightStrategy.automatic,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    final finger = await tester.startGesture(const Offset(5, 5));
    await finger.up();
    await tester.pump();
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
  });

  testWidgets('tapping an attachment action leaves the card border idle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RaftAttachmentCard(
              filename: 'photo.png',
              mimeType: 'image/png',
              sizeBytes: 2048,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    Color? border() {
      final material = find
          .descendant(
            of: find.byType(RaftAttachmentCard),
            matching: find.byType(Material),
          )
          .evaluate()
          .map((e) => e.widget as Material)
          .firstWhere((m) => m.shape is RoundedRectangleBorder);
      return (material.shape! as RoundedRectangleBorder).side.color;
    }

    final idle = border();
    await tester.tap(find.byTooltip('Preview photo.png'));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
    expect(border(), idle);
  });
}
