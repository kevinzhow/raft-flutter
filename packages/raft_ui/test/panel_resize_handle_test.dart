import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget frame(
  RaftFamily family, {
  bool hairline = false,
  double value = 240,
  bool reversed = false,
  ValueChanged<double>? onChanged,
  VoidCallback? onStart,
  VoidCallback? onEnd,
}) => MaterialApp(
  theme: raftTheme(family),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: RaftPanelResizeHandle.hitExtent,
        height: 200,
        child: RaftPanelResizeHandle(
          key: const Key('handle'),
          label: 'Resize',
          value: value,
          reversed: reversed,
          hairline: hairline,
          onChanged: onChanged ?? (_) {},
          onChangeStart: onStart,
          onChangeEnd: onEnd,
        ),
      ),
    ),
  ),
);

/// The 1px rule inside the 8px strip.
Color? rule(WidgetTester t) {
  final box = t.widget<Container>(
    find.descendant(
      of: find.byKey(const Key('handle')),
      matching: find.byType(Container),
    ),
  );
  return box.color;
}

void main() {
  testWidgets(
    'the public page handle paints foreground/25 and darkens on hover',
    (t) async {
      await t.pumpWidget(frame(RaftFamily.elegant, hairline: true));
      final ink = RaftTokens.of(t.element(find.byKey(const Key('handle'))))
          .colors['foreground']!;
      expect(rule(t), ink.withValues(alpha: .25));
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(find.byKey(const Key('handle'))));
      await t.pump();
      expect(rule(t), ink);
      await mouse.removePointer();
    },
  );

  testWidgets('Brutal paints black/25', (t) async {
    await t.pumpWidget(frame(RaftFamily.brutal, hairline: true));
    expect(rule(t), Colors.black.withValues(alpha: .25));
  });

  testWidgets('the signed-in shell handle stays invisible', (t) async {
    await t.pumpWidget(frame(RaftFamily.elegant));
    expect(rule(t), Colors.transparent);
  });

  testWidgets('a drag reports start, each value and end; reversed flips', (
    t,
  ) async {
    final log = <String>[];
    await t.pumpWidget(
      frame(
        RaftFamily.elegant,
        reversed: true,
        onChanged: (v) => log.add('value ${v.round()}'),
        onStart: () => log.add('start'),
        onEnd: () => log.add('end'),
      ),
    );
    await t.drag(find.byKey(const Key('handle')), const Offset(-30, 0));
    expect(log.first, 'start');
    expect(log.last, 'end');
    // Dragging left grows a reversed (left-edge) handle.
    expect(log.where((e) => e.startsWith('value')).last, 'value 270');
  });

  testWidgets('keyboard steps land with start and end', (t) async {
    final log = <String>[];
    await t.pumpWidget(
      frame(
        RaftFamily.elegant,
        onChanged: (v) => log.add('value ${v.round()}'),
        onStart: () => log.add('start'),
        onEnd: () => log.add('end'),
      ),
    );
    Focus.of(
      t.element(
        find
            .descendant(
              of: find.byKey(const Key('handle')),
              matching: find.byType(GestureDetector),
            )
            .first,
      ),
    ).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(log, ['start', 'value 256', 'end']);
  });
}
