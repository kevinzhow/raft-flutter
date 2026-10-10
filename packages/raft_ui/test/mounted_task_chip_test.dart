import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    Future<void> mount(
      WidgetTester tester,
      Widget child, {
      RaftDensity density = RaftDensity.desktop,
      double width = 390,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: RaftDensityScope(
              density: density,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    RaftMountedMessageTaskChip chip({
      VoidCallback? onOpen,
      FocusNode? focus,
      String? claimant,
      bool loading = false,
    }) => RaftMountedMessageTaskChip(
      number: 10,
      status: RaftMessageTaskStatus.inProgress,
      title: 'Actual public task 中文 日本語',
      openLabel: 'Open task #10: Actual public task 中文 日本語',
      claimant: claimant,
      focusNode: focus,
      loading: loading,
      onOpen: onOpen,
    );

    test('$family/$dark source status palette and mounted border', () {
      final t = raftTheme(family, dark: dark).extension<RaftTokens>()!;
      for (final status in RaftMessageTaskStatus.values) {
        final r = RaftMessageTaskChipRecipe(t, status);
        expect(r.chipHeight, family == RaftFamily.brutal ? 18.25 : 19);
        expect(r.borderWidth, family == RaftFamily.brutal ? 1 : .5);
        expect(r.textStyle.fontSize, 13);
        expect(
          r.textStyle.fontWeight,
          family == RaftFamily.brutal ? FontWeight.w500 : FontWeight.w400,
        );
        expect(r.transformsOnInteraction, isFalse);
        expect(r.overlayGradient, isNull);
        expect(r.insetHighlightAlpha, 0);
        expect(r.shadows(hovered: true, focused: true, pressed: true), isEmpty);
        expect(r.focusOutlineWidth, 2);
        expect(r.focusOutlineOffset, 2);
        expect(
          r.backgroundForInteraction(hovered: true, pressed: true),
          r.background,
        );
      }
      final todo = RaftMessageTaskChipRecipe(t, RaftMessageTaskStatus.todo);
      final closed = RaftMessageTaskChipRecipe(t, RaftMessageTaskStatus.closed);
      if (family == RaftFamily.brutal) {
        expect(closed.background, t.colors['color-brutal-stone']);
        expect(todo.background, t.colors['color-brutal-orange']);
      } else {
        expect(closed.background, todo.background);
        expect(closed.iconForeground, t.colors['inactive']);
        expect(todo.iconForeground, t.colors['foreground-placeholder']);
        expect(
          todo.side().color,
          t.colors['line-muted']!.withValues(
            alpha: t.colors['line-muted']!.a * .75,
          ),
        );
        expect(
          RaftMessageTaskChipRecipe(
            t,
            RaftMessageTaskStatus.inProgress,
          ).foreground,
          t.colors[dark ? 'primary-strong' : 'color-brutal-yellow-800'],
        );
      }
    });

    testWidgets(
      '$family/$dark footer paints identifier/claimant, title only aria',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var calls = 0;
          await mount(
            tester,
            chip(onOpen: () => calls++, claimant: 'owner中文日本語'),
          );
          expect(find.text('#10'), findsOneWidget);
          expect(find.text('@owner中文日本語'), findsOneWidget);
          expect(find.text('Actual public task 中文 日本語'), findsNothing);
          final control = find.byType(RaftControl);
          expect(
            tester
                .getSemantics(
                  find.bySemanticsLabel(
                    'Open task #10: Actual public task 中文 日本語',
                  ),
                )
                .label,
            'Open task #10: Actual public task 中文 日本語',
          );
          expect(
            tester.getSize(control).height,
            family == RaftFamily.brutal ? 18.25 : 19,
          );
          final rect = tester.getRect(find.byType(RaftMessageTaskStatusIcon));
          expect(rect.size, const Size(12, 12));
          await tester.tap(control);
          expect(calls, 1);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 350));
          semantics.dispose();
        }
      },
    );

    testWidgets(
      '$family/$dark hover brightness has no Button transform or shadow',
      (tester) async {
        await mount(tester, chip(onOpen: () {}));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(500, 300));
        await mouse.moveTo(tester.getCenter(find.byType(RaftControl)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        ColorFilter filter() => tester
            .widget<ColorFiltered>(find.byType(ColorFiltered))
            .colorFilter;
        final b = family == RaftFamily.brutal ? .90 : .96;
        expect(
          filter(),
          ColorFilter.matrix([
            b,
            0,
            0,
            0,
            0,
            0,
            b,
            0,
            0,
            0,
            0,
            0,
            b,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
        );
        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(RaftControl),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(container.transform!.storage[12], 0);
        expect(container.transform!.storage[13], 0);
        expect((container.decoration! as BoxDecoration).boxShadow, isEmpty);
        await mouse.moveTo(const Offset(500, 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        expect(
          filter(),
          const ColorFilter.matrix([
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
        );
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
      },
    );

    testWidgets(
      '$family/$dark keyboard opens once and disabled/loading rejects',
      (tester) async {
        var calls = 0;
        final focus = FocusNode();
        try {
          await mount(tester, chip(onOpen: () => calls++, focus: focus));
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(focus.hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(calls, 1);
          await mount(
            tester,
            chip(onOpen: () => calls++, loading: true, focus: focus),
          );
          await tester.tap(find.byType(RaftControl));
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(calls, 1);
          await mount(tester, chip(focus: focus));
          await tester.tap(find.byType(RaftControl));
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(calls, 1);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 350));
          focus.dispose();
        }
      },
    );

    testWidgets(
      '$family/$dark constrained claimant and explicit native touch flow',
      (tester) async {
        var calls = 0;
        await mount(
          tester,
          chip(
            onOpen: () => calls++,
            claimant: 'very-long-authorized-claimant中文日本語',
          ),
          density: RaftDensity.touch,
          width: 150,
        );
        expect(tester.takeException(), isNull);
        final control = find.byType(RaftControl);
        expect(
          tester.getSize(control).height,
          RaftMessageTaskChipRecipe(
            RaftTokens.of(tester.element(control)),
            RaftMessageTaskStatus.inProgress,
          ).chipHeight,
        );
        final paint = tester.getSize(
          find.descendant(
            of: control,
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(paint.height, family == RaftFamily.brutal ? 18.25 : 19);
        final slot = tester.getRect(control);
        await tester.tapAt(Offset(slot.center.dx, slot.bottom - 1));
        expect(calls, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
      },
    );
  }
}
