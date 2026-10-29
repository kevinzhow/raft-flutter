import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/theme.dart';

Widget publicRow({bool coarse = false, bool popupOpen = true}) =>
    RaftMessageRow(
      key: const Key('owned-row'),
      author: 'Public',
      timestamp: '14:30',
      coarsePointer: coarse,
      popupOpen: popupOpen,
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
  testWidgets(
    'scroll retires portal; fresh opening uses current viewport anchor',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var popupOpen = true;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              theme: raftTheme(),
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
                          publicRow(popupOpen: popupOpen),
                          const SizedBox(height: 1000),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pump();
      final before = tester.getRect(find.byKey(const Key('owned-action')));
      scroll.jumpTo(40);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('owned-action')), findsNothing);
      Future<void> reopen() async {
        update(() => popupOpen = false);
        await tester.pump();
        update(() => popupOpen = true);
        await tester.pump();
        await tester.pump();
      }

      await reopen();
      final after = tester.getRect(find.byKey(const Key('owned-action')));
      expect(after.top, closeTo(before.top - 40, 1e-6));
      scroll.jumpTo(220);
      await tester.pump();
      await tester.pump();
      await reopen();
      expect(find.byKey(const Key('owned-action')), findsNothing);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump();
      await reopen();
      expect(find.byKey(const Key('owned-action')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(find.byKey(const Key('owned-action')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden route, coarse pointer and removed row cannot retain an overlay',
    (tester) async {
      var ticker = true, coarse = false, mounted = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
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
