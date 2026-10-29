import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Material(
    child: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets('overlay result pieces render in ${dark ? 'dark' : 'light'}', (
      t,
    ) async {
      var retried = 0, opened = 0;
      await t.pumpWidget(
        host(
          dark,
          Column(
            children: [
              const RaftQuickSwitcherFilterRow(
                child: RaftSearchFilterWrap(children: [Text('From')]),
              ),
              RaftQuickSwitcherErrorCard(
                title: 'Search failed',
                body: 'The last search request failed.',
                actionLabel: 'Retry',
                onAction: () => retried++,
              ),
              RaftQuickSwitcherThreadGroup(
                badge: 'Thread',
                where: '#design',
                hits: '2 hits',
                time: '5 minutes ago',
                title: 'Parity discussion',
                children: [
                  for (final id in ['a', 'b'])
                    RaftQuickSwitcherHit(
                      where: '#design',
                      threadLabel: 'thread',
                      warnings: const ['Archived'],
                      sender: 'Cindy',
                      time: '1 minute ago',
                      snippet: Text('hit $id'),
                      selected: id == 'a',
                      nested: true,
                      onPressed: () => opened++,
                    ),
                ],
              ),
              const RaftQuickSwitcherEmpty(
                title: 'Search everything',
                detail: 'Search channels.',
              ),
              const RaftQuickSwitcherEntityScroll(children: [Text('row')]),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('quick-switcher-filters')), findsOneWidget);
      expect(find.byKey(const Key('quick-switcher-error')), findsOneWidget);
      expect(
        find.byKey(const Key('quick-switcher-thread-group')),
        findsOneWidget,
      );
      expect(find.text('hit a'), findsOneWidget);
      await t.tap(find.text('Retry'));
      await t.tap(find.text('hit b'));
      expect(retried, 1);
      expect(opened, 1);
    });
  }

  testWidgets('the skeleton shows five placeholder cards', (t) async {
    await t.pumpWidget(host(false, const RaftQuickSwitcherSkeleton()));
    expect(find.byType(RaftSkeleton), findsNWidgets(5 * 5));
    await t.pumpWidget(const SizedBox.shrink());
  });
}
