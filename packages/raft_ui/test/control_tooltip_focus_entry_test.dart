import 'package:flutter/gestures.dart';
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
    for (final pointerKind in [
      PointerDeviceKind.mouse,
      PointerDeviceKind.touch,
    ]) {
      testWidgets(
        'Tooltip requires genuine keyboard focus entry $family/$dark/$pointerKind',
        (tester) async {
          final opener = FocusNode();
          final before = FocusNode();
          final focusEvents = <bool>[];
          opener.addListener(() => focusEvents.add(opener.hasFocus));
          var presses = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: RaftTooltipProvider(
                  delay: const Duration(milliseconds: 600),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RaftControl(
                          focusNode: before,
                          onPressed: () {},
                          child: const Text('Before'),
                        ),
                        RaftControl(
                          key: const Key('opener'),
                          focusNode: opener,
                          tooltip: 'Add reaction',
                          onPressed: () => presses++,
                          child: const Text('Plus'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          final pointer = await tester.startGesture(
            tester.getCenter(find.byKey(const Key('opener'))),
            kind: pointerKind,
          );
          await pointer.up();
          await tester.pumpAndSettle();
          expect(opener.hasFocus, true);
          expect(focusEvents, [true]);
          expect(presses, 1);
          expect(
            find.byKey(const ValueKey('raft-tooltip-surface')),
            findsNothing,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 800));
          // Escape changes outline modality, but never produces another focus entry.
          expect(opener.hasFocus, true);
          expect(focusEvents, [true]);
          expect(
            find.byKey(const ValueKey('raft-tooltip-surface')),
            findsNothing,
          );

          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          expect(before.hasFocus, true);
          expect(focusEvents, [true, false]);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.pump();
          expect(opener.hasFocus, true);
          expect(focusEvents, [true, false, true]);
          expect(
            find.byKey(const ValueKey('raft-tooltip-surface')),
            findsOneWidget,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(opener.hasFocus, true);
          expect(
            find.byKey(const ValueKey('raft-tooltip-surface')),
            findsNothing,
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          opener.dispose();
          before.dispose();
        },
      );
    }
  }
}
