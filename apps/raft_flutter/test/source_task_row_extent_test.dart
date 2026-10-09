import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;

void main() {
  testWidgets(
    'Source task row measures fractional card without stretching it',
    (tester) async {
      await tester.runAsync(loadParityFonts);
      var opens = 0;
      final theme = raftTheme(RaftFamily.brutal);
      final tokens = theme.extension<RaftTokens>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: DefaultTextStyle(
                style: RaftTaskSectionRecipe(tokens).documentStyle,
                child: SizedBox(
                  width: 358,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SourceTaskRowExtent(
                        child: RaftTaskCard(
                          title: 'Align the tabbar capture crops between React and Android',
                          description: 'Both providers must wrap exactly the tabbar at width 390.',
                          channel: 'design',
                          number: '214',
                          status: 'todo',
                          statusOptions: raftTaskStatuses,
                          onStatus: (_) {},
                        ),
                      ),
                      const SizedBox(height: 10),
                      SourceTaskRowExtent(
                        child: RaftTaskCard(
                          title: 'Review the thread header strip baselines',
                          channel: 'design',
                          number: '210',
                          status: 'in_review',
                          statusOptions: raftTaskStatuses,
                          onStatus: (_) {},
                          onTap: () => opens++,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final cards = find.byType(RaftTaskCard);
      final rows = find.byType(SourceTaskRowExtent);
      // Actual Source DOM: the first card is 147.25px, tanstack rounds the
      // observed extent to 147px, then adds its 10px inter-row gap.
      expect(tester.getSize(cards.first).height, 147.25);
      expect(tester.getSize(rows.first).height, 147);
      expect(tester.getTopLeft(cards.last).dy, 157);
      await tester.tap(find.text('Review the thread header strip baselines'));
      expect(opens, 1);
      await tester.tap(find.text('In Review'));
      await tester.pumpAndSettle();
      expect(find.byType(RaftInlineBadgeMenu), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
