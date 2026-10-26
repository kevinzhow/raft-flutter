import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_flutter/platform/desktop_caption_controls.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'Windows native maximize hover paints without a Flutter pointer',
    (tester) async {
      const channel = MethodChannel(DesktopTitleBarController.channelName);
      final state = <String, Object>{
        'height': 0.0,
        'customControls': true,
        'active': true,
      };
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'status' || call.method == 'setIntegrated'
            ? state
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final controller = DesktopTitleBarController(
        platform: TargetPlatform.windows,
        web: false,
      );
      addTearDown(controller.state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: DesktopTitleBar(
            controller: controller,
            integrated: true,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Color? fill() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(const Key('desktop-caption-maximize')),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .first
          .color;
      expect(fill(), isNull);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall('state', {...state, 'maximizeHovered': true}),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(fill(), isNotNull);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('state', state)),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(fill(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('Windows close hover uses native red and white X $brightness', (
      tester,
    ) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: brightness == Brightness.dark),
          home: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 46,
                height: 48,
                child: DesktopCaptionControls(
                  layout: DesktopCaptionLayout.parse(':close'),
                  windows: true,
                  maximized: false,
                  active: true,
                  visible: true,
                  onAction: (_) {},
                  onRects: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer();
      await mouse.moveTo(
        tester.getCenter(find.byKey(const Key('desktop-caption-close'))),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(
        () => render.toImage(pixelRatio: 1),
      ))!;
      final pixels = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      Color pixel(int x, int y) {
        final offset = (y * image.width + x) * 4;
        return Color.fromARGB(
          pixels.getUint8(offset + 3),
          pixels.getUint8(offset),
          pixels.getUint8(offset + 1),
          pixels.getUint8(offset + 2),
        );
      }

      try {
        expect(pixel(5, 24), const Color(0xffc42b1c));
        expect(pixel(23, 24).g, greaterThan(.8));
        expect(pixel(23, 24).b, greaterThan(.8));
        expect(find.text('Close window'), findsNothing);
      } finally {
        image.dispose();
        await mouse.removePointer();
      }
    });
  }
}
