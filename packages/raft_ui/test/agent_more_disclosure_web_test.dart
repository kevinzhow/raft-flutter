import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final device in [
    (TargetPlatform.linux, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
  ]) {
    testWidgets('agent disclosure uses input mode ${device.$1}/${device.$2}', (
      t,
    ) async {
      t.view.physicalSize = device.$2;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var open = false;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: device.$1),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => RaftAgentMoreDisclosure(
                  open: open,
                  onToggle: () => setState(() => open = !open),
                  children: const [Text('Advanced options')],
                ),
              ),
            ),
          ),
        ),
      );
      final disclosure = find.byType(RaftAgentMoreDisclosure);
      expect(
        RaftInteraction.of(t.element(disclosure)).touch,
        device.$1 == TargetPlatform.android,
      );
      await t.tap(find.text('More'));
      await t.pump();
      expect(find.text('Advanced options'), findsOneWidget);
      await t.tap(find.text('More'));
      await t.pump();
      expect(find.text('Advanced options'), findsNothing);
    });
  }

  for (final dark in [false, true]) {
    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      testWidgets('agent disclosure keyboard $key $dark', (t) async {
        var open = false;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: StatefulBuilder(
                  builder: (context, setState) => RaftAgentMoreDisclosure(
                    open: open,
                    onToggle: () => setState(() => open = !open),
                    children: const [Text('Advanced options')],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        final focus = t.widget<RaftCssOuterShadow>(
          find.descendant(
            of: find.byType(RaftAgentMoreDisclosure),
            matching: find.byType(RaftCssOuterShadow),
          ),
        );
        expect(focus.decoration.boxShadow, isNotEmpty);
        await t.sendKeyEvent(key);
        await t.pump();
        expect(find.text('Advanced options'), findsOneWidget);
        await t.sendKeyEvent(key);
        await t.pump();
        // Web conditionally unmounts the children, without an exit animation.
        expect(find.text('Advanced options'), findsNothing);
      });
    }

    testWidgets('agent disclosure exposes expanded button semantics $dark', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      var open = false;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: StatefulBuilder(
                builder: (context, setState) => RaftAgentMoreDisclosure(
                  open: open,
                  onToggle: () => setState(() => open = !open),
                  children: const [Text('Advanced options')],
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        t.getSemantics(find.text('More')),
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      await t.tap(find.text('More'));
      await t.pump();
      expect(
        t.getSemantics(find.text('More')),
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      t.semantics.tap(find.semantics.byLabel('More'));
      await t.pump();
      expect(find.text('Advanced options'), findsNothing);
      handle.dispose();
    });

    testWidgets('agent disclosure uses Web section eyebrow and toggles $dark', (
      t,
    ) async {
      var open = false;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: StatefulBuilder(
                builder: (context, setState) => RaftAgentMoreDisclosure(
                  open: open,
                  onToggle: () => setState(() => open = !open),
                  children: const [Text('Advanced options')],
                ),
              ),
            ),
          ),
        ),
      );
      final disclosure = find.byType(RaftAgentMoreDisclosure);
      final label = find.descendant(
        of: disclosure,
        matching: find.text('More'),
      );
      final glyph = find.descendant(
        of: disclosure,
        matching: find.byType(RaftIcon),
      );
      final text = t.widget<Text>(label);
      final tokens = RaftTokens.of(t.element(disclosure));
      expect(text.style!.fontSize, 13);
      expect(text.style!.height, 18 / 13);
      expect(text.style!.fontWeight, FontWeight.w700);
      expect(text.style!.color, tokens.colors['foreground-hint']);
      expect(t.getSize(glyph), const Size(14, 14));
      expect(t.getTopLeft(label).dx - t.getTopRight(glyph).dx, 8);
      expect(t.getSize(disclosure).height, 18);
      expect(find.text('Advanced options'), findsNothing);
      await t.tap(label);
      await t.pump();
      expect(find.text('Advanced options'), findsOneWidget);
      await t.tap(label);
      await t.pump();
      expect(find.text('Advanced options'), findsNothing);
    });
  }
}
