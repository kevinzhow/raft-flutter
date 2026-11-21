import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/raft/css_box.dart';

void main() {
  testWidgets('Installed grid cards include the border in their minimum size', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: true).copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: RaftConnectedAppsSection(
            tab: RaftConnectedAppsTab.installed,
            counts: (marketplace: 0, installed: 1, myApps: 0),
            onTab: (_) {},
            searchController: search,
            category: 'all',
            categories: const [('all', 'All categories')],
            onCategory: (_) {},
            layout: RaftConnectedAppsLayout.grid,
            onLayout: (_) {},
            rows: const [
              RaftConnectedAppRow(
                id: 'garden-journal',
                name: 'Garden Journal',
                initials: 'GJ',
                meta: 'Other · by Raft Labs',
                badges: [RaftConnectedAppBadge.warning('Permission update')],
              ),
            ],
          ),
        ),
      ),
    );
    final app = find.ancestor(
      of: find.text('Garden Journal'),
      matching: find.byType(RaftCard),
    );
    expect(tester.getSize(app).height, 184);
    final badge = find.byType(RaftBadge);
    final paint = find.descendant(of: badge, matching: find.byType(RaftCssBox));
    final tokens = RaftTokens.of(tester.element(badge));
    final fill = tester.widget<RaftCssBox>(paint.first).fill;
    expect(
      fill,
      raftChromeBlend(tokens.ui['warning-soft'], tokens.ui.layerCard),
    );
  });

  testWidgets('Recommended apps use the group heading and footnote byline', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    const byline = 'Connect GitHub: agents push code and open pull requests.';
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftConnectedAppsSection(
            tab: RaftConnectedAppsTab.installed,
            counts: (marketplace: 1, installed: 0, myApps: 0),
            onTab: (_) {},
            searchController: search,
            category: 'all',
            categories: const [('all', 'All categories')],
            onCategory: (_) {},
            layout: RaftConnectedAppsLayout.grid,
            onLayout: (_) {},
            standalone: true,
            scrollable: true,
            recommendation: RaftMarketplaceAppTile(
              id: 'stamp',
              name: 'Stamp',
              initials: 'ST',
              byline: byline,
              state: RaftMarketplaceAppState.install,
              stateLabel: 'Install',
            ),
          ),
        ),
      ),
    );

    final heading = find.text('Recommended for you');
    final style = tester.widget<Text>(heading).style!;
    final tokens = RaftTokens.of(tester.element(heading));
    expect(style.color, tokens.ui.foregroundHint);
    expect(style.fontSize! * style.height!, 18);
    final recommendation = find.ancestor(
      of: find.text('Stamp'),
      matching: find.byType(RaftCard),
    );
    final headingBlock = find.ancestor(
      of: heading,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.header == true,
      ),
    );
    final headingToCard =
        tester.getTopLeft(recommendation).dy -
        tester.getTopLeft(headingBlock.first).dy;
    final bylineStyle = tester.widget<Text>(find.text(byline)).style!;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(headingToCard, 32);
    expect(bylineStyle.fontSize, 13);
    expect(bylineStyle.fontSize! * bylineStyle.height!, 18);
  });
}
