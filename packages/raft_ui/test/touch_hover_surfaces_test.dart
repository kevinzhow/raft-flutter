import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('touch controls ignore compatibility hover but still activate', (
    tester,
  ) async {
    RaftInteractionState? state;
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftHoverScope(
            enabled: false,
            child: Center(
              child: RaftInteractive(
                onPressed: () => presses++,
                builder: (_, value) {
                  state = value;
                  return const SizedBox(
                    width: 140,
                    height: 48,
                    child: Text('Touch action'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(tester.getCenter(find.text('Touch action')));
    await tester.pump();
    expect(state!.hovered, isFalse);
    await tester.tap(find.text('Touch action'));
    await tester.pump();
    expect(presses, 1);
    expect(state!.hovered, isFalse);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  for (final surface in ['tooltip', 'card']) {
    testWidgets('touch $surface ignores compatibility hover', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftHoverScope(
              enabled: false,
              child: Center(
                child: surface == 'tooltip'
                    ? const RaftTooltip(
                        message: 'Hover details',
                        delay: Duration.zero,
                        child: Text('Touch trigger'),
                      )
                    : RaftHoverCard(
                        delay: Duration.zero,
                        card: (_) => const Text('Hover details'),
                        child: const Text('Touch trigger'),
                      ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(tester.getCenter(find.text('Touch trigger')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Hover details'), findsNothing);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('changing host input mode retires visible hover once', (
    tester,
  ) async {
    late StateSetter update;
    var enabled = true;
    RaftInteractionState? state;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return RaftHoverScope(
              enabled: enabled,
              child: Center(
                child: RaftInteractive(
                  onPressed: () {},
                  builder: (_, value) {
                    state = value;
                    return const SizedBox(
                      width: 140,
                      height: 48,
                      child: Text('Mode action'),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(tester.getCenter(find.text('Mode action')));
    await tester.pump();
    expect(state!.hovered, isTrue);
    update(() => enabled = false);
    await tester.pump();
    await tester.pump();
    expect(state!.hovered, isFalse);
    expect(tester.takeException(), isNull);
    update(() => enabled = true);
    await tester.pump();
    await mouse.moveBy(const Offset(2, 2));
    await tester.pump();
    expect(state!.hovered, isTrue);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('host hover policy follows $platform rather than width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(
        Size(platform == TargetPlatform.android ? 1600 : 390, 800),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      RaftInteractionState? state;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: RaftHoverScope.forPlatform(
            child: Center(
              child: RaftInteractive(
                onPressed: () {},
                builder: (_, value) {
                  state = value;
                  return const SizedBox(
                    width: 140,
                    height: 48,
                    child: Text('Platform action'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(tester.getCenter(find.text('Platform action')));
      await tester.pump();
      expect(state!.hovered, platform == TargetPlatform.linux);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant({platform}));
  }
}
