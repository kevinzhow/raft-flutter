import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

Color fill(WidgetTester t) => t
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(RaftButton),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map(
      (w) => switch (w.decoration) {
        RaftLayeredDecoration d => d.base.color,
        BoxDecoration d => d.color,
        _ => null,
      },
    )
    .whereType<Color>()
    .first;

void main() {
  for (final edge in ['inkBorder', 'ring']) {
    for (final motion in ['overlay', 'scale', 'offsetShadow']) {
      testWidgets('custom hover colors independent of $edge/$motion', (
        t,
      ) async {
        TestGesture? mouse;
        addTearDown(() async {
          if (mouse != null) await mouse.removePointer();
          await t.pumpWidget(const SizedBox());
        });
        final pack = RaftThemePack(
          id: 'independent-button',
          name: {'en': 'Independent button'},
          version: '1.0.0',
          light: RaftModeValues(
            colors: const {
              'layer-button-danger': Color(0xffffaa00),
              'layer-button-danger-hover': Color(0xff8800aa),
              'foreground-button-danger': Color(0xff001122),
            },
            options: {
              'button.hoverSurface': 'variant',
              'press.effect': motion,
              'control.edge': edge,
              'control.sheen': 'none',
              'sticker.ring': 'none',
            },
          ).mergedWith(builtInRaftTheme.light),
          dark: builtInRaftTheme.dark,
        );
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: pack),
            home: Scaffold(
              body: Center(
                child: RaftButton(
                  label: 'Apply',
                  tone: RaftButtonRecipeVariant.danger,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(fill(t), const Color(0xffffaa00));
        final rect = t.getRect(find.byType(RaftButton));
        mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1, 1));
        await mouse.moveTo(rect.center);
        await t.pump();
        await t.pump(const Duration(milliseconds: 200));
        expect(fill(t), const Color(0xff8800aa));
        await mouse.down(rect.center);
        await t.pump();
        await t.pump(const Duration(milliseconds: 200));
        expect(fill(t), const Color(0xff8800aa));
        expect(
          DefaultTextStyle.of(t.element(find.text('Apply'))).style.color,
          const Color(0xff001122),
        );
        await mouse.up();
        expect(t.takeException(), isNull);
      });
    }
  }
}
