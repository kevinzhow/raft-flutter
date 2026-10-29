import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    testWidgets(
      '${dark ? 'dark' : 'light'} short clock retains full date and semantics',
      (t) async {
        final semantics = t.ensureSemantics();
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(2, 300));
        addTearDown(mouse.removePointer);
        try {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: const Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RaftTooltipProvider(
                    delay: Duration(milliseconds: 600),
                    child: RaftMessageTile(
                      author: 'Alice',
                      timestamp: '10/15 16:48',
                      continuationTimestamp: '16:48',
                      timestampTooltip: 'Oct 15, 2026, 16:48',
                      content: 'Public continuation body',
                      continuation: true,
                      compactSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
          );
          final row = find.byType(RaftMessageRow);
          final label = t.getSemantics(row).label;
          expect(label, 'Alice, 10/15 16:48\nPublic continuation body');
          expect(find.text('10/15 16:48'), findsNothing);
          expect(find.text('Oct 15, 2026, 16:48'), findsNothing);
          final body = find.text('Public continuation body');
          final before = t.getRect(body);
          await mouse.moveTo(t.getCenter(body));
          await t.pump(const Duration(milliseconds: 800));
          expect(find.text('Oct 15, 2026, 16:48'), findsNothing);
          await mouse.moveTo(t.getCenter(find.text('16:48')));
          await t.pump(const Duration(milliseconds: 601));
          await t.pump(const Duration(milliseconds: 200));
          expect(find.text('Oct 15, 2026, 16:48'), findsOneWidget);
          expect(t.getRect(body), before);
          expect(t.getSemantics(row).label, label);
          await mouse.moveTo(const Offset(2, 300));
          await t.pumpAndSettle();
          expect(find.text('Oct 15, 2026, 16:48'), findsNothing);
          expect(t.getRect(body), before);
          expect(t.takeException(), isNull);
        } finally {
          semantics.dispose();
          await t.pumpWidget(const SizedBox());
          await t.pump();
        }
      },
    );
  }
}
