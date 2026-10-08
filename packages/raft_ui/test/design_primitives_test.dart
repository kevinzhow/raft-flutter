import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('reparenting a keyed control never activates its callback', (
    tester,
  ) async {
    final key = GlobalKey();
    var clicks = 0;
    Widget fixture(bool left) {
      final control = RaftControl(
        key: key,
        onPressed: () => clicks++,
        child: const Text('Move'),
      );
      return MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(width: 120, child: left ? control : null),
              SizedBox(width: 120, child: left ? null : control),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(fixture(true));
    final state = key.currentState;
    await tester.pumpWidget(fixture(false));
    expect(key.currentState, same(state));
    expect(clicks, 0);
    await tester.tap(find.text('Move'));
    await tester.pump();
    expect(clicks, 1);
    await tester.pumpWidget(fixture(true));
    expect(clicks, 1);
  });
  testWidgets(
    'controls support an ordinary MaterialApp and pointer activation transfers editor focus',
    (tester) async {
      final editorFocus = FocusNode();
      var clicks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: editorFocus),
                RaftButton(label: 'Confirm', onPressed: () => clicks++),
                RaftSelectField<String>(
                  value: 'one',
                  items: const [
                    DropdownMenuItem(value: 'one', child: Text('One')),
                  ],
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      editorFocus.requestFocus();
      await tester.pump();
      expect(editorFocus.hasFocus, true);
      await tester.tap(find.widgetWithText(RaftButton, 'Confirm'));
      await tester.pump();
      expect(clicks, 1);
      expect(editorFocus.hasFocus, false);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editorFocus.dispose();
    },
  );
  testWidgets(
    'RaftButton keeps the Web box in both densities; touch only extends the hit area',
    (tester) async {
      for (final density in RaftDensity.values) {
        var clicks = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.brutal),
            home: Scaffold(
              body: Center(
                child: RaftDensityScope(
                  density: density,
                  child: RaftButton(label: 'Run', onPressed: () => clicks++),
                ),
              ),
            ),
          ),
        );
        // buttonVariants size=md: h-8.
        final rect = tester.getRect(find.byType(RaftButton));
        expect(rect.height, 32);
        await tester.tapAt(Offset(rect.center.dx, rect.bottom + 6));
        await tester.pump();
        expect(clicks, density == RaftDensity.touch ? 1 : 0);
      }
    },
  );
  BoxDecoration buttonDecoration(WidgetTester tester, Finder button) =>
      tester
              .widgetList<Container>(
                find.descendant(of: button, matching: find.byType(Container)),
              )
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .first;
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    final name = '${family.name} ${dark ? 'dark' : 'light'}';
    testWidgets('$name destructive button paints the buttonVariants danger recipe', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: RaftButton(
              label: 'Delete',
              destructive: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      final t = RaftTokens.of(tester.element(find.text('Delete')));
      final decoration = buttonDecoration(tester, find.byType(RaftButton));
      // brutal: bg-brutal-red text-foreground-strong; elegant: bg-danger
      // text-danger-foreground.
      expect(
        decoration.color,
        family == RaftFamily.brutal
            ? const Color(0xfff97264)
            : dark
            // [dark] background-color override of variant=danger.
            ? const Color(0xffdb2c2b)
            : t.semantic.danger,
      );
      final style = DefaultTextStyle.of(tester.element(find.text('Delete'))).style;
      expect(
        style.color,
        family == RaftFamily.brutal
            ? const Color(0xff141110)
            : dark
            ? const Color(0xfffafaf7)
            : t.semantic.dangerForeground,
      );
    });
    testWidgets(
      '$name touch hit area meets 48 px and keyboard activation works',
      (tester) async {
        var clicks = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftDensityScope(
                  density: RaftDensity.touch,
                  child: RaftButton(label: 'Run', onPressed: () => clicks++),
                ),
              ),
            ),
          ),
        );
        final rect = tester.getRect(find.byType(RaftButton));
        expect(rect.height, 32);
        // The touch target's bottom edge sits outside the visual 32 px box.
        await tester.tapAt(Offset(rect.center.dx, rect.bottom + 6));
        await tester.pump();
        expect(clicks, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNotNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(clicks, 2);
        final handle = tester.ensureSemantics();
        try {
          expect(tester, meetsGuideline(androidTapTargetGuideline));
          expect(tester, meetsGuideline(labeledTapTargetGuideline));
        } finally {
          handle.dispose();
        }
      },
    );
    testWidgets(
      '$name hover and press follow the recipe; drag-off cancels activation',
      (tester) async {
        var clicks = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftButton(label: 'Run', onPressed: () => clicks++),
              ),
            ),
          ),
        );
        final target = find.byType(RaftButton);
        final t = RaftTokens.of(tester.element(target));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(target));
        await tester.pump();
        // variant=accent hover: brutal keeps bg-brutal-pink (and lifts),
        // elegant uses the accent hover role.
        final hovered = buttonDecoration(tester, target);
        expect(
          hovered.color,
          family == RaftFamily.brutal
              ? const Color(0xfffe7da8)
              : t.semantic.accentHover,
        );
        final gesture = await tester.startGesture(tester.getCenter(target));
        await tester.pump();
        final pressed = tester
            .widgetList<Transform>(
              find.descendant(of: target, matching: find.byType(Transform)),
            )
            .first
            .transform;
        // active: brutal `translate: 1px 1px`, elegant `scale: 0.985`.
        expect(
          family == RaftFamily.brutal ? pressed.storage[12] : pressed.storage[0],
          family == RaftFamily.brutal ? 1 : .985,
        );
        await gesture.moveBy(const Offset(300, 0));
        await gesture.up();
        await tester.pump();
        expect(clicks, 0);
        await mouse.removePointer();
      },
    );
    testWidgets(
      '$name disabled/loading buttons never invoke actions and all exact icons paint',
      (tester) async {
        var clicks = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  const RaftButton(label: 'Disabled'),
                  RaftButton(
                    label: 'Loading',
                    busy: true,
                    onPressed: () => clicks++,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        children: [
                          for (final glyph in RaftGlyph.values) RaftIcon(glyph),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text('Disabled'));
        await tester.tap(find.widgetWithText(RaftButton, 'Loading'));
        await tester.pump();
        expect(clicks, 0);
        expect(tester.takeException(), isNull);
        final theme = raftTheme(family, dark: dark);
        expect(
          theme.colorScheme.primary,
          family == RaftFamily.brutal
              ? const Color(0xffffd440)
              : const Color(0xffffd441),
        );
        expect(
          theme.textTheme.titleMedium!.fontFamily,
          family == RaftFamily.brutal
              ? 'packages/raft_ui/HankenGrotesk'
              : 'packages/raft_ui/Inter',
        );
      },
    );
  }
}
