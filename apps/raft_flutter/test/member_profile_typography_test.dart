import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;

void main() {
  setUpAll(loadParityFonts);

  Future<void> host(
    WidgetTester tester,
    Widget child, {
    RaftFamily family = RaftFamily.brutal,
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    );
  }

  // Real Chromium/font probe, not rounded Flutter paragraph metrics:
  // Hanken 12/16 => 12, 14/20 => 15, 16/20 => 15, 18/22.5 => 17.
  for (final (size, line, baseline) in [
    (12.0, 16.0, 12.0),
    (14.0, 20.0, 15.0),
    (16.0, 20.0, 15.0),
    (18.0, 22.5, 17.0),
  ]) {
    testWidgets('CSS line box $size/$line has measured baseline $baseline', (
      tester,
    ) async {
      await host(
        tester,
        RaftCssText(
          'Profile',
          style: TextStyle(
            fontFamily: 'packages/raft_ui/HankenGrotesk',
            fontSize: size,
            height: line / size,
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(RaftCssText));
      expect(box.size.height, line);
      // Baseline read outside layout uses the public dry-baseline contract.
      expect(
        box.getDryBaseline(BoxConstraints(), TextBaseline.alphabetic),
        baseline,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fractional profile name does not shift following handle', (
    tester,
  ) async {
    await host(
      tester,
      const SizedBox(
        width: 390,
        child: RaftProfileIdentity(
          name: 'Product UX Designer',
          handle: 'Product-UX-Designer',
          avatarUrl: 'pixel:robot',
        ),
      ),
    );
    final name = find.ancestor(
      of: find.text('Product UX Designer'),
      matching: find.byType(RaftCssText),
    );
    final handle = find.ancestor(
      of: find.text('@Product-UX-Designer'),
      matching: find.byType(RaftCssText),
    );
    expect(tester.getRect(name).top, 20);
    expect(tester.getRect(name).height, 22.5);
    expect(tester.getRect(handle).top, 42.5);
  });

  testWidgets('description still selects and copies actual text', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await host(
      tester,
      const SizedBox(
        width: 350,
        child: RaftDescriptionBlock(text: 'Turns product feedback into specs.'),
      ),
    );
    final paragraph = find.text('Turns product feedback into specs.');
    await tester.longPressAt(
      tester.getTopLeft(paragraph) + const Offset(50, 10),
    );
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, isNotEmpty);
    expect('Turns product feedback into specs.', contains(copied!));
  });

  testWidgets('fractional section border keeps layout but snaps CSS paint', (
    tester,
  ) async {
    final capture = GlobalKey();
    await host(
      tester,
      RepaintBoundary(
        key: capture,
        child: ColoredBox(
          color: Colors.white,
          child: SizedBox(
            width: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 22.5),
                RaftPanelSection(children: const [SizedBox(height: 20)]),
              ],
            ),
          ),
        ),
      ),
    );
    // Source name height22.5 does not round its downstream layout: border
    // occupies22.5..23.5; only its paint origin becomes23 (Blink readback).
    expect(tester.getRect(find.byType(RaftPanelSection)).top, 22.5);
    expect(tester.getSize(find.byType(RaftPanelSection)).height, 53);
    final boundary =
        capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = (await tester.runAsync(
      () => boundary.toImage(pixelRatio: 3),
    ))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    List<int> pixel(int y) =>
        List.generate(3, (c) => bytes.getUint8((y * image.width + 3) * 4 + c));
    expect(pixel(68), [255, 255, 255]);
    expect(pixel(69), [229, 229, 229]);
    expect(pixel(71), [229, 229, 229]);
    expect(pixel(72), [255, 255, 255]);
    image.dispose();
  });

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark wrapping, scaling and semantics survive resize',
      (tester) async {
        final semantics = tester.ensureSemantics();

        const text = 'Description with longer words and retained content.';
        Widget content(double width) => SizedBox(
          width: width,
          child: RaftCssText(
            text,
            style: const TextStyle(fontSize: 14, height: 20 / 14),
          ),
        );
        await host(tester, content(200), family: family, dark: dark);
        final initial = tester.getSize(find.byType(RaftCssText)).height;
        await host(
          tester,
          content(100),
          family: family,
          dark: dark,
          scale: 1.5,
        );
        expect(
          tester.getSize(find.byType(RaftCssText)).height,
          greaterThan(initial),
        );
        expect(find.bySemanticsLabel(text), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
