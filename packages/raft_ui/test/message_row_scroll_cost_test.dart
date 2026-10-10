import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'scroll does not rebuild idle or active message rows $family/$dark',
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
            theme: raftTheme(family, dark: dark),
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
        final before = t.getRect(find.byKey(const ValueKey('action-2')));
        rebuiltRows = 0;
        scroll.jumpTo(30);
        await t.pump();
        await t.pump();
        expect(
          rebuiltRows,
          0,
          reason: 'The active overlay refreshes without rebuilding the owning message.',
        );
        expect(
          t.getRect(find.byKey(const ValueKey('action-2'))).top,
          closeTo(before.top - 10, .01),
        );
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
