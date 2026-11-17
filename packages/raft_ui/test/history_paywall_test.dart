import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const _rows = [
  RaftHiddenMessagePreview(
    id: 'a',
    author: 'Mina',
    timestamp: 'Oct 2, 10:14',
    text: 'The migration plan is ready for review',
  ),
  RaftHiddenMessagePreview(
    id: 'b',
    author: 'Dev',
    timestamp: 'Oct 3, 09:02',
    text: 'Sent an attachment',
  ),
];

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';

    Future<void> mount(
      WidgetTester t,
      Widget child, {
      double width = 520,
    }) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = Size(width, 900);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
      await t.pump(const Duration(milliseconds: 350));
    }

    testWidgets('$mode start: glimpse rows above the card, faded and inert', (
      t,
    ) async {
      var upgrades = 0, tapped = 0;
      await mount(
        t,
        RaftHistoryPaywall(
          title: '12 earlier messages are older than 30 days',
          description: 'Free shows only the last 30 days.',
          upgradeLabel: 'Upgrade to Pro',
          onUpgrade: () => upgrades++,
          glimpse: _rows,
        ),
      );
      final preview = find.byKey(const ValueKey('history-paywall-preview'));
      expect(preview, findsOneWidget);
      expect(find.text('Mina'), findsOneWidget);
      expect(find.text('Sent an attachment'), findsOneWidget);
      // The glimpse is above the card.
      expect(
        t.getBottomLeft(preview).dy,
        lessThanOrEqualTo(
          t.getTopLeft(find.byKey(const ValueKey('history-paywall-card'))).dy,
        ),
      );
      // Opacity .7 and a 48px fade mask.
      final opacity = t.widget<Opacity>(
        find.descendant(of: preview, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.7);
      expect(
        find.descendant(of: preview, matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
      expect(RaftHistoryPaywall.fadeExtent, 48);
      // Not hit-testable, not in semantics.
      await t.tapAt(t.getCenter(find.text('Mina')));
      expect(tapped, 0);
      expect(
        find.descendant(of: preview, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(find.bySemanticsLabel(RegExp('Mina')), findsNothing);
      // The one action.
      await t.tap(find.byKey(const ValueKey('history-paywall-upgrade')));
      expect(upgrades, 1);
      expect(
        find.byKey(const ValueKey('history-paywall-none-recent')),
        findsNothing,
      );
    });

    testWidgets('$mode the Upgrade button works from the keyboard', (t) async {
      var upgrades = 0;
      await mount(
        t,
        RaftHistoryPaywall(
          title: 'Messages older than 30 days are hidden',
          description: 'd',
          upgradeLabel: 'Upgrade to Pro',
          onUpgrade: () => upgrades++,
        ),
      );
      expect(
        find.byKey(const ValueKey('history-paywall-preview')),
        findsNothing,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(upgrades, 1);
      expect(
        t.getSemantics(find.byKey(const ValueKey('history-paywall-upgrade'))),
        matchesSemantics(
          label: 'Upgrade to Pro',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          isFocused: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    });

    testWidgets('$mode allHidden notice and recent divider are exclusive', (
      t,
    ) async {
      Widget paywall({String? none, String? divider}) => RaftHistoryPaywall(
        title: 't',
        description: 'd',
        upgradeLabel: 'Upgrade to Pro',
        onUpgrade: () {},
        glimpse: _rows,
        noRecentLabel: none,
        recentDividerLabel: divider,
      );
      await mount(t, paywall(none: 'No new messages in the last 30 days'));
      expect(find.text('No new messages in the last 30 days'), findsOneWidget);
      expect(find.text('Last 30 days'), findsNothing);
      await mount(t, paywall(divider: 'Last 30 days'));
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('history-paywall-recent-divider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('history-paywall-none-recent')),
        findsNothing,
      );
    });

    testWidgets(
      '$mode target mode: lighter neighbours around the muted target',
      (t) async {
        var opened = 0;
        await mount(
          t,
          RaftHistoryPaywall(
            title: 'The message you are looking for is older than 30 days',
            description: 'd',
            upgradeLabel: 'Upgrade to Pro',
            onUpgrade: () {},
            before: [_rows.first],
            target: _rows.last,
            after: [_rows.first],
            targetReplies: RaftHiddenTargetReplies(
              summary: '4 replies',
              semanticLabel: 'Open 4 replies',
              onOpen: () => opened++,
              reply: const RaftInlineReply(
                id: 'r',
                author: 'Mina',
                preview: 'Shipped it',
                senderType: 'user',
                timestamp: 'Nov 1',
              ),
            ),
          ),
        );
        double opacityOf(String key) => t
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        expect(
          t
              .widget<Opacity>(
                find.byKey(const ValueKey('history-paywall-target')),
              )
              .opacity,
          0.6,
        );
        expect(opacityOf('history-paywall-before'), 0.4);
        expect(opacityOf('history-paywall-after'), 0.4);
        // The card sits between before/target and after.
        final card = t
            .getTopLeft(find.byKey(const ValueKey('history-paywall-card')))
            .dy;
        expect(
          t.getTopLeft(find.byKey(const ValueKey('history-paywall-before'))).dy,
          lessThan(card),
        );
        expect(
          t.getTopLeft(find.byKey(const ValueKey('history-paywall-after'))).dy,
          greaterThan(card),
        );
        // The replies box is the one live control inside the muted target.
        await t.tap(
          find.byKey(const ValueKey('history-paywall-target-replies')),
        );
        expect(opened, 1);
      },
    );
  }
}
