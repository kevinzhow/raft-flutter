import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Edge to edge: a modal taller than the screen must scroll its last control
// clear of the system gesture / navigation bar.
void main() {
  testWidgets(
    'tall modal scrolls clear of the gesture bar',
    (t) async {
      t.view.physicalSize = const Size(1081, 2402);
      t.view.devicePixelRatio = 2.625;
      t.view.padding = const FakeViewPadding(top: 100, bottom: 48);
      t.view.viewPadding = const FakeViewPadding(top: 100, bottom: 48);
      addTearDown(() {
        t.view.reset();
        t.view.resetPadding();
        t.view.resetViewPadding();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftModalBackdrop(
              child: Column(
                children: [
                  const SizedBox(height: 1200),
                  SizedBox(key: const ValueKey('last'), height: 40, width: 200),
                ],
              ),
            ),
          ),
        ),
      );
      await t.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
      await t.pumpAndSettle();
      final screenH = t.view.physicalSize.height / t.view.devicePixelRatio;
      final inset = 48 / t.view.devicePixelRatio;
      expect(
        screenH - t.getRect(find.byKey(const ValueKey('last'))).bottom,
        closeTo(16 + inset, .5),
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'short modal stays centred without scrolling',
    (t) async {
      t.view.physicalSize = const Size(1081, 2402);
      t.view.devicePixelRatio = 2.625;
      t.view.padding = const FakeViewPadding(top: 100, bottom: 48);
      t.view.viewPadding = const FakeViewPadding(top: 100, bottom: 48);
      addTearDown(() {
        t.view.reset();
        t.view.resetPadding();
        t.view.resetViewPadding();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: const Scaffold(
            body: RaftModalBackdrop(child: SizedBox(height: 100, width: 200)),
          ),
        ),
      );
      final position = t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, 0);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
