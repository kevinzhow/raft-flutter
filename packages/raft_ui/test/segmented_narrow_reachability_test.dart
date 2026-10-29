import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final direction in TextDirection.values) {
      for (final input in ['touch', 'mouse', 'keyboard']) {
        testWidgets(
          'narrow one-row choices remain reachable dark=$dark dir=$direction input=$input',
          (t) async {
            addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
            var value = 'small';
            final changed = <String>[];
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                home: Directionality(
                  textDirection: direction,
                  child: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 150,
                        child: StatefulBuilder(
                          builder: (context, update) =>
                              RaftSegmentedControl<String>(
                                value: value,
                                onChanged: (next) => update(() {
                                  value = next;
                                  changed.add(next);
                                }),
                                items: const [
                                  RaftSegmentedOption(
                                    value: 'small',
                                    label: 'Small',
                                  ),
                                  RaftSegmentedOption(
                                    value: 'medium',
                                    label: 'Medium',
                                  ),
                                  RaftSegmentedOption(
                                    value: 'large',
                                    label: 'Large',
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
            await t.pumpAndSettle();
            final viewport = find.descendant(
              of: find.byType(RaftSegmentedTrack),
              matching: find.byType(SingleChildScrollView),
            );
            expect(viewport, findsOneWidget);
            final frame = t.getRect(viewport);
            expect(frame.width, 150);
            expect(
              frame.contains(t.getRect(find.text('Large')).center),
              isFalse,
            );
            if (input == 'keyboard') {
              await t.sendKeyEvent(LogicalKeyboardKey.tab);
              await t.pumpAndSettle();
              await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
              await t.pumpAndSettle();
              expect(value, 'medium');
              await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
            } else {
              await t.drag(
                viewport,
                Offset(direction == TextDirection.ltr ? -250 : 250, 0),
                kind: input == 'mouse'
                    ? PointerDeviceKind.mouse
                    : PointerDeviceKind.touch,
              );
            }
            await t.pumpAndSettle();
            final target = t.getRect(find.text('Large'));
            expect(
              frame.contains(target.center),
              isTrue,
              reason: 'the visible hit target must be inside its viewport',
            );
            final beforeTap = changed.length;
            await t.tap(find.text('Large'));
            await t.pumpAndSettle();
            expect(value, 'large');
            expect(
              changed.length,
              beforeTap + 1,
              reason: 'an actual visible pointer tap invokes the callback',
            );
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  }
}
