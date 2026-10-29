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
      testWidgets('actual banner body source line and foreground $id/$dark', (
        t,
      ) async {
        addTearDown(() => t.pumpWidget(const SizedBox()));
        final pack = packForThemeId(id);
        final tokens = RaftTokens.theme(pack: pack, dark: dark);
        final originalElegant =
            id == elegantThemePackId || (id == brutalThemePackId && dark);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: pack, dark: dark),
            home: const Scaffold(
              body: RaftBanner(
                status: RaftBannerRecipeStatus.destructive,
                description: 'Body with descenders gy.',
              ),
            ),
          ),
        );
        final style = t
            .widget<Text>(find.text('Body with descenders gy.'))
            .style!;
        expect(style.fontSize, originalElegant ? 13 : 14);
        expect(style.fontSize! * style.height!, originalElegant ? 16 : 20);
        expect(style.color, originalElegant ? tokens.muted : tokens.ink);
      });
    }
  }

  testWidgets('Raft destructive explanation uses the shared static banner', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(
          body: RaftConfirmDialog(
            title: 'Delete',
            message: 'This cannot be undone.',
          ),
        ),
      ),
    );
    expect(find.byType(RaftBanner), findsOneWidget);
    expect(t.widget<RaftBanner>(find.byType(RaftBanner)).live, isFalse);
  });
  for (final glyph in [null, RaftGlyph.info]) {
    testWidgets('source default banner puts the action under the copy $glyph', (
      t,
    ) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 700,
                child: RaftBanner(
                  description: 'Reconnect to send',
                  glyph: glyph,
                  action: RaftButton(
                    key: const ValueKey('retry'),
                    label: 'Retry',
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final text = t.getRect(find.text('Reconnect to send'));
      final action = t.getRect(find.byKey(const ValueKey('retry')));
      // raft-ui 0.7 `BannerAction`: a row under the copy, from its left edge.
      expect(action.top, greaterThanOrEqualTo(text.bottom));
      expect(action.left, text.left);
      if (glyph != null) expect(t.getRect(find.byType(RaftIcon)).top, text.top);
    });
  }
  testWidgets('caller plainMessage skips the warning frame', (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(
          body: RaftConfirmDialog(
            title: 'Confirm',
            message: 'Choose an option.',
            plainMessage: true,
          ),
        ),
      ),
    );
    expect(find.byType(RaftBanner), findsNothing);
  });
  testWidgets('Raft md banner has source inset glyph and top alignment', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: RaftBanner(
                key: ValueKey('banner'),
                status: RaftBannerRecipeStatus.destructive,
                glyph: RaftGlyph.octagonAlert,
                description: 'Several lines of explanation must keep the icon at the start of the paragraph.',
              ),
            ),
          ),
        ),
      ),
    );
    final root = t.getRect(find.byKey(const ValueKey('banner')));
    final icon = t.getRect(find.byType(RaftIcon));
    expect(icon.width, 20);
    expect(icon.left - root.left, 14);
    expect(icon.top - root.top, 12);
    final text = t.widget<Text>(
      find.text(
        'Several lines of explanation must keep the icon at the start of the paragraph.',
      ),
    );
    expect(text.style!.fontSize, 14);
  });
}
