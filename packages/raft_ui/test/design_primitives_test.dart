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
    'desktop density retains source layout bounds while touch expands its target',
    (tester) async {
      for (final (density, expected) in [
        (RaftDensity.desktop, 32.0),
        (RaftDensity.touch, 48.0),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.brutal),
            home: Scaffold(
              body: Center(
                child: RaftDensityScope(
                  density: density,
                  child: RaftButton(label: 'Run', onPressed: () {}),
                ),
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftControl)).height, expected);
        expect(tester.getSize(find.byType(AnimatedContainer)).height, 32);
      }
    },
  );
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    final name = '${family.name} ${dark ? 'dark' : 'light'}';
    testWidgets('$name default danger retains exact upstream pixels', (
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
      final surface = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect(
        decoration.color,
        family == RaftFamily.brutal
            ? const Color(0xfff97264)
            : dark
            ? const Color(0xffdb2c2b)
            : const Color(0xfff70720),
      );
      final label = tester.widget<Text>(find.text('Delete'));
      final style = DefaultTextStyle.of(tester.element(find.text('Delete')))
          .style
          .merge(label.style);
      expect(
        style.color,
        family == RaftFamily.brutal
            ? const Color(0xff141110)
            : dark
            ? const Color(0xfffafaf7)
            : const Color(0xffffffff),
      );
    });
    testWidgets(
      '$name visual recipe preserves 48 px hit area and keyboard activation',
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
        final rect = tester.getRect(find.byType(RaftControl));
        expect(rect.height, greaterThanOrEqualTo(48));
        final surface = find.descendant(
          of: find.byType(RaftControl),
          matching: find.byType(AnimatedContainer),
        );
        expect(tester.getSize(surface).height, 32);
        // The target's bottom edge sits outside the visual 32 px surface.
        await tester.tapAt(Offset(rect.center.dx, rect.bottom - 2));
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
      '$name hover, press, drag cancel and reduced motion preserve state contract',
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
        final target = find.byType(RaftControl),
            surface = find.byType(AnimatedContainer);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(target));
        await tester.pump();
        final hovered =
            tester.widget<AnimatedContainer>(surface).decoration!
                as BoxDecoration;
        expect(
          hovered.color,
          family == RaftFamily.brutal
              ? const Color(0xfffe7da8)
              : dark
              // foundation.css elegant.dark --accent-hover (color-mix(in
              // srgb-linear, accent-soft 78%, accent-strong)), Chrome-composite fit.
              ? RaftSemanticColors.elegantDark.accentHover
              : const Color(0xfff8cad8),
        );
        final gesture = await tester.startGesture(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 110));
        final down = tester.widget<AnimatedContainer>(surface).transform!;
        expect(
          family == RaftFamily.brutal ? down.storage[12] : down.storage[0],
          family == RaftFamily.brutal ? 1 : .985,
        );
        await gesture.moveBy(const Offset(300, 0));
        await gesture.up();
        await tester.pump();
        expect(clicks, 0);
        await mouse.removePointer();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: RaftButton(label: 'Run', onPressed: () => clicks++),
                ),
              ),
            ),
          ),
        );
        final reduced = await tester.startGesture(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 110));
        final reducedSurface = tester.widget<AnimatedContainer>(surface);
        expect(reducedSurface.duration, Duration.zero);
        expect(reducedSurface.transform!.storage[0], 1);
        expect(reducedSurface.transform!.storage[12], 0);
        await reduced.cancel();
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
