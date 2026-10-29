import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Every unread count in the sidebar, the rail and the phone tab bar is the
/// Web `SidebarItemCount`/`AppRailItemBadge` chip: a 20px tall capsule that
/// keeps its own size, whatever the height of the row around it. A row hands
/// its trailing child loose vertical constraints, so a count that centres
/// its content with an `Align` (a `Container(alignment:)`) stretches to the
/// full row height: the tall pink bar in the Activity row (v0.1.0+31).
void main() {
  const counts = [1, 12, 120];
  // The test font is Ahem (12px per character for the current count role): the chip's natural width is
  // its text plus the Source's 6+6 layout padding (its border paints
  // inside that box). A stretched chip is far taller, not wider, so the cap only has to
  // keep the width a function of the digits.
  double maxWidth(int count) => 12.0 + 12 * (count > 99 ? 3 : '$count'.length);

  for (final dark in raftThemeMatrix([false, true], full: true)) {
    for (final (width, density) in [
      (280.0, RaftDensity.desktop),
      (360.0, RaftDensity.touch),
      (412.0, RaftDensity.touch),
    ]) {
      // One test per look and width: the scenarios below run in turn, so the
      // matrix stays inside the test budget and a failure names its scenario.
      final scenarios = <(String, Future<void> Function(WidgetTester))>[];
      void scenario(String name, Future<void> Function(WidgetTester) body) =>
          scenarios.add((name, body));

      Future<void> mount(
        WidgetTester tester,
        Widget child, {
        double textScale = 1,
      }) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: app!,
            ),
            home: Scaffold(
              body: RaftDensityScope(
                density: density,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: width, child: child),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      // The chip is the smallest decorated box around the count's text: the
      // Activity row builds its own, every other count is a shared widget.
      Rect countRect(WidgetTester tester, int count) {
        final text = count > 99 ? '99+' : '$count';
        final boxes =
            find
                .ancestor(
                  of: find.text(text),
                  matching: find.byWidgetPredicate(
                    (w) =>
                        (w is Container && w.decoration != null) ||
                        w is RaftRecipeBox,
                  ),
                )
                .evaluate()
                .map(
                  (e) => tester.getRect(find.byElementPredicate((x) => x == e)),
                )
                .toList()
              ..sort(
                (a, b) => (a.width * a.height).compareTo(b.width * b.height),
              );
        expect(boxes, isNotEmpty);
        return boxes.first;
      }

      void expectChip(
        WidgetTester tester,
        int count,
        String? label, {
        bool centered = true,
        double minHeight = 14,
      }) {
        final chip = countRect(tester, count);
        final reason = '$dark ${width}px $density count $count';
        expect(
          chip.height,
          inInclusiveRange(minHeight, 20),
          reason: '$reason height',
        );
        expect(chip.width, greaterThanOrEqualTo(chip.height), reason: reason);
        expect(chip.width, lessThanOrEqualTo(maxWidth(count)), reason: reason);
        if (centered) {
          expect(
            (chip.center.dy -
                    tester
                        .getRect(
                          find
                              .ancestor(
                                of: find.text(label!),
                                matching: find.byType(RaftCssLineBox),
                              )
                              .first,
                        )
                        .center
                        .dy)
                .abs(),
            lessThanOrEqualTo(1),
            reason: '$reason vertical centre',
          );
        }
      }

      for (final count in counts) {
        for (final (name, build) in <(String, Widget Function(int))>[
          (
            'Activity',
            (n) => RaftNavItem(
              role: RaftNavItemRole.activity,
              label: 'Activity',
              glyph: RaftGlyph.activity,
              unread: n,
              onTap: () {},
            ),
          ),
          (
            'channel',
            (n) => RaftNavItem(
              label: 'general',
              glyph: RaftGlyph.hash,
              conversationKind: RaftConversationNavKind.channel,
              unread: n,
              onTap: () {},
            ),
          ),
          (
            'direct message',
            (n) => RaftNavItem(
              label: 'Ada',
              glyph: RaftGlyph.user,
              conversationKind: RaftConversationNavKind.directMessage,
              unread: n,
              onTap: () {},
            ),
          ),
          (
            'generic row',
            (n) => RaftNavItem(
              label: 'Members',
              glyph: RaftGlyph.users,
              unread: n,
              onTap: () {},
            ),
          ),
        ]) {
          scenario(
            '$dark ${width}px $density $name unread $count keeps the chip size',
            (tester) async {
              await mount(tester, build(count));
              expectChip(
                tester,
                count,
                const {
                  'Activity': 'Activity',
                  'channel': 'general',
                  'direct message': 'Ada',
                  'generic row': 'Members',
                }[name],
              );
            },
          );
        }
      }

      for (final (name, row) in <(String, Widget)>[
        (
          'Activity',
          RaftNavItem(
            role: RaftNavItemRole.activity,
            label: 'Activity',
            glyph: RaftGlyph.activity,
            unread: 12,
            onTap: () {},
          ),
        ),
        (
          'channel',
          RaftNavItem(
            label: 'general',
            glyph: RaftGlyph.hash,
            conversationKind: RaftConversationNavKind.channel,
            unread: 12,
            onTap: () {},
          ),
        ),
      ]) {
        scenario(
          '$dark ${width}px $density $name chip grows with larger text without stretching',
          (tester) async {
            await mount(tester, row, textScale: 2);
            final chip = countRect(tester, 12);
            final text = tester.getRect(find.text('12'));
            // The chip wraps its (bounded) text: a few px of padding, not the
            // row height.
            expect(chip.height, lessThanOrEqualTo(text.height + 8));
            expect(chip.width, lessThanOrEqualTo(text.width + 20));
          },
        );
      }

      scenario(
        '$dark ${width}px $density mention-list badges keep their size in a tall row',
        (tester) async {
          // `Container(minHeight:, alignment:)` fills a Row's height, the same
          // stretch as the Activity chip.
          await mount(
            tester,
            const SizedBox(
              height: 60,
              child: Row(
                children: [
                  RaftActorTypeBadge(label: 'Agent'),
                  RaftArchivedBadge(label: 'archived'),
                ],
              ),
            ),
          );
          for (final type in [RaftActorTypeBadge, RaftArchivedBadge]) {
            final rect = tester.getRect(find.byType(type));
            expect(rect.height, inInclusiveRange(10, 28), reason: '$type');
            expect(rect.width, greaterThan(rect.height), reason: '$type');
            expect(rect.center.dy, closeTo(30, 1), reason: '$type');
          }
        },
      );

      scenario(
        '$dark ${width}px $density Saved count stays text beside the Activity chip',
        (tester) async {
          await mount(
            tester,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RaftNavItem(
                  role: RaftNavItemRole.activity,
                  label: 'Activity',
                  glyph: RaftGlyph.activity,
                  unread: 1,
                  onTap: () {},
                ),
                RaftNavItem(
                  role: RaftNavItemRole.saved,
                  label: 'Saved',
                  glyph: RaftGlyph.bookmark,
                  count: 5,
                  onTap: () {},
                ),
              ],
            ),
          );
          expectChip(tester, 1, 'Activity');
          final saved = tester.getRect(find.textContaining('5').first);
          expect(saved.height, lessThan(20));
          expect(
            (saved.center.dy - tester.getRect(find.text('Saved')).center.dy)
                .abs(),
            lessThanOrEqualTo(1),
          );
        },
      );

      scenario('$dark ${width}px $density rail count keeps the chip size', (
        tester,
      ) async {
        await mount(
          tester,
          SizedBox(
            width: 56,
            height: 400,
            child: RaftWorkspaceRail(
              destinations: const [
                RaftRailDestination(
                  id: 'chat',
                  label: 'Chat',
                  glyph: RaftGlyph.messageSquare,
                ),
                RaftRailDestination(
                  id: 'activity',
                  label: 'Activity',
                  glyph: RaftGlyph.activity,
                  unread: 12,
                ),
              ],
              selected: 'chat',
              onSelected: (_) {},
              workspaceName: 'Visual Server',
              onWorkspace: () {},
            ),
          ),
        );
        expectChip(tester, 12, null, centered: false, minHeight: 8);
      });

      scenario(
        '$dark ${width}px $density phone tab-bar count keeps the chip size',
        (tester) async {
          await mount(
            tester,
            RaftMobileNav(
              selectedId: 'home',
              onSelected: (_) {},
              viewportHeight: 800,
              bottomInset: 0,
              items: const [
                RaftMobileNavItem(
                  id: 'home',
                  label: 'Home',
                  glyph: RaftGlyph.home,
                  badgeCount: 12,
                ),
                RaftMobileNavItem(
                  id: 'tasks',
                  label: 'Tasks',
                  glyph: RaftGlyph.squareCheck,
                ),
              ],
            ),
          );
          expectChip(tester, 12, null, centered: false);
        },
      );

      testWidgets('$dark ${width}px $density count chips keep their size', (
        tester,
      ) async {
        for (final (name, body) in scenarios) {
          printOnFailure('scenario: $name');
          await body(tester);
        }
      });
    }
  }
}
