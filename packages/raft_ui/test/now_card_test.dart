// Web AgentNowCard (v1.24.0) as raft_ui lays it out: Ottie, the first line,
// the step and focus lines, the recent turns, and a heading that is a button;
// plus the Web-style TextLink variants and Ottie's three poses.
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(Widget child, {bool dark = false, double width = 380}) =>
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: RaftInteractionScope(
        interaction: RaftInteraction.pointerMode,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  for (final dark in [false, true]) {
    for (final status in RaftOtterStatus.values) {
      testWidgets('card with Ottie ${status.name} ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            dark: dark,
            RaftNowCard(
              otter: status,
              eyebrow: 'Recent activity',
              onOpenEyebrow: () {},
              lead: const Text('Working · for 2m 14s'),
              step: 'Running npm test',
              focus: '@Remy · #deploy · ran 3 commands',
              rows: const [
                RaftNowTurnRow(
                  time: '09:41',
                  trigger: 'DM from @xxchan',
                  actions: 'ran 3 commands and read a file',
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('raft-otter-indicator')),
          findsOneWidget,
        );
        expect(find.text('Running npm test'), findsOneWidget);
        expect(find.text('09:41'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'without a heading handler the eyebrow is plain text, not a button',
    (tester) async {
      await tester.pumpWidget(
        host(
          const RaftNowCard(
            otter: RaftOtterStatus.wait,
            eyebrow: 'Recent activity',
            lead: Text('Idle'),
          ),
        ),
      );
      expect(find.text('Recent activity'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-now-open-activity')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the heading is a button: tap and the keyboard open it, and a screen reader hears it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var opened = 0;
      await tester.pumpWidget(
        host(
          RaftNowCard(
            otter: RaftOtterStatus.wait,
            eyebrow: 'Recent activity',
            onOpenEyebrow: () => opened++,
            lead: const Text('Idle'),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('agent-now-open-activity'));
      await tester.tap(button);
      expect(opened, 1);
      // Keyboard: Tab to it, Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, 2);
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocused: true,
          label: 'Recent activity',
        ),
      );
      semantics.dispose();
    },
  );

  testWidgets('Ottie is decoration: it adds nothing to the semantics tree', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const RaftNowCard(otter: RaftOtterStatus.error, lead: Text('Offline')),
      ),
    );
    expect(find.bySemanticsLabel('?'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'long step, focus and trigger lines are cut, not wrapped or overflowing',
    (tester) async {
      final long = List.filled(20, 'a very long sentence').join(' ');
      await tester.pumpWidget(
        host(
          width: 260,
          RaftNowCard(
            otter: RaftOtterStatus.process,
            lead: const Text('Working'),
            step: long,
            focus: long,
            rows: [
              RaftNowTurnRow(
                time: '09:41',
                trigger: long,
                actions: long,
                badges: const [Text('Stopped')],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('agent-now-step'))).height,
        lessThan(30),
      );
    },
  );

  group('TextLink variants', () {
    testWidgets('muted link: hovering it and tapping it work', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          RaftTextLink(
            label: 'Retry',
            variant: RaftTextLinkVariant.muted,
            onPressed: () => taps++,
          ),
        ),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Retry')));
      await tester.pump();
      await tester.tap(find.text('Retry'));
      expect(taps, 1);
    });

    testWidgets('muted text is the body size, not the 11px saved-action size', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              RaftTextLink(label: 'Saved link', onPressed: () {}),
              RaftTextLink(
                label: 'Muted link',
                variant: RaftTextLinkVariant.muted,
                onPressed: () {},
              ),
              RaftTextLink(
                label: 'Strong link',
                variant: RaftTextLinkVariant.strong,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      double sizeOf(String text) => tester
          .widget<RichText>(
            find.descendant(
              of: find.widgetWithText(RaftTextLink, text),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style!
          .fontSize!;
      expect(sizeOf('Saved link'), 11);
      expect(sizeOf('Muted link'), greaterThan(12));
      expect(sizeOf('Strong link'), sizeOf('Muted link'));
    });

    testWidgets('a disabled muted link does nothing', (tester) async {
      await tester.pumpWidget(
        host(
          const RaftTextLink(
            label: 'Restarting…',
            variant: RaftTextLinkVariant.muted,
          ),
        ),
      );
      await tester.tap(find.text('Restarting…'));
      expect(tester.takeException(), isNull);
    });
  });
}
