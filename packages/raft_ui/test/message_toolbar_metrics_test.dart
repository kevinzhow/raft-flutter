import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// raft-ui 0.95.3 message-item `toolbar` / `toolbarButton`: a mouse from 768px
// (`md:pointer-fine`) draws 34px buttons (radius 8) in a 42px bar, below that
// 28px buttons (radius 6) in a 36px bar; p-1, gap-1, rounded-container 10,
// the 1px line-seam ring inside the box, svg 16.
Widget host(Size size, {TargetPlatform? platform, bool continuation = false}) =>
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform ?? TargetPlatform.linux),
      home: MediaQuery(
        data: MediaQueryData(size: size, devicePixelRatio: 1),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: size.width,
                child: RaftMessageRow(
                  key: const Key('row'),
                  continuation: continuation,
                  author: 'Ada',
                  timestamp: '09:41',
                  content: const Text('hello', key: Key('body')),
                  toolbar: RaftMessageToolbar(
                    children: [
                      for (var i = 0; i < 5; i++)
                        RaftMessageToolbarAction(
                          key: Key('a$i'),
                          label: 'Action $i',
                          icon: const SizedBox(key: Key('glyph')),
                          onPressed: () {},
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> hover(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(find.byKey(const Key('body'))));
  await tester.pump();
  addTearDown(mouse.removePointer);
}

void main() {
  for (final (size, bar, button, top) in [
    (const Size(1440, 900), const Size(194, 42), 34.0, -21.0),
    (const Size(390, 844), const Size(164, 36), 28.0, -18.0),
  ]) {
    testWidgets('toolbar at ${size.width.toInt()}: $bar, button $button', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(size));
      await hover(tester);
      expect(tester.getSize(find.byType(RaftMessageToolbar)), bar);
      expect(tester.getSize(find.byKey(const Key('a0'))), Size.square(button));
      final context = tester.element(find.byKey(const Key('row')));
      final margin = RaftMessageRowRecipe(
        RaftTokens.of(context),
        viewportWidth: size.width,
      ).margin.top;
      expect(
        tester.getTopLeft(find.byType(RaftMessageToolbar)).dy -
            tester.getTopLeft(find.byKey(const Key('row'))).dy -
            margin,
        top,
      );
      final toolbar = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RaftMessageToolbar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = toolbar.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(10));
      // The ring is inside the box, never an outside spread.
      expect(decoration.boxShadow!.where((s) => s.spreadRadius > 0), isEmpty);
      expect(toolbar.foregroundDecoration, isA<BoxDecoration>());
      expect(
        tester.getSize(find.byKey(const Key('glyph')).first),
        const Size.square(16),
      );
    });
  }

  testWidgets(
    'toolbar top is relative to the filled row: -21 on a continuation',
    (tester) async {
      const size = Size(1440, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(size, continuation: true));
      await hover(tester);
      // No turn margin on a continuation: -21 from the row's outer top; a turn
      // start sits `margin.top` lower (Web -13 with its 8px turn border).
      expect(
        tester.getTopLeft(find.byType(RaftMessageToolbar)).dy -
            tester.getTopLeft(find.byKey(const Key('row'))).dy,
        -21,
      );
    },
  );

  testWidgets('touch (Android 856x944): no toolbar', (tester) async {
    const size = Size(856, 944);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(size, platform: TargetPlatform.android));
    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    await touch.down(tester.getCenter(find.byKey(const Key('body'))));
    await tester.pump();
    expect(find.byType(RaftMessageToolbar), findsNothing);
    await touch.up();
  });

  testWidgets('saved indicator icon is the recipe slot size, 14', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(body: RaftMessageSavedIndicator()),
      ),
    );
    expect(
      tester.getSize(
        find.descendant(
          of: find.byKey(const Key('message-saved-badge')),
          matching: find.byType(RaftIcon),
        ),
      ),
      const Size.square(14),
    );
  });

  testWidgets('reaction chip: px 7/7, count in mono-meta', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RaftMountedReaction(
              label: 'x',
              glyph: const SizedBox(width: 15, height: 15),
              count: 3,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    final chip = find.byType(RaftMountedReaction);
    final count = tester.getRect(find.text('3'));
    final box = tester.getRect(chip);
    expect(count.right + 7, closeTo(box.right, .6));
    final style = tester.widget<Text>(find.text('3')).style!;
    expect(style.fontSize, 12);
    expect(style.height, 16 / 12);
  });
}
