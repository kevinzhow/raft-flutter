import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('Search uses the browser scale mode for the field border', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    tester.view.devicePixelRatio = 3;
    RaftBorderSnap.emulatedDeviceScaleFactor = true;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => RaftBorderSnap.emulatedDeviceScaleFactor = false);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final app = MaterialApp(
      theme: raftTheme(),
      home: Material(
        child: Center(
          child: SizedBox(
            width: 220,
            child: RaftSearchInput(
              controller: controller,
              focusNode: focus,
              hint: 'Search',
              clearLabel: 'Clear Search',
              onClear: controller.clear,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app);

    final input = find.byType(RaftSearchInput);
    double borderWidth() =>
        (tester
                    .widgetList<DecoratedBox>(
                      find.descendant(
                        of: input,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .map((widget) => widget.decoration)
                    .whereType<BoxDecoration>()
                    .firstWhere((decoration) => decoration.border is Border)
                    .border!
                as Border)
            .top
            .width;
    expect(borderWidth(), 1);
    final field = find.byType(TextField);
    List<double> focusSpreads() => [
      for (final paint in tester.widgetList<CustomPaint>(
        find.descendant(of: input, matching: find.byType(CustomPaint)),
      ))
        if (paint.painter case final RaftOuterShadowPainter painter)
          for (final shadow in painter.shadows)
            if (shadow.color.a > 0) shadow.spreadRadius,
    ];

    expect(focusSpreads(), isEmpty);
    await tester.tap(field);
    await tester.pump();
    expect(focusSpreads(), unorderedEquals([2, 4]));

    RaftBorderSnap.emulatedDeviceScaleFactor = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    expect(borderWidth(), closeTo(4 / 3, .00001));
    await tester.tap(field);
    await tester.pump();
    expect(focusSpreads(), unorderedEquals([2, 4]));
  });

  testWidgets('A pinned toolbar reveals active chips and fades hidden edges', (
    tester,
  ) async {
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Center(
          child: RepaintBoundary(
            key: captureKey,
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(
                width: 200,
                child: RaftFitToolbar(
                  children: [
                    RaftFitGroup(
                      firstLine: true,
                      scroll: true,
                      end: const SizedBox(width: 60, height: 32),
                      items: const [
                        RaftFitChild(
                          child: ColoredBox(
                            color: Colors.black,
                            child: SizedBox(width: 100, height: 32),
                          ),
                        ),
                        RaftFitChild(
                          active: true,
                          child: ColoredBox(
                            color: Colors.black,
                            child: SizedBox(width: 80, height: 32),
                          ),
                        ),
                        RaftFitChild(
                          child: ColoredBox(
                            color: Colors.black,
                            child: SizedBox(width: 100, height: 32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroller = find.descendant(
      of: find.byKey(captureKey),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scroller).position;
    expect(position.pixels, greaterThan(24));
    expect(position.pixels, lessThan(position.maxScrollExtent - 24));

    Future<int?> rightEdgeInk() => tester.runAsync(() async {
      final bounds = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final end =
          (tester.getTopRight(scroller).dx -
                  tester.getTopLeft(find.byKey(captureKey)).dx)
              .floor();
      final image = await bounds.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final green = (bytes as ByteData).getUint8(
        (image.width * (image.height ~/ 2) + end - 4) * 4 + 1,
      );
      image.dispose();
      return green;
    });
    expect(await rightEdgeInk(), greaterThan(170));

    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(await rightEdgeInk(), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
