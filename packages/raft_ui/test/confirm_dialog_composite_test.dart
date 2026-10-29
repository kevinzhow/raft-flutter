import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

RaftThemePack customPack({required String dialog}) => RaftThemePack.parse(
  jsonEncode({
    'format': raftThemePackFormat,
    'id': 'user:confirm-composite',
    'name': {'en': 'Custom confirm colors'},
    'version': '1',
    'extends': 'raft',
    'modes': {
      for (final mode in ['light', 'dark'])
        mode: {
          'colors': {
            'layer-dialog': dialog,
            'layer-banner-destructive': 'rgba(220 40 40 / 0.18)',
          },
        },
    },
  }),
);

void main() {
  for (final dark in [false, true]) {
    for (final custom in [false, true]) {
      testWidgets(
        'confirm explanation composites over dialog: dark=$dark custom=$custom',
        (t) async {
          final pack = custom ? customPack(dialog: '#34445a') : null;
          final tokens = RaftTokens.theme(pack: pack, dark: dark);
          final background =
              tokens.themeOverrides?.colors['layer-dialog'] ?? tokens.popover;
          final fill = tokens.colors['layer-banner-destructive']!;
          if (custom) {
            expect(pack!.warnings, isEmpty);
            expect(background, const Color(0xff34445a));
            expect(fill.a, closeTo(0.18, 0.005));
          }
          final expected = fill.a < 1
              ? raftChromeBlend(fill, background)
              : fill;
          addTearDown(() => t.pumpWidget(const SizedBox()));
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: pack, dark: dark),
              home: RepaintBoundary(
                key: const ValueKey('raster'),
                child: Scaffold(
                  body: const RaftConfirmDialog(
                    title: 'Confirm',
                    message: 'Warning.',
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final rect = t.getRect(find.byType(RaftBanner));
          final render = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('raster')),
          );
          final image = await t.runAsync(() => render.toImage(pixelRatio: 1));
          final raw = await t.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
          );
          final x = (rect.right - 24).floor(), y = (rect.top + 20).floor();
          final offset = (y * image!.width + x) * 4;
          final actual = raw!.buffer.asUint8List().sublist(offset, offset + 4);
          image.dispose();
          expect(
            actual,
            [
              expected.r * 255,
              expected.g * 255,
              expected.b * 255,
              255,
            ].map((v) => v.round()).toList(),
            reason: 'the banner must composite on the active dialog surface',
          );
        },
      );
    }
  }

  testWidgets('translucent custom dialog keeps alpha compositing live', (
    t,
  ) async {
    final pack = customPack(dialog: 'rgba(52 68 90 / 0.65)');
    expect(pack.warnings, isEmpty);
    final tokens = RaftTokens.theme(pack: pack, dark: true);
    expect(
      tokens.themeOverrides!.colors['layer-dialog']!.a,
      closeTo(0.65, 0.005),
    );
    expect(tokens.colors['layer-banner-destructive']!.a, closeTo(0.18, 0.005));
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: pack, dark: true),
        home: const Scaffold(
          body: RaftConfirmDialog(title: 'Confirm', message: 'Warning.'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t.widget<RaftBanner>(find.byType(RaftBanner)).backgroundColor,
      isNull,
    );
  });
}
