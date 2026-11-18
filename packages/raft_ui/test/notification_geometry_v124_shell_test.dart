import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'notification header and tiles follow the opened center ($dark)',
      (tester) async {
        const glyph = RaftGlyph.monitor;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: const Scaffold(
              body: Center(
                child: RaftNotificationCenter(
                  entries: [
                    RaftNotificationEntry(
                      id: 'computer',
                      kind: RaftNotificationKind.warning,
                      title: 'Computer unavailable',
                      glyph: glyph,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final header = find.byKey(const Key('notification-center-header'));
        final row = find.byKey(const ValueKey('notification-entry-computer'));
        final icon = find.descendant(of: row, matching: find.byType(RaftIcon));
        final container = find
            .ancestor(of: icon, matching: find.byType(Container))
            .first;
        final tokens = RaftTokens.of(tester.element(header));
        expect(tester.getSize(header).height, 52);
        expect(tester.getSize(container), const Size.square(35));
        expect(tester.getSize(icon), const Size.square(18));
        final decoration =
            tester.widget<Container>(header).decoration! as BoxDecoration;
        expect(
          decoration.border,
          Border(bottom: BorderSide(color: tokens.ui.lineSeam)),
        );
        expect(
          tester.getTopLeft(find.text('Computer unavailable')).dx -
              tester.getTopRight(container).dx,
          12,
        );
        expect(
          tester.getTopLeft(icon).dy,
          greaterThan(tester.getBottomLeft(header).dy),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
