import 'dart:ui' show Tristate;

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
    testWidgets(
      '$family dark=$dark controlled Switch supports pointer and keyboard',
      (tester) async {
        var value = false;
        final changes = <bool>[];
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, rebuild) => RaftDensityScope(
                    density: RaftDensity.desktop,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: RaftSwitch(
                        value: value,
                        size: RaftSwitchSize.md,
                        semanticLabel: 'Model name',
                        onChanged: (next) {
                          changes.add(next);
                          rebuild(() => value = next);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.getSize(find.byType(RaftSwitch)), const Size(36, 20));
          await tester.tap(find.byType(RaftSwitch));
          await tester.pumpAndSettle();
          expect(changes, [true]);
          expect(
            tester
                .getSemantics(find.byType(RaftSwitch))
                .flagsCollection
                .isToggled,
            Tristate.isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(changes, [true, false]);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(changes, [true, false, true]);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          handle.dispose();
        }
      },
    );
  }
  testWidgets('disabled touch switch keeps48px target and never toggles', (
    tester,
  ) async {
    var changed = 0;
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant, dark: true),
          home: Scaffold(
            body: RaftDensityScope(
              density: RaftDensity.touch,
              child: Align(
                alignment: Alignment.topLeft,
                child: RaftSwitch(
                  value: false,
                  enabled: false,
                  size: RaftSwitchSize.md,
                  onChanged: (_) => changed++,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(RaftSwitch)), const Size(48, 48));
      expect(
        tester.getSemantics(find.byType(RaftSwitch)).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      await tester.tapAt(tester.getCenter(find.byType(RaftSwitch)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(changed, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      handle.dispose();
    }
  });
  testWidgets(
    'canceled switch press has no change and reduced motion is immediate',
    (tester) async {
      var changed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: RaftDensityScope(
                density: RaftDensity.desktop,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RaftSwitch(value: true, onChanged: (_) => changed++),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RaftSwitch)),
      );
      await gesture.moveBy(const Offset(200, 0));
      await gesture.up();
      await tester.pump();
      expect(changed, 0);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
      await tester.tap(find.byType(RaftSwitch));
      expect(changed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('optional model label preserves Agent badge and thread action', (
    tester,
  ) async {
    var threads = 0;
    Future<void> render(String? model) => tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: RaftMessageTile(
            author: 'Agent Ada',
            content: 'Preview',
            timestamp: '09:41',
            badge: 'Agent',
            modelLabel: model,
            threadLabel: 'Open thread',
            onThread: () => threads++,
          ),
        ),
      ),
    );
    await render('Actual model');
    expect(find.text('Actual model'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
    await tester.tap(find.text('Open thread'));
    expect(threads, 1);
    await render(null);
    expect(find.text('Actual model'), findsNothing);
    expect(find.text('Agent'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
