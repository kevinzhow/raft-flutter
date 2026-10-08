import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/design_primitives.dart';
import 'package:raft_ui/src/quick_reaction_picker.dart';
import 'package:raft_ui/src/theme.dart';

Widget host({
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
  ValueChanged<String>? select,
  VoidCallback? dismiss,
  FocusNode? opener,
  bool enabled = true,
  bool visible = true,
  VoidCallback? enter,
  VoidCallback? leave,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: Column(
      children: [
        TextButton(
          focusNode: opener,
          onPressed: () {},
          child: const Text('Source opener'),
        ),
        if (visible)
          RaftQuickReactionPicker(
            glyphBuilder: (emoji) => ColoredBox(
              key: ValueKey('public-glyph-$emoji'),
              color: Colors.blue,
            ),
            labelBuilder: (emoji) => 'React with $emoji',
            onSelect: select ?? (_) {},
            onDismiss: dismiss ?? () {},
            returnFocusNode: opener,
            enabled: enabled,
            onBoundaryEnter: enter,
            onBoundaryLeave: leave,
          ),
      ],
    ),
  ),
);
void main() {
  testWidgets(
    'pointer-open Escape is consumed before background navigation and listener retires',
    (t) async {
      var background = 0, dismissed = 0;
      var open = true;
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      background++,
                },
                child: Focus(
                  autofocus: true,
                  child: Scaffold(
                    body: open
                        ? RaftQuickReactionPicker(
                            glyphBuilder: (_) => const SizedBox(),
                            labelBuilder: (value) => value,
                            onSelect: (_) {},
                            onDismiss: () {
                              dismissed++;
                              update(() => open = false);
                            },
                          )
                        : const SizedBox(),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(dismissed, 1);
      expect(background, 0);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(dismissed, 1);
      expect(background, 1);
    },
  );

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'seven source buttons preserve order and mounted dimensions $family/$dark',
      (tester) async {
        final selections = <String>[];
        await tester.pumpWidget(
          host(family: family, dark: dark, select: selections.add),
        );
        final controls = find.descendant(
          of: find.byType(RaftQuickReactionPicker),
          matching: find.byType(RaftControl),
        );
        expect(controls, findsNWidgets(7));
        final positions = <double>[];
        for (final value in raftQuickReactions) {
          final f = find.byKey(ValueKey('quick-reaction-$value'));
          expect(tester.getSize(f), const Size(28, 28));
          expect(
            tester.getSize(find.byKey(ValueKey('public-glyph-$value'))),
            const Size(18, 18),
          );
          positions.add(tester.getTopLeft(f).dx);
          await tester.tap(f);
          await tester.pump();
        }
        expect(selections, raftQuickReactions);
        for (var i = 1; i < positions.length; i++) {
          expect(positions[i] - positions[i - 1], 30);
        }
        expect(
          tester.getSize(find.byType(RaftQuickReactionPicker)),
          Size(
            family == RaftFamily.brutal ? 224 : 220,
            family == RaftFamily.brutal ? 40 : 36,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'opening preserves opener focus then normal Tab enters first button',
    (tester) async {
      final opener = FocusNode();
      addTearDown(opener.dispose);
      final selected = <String>[];
      await tester.pumpWidget(host(opener: opener, select: selected.add));
      opener.requestFocus();
      await tester.pump();
      expect(opener.hasFocus, isTrue);
      await tester.pump();
      expect(opener.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(selected, ['👍']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Escape dismisses with opener outside popup and returns focus', (
    tester,
  ) async {
    final opener = FocusNode();
    addTearDown(opener.dispose);
    var dismissed = 0;
    await tester.pumpWidget(host(opener: opener, dismiss: () => dismissed++));
    opener.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(opener.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dismissed, 1);
    expect(opener.hasFocus, isTrue);
  });
  testWidgets('unmount releases global Escape listener', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(dismiss: () => calls++));
    await tester.pumpWidget(host(visible: false));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls, 0);
  });
  testWidgets('controlled disabled state blocks selection', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(enabled: false, select: (_) => calls++));
    await tester.tap(find.byKey(const ValueKey('quick-reaction-👍')));
    await tester.pump();
    expect(calls, 0);
    final control = tester.widget<RaftControl>(
      find.byKey(const ValueKey('quick-reaction-👍')),
    );
    expect(control.onPressed, isNull);
  });
  testWidgets(
    'surface reports boundary without implementing timer or mutation',
    (tester) async {
      var enters = 0, leaves = 0;
      await tester.pumpWidget(
        host(enter: () => enters++, leave: () => leaves++),
      );
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: const Offset(2, 400));
      await pointer.moveTo(
        tester.getCenter(find.byKey(const ValueKey('quick-reaction-👍'))),
      );
      await tester.pump();
      expect(enters, 1);
      await pointer.moveTo(const Offset(2, 400));
      await tester.pump();
      expect(leaves, 1);
      await pointer.removePointer();
    },
  );
}
