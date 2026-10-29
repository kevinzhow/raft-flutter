import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/mermaid_fullscreen.dart';

Widget host(bool dark, VoidCallback onClose, Size size) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: Scaffold(
      body: RaftMermaidFullscreen(
        onClose: onClose,
        diagram: const SizedBox(
          key: Key('diagram'),
          width: 300,
          height: 150,
          child: ColoredBox(color: Colors.red),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the diagram is contain-fitted inside the stage padding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(false, () {}, const Size(1280, 800)));
    final box = tester.getRect(find.byKey(const Key('diagram')));
    // `.r-mermaid-fullscreen` p-6 from md: a 1232x752 stage; the 2:1 diagram
    // magnifies to the width.
    expect(box.width, closeTo(1232, 1));
    expect(box.height, closeTo(616, 1));
    expect(box.left, closeTo(24, 1));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(host(false, () {}, const Size(390, 844)));
    expect(
      tester.getRect(find.byKey(const Key('diagram'))).left,
      closeTo(12, 1),
    );
  });

  for (final dark in [false, true]) {
    testWidgets(
      'close control, Escape and the backdrop close (${dark ? 'dark' : 'light'})',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var closed = 0;
        await tester.pumpWidget(
          host(dark, () => closed++, const Size(1280, 800)),
        );
        await tester.tap(find.byTooltip('Close Fullscreen'));
        expect(closed, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(closed, 2);
        // The 24px margin around the stage is the backdrop.
        await tester.tapAt(const Offset(8, 400));
        expect(closed, 3);
      },
    );
  }

  testWidgets('double tap zooms in and a second one resets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(false, () {}, const Size(1280, 800)));
    final before = tester.getRect(find.byKey(const Key('diagram')));
    final point = tester.getCenter(find.byKey(const Key('diagram')));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('diagram'))).width,
      closeTo(before.width * 2, 2),
    );
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('diagram'))).width,
      closeTo(before.width, 2),
    );
  });
}
