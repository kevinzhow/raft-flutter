import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';
import 'package:raft_ui/src/surface_background_scope.dart';

// Independent bytes from the actual pinned Web Help popup, not from a Dart
// blend formula. db5e399f / raft-ui 0.7.0, normal and compact hover/focus:
// .../help-popup-reference/site/latest/react/...help-popup.hover.raft-dark.png
// SHA256 55e9dc86dc56b547d2ec55dc242c96ba30b4ece9bd8a041794fa22f99f70c081.
// Empty row samples (280,50), (280,52): [56,52,37,255]. Default body:
// SHA256 1c3ecdb9c8b16c2650145393259ea44ff1a2024b08dcee6ef46ab98fefbedc00,
// same samples [41,41,39,255]. See reference-review/menu-surface-web-samples.json.
const _webBase = Color(0xff292927);
const _webBaseRgba = [41, 41, 39, 255];
const _webHighlightRgba = [56, 52, 37, 255];
const _raster = ValueKey('menu-background-raster');
const _row = ValueKey('menu-background-row');

Future<void> _mount(WidgetTester tester, WidgetBuilder build) async {
  tester.view.physicalSize = const Size(480, 480);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: true, platform: TargetPlatform.linux),
      home: RepaintBoundary(
        key: _raster,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(builder: build),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<List<List<int>>> _pixels(
  WidgetTester tester,
  List<Offset> points,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_raster),
  );
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  try {
    final raw = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final bytes = raw!.buffer.asUint8List();
    return [
      for (final point in points)
        bytes.sublist(
          (point.dy.floor() * image!.width + point.dx.floor()) * 4,
          (point.dy.floor() * image.width + point.dx.floor()) * 4 + 4,
        ),
    ];
  } finally {
    image?.dispose();
  }
}

Offset _emptyRowPoint(WidgetTester tester, Finder row) {
  final rect = tester.getRect(row);
  // The short label stays at the start; this point avoids text, rounded edges,
  // indicators and borders. It observes paint rather than style properties.
  return Offset(rect.right - 24, rect.center.dy);
}

RaftSlotStyle _paintStyle(
  RaftTokenResolver tokens, {
  Color fill = _webBase,
  CssValue? literal,
  CssValue? image,
  CssValue? shadow,
  double? opacity,
  Map<String, Map<String, CssValue>> targets = const {},
}) => RaftSlotStyle(
  {
    'background-color': literal ?? CssColor(fill.toARGB32(), null, fill),
    'height': const CssNum(36, 'px'),
    if (image != null) 'background-image': image,
    if (shadow != null) 'box-shadow': shadow,
    if (opacity != null) 'opacity': CssNum(opacity),
  },
  targets,
  const [],
  tokens,
);

RaftMenuPopupSlots _selectSlots(
  BuildContext context,
  RaftMenuPopupRowState state, {
  Map<String, CssValue>? listProperties,
}) {
  final t = RaftTokens.of(context);
  final slots = RaftSelectRecipe.resolve(
    theme: t.recipeTheme,
    tokens: t.recipeTokens,
    states: t.recipeStates(
      hovered: state.hovered,
      focusVisible: state.focusVisible,
      disabled: state.disabled,
      extra: [
        if (state.selected) 'data-selected',
        if (state.disabled) 'data-disabled',
        if (state.highlighted) 'data-highlighted',
      ],
    ),
  );
  return RaftMenuPopupSlots(
    content: slots.content,
    list: listProperties == null
        ? slots.list
        : slots.list.copyWith(
            properties: {...slots.list.properties, ...listProperties},
          ),
    item: slots.item,
    itemLeading: slots.itemLeading,
    itemText: slots.itemText,
    itemIndicator: slots.itemIndicator,
  );
}

void _contractTest(
  String name,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.reset();
    }
  });
}

