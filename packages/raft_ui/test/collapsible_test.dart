import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'rendered height collapse expands, respects disabled preference and remeasures',
    (tester) async {
      Widget frame({bool enabled = true, double height = 700}) => MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RaftCollapsible(
              key: const Key('content'),
              enabled: enabled,
              child: SizedBox(
                height: height,
                width: 400,
                child: const Text('Long content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(frame());
      await tester.pumpAndSettle();
      expect(find.text('Show more'), findsOneWidget);
      expect(tester.getSize(find.byType(ClipRect).last).height, 320);
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Collapse'), findsOneWidget);
      expect(tester.getSize(find.byType(ClipRect).last).height, 700);
      await tester.pumpWidget(frame(enabled: false));
      await tester.pumpAndSettle();
      expect(find.text('Collapse'), findsNothing);
      expect(tester.getSize(find.byType(ClipRect).last).height, 700);
      await tester.pumpWidget(frame(height: 100));
      await tester.pumpAndSettle();
      expect(find.text('Collapse'), findsNothing);
      expect(tester.getSize(find.byType(ClipRect).last).height, 100);
    },
  );
  testWidgets('keyboard focus below the clipped edge expands actual content', (
    tester,
  ) async {
    final focus = FocusNode();
    final visibleFocus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RaftCollapsible(
              child: Column(
                children: [
                  TextButton(
                    focusNode: visibleFocus,
                    onPressed: () {},
                    child: const Text('Visible action'),
                  ),
                  const SizedBox(height: 400),
                  TextButton(
                    focusNode: focus,
                    onPressed: () {},
                    child: const Text('Hidden action'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hidden action').hitTestable(), findsNothing);
    visibleFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('Show more'), findsOneWidget);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('Collapse'), findsOneWidget);
    expect(find.text('Hidden action').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
    visibleFocus.dispose();
  });
}
