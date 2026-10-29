import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    for (final withTooltip in [false, true]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} tooltip $withTooltip keeps its continuation gutter height',
        (tester) async {
          try {
            for (final scale in [1.0, 2.0, 3.1]) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: raftTheme(dark: dark),
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 300,
                          child: RaftMessageRow(
                            author: 'Public author',
                            timestamp: withTooltip ? 'Oct 16, 14:30' : '14:30',
                            continuationTimestamp: '14:30',
                            timestampTooltip: withTooltip
                                ? 'Oct 16, 2026, 14:30'
                                : null,
                            continuation: true,
                            content: const Text('Public message body'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              final clock = find.text('14:30');
              final anchor = tester.getRect(
                find.ancestor(of: clock, matching: find.byType(SizedBox)).first,
              );
              final paint = tester.getRect(clock);
              expect(
                anchor.height,
                (4 + 10 * scale).clamp(14, double.infinity),
              );
              expect(paint.top, greaterThanOrEqualTo(anchor.top + 4 - .01));
              expect(paint.bottom, lessThanOrEqualTo(anchor.bottom + .01));
              expect(paint.left, greaterThanOrEqualTo(anchor.left - .01));
              expect(paint.right, lessThanOrEqualTo(anchor.right + .01));
              expect(tester.takeException(), isNull);
            }
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          }
        },
      );
    }
  }
}
