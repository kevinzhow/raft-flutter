import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/tap_slop.dart';

enum _Action { anchor, button, expander }

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
      for (final excluded in [false, true]) {
        for (final actionType in _Action.values) {
          for (final scrolling in [false, true]) {
            testWidgets(
              '$platform $direction neighbor wins: excluded=$excluded '
              'action=$actionType scrolling=$scrolling',
              (t) async {
                var neighbor = 0;
                var action = 0;
                final scroll = ScrollController();
                t.view.physicalSize = const Size(390, 844);
                t.view.devicePixelRatio = 1;
                addTearDown(t.view.reset);
                addTearDown(scroll.dispose);
                addTearDown(() async {
                  await t.pumpWidget(const SizedBox.shrink());
                  await t.pumpAndSettle();
                });
                final gesture = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => action++,
                  child: const ColoredBox(color: Colors.red),
                );
                final row = Row(
                  children: [
                    SizedBox(
                      key: const ValueKey('neighbor'),
                      width: 64,
                      height: 24,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: excluded,
                        onTap: () => neighbor++,
                        child: const ColoredBox(color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (actionType == _Action.button)
                      RaftButton(
                        key: const ValueKey('action'),
                        glyph: RaftGlyph.trash2,
                        uiSize: RaftButtonSize.iconSm,
                        onPressed: () => action++,
                      )
                    else
                      RaftTapSlopAnchor(
                        key: const ValueKey('action'),
                        minSize: const Size.square(48),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: actionType == _Action.expander
                              ? RaftTouchTargetExpander(
                                  minSize: const Size.square(48),
                                  child: gesture,
                                )
                              : gesture,
                        ),
                      ),
                  ],
                );
                await t.pumpWidget(
                  MaterialApp(
                    theme: raftTheme(platform: platform),
                    builder: (context, child) =>
                        Directionality(textDirection: direction, child: child!),
                    home: Scaffold(
                      body: Center(
                        child: SizedBox(
                          width: 390,
                          height: 500,
                          child: RaftFormSheet(
                            title: 'Form',
                            onClose: () {},
                            body: SizedBox(
                              height: 100,
                              // This nested host must respect the outer
                              // sheet host's probe of actual visual bounds.
                              child: RaftTapSlopHost(
                                child: scrolling
                                    ? SingleChildScrollView(
                                        controller: scroll,
                                        child: Column(
                                          children: [
                                            row,
                                            const SizedBox(height: 400),
                                          ],
                                        ),
                                      )
                                    : row,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await t.pumpAndSettle();
                final n = t.getRect(find.byKey(const ValueKey('neighbor')));
                final a = t.getRect(find.byKey(const ValueKey('action')));
                final actionIsRight = a.center.dx > n.center.dx;
                final edge = Offset(
                  actionIsRight ? n.right - 2 : n.left + 2,
                  n.center.dy,
                );
                await t.tapAt(edge);
                await t.pumpAndSettle();
                expect([neighbor, action], [1, 0]);
                await t.tapAt(a.center);
                await t.pumpAndSettle();
                expect([neighbor, action], [1, 1]);
                await t.tapAt(
                  Offset(actionIsRight ? a.left - 2 : a.right + 2, a.center.dy),
                );
                await t.pumpAndSettle();
                expect(
                  [neighbor, action],
                  [1, 2],
                  reason: 'The empty gap remains an expanded touch target',
                );
                if (scrolling) {
                  await t.dragFrom(edge, const Offset(0, -60));
                  await t.pumpAndSettle();
                  expect(scroll.offset, greaterThan(0));
                  expect([neighbor, action], [1, 2]);
                }
                expect(t.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  }

  testWidgets('an absorbing overlay blocks neighbouring expansion', (t) async {
    var action = 0;
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: RaftTapSlopHost(
                child: Stack(
                  children: [
                    Positioned(
                      left: 60,
                      top: 20,
                      child: RaftTapSlopAnchor(
                        key: const ValueKey('action'),
                        minSize: const Size.square(48),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => action++,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      top: 0,
                      width: 60,
                      height: 100,
                      child: AbsorbPointer(
                        child: ColoredBox(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final a = t.getRect(find.byKey(const ValueKey('action')));
    await t.tapAt(Offset(a.left - 2, a.center.dy));
    await t.pumpAndSettle();
    expect(action, 0);
    await t.tapAt(a.center);
    await t.pumpAndSettle();
    expect(action, 1);
    expect(t.takeException(), isNull);
  });
}
