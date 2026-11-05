import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/native_surface_occlusion.dart';

Future<RaftNativeSurfaceOcclusion> pumpHost(
  WidgetTester tester,
  Widget child,
) async {
  late RaftNativeSurfaceOcclusion registry;
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Builder(
        builder: (context) {
          registry = RaftNativeSurfaceOcclusion.forView(context);
          return Scaffold(body: child);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return registry;
}

void main() {
  testWidgets('painted bounds yield only their occupied area and retire', (
    tester,
  ) async {
    var taps = 0;
    final registry = await pumpHost(
      tester,
      Stack(
        children: [
          Positioned(
            left: 100,
            top: 100,
            width: 80,
            height: 60,
            child: RaftNativeSurfaceOccluder(
              child: GestureDetector(
                onTap: () => taps++,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
    expect(registry.overlaps(const Rect.fromLTWH(120, 110, 10, 10)), isTrue);
    expect(registry.overlaps(const Rect.fromLTWH(200, 110, 10, 10)), isFalse);
    await tester.tapAt(const Offset(120, 120));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(registry.overlaps(const Rect.fromLTWH(120, 110, 10, 10)), isFalse);
  });

  testWidgets('clipped overflow does not hide unrelated native content', (
    tester,
  ) async {
    final registry = await pumpHost(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 80,
          height: 80,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: 200,
              child: SizedBox(
                width: 200,
                height: 80,
                child: RaftNativeSurfaceOccluder(
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(registry.overlaps(const Rect.fromLTWH(70, 10, 5, 5)), isTrue);
    expect(registry.overlaps(const Rect.fromLTWH(90, 10, 5, 5)), isFalse);
  });

  testWidgets('inactive retained overlay retires and restores its same entry', (
    tester,
  ) async {
    var active = true;
    late StateSetter update;
    final registry = await pumpHost(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return TickerMode(
            enabled: active,
            child: const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 60,
                height: 60,
                child: RaftNativeSurfaceOccluder(
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          );
        },
      ),
    );
    const probe = Rect.fromLTWH(10, 10, 10, 10);
    expect(registry.overlaps(probe), isTrue);
    update(() => active = false);
    await tester.pumpAndSettle();
    expect(registry.overlaps(probe), isFalse);
    update(() => active = true);
    await tester.pumpAndSettle();
    expect(registry.overlaps(probe), isTrue);
  });

  testWidgets('canonical tooltip registers its real portal and retires', (
    tester,
  ) async {
    final registry = await pumpHost(
      tester,
      const Center(
        child: RaftTooltip(
          message: 'Canonical native cover',
          delay: Duration.zero,
          child: SizedBox(width: 80, height: 40, child: Text('Trigger')),
        ),
      ),
    );
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: const Offset(1, 1));
    await pointer.moveTo(tester.getCenter(find.text('Trigger')));
    await tester.pumpAndSettle();
    final bounds = tester.getRect(find.text('Canonical native cover'));
    expect(registry.overlaps(bounds), isTrue);
    expect(registry.overlaps(const Rect.fromLTWH(1, 1, 10, 10)), isFalse);
    await pointer.removePointer();
    await tester.pumpAndSettle();
    expect(registry.overlaps(bounds), isFalse);
  });

  testWidgets('canonical popover keeps its click and retires on close', (
    tester,
  ) async {
    final menu = MenuController();
    final anchor = GlobalKey();
    var selected = false;
    final registry = await pumpHost(
      tester,
      Center(
        child: RaftPopoverAnchor(
          controller: menu,
          anchorKey: anchor,
          builder: (context, controller, child) => RaftButton(
            key: anchor,
            label: 'Open popup',
            onPressed: controller.open,
          ),
          popup: SizedBox(
            width: 220,
            child: RaftButton(
              label: 'Choose value',
              onPressed: () {
                selected = true;
                menu.close();
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open popup'));
    await tester.pumpAndSettle();
    final bounds = tester.getRect(find.text('Choose value'));
    expect(registry.overlaps(bounds), isTrue);
    await tester.tap(find.text('Choose value'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(registry.overlaps(bounds), isFalse);
  });
}
