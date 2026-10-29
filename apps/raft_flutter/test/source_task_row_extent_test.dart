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
      final theme = raftTheme();
      final tokens = theme.extension<RaftTokens>()!;
      Future<void> pump(double? constrainedHeight) async {
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
                          // Measure the current font layout first, then add a
                          // quarter pixel to its rounded natural extent.
                          child: SizedBox(
                            height: constrainedHeight,
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
      }

      await pump(null);
      final cards = find.byType(RaftTaskCard);
      final roundedNatural = tester.getSize(cards.first).height.ceilToDouble();
      final fractionalHeight = roundedNatural + .25;
      await pump(fractionalHeight);
      final rows = find.byType(SourceTaskRowExtent);
      // Tanstack rounds the measured quarter-pixel extent down to its
      // whole-pixel floor, then adds the unchanged 10px inter-row gap.
      expect(tester.getSize(cards.first).height, fractionalHeight);
      expect(tester.getSize(rows.first).height, roundedNatural);
      expect(tester.getTopLeft(cards.last).dy, roundedNatural + 10);
      await tester.tap(find.text('Review the thread header strip baselines'));
      expect(opens, 1);
      await tester.tap(find.text('In Review'));
      await tester.pumpAndSettle();
      expect(find.byType(RaftInlineBadgeMenu), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