void main() {
  _contractTest(
    'Help action paint matches recorded Web base, hover and focus',
    (tester) async {
      for (final state in ['default', 'hover', 'focus']) {
        Color? declared;
        await _mount(
          tester,
          (_) => RaftMenuPanel(
            width: 320,
            padding: EdgeInsets.zero,
            children: [
              Builder(
                builder: (context) {
                  declared = RaftSurfaceBackgroundScope.of(context);
                  return Semantics(
                    container: true,
                    role: SemanticsRole.menuItem,
                    label: 'Action',
                    enabled: true,
                    excludeSemantics: true,
                    child: RaftMenuActionRow(
                      key: _row,
                      label: 'Action',
                      hovered: state == 'hover',
                      focusVisible: state == 'focus',
                    ),
                  );
                },
              ),
            ],
          ),
        );
        expect(declared, _webBase);
        final sample = await _pixels(tester, [
          _emptyRowPoint(tester, find.byKey(_row)),
        ]);
        expect(
          sample.single,
          state == 'default' ? _webBaseRgba : _webHighlightRgba,
          reason: 'Actual Web Help $state bytes, including the blue channel37.',
        );
      }
    },
  );

  _contractTest(
    'Select backend shares its real opaque paint with focused row',
    (tester) async {
      Color? declared;
      await _mount(
        tester,
        (context) => RaftMenuPopupBackend(
          anchorWidth: 320,
          maxHeight: 168,
          entries: [
            RaftMenuPopupEntry(
              key: _row,
              label: 'Choice',
              selected: true,
              labelChild: Builder(
                builder: (context) {
                  declared = RaftSurfaceBackgroundScope.of(context);
                  return const Text('Choice');
                },
              ),
            ),
          ],
          resolveSlots: (state) => _selectSlots(context, state),
          onActivate: (_) {},
          onDismiss: () {},
        ),
      );
      expect(declared, _webBase);
      final sample = await _pixels(tester, [
        _emptyRowPoint(tester, find.byKey(_row)),
      ]);
      expect(sample.single, _webHighlightRgba);
    },
  );

  _contractTest(
    'unknown or absent background preserves nonuniform live paint',
    (tester) async {
      for (final nullBarrier in [false, true]) {
        Color? declared = Colors.green;
        await _mount(tester, (_) {
          final row = Builder(
            builder: (context) {
              declared = RaftSurfaceBackgroundScope.of(context);
              return const RaftMenuActionRow(label: 'Action', hovered: true);
            },
          );
          final body = SizedBox(
            width: 320,
            height: 36,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: ColoredBox(color: Colors.red)),
                      Expanded(child: ColoredBox(color: Colors.blue)),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: nullBarrier
                      ? RaftSurfaceBackgroundScope(color: null, child: row)
                      : row,
                ),
              ],
            ),
          );
          return nullBarrier
              ? RaftSurfaceBackgroundScope(color: _webBase, child: body)
              : body;
        });
        expect(declared, isNull);
        final sample = await _pixels(tester, [
          const Offset(140, 18),
          const Offset(280, 18),
        ]);
        expect(
          sample[0],
          isNot(sample[1]),
          reason:
              'An unknown surface cannot borrow an outer solid fill and '
              'flatten the actual two-colour backdrop.',
        );
      }
    },
  );

  _contractTest(
    'Dialog declares the fill it actually paints, then updates it',
    (tester) async {
      for (final fill in [_webBase, const Color(0xff34445a)]) {
        Color? declared;
        await _mount(
          tester,
          (context) => RaftSurfaceBackgroundScope(
            color: Colors.red,
            child: ColoredBox(
              color: Colors.red,
              child: RaftDialogSurface(
                surfaceStyle: _paintStyle(
                  RaftTokens.of(context).recipeTokens,
                  fill: fill,
                ),
                child: Builder(
                  builder: (context) {
                    declared = RaftSurfaceBackgroundScope.of(context);
                    return const SizedBox(width: 320, height: 36);
                  },
                ),
              ),
            ),
          ),
        );
        final sample = await _pixels(tester, [const Offset(280, 18)]);
        expect(declared, fill);
        expect(
          sample.single,
          fill == _webBase ? _webBaseRgba : [52, 68, 90, 255],
          reason:
              'The declared paint is the real Dialog source style, not '
              'the outer scope or an assumed popover theme token.',
        );
      }
    },
  );

  _contractTest('nonuniform or translucent surface blocks outer declaration', (
    tester,
  ) async {
    for (final owner in ['popover', 'dialog']) {
      for (final condition in [
        'alpha',
        'opacity',
        'image',
        'before',
        'inset',
      ]) {
        Color? declared = Colors.green;
        await _mount(tester, (context) {
          final style = _paintStyle(
            RaftTokens.of(context).recipeTokens,
            fill: condition == 'alpha'
                ? const Color.fromRGBO(41, 41, 39, .65)
                : _webBase,
            opacity: condition == 'opacity' ? .8 : null,
            image: condition == 'image'
                ? const CssKeyword('fixture-image')
                : null,
            shadow: condition == 'inset'
                ? const CssSeq([
                    CssKeyword('inset'),
                    CssNum(0, 'px'),
                    CssNum(0, 'px'),
                    CssNum(0, 'px'),
                    CssNum(100, 'px'),
                    CssColor(0xff000000),
                  ])
                : null,
            targets: condition == 'before'
                ? {
                    '::before': {
                      'background-color': const CssColor(0x33000000),
                    },
                  }
                : const {},
          );
          final probe = Builder(
            builder: (context) {
              declared = RaftSurfaceBackgroundScope.of(context);
              return const SizedBox(width: 320, height: 36);
            },
          );
          return RaftSurfaceBackgroundScope(
            color: Colors.red,
            child: owner == 'popover'
                ? RaftPopoverSurface(surfaceStyle: style, child: probe)
                : RaftDialogSurface(surfaceStyle: style, child: probe),
          );
        });
        if (condition == 'inset') {
          final actual = await _pixels(tester, [const Offset(280, 18)]);
          expect(actual.single, [
            0,
            0,
            0,
            255,
          ], reason: 'The actual inset paints over the declared fill.');
        }
        expect(
          declared,
          isNull,
          reason: '$owner $condition must block, not look past itself.',
        );
      }
    }
  });

  _contractTest('Select list owns its fill and blocks uncertain list layers', (
    tester,
  ) async {
    for (final condition in ['opaque', 'alpha', 'opacity', 'image']) {
      Color? declared = Colors.green;
      await _mount(tester, (context) {
        final listFill = condition == 'alpha'
            ? const Color.fromRGBO(52, 68, 90, .65)
            : const Color(0xff34445a);
        return RaftMenuPopupBackend(
          anchorWidth: 320,
          maxHeight: 168,
          entries: [
            RaftMenuPopupEntry(
              label: 'Choice',
              labelChild: Builder(
                builder: (context) {
                  declared = RaftSurfaceBackgroundScope.of(context);
                  return const Text('Choice');
                },
              ),
            ),
          ],
          resolveSlots: (state) => _selectSlots(
            context,
            state,
            listProperties: {
              'background-color': CssColor(listFill.toARGB32(), null, listFill),
              if (condition == 'opacity') 'opacity': const CssNum(.8),
              if (condition == 'image')
                'background-image': const CssKeyword('fixture-image'),
            },
          ),
          onActivate: (_) {},
          onDismiss: () {},
        );
      });
      expect(
        declared,
        condition == 'opaque' ? const Color(0xff34445a) : isNull,
        reason:
            'The list is nearer than content; $condition cannot reuse '
            'the content surface as if the list had no paint of its own.',
      );
    }
  });

  _contractTest('fitted literals and image paint retain their existing raster', (
    tester,
  ) async {
    for (final kind in ['chrome-fit', 'image']) {
      await _mount(tester, (context) {
        final rt = RaftTokens.of(context).recipeTokens;
        // Existing generated CssColor.paint contract, copied from utility
        // literal _v361 / chrome-literal-fits.json. It already calibrates the
        // source-over paint; a second integer-composite pass must not alter it.
        const fitted = CssColor(
          0x1f141111,
          'oklch(0.1813 0.00497 17.62 / 0.12)',
          Color.from(
            alpha: .121409,
            red: .051103,
            green: .051103,
            blue: .049304,
          ),
        );
        final style = _paintStyle(
          rt,
          literal: kind == 'chrome-fit'
              ? fitted
              : const CssVar('--brand-soft', null, 'brandSoft'),
          image: kind == 'image'
              ? const CssFunction('linear-gradient', [
                  CssColor(0x33ffffff),
                  CssColor(0x33ffffff),
                ])
              : null,
        );
        return RaftSurfaceBackgroundScope(
          color: const Color(0xff636363),
          child: ColoredBox(
            color: const Color(0xff636363),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftRecipeBox(
                    key: const ValueKey('raw-fitted-paint'),
                    style: style,
                    tokens: rt,
                    child: const SizedBox(width: 320, height: 36),
                  ),
                  RaftMenuSlotRow(
                    key: _row,
                    label: 'Action',
                    root: style,
                    tokens: rt,
                  ),
                ],
              ),
            ),
          ),
        );
      });
      final samples = await _pixels(tester, [
        _emptyRowPoint(tester, find.byKey(const ValueKey('raw-fitted-paint'))),
        _emptyRowPoint(tester, find.byKey(_row)),
      ]);
      expect(
        samples[1],
        samples[0],
        reason:
            '$kind is an existing paint contract: the action row cannot '
            'apply a second correction or flatten its image layer.',
      );
    }
  });
}
