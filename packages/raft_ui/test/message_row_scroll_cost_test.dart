import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'scroll retires only the hovered row and leaves idle rows untouched ${dark ? 'dark' : 'light'}',
      (t) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var rebuiltRows = 0;
        final previous = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (element, built) {
          previous?.call(element, built);
          if (element.widget is RaftMessageRow) rebuiltRows++;
        };
        addTearDown(() => debugOnRebuildDirtyWidget = previous);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SizedBox(
                height: 500,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      for (var i = 0; i < 30; i++)
                        RaftMessageRow(
                          key: ValueKey('row-$i'),
                          author: 'Alice $i',
                          timestamp: '12:00',
                          content: Text('Message $i'),
                          toolbar: RaftMessageToolbar(
                            children: [
                              RaftMessageToolbarAction(
                                key: ValueKey('action-$i'),
                                label: 'Save $i',
                                icon: const SizedBox(),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        rebuiltRows = 0;
        for (var i = 1; i <= 10; i++) {
          scroll.jumpTo(i * 2);
          await t.pump();
          await t.pump();
        }
        expect(
          rebuiltRows,
          0,
          reason: 'Viewport movement must not rebuild every message.',
        );
        expect(
          find.byType(RaftMessageToolbar),
          findsNothing,
          reason: 'Idle rows own no toolbar overlay subtree.',
        );
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(790, 590));
        await mouse.moveTo(t.getCenter(find.text('Message 2')));
        await t.pump();
        await t.pump();
        expect(find.byKey(const ValueKey('action-2')), findsOneWidget);
        final before = t.getRect(find.text('Message 2'));
        rebuiltRows = 0;
        scroll.jumpTo(30);
        await t.pump();
        await t.pump();
        expect(
          rebuiltRows,
          1,
          reason: 'Only the previously hovered row retires its floating strip.',
        );
        expect(find.byType(RaftMessageToolbar), findsNothing);
        expect(
          t.getRect(find.text('Message 2')).top,
          closeTo(before.top - 10, .01),
        );
        rebuiltRows = 0;
        scroll.jumpTo(40);
        await t.pump();
        await t.pump();
        expect(rebuiltRows, 0);
        expect(
          find.byType(RaftMessageToolbar),
          findsNothing,
          reason: 'Content moving under a stationary pointer cannot reopen a toolbar.',
        );
        await mouse.moveTo(
          t.getCenter(find.text('Message 2')) + const Offset(1, 0),
        );
        await t.pump();
        await t.pump();
        expect(find.byKey(const ValueKey('action-2')), findsOneWidget);
        await mouse.removePointer();
        await t.pump();
        await t.pump();
        expect(find.byType(RaftMessageToolbar), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      },
    );
  }
}
