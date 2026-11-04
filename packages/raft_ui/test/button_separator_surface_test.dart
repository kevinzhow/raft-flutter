import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';
import 'package:raft_ui/src/surface_background_scope.dart';

import 'dart:ui' as ui;

import 'control_transition_paint_test.dart' show pixel;

const _fill = Color(0xff242422);
const _button = ValueKey('surface-ring-button');

Future<void> _mount(
  WidgetTester t, {
  required Widget child,
  bool known = true,
  double dpr = 1,
  Color? surface,
}) async {
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = const Size(220, 140) * dpr;
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: true, platform: TargetPlatform.linux),
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: const ValueKey('paint'),
          child: RaftSurfaceBackgroundScope(
            color: known ? surface ?? _fill : null,
            child: ColoredBox(
              color: _fill,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(width: 160, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<({List<int> bytes, int width, int height})> _raster(
  WidgetTester t,
) async => (await t.runAsync(() async {
  final render = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('paint')),
  );
  final image = await render.toImage(pixelRatio: t.view.devicePixelRatio);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List()
        .toList();
    return (bytes: bytes, width: image.width, height: image.height);
  } finally {
    image.dispose();
  }
}))!;

Widget _raw(String kind, bool enabled) => Builder(
  builder: (context) {
    final tokens = RaftTokens.of(context).recipeTokens;
    final color = kind == 'literal-fit'
        ? const CssColor(
            0x59fafaf7,
            'fixture fitted paint',
            Color.from(alpha: .349, red: .98, green: .98, blue: .969),
          )
        : kind == 'other-token'
        ? const CssVar('--line-hairline', null, 'lineHairline')
        : const CssVar('--sticker-edge', null, 'stickerEdge');
    final root = RaftSlotStyle(
      {
        'background-color': CssColor(
          kind == 'transparent-control' ? 0x00ff99c3 : 0xffff99c3,
        ),
        for (final corner in [
          'top-left',
          'top-right',
          'bottom-right',
          'bottom-left',
        ])
          'border-$corner-radius': const CssNum(8, 'px'),
        'box-shadow': CssSeq([
          CssNum(kind == 'offset' ? 1 : 0, 'px'),
          const CssNum(0, 'px'),
          CssNum(kind == 'blur' ? 2 : 0, 'px'),
          const CssNum(1.5, 'px'),
          color,
        ]),
      },
      const {},
      const [],
      tokens,
    );
    Widget box = RaftRecipeBox(
      style: root,
      tokens: tokens,
      width: 160,
      height: 44,
      compositeSharpStickerEdge: enabled,
      decorationOverride: kind == 'override'
          ? (d) => d.copyWith(
              boxShadow: const [
                BoxShadow(color: Color(0x80445566), spreadRadius: 1.5),
              ],
            )
          : null,
    );
    if (kind == 'fractional-translation')
      box = Transform.translate(offset: const Offset(.5, 0), child: box);
    if (kind == 'scale') box = Transform.scale(scale: 1.1, child: box);
    if (kind == 'rotation') box = Transform.rotate(angle: .1, child: box);
    return box;
  },
);

Widget _action() => RaftButton(
  key: _button,
  label: 'Install app',
  uiSize: RaftButtonSize.lg,
  uiVariant: RaftButtonVariant.accent,
  onPressed: () {},
);

void main() {
  void retire(WidgetTester t) {
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
  }

  testWidgets('Button sharp rings use actual Web bytes on owned dark Card', (
    t,
  ) async {
    retire(t);
    await _mount(t, child: _action());
    // Real pinned Web private-invite dark samples: (53,800), (52,800),
    // over actual layer-card #242422. Geometry is unchanged by translation.
    expect(
      await pixel(t, const Offset(15, 38)),
      const Color.fromARGB(255, 110, 110, 108),
    );
    expect(
      await pixel(t, const Offset(14, 38)),
      const Color.fromARGB(255, 72, 72, 71),
    );
  });

  testWidgets('unknown Button backdrop retains existing ring raster', (
    t,
  ) async {
    retire(t);
    await _mount(t, child: _action(), known: false);
    expect(
      await pixel(t, const Offset(15, 38)),
      const Color.fromARGB(255, 111, 111, 108),
    );
    expect(
      await pixel(t, const Offset(14, 38)),
      const Color.fromARGB(255, 73, 73, 71),
    );
  });

  testWidgets('Separator uses actual Web hairline on owned dark Card', (
    t,
  ) async {
    retire(t);
    await _mount(t, child: const RaftSeparator());
    expect(
      await pixel(t, const Offset(80, 16)),
      const Color.fromARGB(255, 57, 57, 55),
    );
  });

  for (final dpr in [1.0, 2.0, 3.0]) {
    testWidgets('Button ring matches independent Web DPR $dpr samples', (
      t,
    ) async {
      retire(t);
      await _mount(t, child: _action(), dpr: dpr);
      final rect = t.getRect(find.byKey(_button));
      final image = await _raster(t);
      final extent = (1.5 * dpr).ceil();
      for (var distance = 1; distance <= extent; distance++) {
        final x = (rect.left * dpr).round() - distance,
            y = (rect.center.dy * dpr).round();
        final i = (y * image.width + x) * 4;
        expect(
          image.bytes.sublist(i, i + 4),
          distance <= 1.5 * dpr ? [110, 110, 108, 255] : [72, 72, 71, 255],
          reason: 'Actual pinned Web DPR2/3 samples are archived with PNG hashes; DPR1 is the full-page baseline.',
        );
      }
    });
  }

  testWidgets(
    'unsafe or fitted ring contexts preserve the complete old raster',
    (t) async {
      retire(t);
      for (final kind in [
        'unknown',
        'transparent-backdrop',
        'transparent-control',
        'fractional-dpr',
        'fractional-translation',
        'scale',
        'rotation',
        'blur',
        'offset',
        'literal-fit',
        'other-token',
        'override',
      ]) {
        final images = <List<int>>[];
        for (final enabled in [false, true]) {
          await _mount(
            t,
            child: _raw(kind, enabled),
            known: kind != 'unknown',
            surface: kind == 'transparent-backdrop'
                ? const Color(0x80242422)
                : null,
            dpr: kind == 'fractional-dpr' ? 1.5 : 1,
          );
          images.add((await _raster(t)).bytes);
        }
        expect(
          images[1],
          images[0],
          reason: '$kind must keep the original complete vector raster.',
        );
      }
    },
  );
}
