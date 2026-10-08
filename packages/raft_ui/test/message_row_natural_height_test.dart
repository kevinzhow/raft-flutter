import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final agent in [false, true]) {
      testWidgets(
        'natural header and adjacent body/footer margin $family/$dark/agent=$agent',
        (t) async {
          var mentions = 0;
          final theme = raftTheme(family, dark: dark);
          Future<void> mount(bool footer) async {
            await t.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 650,
                      child: RaftMessageRow(
                        author: agent ? 'Cindy' : 'artin',
                        timestamp: '06/22 10:30',
                        onAuthor: () => mentions++,
                        metadata: agent
                            ? const Text(
                                'GPT-5 Codex',
                                style: TextStyle(fontSize: 11, height: 1),
                              )
                            : null,
                        subtitle: 'Public description',
                        content: const SizedBox(
                          key: ValueKey('body'),
                          height: 20,
                          width: 200,
                        ),
                        footer: footer
                            ? const SizedBox(
                                key: ValueKey('footer'),
                                height: 20,
                                width: 100,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pump();
          }

          await mount(false);
          final withoutFooter = t.getSize(find.byType(RaftMessageRow)).height;
          final author = find.byWidgetPredicate(
            (w) => w is RaftControl && w.kind == RaftControlKind.textLink,
          );
          expect(
            t.getSize(author).height,
            family == RaftFamily.brutal ? 20 : 14,
          );
          await t.tap(author);
          expect(mentions, 1);
          await mount(true);
          final recipe = RaftMessageRowRecipe(
            theme.extension<RaftTokens>()!,
            viewportWidth: 800,
          );
          final gap =
              t.getTopLeft(find.byKey(const ValueKey('footer'))).dy -
              t.getBottomLeft(find.byKey(const ValueKey('body'))).dy;
          expect(
            gap,
            recipe.footerGap > recipe.bodyGap
                ? recipe.footerGap
                : recipe.bodyGap,
          );
          expect(
            t.getSize(find.byType(RaftMessageRow)).height - withoutFooter,
            family == RaftFamily.brutal ? 26 : 20,
          );
          if (family == RaftFamily.elegant) {
            expect(withoutFooter, agent ? 81 : 74);
            expect(
              t.getSize(find.byType(RaftMessageRow)).height,
              agent ? 101 : 94,
            );
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
