import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';
import 'package:raft_ui/src/surface_background_scope.dart';

const _raster = ValueKey('owned-surface-raster');
const _backdrop = Color(0xff0d0d0b);
const _fill = Color(0xff242422);

Future<void> _mount(WidgetTester t, WidgetBuilder build) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(240, 160);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: true),
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _raster,
          child: RaftSurfaceBackgroundScope(
            color: _backdrop,
            child: ColoredBox(
              color: _backdrop,
              child: Builder(builder: build),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<List<int>> _pixel(WidgetTester t, int x, int y) async =>
    (await t.runAsync(() async {
      final box = t.renderObject<RenderRepaintBoundary>(find.byKey(_raster));
      final image = await box.toImage(pixelRatio: 1);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        return bytes.sublist(
          (y * image.width + x) * 4,
          (y * image.width + x) * 4 + 4,
        );
      } finally {
        image.dispose();
      }
    }))!;

void main() {
  void retire(WidgetTester t) {
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
  }

  testWidgets('opaque Card owns its descendant surface and Web hairline', (
    t,
  ) async {
    retire(t);
    Color? declared;
    await _mount(
      t,
      (context) => SizedBox(
        width: 120,
        height: 80,
        child: RaftCard(
          child: Builder(
            builder: (context) {
              declared = RaftSurfaceBackgroundScope.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    expect(declared, _fill);
    // Independent bytes sampled from the real db5e399 / raft-ui 0.7.0
    // private-invite dark Card's straight border (visual06 Web provider).
    expect(await _pixel(t, 0, 40), [57, 57, 55, 255]);
  });

  testWidgets('unknown paint blocks outer surface declarations', (t) async {
    retire(t);
    for (final kind in [
      'unpainted',
      'translucent',
      'image',
      'opacity',
      'inset',
      'sheen',
    ]) {
      Color? declared;
      await _mount(t, (context) {
        final tokens = RaftTokens.of(context).recipeTokens;
        final style = RaftSlotStyle(
          {
            if (kind != 'unpainted')
              'background-color': CssColor(
                kind == 'translucent' ? 0x80242422 : 0xff242422,
              ),
            if (kind == 'image')
              'background-image': const CssKeyword('fixture-image'),
            if (kind == 'opacity') 'opacity': const CssNum(.8),
            if (kind == 'inset')
              'box-shadow': const CssSeq([
                CssKeyword('inset'),
                CssNum(0, 'px'),
                CssNum(0, 'px'),
                CssNum(0, 'px'),
                CssNum(1, 'px'),
                CssColor(0xffffffff),
              ]),
          },
          {
            if (kind == 'sheen')
              '::before': {'background-color': const CssColor(0x80ffffff)},
          },
          const [],
          tokens,
        );
        return RaftRecipeBox(
          declareSurface: true,
          style: style,
          tokens: tokens,
          width: 120,
          height: 80,
          child: Builder(
            builder: (context) {
              declared = RaftSurfaceBackgroundScope.of(context);
              return const SizedBox.expand();
            },
          ),
        );
      });
      expect(
        declared,
        kind == 'unpainted' ? _backdrop : isNull,
        reason:
            '$kind must describe its actual paint; a layout-only slot '
            'preserves the declared ancestor while uncertain paint blocks it.',
      );
    }
  });

  testWidgets('decoration overrides determine the actual owned surface', (
    t,
  ) async {
    retire(t);
    for (final gradient in [false, true]) {
      Color? declared;
      await _mount(t, (context) {
        final tokens = RaftTokens.of(context).recipeTokens;
        return RaftRecipeBox(
          declareSurface: true,
          style: RaftSlotStyle(
            const {'background-color': CssColor(0xff242422)},
            const {},
            const [],
            tokens,
          ),
          tokens: tokens,
          width: 120,
          height: 80,
          decorationOverride: (d) => d.copyWith(
            color: const Color(0xff34445a),
            gradient: gradient
                ? const LinearGradient(colors: [Colors.white, Colors.black])
                : null,
          ),
          child: Builder(
            builder: (context) {
              declared = RaftSurfaceBackgroundScope.of(context);
              return const SizedBox.expand();
            },
          ),
        );
      });
      expect(declared, gradient ? isNull : const Color(0xff34445a));
      final actual = await _pixel(t, 10, 40);
      if (gradient) {
        expect(
          actual,
          isNot([52, 68, 90, 255]),
          reason: 'The override gradient must remain actual paint.',
        );
      } else {
        expect(actual, [52, 68, 90, 255]);
      }
    }
  });

  testWidgets('a nested translucent Card does not inherit an opaque ancestor', (
    t,
  ) async {
    retire(t);
    Color? outer, inner;
    await _mount(
      t,
      (context) => SizedBox(
        width: 120,
        height: 80,
        child: RaftCard(
          background: const Color(0xff34445a),
          child: Builder(
            builder: (context) {
              outer = RaftSurfaceBackgroundScope.of(context);
              return RaftCard(
                background: const Color(0x80242422),
                child: Builder(
                  builder: (context) {
                    inner = RaftSurfaceBackgroundScope.of(context);
                    return const SizedBox.expand();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(outer, const Color(0xff34445a));
    expect(inner, isNull);
  });

  testWidgets('ordinary recipe slots preserve their caller ownership', (
    t,
  ) async {
    retire(t);
    Color? declared;
    await _mount(t, (context) {
      final tokens = RaftTokens.of(context).recipeTokens;
      return RaftRecipeBox(
        style: RaftSlotStyle(
          const {'background-color': CssColor(0xff242422)},
          const {},
          const [],
          tokens,
        ),
        tokens: tokens,
        width: 120,
        height: 80,
        child: Builder(
          builder: (context) {
            declared = RaftSurfaceBackgroundScope.of(context);
            return const SizedBox.expand();
          },
        ),
      );
    });
    expect(declared, _backdrop);
    expect(await _pixel(t, 40, 40), [36, 36, 34, 255]);
  });

  testWidgets('literal and overridden border paint is not corrected twice', (
    t,
  ) async {
    retire(t);
    for (final overridden in [false, true]) {
      await _mount(t, (context) {
        final tokens = RaftTokens.of(context).recipeTokens;
        final style = RaftSlotStyle(
          {
            'background-color': const CssColor(0xff242422),
            for (final side in ['top', 'right', 'bottom', 'left']) ...{
              'border-$side-width': const CssNum(1, 'px'),
              'border-$side-color': overridden
                  ? const CssVar('--line-hairline', null, 'lineHairline')
                  : const CssColor(0x26e5e5e2),
            },
          },
          const {},
          const [],
          tokens,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final owner in [false, true])
              RaftRecipeBox(
                declareSurface: owner,
                style: style,
                tokens: tokens,
                width: 120,
                height: 80,
                decorationOverride: overridden
                    ? (d) => d.copyWith(
                        border: Border.all(color: const Color(0x33ffffff)),
                      )
                    : null,
              ),
          ],
        );
      });
      expect(await _pixel(t, 0, 40), await _pixel(t, 0, 120));
    }
  });

  testWidgets('changing Card paint retains the editor state and focus', (
    t,
  ) async {
    retire(t);
    final fill = ValueNotifier<Color>(_fill);
    final controller = TextEditingController();
    final focus = FocusNode();
    try {
      await _mount(
        t,
        (context) => SizedBox(
          width: 200,
          child: ValueListenableBuilder<Color>(
            valueListenable: fill,
            builder: (_, color, child) =>
                RaftCard(background: color, child: child!),
            child: Material(
              type: MaterialType.transparency,
              child: TextField(controller: controller, focusNode: focus),
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'Keep this draft');
      controller.selection = const TextSelection.collapsed(offset: 4);
      final state = t.state(find.byType(EditableText));
      for (final color in [
        Colors.transparent,
        const Color(0x80242422),
        _fill,
      ]) {
        fill.value = color;
        await t.pumpAndSettle();
        expect(identical(t.state(find.byType(EditableText)), state), isTrue);
        expect(focus.hasFocus, isTrue);
        expect(controller.text, 'Keep this draft');
        expect(controller.selection.baseOffset, 4);
      }
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      focus.dispose();
      controller.dispose();
      fill.dispose();
    }
  });
}
