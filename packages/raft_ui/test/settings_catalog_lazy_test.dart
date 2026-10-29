@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '1000 MCP cards stay lazy and retain expanded tools ${dark ? 'dark' : 'light'}',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RaftMcpServersSection(
                scrollable: true,
                servers: [
                  for (var i = 0; i < 1000; i++)
                    RaftMcpServerRow(
                      id: '$i',
                      name: 'MCP $i',
                      provider: 'custom',
                      endpointUrl: 'https://fixture.invalid/mcp/$i',
                      tools: [RaftMcpTool('Tool $i', 'Fixture tool')],
                    ),
                ],
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key as ValueKey<String>).value.startsWith('mcp-server-'),
              )
              .evaluate()
              .length,
          lessThan(30),
        );
        await t.tap(find.byKey(const ValueKey('mcp-tools-toggle-0')));
        await t.pump();
        expect(find.text('Tool 0'), findsOneWidget);
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await t.scrollUntilVisible(
          find.text('MCP 999'),
          4000,
          scrollable: scrollable,
          maxScrolls: 100,
        );
        expect(find.text('MCP 999'), findsOneWidget);
        t.state<ScrollableState>(scrollable).position.jumpTo(0);
        await t.pumpAndSettle();
        expect(find.text('Tool 0'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
    for (final layout in RaftConnectedAppsLayout.values) {
      testWidgets(
        '1000 app cards stay lazy ${dark ? 'dark' : 'light'}/$layout',
        (t) async {
          t.view.physicalSize = const Size(1200, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final search = TextEditingController();
          addTearDown(search.dispose);
          var opened = '';
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: RaftConnectedAppsSection(
                  scrollable: true,
                  description: 'Fixture applications',
                  tab: RaftConnectedAppsTab.myApps,
                  counts: (marketplace: 0, installed: 0, myApps: 1000),
                  onTab: (_) {},
                  searchController: search,
                  category: 'all',
                  categories: const [('all', 'All categories')],
                  onCategory: (_) {},
                  layout: layout,
                  onLayout: (_) {},
                  rows: [
                    for (var i = 0; i < 1000; i++)
                      RaftConnectedAppRow(
                        id: '$i',
                        name: 'App $i',
                        initials: 'AP',
                        meta: 'Fixture',
                        onOpenName: () => opened = '$i',
                      ),
                  ],
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            find.textContaining(RegExp(r'^App \d+$')).evaluate().length,
            lessThan(30),
          );
          await t.scrollUntilVisible(
            find.text('App 999'),
            4000,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
            maxScrolls: 100,
          );
          await t.tap(find.text('App 999'));
          expect(opened, '999');
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
