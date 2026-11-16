import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/covered_pane.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/theme.dart';

const bodyKey = Key('cover-body');
const actionKey = Key('cover-action');

Widget host(bool covered, {VoidCallback? onPressed}) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 900,
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: RaftCoveredPane(
            covered: covered,
            child: RaftMessageRow(
              author: 'Public Agent',
              timestamp: '14:30',
              content: const Text('Public body', key: bodyKey),
              toolbar: RaftMessageToolbar(
                children: [
                  RaftMessageToolbarAction(
                    key: actionKey,
                    label: 'Save',
                    icon: const SizedBox(),
                    onPressed: onPressed ?? () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a covered pane puts the strip away under a resting pointer; '
      'uncovering brings it back', (tester) async {
    await tester.pumpWidget(host(false));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(2, 400));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(bodyKey)));
    await tester.pump();
    final action = find.byKey(actionKey);
    await mouse.moveTo(tester.getCenter(action));
    await tester.pump();
    expect(action.hitTestable(), findsOneWidget);
    await tester.pumpWidget(host(true));
    await tester.pump();
    expect(find.byType(RaftMessageToolbar), findsNothing);
    // Keyboard focus does not reopen it while covered either.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byType(RaftMessageToolbar), findsNothing);
    await tester.pumpWidget(host(false));
    await tester.pump();
    await tester.pump();
    expect(find.byType(RaftMessageToolbar), findsOneWidget);
  });

  testWidgets('focus left by a click does not hold the strip open; keyboard '
      'focus does', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(host(false, onPressed: () => pressed++));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(2, 400));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(bodyKey)));
    await tester.pump();
    final action = find.byKey(actionKey);
    await mouse.moveTo(tester.getCenter(action));
    await tester.pump();
    await mouse.down(tester.getCenter(action));
    await mouse.up();
    await tester.pump();
    expect(pressed, 1);
    final focus = FocusManager.instance.primaryFocus;
    expect(focus?.context, isNotNull);
    expect(
      find.ancestor(
        of: find.byElementPredicate((e) => identical(e, focus!.context)),
        matching: find.byType(RaftMessageRow),
      ),
      findsOneWidget,
      reason: 'the click left focus inside the row',
    );
    await mouse.moveTo(const Offset(2, 400));
    await tester.pump();
    expect(find.byType(RaftMessageToolbar), findsNothing);
    // A key press makes that same focus visible: the strip shows for it.
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RaftMessageToolbar), findsOneWidget);
  });
}
