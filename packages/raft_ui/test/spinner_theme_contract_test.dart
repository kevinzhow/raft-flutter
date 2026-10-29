import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  testWidgets('custom default extent yields to recipe and physical sizes', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    final pack = RaftThemePack(
      id: 'custom-spinner',
      name: {'en': 'Custom spinner'},
      version: '1.0.0',
      light: const RaftModeValues(geometry: {'size.spinnerDefault': 24})
          .mergedWith(builtInRaftTheme.light),
      dark: builtInRaftTheme.dark,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: pack),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftSpinner(key: ValueKey('default')),
                  RaftSpinner(
                    key: ValueKey('recipe'),
                    recipeSize: RaftSpinnerRecipeSize.xs,
                  ),
                  RaftSpinner(
                    key: ValueKey('physical'),
                    size: 28,
                    recipeSize: RaftSpinnerRecipeSize.lg,
                    inverse: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      t.getSize(find.byKey(const ValueKey('default'))),
      const Size.square(24),
    );
    expect(
      t.getSize(find.byKey(const ValueKey('recipe'))),
      const Size.square(9.5),
    );
    expect(
      t.getSize(find.byKey(const ValueKey('physical'))),
      const Size.square(28),
    );
    final inverse = find.descendant(
      of: find.byKey(const ValueKey('physical')),
      matching: find.byType(RaftPixelSpinner),
    );
    expect(t.widget<RaftPixelSpinner>(inverse).color, Colors.white);
  });
  testWidgets(
    'pixel animation uses custom turn duration and stops for reduced motion',
    (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      final pack = RaftThemePack(
        id: 'slow-spinner',
        name: {'en': 'Slow spinner'},
        version: '1.0.0',
        light: const RaftModeValues(geometry: {'duration.spinnerTurn': 2000})
            .mergedWith(builtInRaftTheme.light),
        dark: builtInRaftTheme.dark,
      );
      Widget app(bool reduced) => MaterialApp(
        theme: raftTheme(pack: pack),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const Scaffold(body: Center(child: RaftSpinner())),
        ),
      );
      await t.pumpWidget(app(false));
      await t.pump();
      await t.pump(const Duration(milliseconds: 250));
      final paint = find.descendant(
        of: find.byType(RaftPixelSpinner),
        matching: find.byType(CustomPaint),
      );
      final dynamic painter = t.widget<CustomPaint>(paint).painter!;
      expect(painter.phase as double, closeTo(.125, .001));
      await t.pumpWidget(app(true));
      await t.pump(const Duration(seconds: 3));
      expect(t.binding.transientCallbackCount, 0);
      final dynamic stillPainter = t.widget<CustomPaint>(paint).painter!;
      expect(stillPainter.phase, isNull);
    },
  );
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('source spinner appearance and default extent $id/$dark', (
        t,
      ) async {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id), dark: dark),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: const Scaffold(
                body: Center(
                  child: IconTheme(
                    data: IconThemeData(color: Colors.red),
                    child: DefaultTextStyle(
                      style: TextStyle(color: Colors.blue),
                      child: RaftSpinner(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final native = id == raftThemePackId;
        final brutal = id == brutalThemePackId && !dark;
        expect(
          find.byType(RaftPixelSpinner),
          native ? findsOneWidget : findsNothing,
        );
        expect(
          t.getSize(find.byType(RaftSpinner)),
          Size.square(
            native
                ? 12
                : brutal
                ? 16
                : 14,
          ),
        );
        if (native)
          expect(
            t.widget<RaftPixelSpinner>(find.byType(RaftPixelSpinner)).color,
            Colors.blue,
          );
        await t.pump(const Duration(seconds: 2));
        expect(t.binding.transientCallbackCount, 0);
        expect(t.takeException(), isNull);
      });
    }
  }
}
