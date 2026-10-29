import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('desktop pointer focus cannot reopen a pressed avatar preview', (
    t,
  ) async {
    final strategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
    var clicks = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Center(
            child: RaftHoverCard(
              card: (_) => const Text('Agent preview'),
              child: RaftAvatarButton(
                onPressed: () => clicks++,
                child: const SizedBox(width: 32, height: 32, child: Text('A')),
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(find.byType(RaftAvatarButton)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Agent preview'), findsOneWidget);
      await mouse.down(t.getCenter(find.byType(RaftAvatarButton)));
      await t.pump(const Duration(milliseconds: 120));
      await mouse.up();
      await t.pump(const Duration(milliseconds: 500));
      expect(clicks, 1);
      expect(find.text('Agent preview'), findsNothing);
    } finally {
      await mouse.removePointer();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }
  });
}
