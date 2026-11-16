import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// ListRow family against raft-ui 0.95.3 (list-row.recipe.mjs,
// list-row-skeleton.mjs): the touch row is 56px with py 8 (`pointer-coarse`),
// risk tones, subtitle, truncating meta, `attached` rules, and the skeleton.
// Input mode is set with RaftInteractionScope, never by width.

const _touchSizes = [Size(856, 944), Size(944, 856)];
const _mouseSizes = [Size(390, 844), Size(1024, 768)];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required bool touch,
  bool dark = false,
  double width = 340,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RaftInteractionScope(
      interaction: touch
          ? RaftInteraction.touchMode
          : RaftInteraction.pointerMode,
      child: MaterialApp(
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _k = ValueKey('row');

RaftListRow _row({
  Key key = _k,
  RaftListRowVariant variant = RaftListRowVariant.standard,
  RaftListRowTone tone = RaftListRowTone.normal,
  bool interactive = true,
  bool disabled = false,
  bool selected = false,
  bool attached = false,
  VoidCallback? onPressed,
  String title = 'Title',
  Widget? lead,
}) => RaftListRow(
  key: key,
  variant: variant,
  tone: tone,
  interactive: interactive,
  disabled: disabled,
  selected: selected,
  attached: attached,
  onPressed: interactive && !disabled ? (onPressed ?? () {}) : null,
  children: [
    ?lead,
    RaftListRowBody(children: [RaftListRowTitle(title)]),
  ],
);

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Color? _fill(WidgetTester tester, Finder row) {
  final box = find
      .descendant(of: row, matching: find.byType(DecoratedBox))
      .first;
  return switch (tester.widget<DecoratedBox>(box).decoration) {
    RaftLayeredDecoration(:final base) => base.color,
    BoxDecoration(:final color) => color,
    _ => null,
  };
}

Finder _rules(RaftUiColors ui) => find.byWidgetPredicate(
  (w) => w is ColoredBox && w.color.toARGB32() == ui.lineHairline.toARGB32(),
);

void main() {
  final ui = RaftUiColors.of(false);

  group('touch density (pointer-coarse)', () {
    for (final size in _touchSizes) {
      testWidgets('default row is 56px on touch at $size', (tester) async {
        await _pump(tester, _row(), size: size, touch: true);
        expect(tester.getSize(find.byKey(_k)).height, 56);
      });
      testWidgets('two-line row on touch is 8 + 46 + 8 at $size', (
        tester,
      ) async {
        await _pump(
          tester,
          RaftListRow(
            key: _k,
            onPressed: () {},
            children: const [
              SizedBox.square(dimension: 35),
              RaftListRowBody(
                children: [
                  RaftListRowTop(
                    children: [
                      RaftListRowTitle('Wug'),
                      RaftListRowMeta('10:40'),
                    ],
                  ),
                  RaftListRowBottom(
                    children: [RaftListRowDescription('Draft is in #launch.')],
                  ),
                ],
              ),
            ],
          ),
          size: size,
          touch: true,
        );
        expect(tester.getSize(find.byKey(_k)).height, 62);
        expect(_style(tester, 'Wug').fontSize, 16);
        expect(tester.getSize(find.text('Wug')).height, 24);
      });
    }
    for (final size in _mouseSizes) {
      testWidgets('default row is 64px with a mouse at $size', (tester) async {
        await _pump(tester, _row(), size: size, touch: false);
        expect(tester.getSize(find.byKey(_k)).height, 64);
      });
    }
    testWidgets('plain row keeps py 12 on touch and with a mouse', (
      tester,
    ) async {
      await _pump(
        tester,
        _row(variant: RaftListRowVariant.plain),
        size: _touchSizes[0],
        touch: true,
      );
      expect(tester.getSize(find.byKey(_k)).height, 48);
    });
    testWidgets(
      'desktop type step: title 14/22 at 1024x768 mouse, 16/24 touch',
      (tester) async {
        await _pump(tester, _row(), size: const Size(1024, 768), touch: false);
        expect(_style(tester, 'Title').fontSize, 14);
        expect(tester.getSize(find.text('Title')).height, 22);
        await _pump(tester, _row(), size: const Size(944, 856), touch: true);
        expect(_style(tester, 'Title').fontSize, 16);
        expect(tester.getSize(find.text('Title')).height, 24);
        await _pump(tester, _row(), size: const Size(390, 844), touch: false);
        expect(_style(tester, 'Title').fontSize, 16);
      },
    );
  });

  group('risk tones', () {
    for (final size in [..._touchSizes, _mouseSizes[0]]) {
      for (final dark in [false, true]) {
        testWidgets(
          'danger and warning ink title and icon ($size dark=$dark)',
          (tester) async {
            final c = RaftUiColors.of(dark);
            for (final tone in [
              RaftListRowTone.warning,
              RaftListRowTone.danger,
            ]) {
              final expected = tone == RaftListRowTone.warning
                  ? c['warning-strong']
                  : c['danger-strong'];
              await _pump(
                tester,
                _row(
                  tone: tone,
                  variant: RaftListRowVariant.plain,
                  lead: const RaftListRowIcon(RaftGlyph.search),
                ),
                size: size,
                touch: size == _touchSizes[0] || size == _touchSizes[1],
                dark: dark,
              );
              expect(_style(tester, 'Title').color, expected);
              final icon = tester.widget<RaftIcon>(find.byType(RaftIcon));
              expect(icon.color, expected);
            }
          },
        );
      }
    }
    testWidgets('disabled and display-only risk rows keep the plain inks', (
      tester,
    ) async {
      await _pump(
        tester,
        _row(
          tone: RaftListRowTone.danger,
          disabled: true,
          lead: const RaftListRowIcon(RaftGlyph.search),
        ),
        size: _touchSizes[0],
        touch: true,
      );
      expect(_style(tester, 'Title').color, ui.foregroundDisabled);
      expect(
        tester.widget<RaftIcon>(find.byType(RaftIcon)).color,
        ui.foregroundDisabled,
      );
      await _pump(
        tester,
        _row(
          tone: RaftListRowTone.danger,
          interactive: false,
          lead: const RaftListRowIcon(RaftGlyph.search),
        ),
        size: _touchSizes[0],
        touch: true,
      );
      expect(_style(tester, 'Title').color, ui.foreground);
      expect(
        tester.widget<RaftIcon>(find.byType(RaftIcon)).color,
        ui.foregroundHint,
      );
    });
  });

  group('subtitle and meta', () {
    Widget withSubtitle() => RaftListRow(
      key: _k,
      onPressed: () {},
      children: const [
        RaftListRowBody(
          children: [
            RaftListRowTitle('Wug'),
            RaftListRowSubtitle('Agent for the launch week checklist'),
          ],
        ),
      ],
    );
    testWidgets('subtitle is footnote 400 in the row ink, one line', (
      tester,
    ) async {
      await _pump(tester, withSubtitle(), size: _touchSizes[0], touch: true);
      final s = _style(tester, 'Agent for the launch week checklist');
      expect(s.fontSize, 13);
      expect(s.fontWeight, FontWeight.w400);
      expect(s.color, ui.foreground);
      final text = tester.widget<Text>(
        find.text('Agent for the launch week checklist'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      await _pump(
        tester,
        withSubtitle(),
        size: const Size(1024, 768),
        touch: false,
      );
      expect(
        _style(tester, 'Agent for the launch week checklist').fontSize,
        12,
      );
    });
    testWidgets('a muted row inks the subtitle muted', (tester) async {
      await _pump(
        tester,
        RaftListRow(
          key: _k,
          tone: RaftListRowTone.muted,
          onPressed: () {},
          children: const [
            RaftListRowBody(children: [RaftListRowSubtitle('Sub')]),
          ],
        ),
        size: _touchSizes[0],
        touch: true,
      );
      expect(_style(tester, 'Sub').color, ui.foregroundMuted);
    });
    for (final size in [_touchSizes[0], _mouseSizes[0]]) {
      testWidgets('long meta truncates without overflow at $size', (
        tester,
      ) async {
        await _pump(
          tester,
          RaftListRow(
            key: _k,
            onPressed: () {},
            children: const [
              RaftListRowBody(
                children: [
                  RaftListRowTop(
                    children: [
                      RaftListRowTitle('A long conversation title'),
                      RaftListRowMeta(
                        '2026-11-16 10:40:12 Europe/Berlin standard',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          size: size,
          touch: size == _touchSizes[0],
          width: 120,
        );
        expect(tester.takeException(), isNull);
        final meta = tester.widget<Text>(
          find.text('2026-11-16 10:40:12 Europe/Berlin standard'),
        );
        expect(meta.overflow, TextOverflow.ellipsis);
        expect(
          tester.getSize(find.byType(RaftListRowMeta)).width,
          lessThanOrEqualTo(120 - 32 + .01),
        );
      });
    }
  });

  group('attached rows', () {
    Widget list(List<Widget> rows) => RaftListRowList(children: rows);
    RaftListRow plain(
      String key, {
      bool interactive = true,
      bool attached = false,
    }) => _row(
      key: ValueKey(key),
      variant: RaftListRowVariant.plain,
      interactive: interactive,
      attached: attached,
    );
    testWidgets('no rule above an attached interactive row', (tester) async {
      await _pump(
        tester,
        list([plain('a'), plain('b', attached: true)]),
        size: _touchSizes[0],
        touch: true,
      );
      expect(_rules(ui), findsNothing);
      // min-h-control: 44 on touch.
      expect(tester.getSize(find.byKey(const ValueKey('b'))).height, 44);
      // plain attached: pt-0.
    });
    testWidgets(
      'display-only attached row after an interactive row gets the rule and py',
      (tester) async {
        await _pump(
          tester,
          list([plain('a'), plain('b', interactive: false, attached: true)]),
          size: _touchSizes[0],
          touch: true,
        );
        expect(_rules(ui), findsOneWidget);
        expect(tester.getSize(find.byKey(const ValueKey('b'))).height, 48);
      },
    );
    testWidgets(
      'display-only attached row after a display-only row: no rule, pt 0',
      (tester) async {
        await _pump(
          tester,
          list([
            plain('a', interactive: false),
            plain('b', interactive: false, attached: true),
          ]),
          size: _touchSizes[0],
          touch: true,
        );
        expect(_rules(ui), findsNothing);
        expect(tester.getSize(find.byKey(const ValueKey('b'))).height, 36);
      },
    );
    testWidgets(
      'display-only attached row after an attached interactive row: no rule',
      (tester) async {
        await _pump(
          tester,
          list([
            plain('a'),
            plain('b', attached: true),
            plain('c', interactive: false, attached: true),
          ]),
          size: _mouseSizes[1],
          touch: false,
        );
        expect(_rules(ui), findsNothing);
        expect(tester.getSize(find.byKey(const ValueKey('b'))).height, 34);
      },
    );
    testWidgets('non-attached rows keep their rule', (tester) async {
      await _pump(
        tester,
        list([plain('a'), plain('b')]),
        size: _touchSizes[0],
        touch: true,
      );
      expect(_rules(ui), findsOneWidget);
    });
  });

  group('skeleton', () {
    for (final size in [_touchSizes[0], _mouseSizes[1]]) {
      final touch = size == _touchSizes[0];
      testWidgets('default skeleton is the loaded row height at $size', (
        tester,
      ) async {
        Widget loaded() => RaftListRow(
          key: _k,
          onPressed: () {},
          children: const [
            SizedBox.square(dimension: 35),
            RaftListRowBody(
              children: [
                RaftListRowTop(
                  children: [RaftListRowTitle('Wug'), RaftListRowMeta('10:40')],
                ),
                RaftListRowBottom(
                  children: [RaftListRowDescription('Draft is in #launch.')],
                ),
              ],
            ),
          ],
        );
        await _pump(tester, loaded(), size: size, touch: touch);
        final h = tester.getSize(find.byKey(_k)).height;
        await _pump(
          tester,
          const RaftListRowSkeleton(key: _k),
          size: size,
          touch: touch,
        );
        expect(tester.getSize(find.byKey(_k)).height, h);
        expect(
          tester.getSize(
            find.byKey(const ValueKey('list-row-skeleton-leading')),
          ),
          const Size(35, 35),
        );
      });
      testWidgets(
        'plain skeleton uses the 20px icon and no description at $size',
        (tester) async {
          await _pump(
            tester,
            const RaftListRowSkeleton(
              key: _k,
              variant: RaftListRowVariant.plain,
              leading: true,
            ),
            size: size,
            touch: touch,
          );
          expect(
            tester.getSize(
              find.byKey(const ValueKey('list-row-skeleton-leading')),
            ),
            const Size(20, 20),
          );
          expect(
            find.byKey(const ValueKey('list-row-skeleton-description')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('list-row-skeleton-meta')),
            findsNothing,
          );
        },
      );
    }
    testWidgets('bar widths follow the 45/35/55 and 75/60/70 pattern', (
      tester,
    ) async {
      const titles = [.45, .35, .55];
      const descriptions = [.75, .60, .70];
      for (var i = 0; i < 3; i++) {
        await _pump(
          tester,
          RaftListRowSkeleton(key: _k, index: i),
          size: _touchSizes[0],
          touch: true,
        );
        final title = tester.getSize(
          find.byKey(const ValueKey('list-row-skeleton-title')),
        );
        final description = tester.getSize(
          find.byKey(const ValueKey('list-row-skeleton-description')),
        );
        final meta = tester.getSize(
          find.byKey(const ValueKey('list-row-skeleton-meta')),
        );
        expect(meta.width, 36);
        // The title box is the line minus the 36px meta and the 8px gap.
        final bodyWidth = 340 - 32 - 35 - 12;
        expect(title.width, closeTo((bodyWidth - 36 - 8) * titles[i], .6));
        expect(description.width, closeTo(bodyWidth * descriptions[i], .6));
        expect(title.height, 12);
        expect(description.height, closeTo(10.5, .01));
      }
    });
  });

  group('already aligned', () {
    testWidgets(
      'hover fills only with a mouse; selected wins; press is fill-medium',
      (tester) async {
        await _pump(tester, _row(), size: _mouseSizes[1], touch: false);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byKey(_k)));
        await tester.pump();
        expect(
          _fill(tester, find.byKey(_k))!.toARGB32(),
          ui['fill-subtle'].toARGB32(),
        );
        await mouse.down(tester.getCenter(find.byKey(_k)));
        await tester.pump();
        expect(
          _fill(tester, find.byKey(_k))!.toARGB32(),
          ui['fill-medium'].toARGB32(),
        );
        await mouse.up();
        await mouse.removePointer();
        await _pump(tester, _row(), size: _touchSizes[0], touch: true);
        final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
        await touch.down(tester.getCenter(find.byKey(_k)));
        await tester.pump();
        await touch.up();
        await tester.pump();
        expect(_fill(tester, find.byKey(_k))?.a ?? 0, 0);
      },
    );
    testWidgets('selected fills info-soft and reports semantics selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _row(selected: true),
        size: _touchSizes[1],
        touch: true,
      );
      expect(
        _fill(tester, find.byKey(_k))!.toARGB32(),
        ui['info-soft'].toARGB32(),
      );
      expect(
        tester.getSemantics(find.byKey(_k)),
        isSemantics(isSelected: true, hasSelectedState: true),
      );
      handle.dispose();
    });
    testWidgets(
      'keyboard focus paints the inset 2px foreground ring; pointer focus does not',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await _pump(
          tester,
          RaftListRow(
            key: _k,
            focusNode: focus,
            onPressed: () {},
            children: const [
              RaftListRowBody(children: [RaftListRowTitle('Title')]),
            ],
          ),
          size: _mouseSizes[0],
          touch: false,
        );
        List<RaftCssShadow> rings() {
          final box = find
              .descendant(
                of: find.byKey(_k),
                matching: find.byType(DecoratedBox),
              )
              .first;
          final d = tester.widget<DecoratedBox>(box).decoration;
          return d is RaftLayeredDecoration
              ? d.layers.where((s) => s.inset && s.spread == 2).toList()
              : const [];
        }

        await tester.tap(find.byKey(_k));
        await tester.pump();
        expect(rings(), isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        focus.requestFocus();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(rings().map((s) => s.color), [ui.foreground]);
      },
    );
  });
}
