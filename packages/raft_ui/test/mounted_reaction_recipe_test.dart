import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/design_primitives.dart';
import 'package:raft_ui/src/mounted_reaction_recipe.dart';
import 'package:raft_ui/src/theme.dart';

void main() {
  testWidgets(
    'mounted source chip is20px with15px controlled glyph; readonly is not a disabled button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: const Center(
            child: RaftMountedReaction(
              label: 'Public reaction by artin',
              glyph: SizedBox(key: Key('public-glyph')),
              count: 2,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(RaftMountedReaction)).height, 20);
      expect(
        tester.getSize(find.byKey(const Key('public-glyph'))),
        const Size(15, 15),
      );
      expect(find.byType(RaftControl), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('count animates only on changed values and finishes in180ms', (
    tester,
  ) async {
    Widget host(int count) => MaterialApp(
      home: Center(
        child: RaftReactionCount(
          count: count,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
    await tester.pumpWidget(host(2));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpWidget(host(2));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpWidget(host(3));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, .7);
    await tester.pump(const Duration(milliseconds: 81));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pump(const Duration(milliseconds: 99));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion suppresses changed-count animation', (
    tester,
  ) async {
    Widget host(int count) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Center(
          child: RaftReactionCount(
            count: count,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(2));
    await tester.pumpWidget(host(3));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('mounted selected/failure/hover rules differ from generic RUI chip', () {
    final t = raftTheme(RaftFamily.elegant).extension<RaftTokens>()!;
    final error = RaftMountedReactionRecipe(t, failure: true);
    expect(error.radius, BorderRadius.circular(4));
    expect(error.padding, const EdgeInsets.symmetric(horizontal: 6));
    expect(error.textStyle.fontSize, 12);
    expect(error.textStyle.fontWeight, FontWeight.w700);
    expect(error.background, t.colors['warning']!.withValues(alpha: .3));
    expect(error.backgroundFor(hovered: true), t.colors['fill-muted']);
    expect(
      RaftMountedReactionRecipe(t, reacted: true).background,
      t.accentSoft,
    );
  });
}
