import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'N24 220ms signal $family/$dark first click is immediate; keyboard and nested actions stay distinct',
      (tester) async {
        final activation = <int>[];
        var legacy = 0, nested = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: RaftConversationCard(
                    semanticLabel: 'Open conversation',
                    onOpen: () => legacy++,
                    onActivate: activation.add,
                    actions: RaftIconButton(
                      glyph: RaftGlyph.check,
                      tooltip: 'Done',
                      onPressed: () => nested++,
                    ),
                    child: const SizedBox(
                      height: 64,
                      child: Text('A real activity row'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final point =
            tester.getTopLeft(find.byType(RaftConversationCard)) +
            const Offset(40, 40);
        await tester.tapAt(point);
        expect(activation, [1]); // No framework double-tap wait.
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(point);
        expect(activation, [1, 2]);
        expect(legacy, 0);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tapAt(point);
        expect(activation, [1, 2, 1]);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // Focus the row's actual InkWell rather than invoking its callback.
        final ink = tester.element(
          find
              .descendant(
                of: find.byType(RaftConversationCard),
                matching: find.byType(InkWell),
              )
              .first,
        );
        Focus.of(ink).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(activation, [1, 2, 1, 1]);
        final count = activation.length;
        await tester.tap(find.byTooltip('Done'));
        expect(nested, 1);
        expect(activation, hasLength(count));
        expect(
          tester.getSemantics(find.byType(RaftConversationCard)).label,
          contains('Open conversation'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'card consumers without activation detail retain immediate onOpen',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: RaftConversationCard(
              onOpen: () => opened++,
              child: const SizedBox(height: 64, child: Text('Saved item')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Saved item'));
      expect(opened, 1);
    },
  );
  testWidgets('adaptive reparent does not dispatch a conversation activation', (
    tester,
  ) async {
    final key = GlobalKey();
    final details = <int>[];
    Widget host(bool flipped) => MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: Row(
          children: [
            if (flipped) const SizedBox(width: 40),
            SizedBox(
              width: 360,
              child: RaftConversationCard(
                key: key,
                onOpen: () {},
                onActivate: details.add,
                child: const SizedBox(height: 64, child: Text('Retained card')),
              ),
            ),
            if (!flipped) const SizedBox(width: 40),
          ],
        ),
      ),
    );
    await tester.pumpWidget(host(false));
    await tester.pumpWidget(host(true));
    expect(details, isEmpty);
    await tester.tap(find.text('Retained card'));
    expect(details, [1]);
  });
}
