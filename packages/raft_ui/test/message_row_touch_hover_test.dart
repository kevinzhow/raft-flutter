import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const rowKey = ValueKey('touch-row');
const actionKey = ValueKey('touch-row-action');

BoxDecoration rowDecoration(WidgetTester tester) => tester
    .widgetList<Container>(
      find.descendant(of: find.byKey(rowKey), matching: find.byType(Container)),
    )
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((decoration) => decoration.border != null);

void expectIdle(WidgetTester tester) {
  final decoration = rowDecoration(tester);
  expect(decoration.color, Colors.transparent);
  expect(decoration.border, isA<Border>());
  expect((decoration.border! as Border).top.color, Colors.transparent);
  expect(find.byKey(actionKey), findsNothing);
}

Widget messageRow({
  required bool coarse,
  bool popupOpen = false,
  VoidCallback? onActions,
}) => RaftMessageRow(
  key: rowKey,
  coarsePointer: coarse,
  popupOpen: popupOpen,
  author: 'Alice',
  timestamp: '12:00',
  content: const Text('A message to scroll past'),
  onActions: onActions,
  toolbar: RaftMessageToolbar(
    children: [
      RaftMessageToolbarAction(
        key: actionKey,
        label: 'Reply',
        icon: const SizedBox(),
        onPressed: () {},
      ),
    ],
  ),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'touch rows ignore compatibility hover before and after a swipe ${dark ? 'dark' : 'light'}',
      (tester) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var actions = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 400,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      const SizedBox(height: 120),
                      messageRow(coarse: true, onActions: () => actions++),
                      const SizedBox(height: 1200),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectIdle(tester);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(700, 550));
        await mouse.moveTo(tester.getCenter(find.byKey(rowKey)));
        await tester.pump();
        expectIdle(tester);
        await tester.dragFrom(
          tester.getCenter(find.byKey(rowKey)),
          const Offset(0, -80),
          kind: PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        expectIdle(tester);
        await mouse.moveTo(tester.getCenter(find.byKey(rowKey)));
        await tester.pump();
        expectIdle(tester);
        expect(actions, 0, reason: 'A swipe must not open the message menu.');
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'switching to touch retires hover but keeps explicit menus ${dark ? 'dark' : 'light'}',
      (tester) async {
        var coarse = false, popupOpen = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 390,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return messageRow(
                        coarse: coarse,
                        popupOpen: popupOpen,
                        onActions: () => update(() => popupOpen = true),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(700, 550));
        await mouse.moveTo(tester.getCenter(find.byKey(rowKey)));
        await tester.pump();
        await tester.pump();
        expect(rowDecoration(tester).color, isNot(Colors.transparent));
        expect(find.byKey(actionKey), findsOneWidget);
        update(() => coarse = true);
        await tester.pump();
        await tester.pump();
        expectIdle(tester);
        update(() => coarse = false);
        await tester.pump();
        expectIdle(tester);
        await mouse.moveBy(const Offset(1, 0));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(actionKey), findsOneWidget);
        await mouse.removePointer();
        update(() => coarse = true);
        await tester.pump();
        await tester.longPress(find.byKey(rowKey));
        await tester.pump();
        expect(popupOpen, isTrue);
        expect(rowDecoration(tester).color, isNot(Colors.transparent));
        expect(find.byKey(actionKey), findsNothing);
        update(() => popupOpen = false);
        await tester.pump();
        expectIdle(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
