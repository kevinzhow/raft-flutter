import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      test('source row geometry $id/$dark', () {
        final tokens = raftTheme(
          pack: packForThemeId(id),
          dark: dark,
        ).extension<RaftTokens>()!;
        final native = id == raftThemePackId;
        final brutal = id == brutalThemePackId && !dark;
        final narrow = RaftMessageRowRecipe(tokens, viewportWidth: 390);
        final wide = RaftMessageRowRecipe(tokens, viewportWidth: 1280);
        final thread = RaftMessageRowRecipe(
          tokens,
          viewportWidth: 390,
          rowContext: RaftMessageRowContext.thread,
        );
        expect(
          narrow.gutterWidth,
          native
              ? 35
              : brutal
              ? 36
              : 32,
        );
        expect(wide.gutterWidth, native ? 35 : 36);
        expect(narrow.avatarExtent, native ? 35 : 36);
        expect(narrow.gap, native || brutal ? 12 : 8);
        expect(narrow.avatarTop, 2);
        expect(
          narrow.padding,
          native
              ? const EdgeInsets.all(8)
              : brutal
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
              : const EdgeInsets.fromLTRB(16, 8, 16, 6),
        );
        expect(
          thread.padding.left,
          native
              ? 8
              : brutal
              ? 6
              : 12,
        );
        expect(
          wide.padding.left,
          native
              ? 8
              : brutal
              ? 6
              : 28,
        );
        expect(
          narrow.subtitleStyle.fontFamily,
          brutal ? tokens.monoFont : tokens.bodyFont,
        );
        expect(narrow.headerReserve, native ? 0 : 96);
        expect(narrow.headerLine, native || brutal ? 20 : 21);
        expect(
          narrow.bodyGap,
          native
              ? 1
              : brutal
              ? 0
              : 4,
        );
        expect(narrow.bodyBottomGap, native || brutal ? 0 : 4);
        expect(narrow.minimumHeight, native ? 0 : 48);
        expect(
          narrow.borderWidth,
          native
              ? 0
              : brutal
              ? 2
              : 1,
        );
        for (final tier in RaftMessageSizeTier.values) {
          final sized = RaftMessageRowRecipe(
            tokens,
            viewportWidth: 390,
            sizeTier: tier,
          );
          expect(
            sized.avatarExtent,
            native
                ? tier == RaftMessageSizeTier.lg
                      ? 34
                      : 35
                : 36,
          );
          expect(
            sized.time.fontSize! * sized.time.height!,
            native || brutal ? 16 : tier.meta,
          );
        }
      });
    }
  }
  for (final dark in [false, true]) {
    testWidgets(
      'native header preserves the sender and pushes time to the edge $dark',
      (t) async {
        var mentions = 0;
        addTearDown(() => t.pumpWidget(const SizedBox()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 260,
                  child: RaftMessageRow(
                    author: 'Cindy',
                    timestamp: '10:30',
                    onAuthor: () => mentions++,
                    avatar: const SizedBox(key: Key('source-avatar')),
                    metadata: const SizedBox(width: 120, height: 16),
                    subtitle:
                        'A longer description yields before the model and name',
                    content: const SizedBox(
                      height: 24,
                      key: Key('source-body'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final author = find.text('Cindy'), time = find.text('10:30');
        final natural = t
            .renderObject<RenderBox>(author)
            .getMaxIntrinsicWidth(double.infinity);
        expect(t.getSize(author).width, closeTo(natural, .01));
        expect(t.getTopRight(time).dx, closeTo(252, .01));
        expect(t.getTopLeft(find.byKey(const Key('source-body'))).dx, 55);
        expect(t.getTopLeft(find.byKey(const Key('source-avatar'))).dy, 10);
        expect(
          t.getSize(find.byKey(const Key('source-avatar'))),
          const Size.square(35),
        );
        final tokens = RaftTokens.of(t.element(time));
        expect(t.widget<Text>(time).style!.fontFamily, tokens.monoFont);
        await t.tap(author);
        await t.pump();
        expect(mentions, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
