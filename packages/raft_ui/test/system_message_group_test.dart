import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget _host(Widget child, RaftAppearance appearance) => MaterialApp(
  theme: raftTheme(appearance.light, dark: appearance.mode == ThemeMode.dark),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 320, child: child),
    ),
  ),
);

void main() {
  for (final appearance in raftThemeMatrix([
    const RaftAppearance(light: RaftFamily.brutal),
    const RaftAppearance(light: RaftFamily.elegant),
    const RaftAppearance(light: RaftFamily.elegant, mode: ThemeMode.dark),
  ])) {
    testWidgets(
      'system group shows the summary, hides rows until expanded ${appearance.light} ${appearance.mode}',
      (t) async {
        var expanded = false;
        late StateSetter set;
        await t.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return RaftSystemMessageGroup(
                  toggleKey: const ValueKey('toggle'),
                  summary: 'There are 3 system messages',
                  expanded: expanded,
                  onToggle: () => set(() => expanded = !expanded),
                  children: const [
                    RaftSystemMessage(
                      content: 'Cindy joined',
                      timestamp: '10:05',
                    ),
                  ],
                );
              },
            ),
            appearance,
          ),
        );
        expect(find.text('There are 3 system messages'), findsOneWidget);
        expect(find.text('Cindy joined'), findsNothing);
        await t.tap(find.byKey(const ValueKey('toggle')));
        await t.pump();
        expect(find.text('Cindy joined'), findsOneWidget);
        // Inside an expanded group the host re-asserts the note's lead:
        // `pt-1` elegant, `pt-1.5` brutal (a lone note has `pt-[3px]` / 0).
        expect(
          t.getSize(find.byType(RaftSystemMessage)).height,
          appearance.light == RaftFamily.brutal ? 6 + 16 : 4 + 18,
        );
        await t.tap(find.byKey(const ValueKey('toggle')));
        await t.pump();
        expect(find.text('Cindy joined'), findsNothing);
      },
    );
  }

  testWidgets('banner tail link is one atomic tap target', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _host(
        RaftBanner(
          size: RaftBannerRecipeSize.sm,
          textAlign: TextAlign.center,
          description:
              'Message history is limited to 30 days on the Free plan.',
          descriptionTail: (label: 'View Billing', onPressed: () => taps++),
        ),
        const RaftAppearance(light: RaftFamily.elegant),
      ),
    );
    await t.tap(find.text('View Billing'));
    expect(taps, 1);
  });
}
