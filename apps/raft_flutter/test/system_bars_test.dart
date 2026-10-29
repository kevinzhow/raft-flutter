import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/system_bars.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Full theme matrix on purpose (theme/token/recipe test): never sampled, see
// package:raft_ui/test_themes.dart.
void main() {
  testWidgets('Android auth paints header color over opaque page safe area', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 24);
    addTearDown(() {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    });
    for (final theme in [
      for (final id in raftThemeMatrix([
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ], look: raftLookOf))
        for (final dark in [false, true])
          raftTheme(pack: packForThemeId(id), dark: dark),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: boundaryKey,
            child: RaftSystemBars(
              child: AuthView(
                origin: 'https://example.invalid',
                onLogin: (_, _, _) async {},
                onRegister: (_, _, _, _) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AuthView));
      final tokens = RaftTokens.of(context);
      final stripColor = raftStatusBarResolvedColor(
        tester.renderObject(find.byType(RaftStatusBarStrip)),
      );
      expect(stripColor, tokens.colors['layer-auth-header']);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      int pixel(int x, int y) {
        final offset = (y * image.width + x) * 4;
        return Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        ).toARGB32();
      }

      expect(pixel(4, 16), stripColor.toARGB32());
      expect(pixel(4, 16), pixel(4, 40));
      expect(pixel(4, 903), tokens.canvas.toARGB32());
      image.dispose();
      expect(tester.getRect(find.byType(RaftAuthTopBar)).top, 32);
      final annotation = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .descendant(
              of: find.byType(RaftSystemBarSurface),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(annotation.value.statusBarColor, Colors.transparent);
      expect(annotation.value.systemNavigationBarColor, Colors.transparent);
      expect(annotation.value.systemStatusBarContrastEnforced, false);
      expect(annotation.value.systemNavigationBarContrastEnforced, false);
      expect(tester.takeException(), isNull);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'theme changes update transparent system bars and icon contrast',
    (tester) async {
      for (final theme in [
        for (final id in raftThemeMatrix([
          raftThemePackId,
          elegantThemePackId,
          brutalThemePackId,
        ], look: raftLookOf))
          for (final dark in [false, true])
            raftTheme(pack: packForThemeId(id), dark: dark),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const RaftSystemBars(child: SizedBox.expand()),
          ),
        );
        await tester.pumpAndSettle();
        final annotation = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.descendant(
            of: find.byType(RaftSystemBars),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          ),
        );
        expect(annotation.value.statusBarColor, Colors.transparent);
        expect(annotation.value.systemNavigationBarColor, Colors.transparent);
        final contrast = theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        expect(annotation.value.statusBarIconBrightness, contrast);
        expect(annotation.value.systemNavigationBarIconBrightness, contrast);
        expect(annotation.value.systemNavigationBarContrastEnforced, isFalse);
        final fill = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(RaftSystemBars),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(fill.color, theme.scaffoldBackgroundColor);
      }
    },
  );

  testWidgets('paint covers bars while safe controls avoid bars and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 24);
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
    addTearDown(tester.view.reset);
    const control = Key('safe-control');
    const canvas = Key('full-canvas');
    await tester.pumpWidget(
      const MaterialApp(
        home: RaftSystemBars(
          child: Scaffold(
            body: ColoredBox(
              key: canvas,
              color: Colors.white,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(key: control, width: 120, height: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final background = tester.getRect(find.byKey(canvas));
    expect(background, const Rect.fromLTWH(0, 0, 412, 915));
    expect(tester.getRect(find.byKey(control)).bottom, 891);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = const FakeViewPadding(top: 32);
    await tester.pump();
    expect(tester.getRect(find.byKey(control)).bottom, lessThanOrEqualTo(615));
    // Scaffold consumes keyboard insets for its body; inspect the root
    // while separately asserting the interactive control moved above the IME.
    final appContext = tester.element(find.byType(RaftSystemBars));
    expect(MediaQuery.viewInsetsOf(appContext).bottom, 300);
    expect(MediaQuery.viewPaddingOf(appContext).top, 32);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform requests edge-to-edge without immersive hiding', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      final modes = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            modes.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await tester.pumpWidget(
        const MaterialApp(home: RaftSystemBars(child: SizedBox.expand())),
      );
      await tester.pump();
      expect(modes, ['SystemUiMode.edgeToEdge']);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
