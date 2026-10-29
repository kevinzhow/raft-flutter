import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('actual button size and label from source $id/$dark', (
        t,
      ) async {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        final native = id == raftThemePackId;
        final elegant = id == elegantThemePackId || (!native && dark);
        final expected = <RaftButtonRecipeSize, (double, double, FontWeight)>{
          RaftButtonRecipeSize.xs: (
            native ? 32 : 24,
            native ? 13 : 11,
            elegant ? FontWeight.w500 : FontWeight.w700,
          ),
          RaftButtonRecipeSize.sm: (
            native ? 32 : 28,
            native ? 13 : 12,
            elegant ? FontWeight.w500 : FontWeight.w700,
          ),
          RaftButtonRecipeSize.md: (
            32,
            native ? 13 : 14,
            elegant ? FontWeight.w500 : FontWeight.w700,
          ),
          RaftButtonRecipeSize.lg: (
            native
                ? 44
                : elegant
                ? 36
                : 40,
            native
                ? 15
                : elegant
                ? 16
                : 14,
            elegant ? FontWeight.w500 : FontWeight.w700,
          ),
        };
        for (final entry in expected.entries) {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
              home: Scaffold(
                body: Center(
                  child: RaftButton(
                    key: const ValueKey('button'),
                    label: 'Send',
                    tone: RaftButtonRecipeVariant.danger,
                    size: entry.key,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          );
          expect(
            t.getSize(find.byKey(const ValueKey('button'))).width,
            lessThan(200),
            reason: 'source inline-flex button keeps its natural width',
          );
          final label = find.text('Send');
          final style = DefaultTextStyle.of(t.element(label)).style;
          expect(
            t.getSize(find.byKey(const ValueKey('button'))).height,
            entry.value.$1,
            reason: entry.key.name,
          );
          expect(style.fontSize, entry.value.$2, reason: entry.key.name);
          expect(style.fontWeight, entry.value.$3, reason: entry.key.name);
        }
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'button geometry reads component values independent of identity',
    (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      final pack = RaftThemePack(
        id: 'custom-controls',
        name: {'en': 'Custom controls'},
        version: '1.0.0',
        light: const RaftModeValues(
          geometry: {'radius.control': 13, 'stroke.control': 2},
        ).mergedWith(builtInRaftTheme.light),
        dark: builtInRaftTheme.dark,
      );
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack),
          home: Scaffold(
            body: RaftButton(label: 'Send', onPressed: () {}),
          ),
        ),
      );
      final box = find
          .descendant(
            of: find.byType(RaftButton),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final decoration =
          t.widget<DecoratedBox>(box).decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(13));
      expect((decoration.border! as Border).top.width, 2);
    },
  );
  for (final id in raftThemeMatrix([
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('button disabled fades but busy stays opaque $id/$dark', (
        t,
      ) async {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        Widget app({bool busy = false}) => MaterialApp(
          theme: raftTheme(pack: packForThemeId(id), dark: dark),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: RaftButton(
                label: 'Send',
                busy: busy,
                size: RaftButtonRecipeSize.sm,
              ),
            ),
          ),
        );
        await t.pumpWidget(app());
        final fade = find.descendant(
          of: find.byType(RaftButton),
          matching: find.byType(Opacity),
        );
        expect(fade, findsOneWidget);
        expect(t.widget<Opacity>(fade).opacity, .4);
        await t.pumpWidget(app(busy: true));
        await t.pumpAndSettle();
        expect(t.widget<Opacity>(fade).opacity, 1);
        expect(find.byType(RaftSpinner), findsOneWidget);
        expect(find.byType(RaftPixelSpinner), findsNothing);
        expect(t.hasRunningAnimations, isFalse);
      });
    }
  }
  testWidgets('button honors caller alpha-filter compositing', (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
        home: const Scaffold(
          body: Center(
            child: RaftButton(
              label: 'Continue',
              opacityCompositing: RaftOpacityCompositing.alphaFilter,
            ),
          ),
        ),
      ),
    );
    final opacity = find.descendant(
      of: find.byType(RaftButton),
      matching: find.byType(RaftCssOpacity),
    );
    expect(opacity, findsOneWidget);
    expect(t.widget<RaftCssOpacity>(opacity).opacity, .4);
  }, skip: raftLookSkip(raftLookElegant));
}
