import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(
  Widget child, {
  RaftFamily family = RaftFamily.elegant,
  bool reduced = false,
}) => MaterialApp(
  theme: raftTheme(family),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('Web ButtonActivateIntent activates a focused original control', (
    tester,
  ) async {
    var clicks = 0;
    await tester.pumpWidget(
      host(RaftButton(label: 'Default', onPressed: () => clicks++)),
    );
    await tester.tap(find.text('Default'));
    await tester.pump();
    expect(clicks, 1);
    final context = tester.element(find.text('Default'));
    expect(
      Actions.find<ButtonActivateIntent>(context)
          .isEnabled(const ButtonActivateIntent()),
      isTrue,
    );
    Actions.invoke(context, const ButtonActivateIntent());
    expect(clicks, 2);
  });

  testWidgets('Busy original button has disabled named button semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        host(
          RaftButton(
            label: 'Loading',
            busy: true,
            onPressed: () => fail('Busy control activated'),
          ),
          reduced: true,
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('Loading'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, isNot(Tristate.none));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(find.byType(RaftSpinner), findsOneWidget);
      await tester.tap(find.byType(RaftButton));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Glyph stays18px inside48px input prefix constraint', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox.square(
          dimension: 48,
          child: RaftIcon(RaftGlyph.search, size: 18),
        ),
      ),
    );
    final painter = find.descendant(
      of: find.byType(RaftIcon),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(painter), const Size(18, 18));
    expect(tester.getSize(find.byType(RaftIcon)), const Size(48, 48));
  });

  testWidgets('Elegant avatar preserves36px layout and32px painted circle', (
    tester,
  ) async {
    await tester.pumpWidget(host(const RaftAvatar(name: 'Human')));
    expect(tester.getSize(find.byType(RaftAvatar)), const Size(36, 36));
    final surface = find.descendant(
      of: find.byType(RaftAvatar),
      matching: find.byType(Container),
    );
    expect(tester.getSize(surface), const Size(32, 32));
  });

  for (final family in RaftFamily.values) {
    testWidgets(
      '$family field outer box preserves source content plus border',
      (tester) async {
        await tester.pumpWidget(
          host(
            const SizedBox(
              width: 320,
              child: RaftFieldSurface(
                child: TextField(
                  decoration: InputDecoration(hintText: 'Workspace name'),
                ),
              ),
            ),
            family: family,
          ),
        );
        expect(
          tester.getSize(find.byType(RaftFieldSurface)).height,
          family == RaftFamily.brutal ? 44 : 38,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Menu actual ArrowDown and Enter invoke next row; Escape dismisses',
    (tester) async {
      var copied = 0, downloaded = 0, dismissed = 0;
      await tester.pumpWidget(
        host(
          RaftMenuPanel(
            onDismiss: () => dismissed++,
            children: [
              RaftMenuItem(
                label: 'Copy link',
                autofocus: true,
                onPressed: () => copied++,
              ),
              RaftMenuItem(label: 'Download', onPressed: () => downloaded++),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(copied, 0);
      expect(downloaded, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissed, 1);
    },
  );
  testWidgets(
    'Segmented radio arrow keys select and preserve exclusive semantics',
    (tester) async {
      var value = 'diagram';
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) => RaftSegmentedControl<String>(
                value: value,
                items: const [
                  RaftSegmentedOption(value: 'diagram', label: 'Diagram'),
                  RaftSegmentedOption(value: 'code', label: 'Code'),
                ],
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Diagram'));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(value, 'code');
        expect(
          tester.getSemantics(find.text('Code')).flagsCollection.isChecked,
          CheckedState.isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(value, 'diagram');
      } finally {
        semantics.dispose();
      }
    },
  );
}
