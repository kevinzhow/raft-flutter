import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';
import 'package:raft_ui/src/surface_background_scope.dart';

// Actual pinned Web Help divider, y34, safe x12..308, not a Dart blend formula:
// light default SHA6d18cc71a1c30210, dark default SHA1c3ecdb9c8b16c26.
// Source/pixel manifests accompany this test in help-header-border-regression.
const _webDarkBase = Color(0xff292927);
const _capture = ValueKey('help-border-raster');
const _raw = ValueKey('help-border-raw');
const _shared = ValueKey('help-border-shared');
const _surface = ValueKey('workspace-help-popup');

Future<void> _loadFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final family in ['SpaceGrotesk', 'HankenGrotesk', 'Inter']) {
    ByteData bytes;
    try {
      bytes = await rootBundle.load(
        'packages/raft_ui/assets/fonts/$family.ttf',
      );
    } on FlutterError {
      bytes = await rootBundle.load('assets/fonts/$family.ttf');
    }
    await (FontLoader(
      'packages/raft_ui/$family',
    )..addFont(Future.value(bytes))).load();
  }
});

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  bool dark = true,
  double height = 844,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(900, height);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark, platform: TargetPlatform.linux),
      builder: (context, navigator) =>
          RepaintBoundary(key: _capture, child: navigator!),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _retire(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<List<List<int>>> _pixels(
  WidgetTester tester,
  List<Offset> points,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return [
        for (final point in points)
          [
            for (var channel = 0; channel < 4; channel++)
              raw.getUint8(
                (point.dy.floor() * image.width + point.dx.floor()) * 4 +
                    channel,
              ),
          ],
      ];
    } finally {
      image.dispose();
    }
  }))!;
}

RaftSlotStyle _header(BuildContext context) {
  final t = RaftTokens.of(context);
  return RaftWebHelpMenuRecipe.resolve(
    states: t.recipeStates(),
    tokens: t.recipeTokens,
  ).header;
}

Widget _paint(
  RaftSlotStyle style,
  RaftTokenResolver tokens, {
  required bool shared,
}) => shared
    ? RaftMenuItemSurface(
        key: _shared,
        style: style,
        tokens: tokens,
        width: 320,
        applyText: false,
        child: const SizedBox.shrink(),
      )
    : RaftRecipeBox(
        key: _raw,
        style: style,
        tokens: tokens,
        width: 320,
        applyText: false,
        child: const SizedBox.shrink(),
      );

