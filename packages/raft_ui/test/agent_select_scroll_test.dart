import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final (size, keyboard) in [
      (const Size(1280, 720), 0.0),
      (const Size(390, 844), 0.0),
      (const Size(390, 844), 300.0),
    ]) {
      for (final mouse in [false, true]) {
        testWidgets(
          '${dark ? 'dark' : 'light'} $size IME=$keyboard mouse=$mouse reaches the last model',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
            addTearDown(tester.view.reset);
            var selected = 0, calls = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => Column(
                      children: [
                        const Spacer(),
                        SizedBox(
                          width: 280,
                          child: RaftAgentSelect<int>(
                            value: selected,
                            options: [
                              for (var i = 0; i < 40; i++)
                                RaftAgentSelectOption(i, 'Model $i'),
                            ],
                            onChanged: (value) => setState(() {
                              selected = value;
                              calls++;
                            }),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byType(RaftAgentSelect<int>));
            await tester.pumpAndSettle();
            final popup = find.byKey(const ValueKey('raft-select-popup'));
            final scrollable = find.descendant(
              of: popup,
              matching: find.byType(Scrollable),
            );
            expect(
              scrollable,
              findsOneWidget,
              reason: 'The model menu must own a scroll viewport.',
            );
            final viewport = tester.getRect(scrollable);
            expect(viewport.top, greaterThanOrEqualTo(0));
            expect(viewport.bottom, lessThanOrEqualTo(size.height - keyboard));
            expect(viewport.left, greaterThanOrEqualTo(0));
            expect(viewport.right, lessThanOrEqualTo(size.width));
            if (mouse) {
              await tester.sendEventToBinding(
                PointerScrollEvent(
                  position: viewport.center,
                  scrollDelta: const Offset(0, 360),
                  kind: PointerDeviceKind.mouse,
                ),
              );
              await tester.pumpAndSettle();
              expect(
                tester.state<ScrollableState>(scrollable).position.pixels,
                greaterThan(0),
              );
            }
            final last = find.descendant(
              of: popup,
              matching: find.text('Model 39'),
            );
            await tester.scrollUntilVisible(
              last,
              200,
              scrollable: scrollable,
              maxScrolls: 30,
            );
            await tester.tap(last);
            await tester.pumpAndSettle();
            expect(selected, 39);
            expect(calls, 1);
            expect(popup, findsNothing);
            expect(find.text('Model 39'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
