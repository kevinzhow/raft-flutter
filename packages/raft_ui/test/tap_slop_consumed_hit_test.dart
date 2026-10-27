import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/tap_slop.dart';

const _actionKey = ValueKey('review-action');

Widget _action(VoidCallback tap, {double top = 20}) => Positioned(
  left: 60,
  top: top,
  child: RaftTapSlopAnchor(
    key: _actionKey,
    minSize: const Size.square(48),
    child: SizedBox(
      width: 24,
      height: 24,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: const ColoredBox(color: Colors.red),
      ),
    ),
  ),
);

Widget _scene(Widget child, {double height = 100}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 200,
        height: height,
        child: RaftTapSlopHost(child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('consumed hit respects transformHitTests false', (t) async {
    var action = 0;
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
    await t.pumpWidget(
      _scene(
        Stack(
          children: [
            _action(() => action++),
            Positioned(
              left: 0,
              top: 0,
              width: 60,
              height: 100,
              child: Transform.translate(
                offset: const Offset(0, 40),
                // The shield deliberately owns its untransformed hit region.
                transformHitTests: false,
                // This box records the consumed child hit inside Transform.
                child: const Padding(
                  padding: EdgeInsets.zero,
                  child: AbsorbPointer(child: ColoredBox(color: Colors.blue)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    final a = t.getRect(find.byKey(_actionKey));
    await t.tapAt(Offset(a.left - 2, a.center.dy));
    await t.pumpAndSettle();
    expect(
      action,
      0,
      reason: 'The actual direct hit is consumed by the shield',
    );
    await t.tapAt(a.center);
    await t.pumpAndSettle();
    expect(action, 1, reason: 'The adjacent action itself remains available');
    expect(t.takeException(), isNull);
  });

  testWidgets('consumed hit directly in a sliver blocks expansion', (t) async {
    var action = 0;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
    await t.pumpWidget(
      _scene(
        Stack(
          children: [
            _action(() => action++, top: 60),
            Positioned(
              left: 0,
              top: 0,
              width: 200,
              height: 60,
              child: CustomScrollView(
                controller: scroll,
                slivers: const [
                  SliverToBoxAdapter(
                    // AbsorbPointer must be the sliver's immediate box child:
                    // a SizedBox outside it would record a RenderBox first.
                    child: AbsorbPointer(
                      child: SizedBox(
                        height: 60,
                        child: ColoredBox(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        height: 120,
      ),
    );
    await t.pumpAndSettle();
    final a = t.getRect(find.byKey(_actionKey));
    await t.tapAt(Offset(a.center.dx, a.top - 2));
    await t.pumpAndSettle();
    expect(action, 0, reason: 'The sliver shield consumes the original hit');
    await t.tapAt(a.center);
    await t.pumpAndSettle();
    expect(action, 1, reason: 'The action below the shield remains available');
    expect(t.takeException(), isNull);
  });

  testWidgets('hover-only observer does not remove a touch target', (t) async {
    var action = 0;
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
    await t.pumpWidget(
      _scene(
        Listener(
          onPointerHover: (_) {},
          child: ColoredBox(
            color: Colors.transparent,
            child: Stack(children: [_action(() => action++)]),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final a = t.getRect(find.byKey(_actionKey));
    await t.tapAt(Offset(a.left - 2, a.center.dy));
    await t.pumpAndSettle();
    expect(action, 1, reason: 'Hover observation does not own a touch tap');
    await t.tapAt(a.center);
    await t.pumpAndSettle();
    expect(action, 2);
    expect(t.takeException(), isNull);
  });

  testWidgets('nonabsorbing wrapper does not remove a touch target', (t) async {
    var action = 0;
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
    await t.pumpWidget(
      _scene(
        AbsorbPointer(
          absorbing: false,
          child: ColoredBox(
            color: Colors.transparent,
            child: Stack(children: [_action(() => action++)]),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final a = t.getRect(find.byKey(_actionKey));
    await t.tapAt(Offset(a.left - 2, a.center.dy));
    await t.pumpAndSettle();
    expect(action, 1, reason: 'A disabled shield is a pass-through wrapper');
    await t.tapAt(a.center);
    await t.pumpAndSettle();
    expect(action, 2);
    expect(t.takeException(), isNull);
  });
}
