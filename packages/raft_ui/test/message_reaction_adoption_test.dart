import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final appearance in [
    const RaftAppearance(light: RaftFamily.brutal, mode: ThemeMode.light),
    const RaftAppearance(light: RaftFamily.elegant, mode: ThemeMode.light),
    const RaftAppearance(light: RaftFamily.elegant, mode: ThemeMode.dark),
  ]) {
    for (final density in RaftDensity.values) {
      testWidgets(
        'MessageTile uses source reaction face, vector and real target $appearance $density',
        (t) async {
          var taps = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(
                appearance.light,
                dark: appearance.mode == ThemeMode.dark,
              ),
              home: Scaffold(
                body: RaftDensityScope(
                  density: density,
                  child: Center(
                    child: RaftMessageTile(
                      author: 'Public author',
                      content: 'Public body',
                      timestamp: '10:30',
                      reactions: const [
                        {'emoji': '👍', 'count': 2},
                      ],
                      reactedEmojis: const {'👍'},
                      onReaction: (emoji) {
                        expect(emoji, '👍');
                        taps++;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pump(const Duration(milliseconds: 250));
          final reaction = find.byType(RaftMountedReaction);
          expect(reaction, findsOneWidget);
          expect(find.byType(FilterChip), findsNothing);
          final control = find.descendant(
            of: reaction,
            matching: find.byType(RaftControl),
          );
          expect(t.getSize(control).height, 20);
          final face = find.descendant(
            of: control,
            matching: find.byType(AnimatedContainer),
          );
          expect(t.getSize(face).height, 20);
          final glyph = find.byType(RaftReactionGlyph);
          expect(t.getSize(glyph), const Size(15, 15));
          final tokens = RaftTokens.of(t.element(reaction));
          final recipe = RaftMountedReactionRecipe(tokens, reacted: true);
          final resting =
              t.widget<AnimatedContainer>(face).decoration as BoxDecoration;
          expect(resting.color, recipe.background);
          expect(resting.borderRadius, BorderRadius.circular(4));
          expect(resting.boxShadow, isEmpty);
          await t.tap(control);
          await t.pump();
          expect(taps, 1);
          final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(t.getCenter(control));
          await t.pump(const Duration(milliseconds: 250));
          expect(
            (t.widget<AnimatedContainer>(face).decoration as BoxDecoration)
                .color,
            recipe.backgroundFor(hovered: true),
          );
          await mouse.removePointer();
          final pressed = await t.startGesture(t.getCenter(control));
          await pressed.cancel();
          await t.pump();
          expect(taps, 1);
          expect(t.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'readonly reaction stays a span with source20px and no mutation $appearance',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              appearance.light,
              dark: appearance.mode == ThemeMode.dark,
            ),
            home: const Scaffold(
              body: Center(
                child: RaftMessageTile(
                  author: 'Public author',
                  content: 'Read only',
                  timestamp: '10:30',
                  reactions: [
                    {'emoji': '👍', 'count': 2},
                    {'emoji': '🔥', 'count': 0},
                  ],
                  reactedEmojis: {'👍'},
                ),
              ),
            ),
          ),
        );
        final reaction = find.byType(RaftMountedReaction);
        expect(reaction, findsOneWidget);
        expect(t.getSize(reaction).height, 20);
        expect(
          find.descendant(of: reaction, matching: find.byType(RaftControl)),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
