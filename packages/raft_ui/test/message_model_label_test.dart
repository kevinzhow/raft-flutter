import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const model = 'GPT-5 Codex';
const clock = '10:30';
const subtitle = 'Private description';
const badge = 'Bot role';

void main() {
  for (final (platform, size, dark, expectedLine) in [
    (TargetPlatform.android, const Size(390, 844), true, 16.0),
    (TargetPlatform.linux, const Size(1024, 768), false, 18.0),
  ]) {
    testWidgets('model label uses source MessageItemMeta on $platform', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      try {
        final theme = raftTheme(dark: dark).copyWith(platform: platform);
        for (final (index, tier) in RaftMessageSizeTier.values.indexed) {
          await t.pumpWidget(frame(theme, tier));
          final tokens = RaftTokens.of(t.element(find.text(model)));
          final style = mounted(t, model);
          expect(
            style.fontFamily,
            tokens.bodyFont,
            reason: 'Model must use proportional caption, not clock',
          );
          expect(style.fontWeight, FontWeight.w500);
          expect(style.fontSize, 11 + index);
          expect(
            style.fontSize! * style.height!,
            closeTo(expectedLine - 1 + index, .001),
          );
          expect(style.color, tokens.colors['foreground-hint']);
          final recipe = RaftMessageRowRecipe(
            tokens,
            viewportWidth: size.width,
            sizeTier: tier,
          );
          expect(mounted(t, clock).fontFamily, recipe.time.fontFamily);
          expect(mounted(t, clock).height, recipe.time.height);
          expect(
            mounted(t, subtitle).fontFamily,
            recipe.subtitleStyle.fontFamily,
          );
          expect(mounted(t, subtitle).height, recipe.subtitleStyle.height);
          expect(mounted(t, badge).fontFamily, recipe.time.fontFamily);
          expect(mounted(t, badge).fontSize, 10);
        }
      } finally {
        await t.pumpWidget(const SizedBox());
      }
    });
  }

  testWidgets('model label keeps its existing user-pack clock style', (
    t,
  ) async {
    final pack = RaftThemePack.parse('''
{"format":"raft-theme/1","id":"user:model-control","name":"Model control",
 "version":"1.0.0","extends":"raft","modes":{"light":{},"dark":{}}}
''');
    try {
      final theme = raftTheme(pack: pack);
      await t.pumpWidget(frame(theme, RaftMessageSizeTier.md));
      final tokens = RaftTokens.of(t.element(find.text(model)));
      expect(tokens.themeOverrides, isNotNull);
      expect(mounted(t, model), mounted(t, clock));
    } finally {
      await t.pumpWidget(const SizedBox());
    }
  });
}

Widget frame(ThemeData theme, RaftMessageSizeTier tier) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Builder(
      builder: (context) => RaftMessageTile(
        author: 'artin',
        content: 'Archived channel underlay',
        timestamp: clock,
        modelLabel: model,
        subtitle: subtitle,
        badge: badge,
        bodyFontSize: tier.bodySizeFor(RaftTokens.of(context)),
      ),
    ),
  ),
);

TextStyle mounted(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!;
