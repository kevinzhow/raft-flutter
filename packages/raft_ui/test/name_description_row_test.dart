import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web v1.21.12 Sidebar.tsx: the row name is `min-w-0 truncate` and the
// description `min-w-0 flex-1 truncate`. The name keeps its natural width and
// only gives way when the line is full; v1.21.2 capped it at 70%.
void main() {
  Future<void> mount(
    WidgetTester tester, {
    required String label,
    String? description = 'Announcements and community news',
    Widget? tag,
    double width = 240,
    RaftFamily family = RaftFamily.elegant,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(family),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: RaftNavItem(
                key: const ValueKey('row'),
                label: label,
                glyph: RaftGlyph.hash,
                conversationKind: RaftConversationNavKind.channel,
                description: description,
                tag: tag,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder nameFinder(String label) => find.text(label);
  Finder descriptionFinder(String text) => find.text(text);

  for (final family in [RaftFamily.elegant, RaftFamily.brutal]) {
    group('$family', () {
      testWidgets(
        'a short name keeps its natural width, the description gets the rest',
        (tester) async {
          await mount(tester, label: 'ops', family: family);
          final name = tester.getRect(nameFinder('ops'));
          final description = tester.getRect(
            descriptionFinder('Announcements and community news'),
          );
          // `gap-1` between the two, and the description fills to the line end.
          expect(description.left - name.right, closeTo(4, .6));
          final row = tester.getRect(find.byKey(const ValueKey('row')));
          expect(row.right - description.right, lessThan(20));
          expect(name.width, lessThan(60));
        },
      );

      testWidgets('a long name is no longer capped at 70% of the line', (
        tester,
      ) async {
        const long = 'platform-engineering-announcements';
        await mount(tester, label: long, family: family);
        final row = tester.getRect(find.byKey(const ValueKey('row')));
        final name = tester.getRect(nameFinder(long));
        final line = row.width;
        // It takes the line (the old 70% cap would have stopped at 168).
        expect(name.width, greaterThan(line * .7));
        expect(row.right - name.right, lessThan(48));
        // The description gave way instead (nothing of it is left).
        final description = descriptionFinder(
          'Announcements and community news',
        );
        if (description.evaluate().isNotEmpty) {
          expect(tester.getRect(description).width, lessThan(8));
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('name and description never overflow the line', (
        tester,
      ) async {
        for (final width in [120.0, 180.0, 240.0, 300.0, 420.0]) {
          for (final label in ['a', 'general', 'a-rather-long-channel-name']) {
            await mount(tester, label: label, width: width, family: family);
            final row = tester.getRect(find.byKey(const ValueKey('row')));
            final name = tester.getRect(nameFinder(label));
            expect(name.right, lessThanOrEqualTo(row.right + .01));
            final d = descriptionFinder('Announcements and community news');
            if (d.evaluate().isNotEmpty) {
              expect(
                tester.getRect(d).right,
                lessThanOrEqualTo(row.right + .01),
                reason: '$label @ $width',
              );
              expect(tester.getRect(d).left, greaterThanOrEqualTo(name.right));
            }
            expect(tester.takeException(), isNull, reason: '$label @ $width');
          }
        }
      });

      testWidgets('a tag sits between the name and the description, centred', (
        tester,
      ) async {
        await mount(
          tester,
          label: 'Wenyi',
          description: 'Design lead',
          tag: const RaftSidebarTag('Guest'),
          family: family,
        );
        final name = tester.getRect(nameFinder('Wenyi'));
        final tag = tester.getRect(find.byType(RaftSidebarTag));
        final description = tester.getRect(descriptionFinder('Design lead'));
        expect(tag.left - name.right, closeTo(4, .6));
        expect(description.left - tag.right, closeTo(4, .6));
        expect(
          (tag.center.dy - name.center.dy).abs(),
          lessThan(4),
          reason: 'self-center',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('without a description the row is unchanged', (tester) async {
        await mount(
          tester,
          label: 'general',
          description: null,
          family: family,
        );
        expect(nameFinder('general'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets(
    'baseline alignment keeps the smaller description on the name line',
    (tester) async {
      await mount(tester, label: 'ops');
      final name = tester.getRect(nameFinder('ops'));
      final description = tester.getRect(
        descriptionFinder('Announcements and community news'),
      );
      // A 20px name line and a 16px description line share a baseline: the
      // smaller text sits lower in its box, not centred and not on the top edge.
      expect(description.height, lessThan(name.height));
      expect(description.top, greaterThan(name.top));
      expect((name.bottom - description.bottom).abs(), lessThan(4));
    },
  );
}
