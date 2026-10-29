import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 480, child: child),
    ),
  ),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'the archived footer is a centred warning Banner in a p-3 host (dark=$dark)',
      (tester) async {
        await tester.pumpWidget(
          host(
            raftTheme(dark: dark),
            RaftChannelArchivedFooter(
              message: 'This channel is archived.',
              linkLabel: 'Unarchive',
              onLink: () {},
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('channel-archived-footer')),
          findsOneWidget,
        );
        final banner = find.byType(RaftBanner);
        expect(banner, findsOneWidget);
        expect(tester.widget<RaftBanner>(banner).descriptionTail, isNotNull);
        final outer = tester.getRect(
          find.byKey(const ValueKey('channel-archived-footer')),
        );
        final inner = tester.getRect(banner);
        expect(inner.left - outer.left, 12);
        expect(inner.top - outer.top, greaterThanOrEqualTo(12));
      },
    );

    testWidgets(
      'runtime chips are soft Badges: information when detected, muted when not (dark=$dark)',
      (tester) async {
        await tester.pumpWidget(
          host(
            raftTheme(dark: dark),
            const Column(
              children: [
                RaftRuntimeChip(label: 'Codex CLI', detected: true),
                RaftRuntimeChip(label: 'Pi (not installed)', detected: false),
              ],
            ),
          ),
        );
        final badges = tester
            .widgetList<RaftBadge>(find.byType(RaftBadge))
            .toList();
        expect(badges.map((b) => b.variant), [
          RaftBadgeRecipeVariant.information,
          RaftBadgeRecipeVariant.muted,
        ]);
        expect(
          badges.every((b) => b.appearance == RaftBadgeRecipeAppearance.soft),
          isTrue,
        );
      },
    );

    testWidgets(
      'a copyable command is the recipe code box with a 16px copy mark (dark=$dark)',
      (tester) async {
        await tester.pumpWidget(
          host(
            raftTheme(dark: dark),
            const RaftCopyableCode('raft-computer status'),
          ),
        );
        final icon = tester.widget<RaftIcon>(find.byType(RaftIcon));
        expect(icon.size, 16);
        expect(find.byType(RaftButton), findsOneWidget);
      },
    );
  }
}
