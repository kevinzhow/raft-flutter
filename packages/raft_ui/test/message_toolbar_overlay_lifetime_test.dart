import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/theme.dart';

Widget publicRow({bool coarse = false}) => RaftMessageRow(
  key: const Key('owned-row'),
  author: 'Public',
  timestamp: '14:30',
  coarsePointer: coarse,
  popupOpen: true,
  content: const Text('Public body'),
  toolbar: RaftMessageToolbar(
    children: [
      RaftMessageToolbarAction(
        key: const Key('owned-action'),
        label: 'Owned action',
        icon: const SizedBox(),
        onPressed: () {},
      ),
    ],
  ),
);

void main() {
  testWidgets('portal follows scrolling and vanishes beyond owning viewport', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              height: 180,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    publicRow(),
                    const SizedBox(height: 1000),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final before = tester.getRect(find.byKey(const Key('owned-action')));
    scroll.jumpTo(40);
    await tester.pump();
    await tester.pump();
    final after = tester.getRect(find.byKey(const Key('owned-action')));
    expect(after.top, before.top - 40);
    scroll.jumpTo(220);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('owned-action')), findsNothing);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('owned-action')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(find.byKey(const Key('owned-action')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden route, coarse pointer and removed row cannot retain an overlay',
    (tester) async {
      var ticker = true, coarse = false, mounted = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: TickerMode(
                  enabled: ticker,
                  child: mounted ? publicRow(coarse: coarse) : const SizedBox(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('owned-action')), findsOneWidget);
      update(() => ticker = false);
      await tester.pump();
      expect(find.byKey(const Key('owned-action')), findsNothing);
      update(() {
        ticker = true;
        coarse = true;
      });
      await tester.pump();
      expect(find.byKey(const Key('owned-action')), findsNothing);
      update(() => coarse = false);
      await tester.pump();
      expect(find.byKey(const Key('owned-action')), findsOneWidget);
      update(() => mounted = false);
      await tester.pump();
      expect(find.byKey(const Key('owned-action')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
