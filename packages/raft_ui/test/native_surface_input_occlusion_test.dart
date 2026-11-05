import 'dart:ui' show FlutterView, Scene, SemanticsUpdate;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/native_surface_occlusion.dart';

import 'native_surface_occlusion_test.dart' show pumpHost;

void main() {
  testWidgets('same bounds notify when only input blocking changes', (
    tester,
  ) async {
    var blocking = true;
    late StateSetter update;
    final registry = await pumpHost(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return Align(
            alignment: Alignment.topLeft,
            child: RaftNativeSurfaceOccluder(
              blocksInput: blocking,
              child: const SizedBox(width: 80, height: 60),
            ),
          );
        },
      ),
    );
    const probe = Rect.fromLTWH(10, 10, 10, 10);
    var changes = 0;
    void changed() => changes++;
    registry.addListener(changed);
    try {
      expect(registry.blocksInput(probe), isTrue);
      update(() => blocking = false);
      await tester.pumpAndSettle();
      expect(registry.overlaps(probe), isTrue);
      expect(registry.blocksInput(probe), isFalse);
      expect(changes, greaterThan(0));
      final before = changes;
      update(() => blocking = true);
      await tester.pumpAndSettle();
      expect(registry.blocksInput(probe), isTrue);
      expect(changes, greaterThan(before));
    } finally {
      registry.removeListener(changed);
    }
  });

  testWidgets('mixed overlays keep independent input lifetimes', (
    tester,
  ) async {
    var interactiveCount = 2;
    late StateSetter update;
    final registry = await pumpHost(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return Stack(
            children: [
              const Positioned(
                key: ValueKey('passive'),
                left: 100,
                top: 100,
                child: RaftNativeSurfaceOccluder(
                  blocksInput: false,
                  child: SizedBox(width: 100, height: 100),
                ),
              ),
              for (var index = 0; index < interactiveCount; index++)
                Positioned(
                  key: ValueKey(index),
                  left: 130,
                  top: 130,
                  child: const RaftNativeSurfaceOccluder(
                    child: SizedBox(width: 40, height: 40),
                  ),
                ),
            ],
          );
        },
      ),
    );
    const passive = Rect.fromLTWH(110, 110, 10, 10);
    const shared = Rect.fromLTWH(140, 140, 10, 10);
    expect(registry.overlaps(passive), isTrue);
    expect(registry.blocksInput(passive), isFalse);
    expect(registry.blocksInput(shared), isTrue);
    update(() => interactiveCount = 1);
    await tester.pumpAndSettle();
    expect(registry.blocksInput(shared), isTrue);
    update(() => interactiveCount = 0);
    await tester.pumpAndSettle();
    expect(registry.overlaps(shared), isTrue);
    expect(registry.blocksInput(shared), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(registry.overlaps(shared), isFalse);
    expect(registry.blocksInput(shared), isFalse);
  });

  testWidgets('inactive passive overlay retires and returns without blocking', (
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
              child: RaftNativeSurfaceOccluder(
                blocksInput: false,
                child: SizedBox(width: 60, height: 60),
              ),
            ),
          );
        },
      ),
    );
    const probe = Rect.fromLTWH(10, 10, 10, 10);
    expect(registry.overlaps(probe), isTrue);
    expect(registry.blocksInput(probe), isFalse);
    update(() => active = false);
    await tester.pumpAndSettle();
    expect(registry.overlaps(probe), isFalse);
    expect(registry.blocksInput(probe), isFalse);
    update(() => active = true);
    await tester.pumpAndSettle();
    expect(registry.overlaps(probe), isTrue);
    expect(registry.blocksInput(probe), isFalse);
  });

  testWidgets('overlapping coordinates in separate views never share entries', (
    tester,
  ) async {
    final otherView = _SecondaryView(tester.view);
    late RaftNativeSurfaceOcclusion first, second;
    Widget content(bool blocking, void Function(BuildContext) capture) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              capture(context);
              return Align(
                alignment: Alignment.topLeft,
                child: RaftNativeSurfaceOccluder(
                  blocksInput: blocking,
                  child: const SizedBox(width: 80, height: 60),
                ),
              );
            },
          ),
        );
    final firstWidget = View(
      view: tester.view,
      child: content(true, (context) {
        first = RaftNativeSurfaceOcclusion.forView(context);
      }),
    );
    final secondWidget = View(
      view: otherView,
      child: content(false, (context) {
        second = RaftNativeSurfaceOcclusion.forView(context);
      }),
    );
    await tester.pumpWidget(
      ViewCollection(views: [firstWidget, secondWidget]),
      wrapWithView: false,
    );
    await tester.pumpAndSettle();
    const probe = Rect.fromLTWH(10, 10, 10, 10);
    expect(identical(first, second), isFalse);
    expect(first.blocksInput(probe), isTrue);
    expect(second.overlaps(probe), isTrue);
    expect(second.blocksInput(probe), isFalse);
    await tester.pumpWidget(
      ViewCollection(views: [secondWidget]),
      wrapWithView: false,
    );
    await tester.pumpAndSettle();
    expect(first.overlaps(probe), isFalse);
    expect(first.blocksInput(probe), isFalse);
    expect(second.overlaps(probe), isTrue);
    expect(second.blocksInput(probe), isFalse);
    await tester.pumpWidget(
      const ViewCollection(views: []),
      wrapWithView: false,
    );
    await tester.pumpAndSettle();
    expect(second.overlaps(probe), isFalse);
  });
}

class _SecondaryView extends TestFlutterView {
  _SecondaryView(FlutterView view)
    : super(
        view: view,
        platformDispatcher: view.platformDispatcher as TestPlatformDispatcher,
        display: view.display as TestDisplay,
      );

  @override
  int get viewId => 812;

  // This view exercises framework ownership only; the test engine has one view.
  @override
  void render(Scene scene, {Size? size}) {}

  @override
  void updateSemantics(SemanticsUpdate update) {}
}