void main() {
  for (final dark in [false, true]) {
    testWidgets('actual Help divider retains exact Web RGBA; dark=$dark', (
      tester,
    ) async {
      await _loadFonts(tester);
      try {
        for (final height in [844.0, 568.0]) {
          final controller = RaftMenuController();
          try {
            await _mount(
              tester,
              Align(
                alignment: Alignment.centerLeft,
                child: RaftWorkspaceHelpMenu(
                  label: 'Help',
                  heading: 'Help & resources',
                  controller: controller,
                  entries: [
                    for (final label in [
                      'Documentation',
                      'Feedback',
                      'Community',
                      'About',
                    ])
                      RaftMenuEntry(label: label, onPressed: () {}),
                  ],
                ),
              ),
              dark: dark,
              height: height,
            );
            await tester.tap(find.byType(RaftWorkspaceRailAction));
            await tester.pumpAndSettle();
            final popup = tester.getRect(find.byKey(_surface));
            final firstRow = tester.getRect(
              find.widgetWithText(RaftMenuItem, 'Documentation'),
            );
            expect(popup.size, Size(320, height <= 600 ? 163 : 179));
            expect(firstRow.top - popup.top, 35);
            final line = await _pixels(tester, [
              for (var x = 12; x <= 308; x++)
                Offset(popup.left + x, firstRow.top - 1),
            ]);
            expect(
              line,
              everyElement(dark ? [61, 61, 60, 255] : [220, 220, 220, 255]),
              reason: 'Recorded full-width Web border at y34, including red61.',
            );
            expect(tester.takeException(), isNull);
          } finally {
            await _retire(tester);
            controller.dispose();
          }
        }
      } finally {
        tester.view.reset();
      }
    });
  }

  testWidgets(
    'menu border preserves fitted literal and fallback sides independently',
    (tester) async {
      try {
        await _mount(
          tester,
          Builder(
            builder: (context) {
              final rt = RaftTokens.of(context).recipeTokens;
              final header = _header(context);
              final style = header.copyWith(
                properties: {
                  ...header.properties,
                  'height': const CssNum(36, 'px'),
                  for (final side in ['top', 'right', 'left']) ...{
                    'border-$side-width': const CssNum(1, 'px'),
                    'border-$side-style': const CssKeyword('solid'),
                  },
                  // Existing calibrated source paint from chrome-literal-fits.
                  'border-top-color': const CssColor(
                    0x1f141111,
                    'oklch(0.1813 0.00497 17.62 / 0.12)',
                    Color.from(
                      alpha: .121409,
                      red: .051103,
                      green: .051103,
                      blue: .049304,
                    ),
                  ),
                  'border-right-color': const CssColor(0x44335577),
                  'border-left-color': const CssVar(
                    '--line-hairline',
                    CssColor(0x22112233),
                    'lineHairline',
                  ),
                },
              );
              return ColoredBox(
                color: _webDarkBase,
                child: RaftSurfaceBackgroundScope(
                  color: _webDarkBase,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _paint(style, rt, shared: false),
                      _paint(style, rt, shared: true),
                    ],
                  ),
                ),
              );
            },
          ),
        );
        final raw = tester.getRect(find.byKey(_raw));
        final shared = tester.getRect(find.byKey(_shared));
        final positions = [
          const Offset(160, 0),
          const Offset(319, 18),
          const Offset(0, 18),
        ];
        final samples = await _pixels(tester, [
          for (final p in positions) raw.topLeft + p,
          for (final p in positions) shared.topLeft + p,
        ]);
        expect(
          samples.sublist(3),
          samples.sublist(0, 3),
          reason: 'Fitted literal, plain literal and fallback var stay exact.',
        );
        final bottom = await _pixels(tester, [
          shared.topLeft + const Offset(160, 35),
        ]);
        expect(bottom.single, [61, 61, 60, 255]);
        expect(tester.takeException(), isNull);
      } finally {
        await _retire(tester);
        tester.view.reset();
      }
    },
  );

  testWidgets('menu border retains uncertain surface raster', (tester) async {
    try {
      for (final condition in [
        'absent',
        'null-barrier',
        'translucent-owner',
        'own-fill',
        'own-translucent-fill',
        'image',
        'opacity',
        'inset',
        'before',
        'after',
      ]) {
        await _mount(
          tester,
          Builder(
            builder: (context) {
              final rt = RaftTokens.of(context).recipeTokens;
              final header = _header(context);
              final style = header.copyWith(
                properties: {
                  ...header.properties,
                  'height': const CssNum(36, 'px'),
                  if (condition == 'own-fill')
                    'background-color': const CssColor(0xff34445a),
                  if (condition == 'own-translucent-fill')
                    'background-color': const CssColor(0x8033445a),
                  if (condition == 'image')
                    'background-image': const CssKeyword('fixture-image'),
                  if (condition == 'opacity') 'opacity': const CssNum(.8),
                  if (condition == 'inset')
                    'box-shadow': const CssSeq([
                      CssKeyword('inset'),
                      CssNum(0, 'px'),
                      CssNum(0, 'px'),
                      CssNum(0, 'px'),
                      CssNum(100, 'px'),
                      CssColor(0x33000000),
                    ]),
                },
                targets: {
                  ...header.targets,
                  if (condition == 'before' || condition == 'after')
                    '::$condition': {
                      'background-color': const CssColor(0x33000000),
                    },
                },
              );
              Widget panel(bool shared) {
                final paint = _paint(style, rt, shared: shared);
                Widget body = SizedBox(
                  width: 320,
                  height: 36,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: ColoredBox(color: Colors.red)),
                          Expanded(child: ColoredBox(color: Colors.blue)),
                        ],
                      ),
                      if (condition == 'absent')
                        paint
                      else
                        RaftSurfaceBackgroundScope(
                          color: condition == 'null-barrier'
                              ? null
                              : condition == 'translucent-owner'
                              ? const Color(0x80292927)
                              : _webDarkBase,
                          child: paint,
                        ),
                    ],
                  ),
                );
                if (condition == 'null-barrier') {
                  body = RaftSurfaceBackgroundScope(
                    color: _webDarkBase,
                    child: body,
                  );
                }
                return body;
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [panel(false), panel(true)],
              );
            },
          ),
        );
        final raw = tester.getRect(find.byKey(_raw));
        final shared = tester.getRect(find.byKey(_shared));
        final samples = await _pixels(tester, [
          raw.topLeft + const Offset(80, 35),
          raw.topLeft + const Offset(240, 35),
          shared.topLeft + const Offset(80, 35),
          shared.topLeft + const Offset(240, 35),
        ]);
        expect(
          samples.sublist(2),
          samples.sublist(0, 2),
          reason: '$condition cannot substitute an assumed background.',
        );
        if (condition == 'absent' || condition == 'null-barrier') {
          expect(samples[2], isNot(samples[3]));
        }
        expect(tester.takeException(), isNull);
        await _retire(tester);
      }
    } finally {
      await _retire(tester);
      tester.view.reset();
    }
  });
}
