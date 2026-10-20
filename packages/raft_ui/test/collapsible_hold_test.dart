import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Widget frame({
    required bool initiallyExpanded,
    required double height,
    void Function(bool, BuildContext)? onExpandedChanged,
    Key? key,
    Widget? child,
  }) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(
      body: SingleChildScrollView(
        child: RaftCollapsible(
          key: key,
          enabled: true,
          initiallyExpanded: initiallyExpanded,
          onExpandedChanged: onExpandedChanged,
          child:
              child ??
              SizedBox(
                height: height,
                width: 400,
                child: const Text('Reading line'),
              ),
        ),
      ),
    ),
  );

  testWidgets(
    'an unread message is fully open on the first frame and does not jump',
    (tester) async {
      await tester.pumpWidget(frame(initiallyExpanded: true, height: 700));
      final top = tester.getTopLeft(find.text('Reading line'));
      expect(tester.getSize(find.byType(ClipRect).last).height, 700);
      await tester.pump();
      expect(tester.getTopLeft(find.text('Reading line')), top);
      expect(tester.getSize(find.byType(ClipRect).last).height, 700);
      await tester.pumpAndSettle();
      expect(find.text('Collapse'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
      expect(tester.getTopLeft(find.text('Reading line')), top);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a read message starts collapsed', (tester) async {
    await tester.pumpWidget(frame(initiallyExpanded: false, height: 700));
    await tester.pumpAndSettle();
    expect(find.text('Show more'), findsOneWidget);
    expect(tester.getSize(find.byType(ClipRect).last).height, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'becoming read while it is open does not collapse or move the reading line',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        frame(key: key, initiallyExpanded: true, height: 700),
      );
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(find.text('Reading line'));
      expect(tester.getSize(find.byType(ClipRect).last).height, 700);

      await tester.pumpWidget(
        frame(key: key, initiallyExpanded: false, height: 700),
      );
      await tester.pump();
      expect(tester.getTopLeft(find.text('Reading line')), top);
      expect(tester.getSize(find.byType(ClipRect).last).height, 700);
      expect(find.text('Collapse'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a manual collapse stays collapsed when the parent still asks to open',
    (tester) async {
      final key = GlobalKey();
      final seen = <bool>[];
      await tester.pumpWidget(
        frame(
          key: key,
          initiallyExpanded: true,
          height: 700,
          onExpandedChanged: (open, _) => seen.add(open),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Collapse'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();
      expect(seen, [false]);
      expect(find.text('Show more'), findsOneWidget);
      expect(tester.getSize(find.byType(ClipRect).last).height, 320);

      await tester.pumpWidget(
        frame(
          key: key,
          initiallyExpanded: true,
          height: 700,
          onExpandedChanged: (open, _) => seen.add(open),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen, [false]);
      expect(find.text('Show more'), findsOneWidget);
      expect(tester.getSize(find.byType(ClipRect).last).height, 320);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expanding a long message does not move the reading line', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        initiallyExpanded: false,
        height: 700,
        child: const SizedBox(
          height: 700,
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reading line'),
              SizedBox(height: 360),
              Text('Below the fold'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.text('Reading line'));
    expect(find.text('Below the fold').hitTestable(), findsNothing);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Reading line')), top);
    expect(tester.getSize(find.byType(ClipRect).last).height, 700);
    expect(find.text('Below the fold').hitTestable(), findsOneWidget);
    await tester.pump();
    expect(tester.getTopLeft(find.text('Reading line')), top);
    expect(tester.takeException(), isNull);
  });
}
