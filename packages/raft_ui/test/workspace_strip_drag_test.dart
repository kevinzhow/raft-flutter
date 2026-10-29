import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Finder item(String id) => find.byKey(ValueKey('topbar-workspace-$id'));
final floating = find.byKey(const Key('topbar-workspace-drag-overlay'));
Rect paintRect(WidgetTester t, Finder finder) {
  final box = t.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

class Harness {
  final order = ['a', 'b', 'c'];
  final moves = <List<int>>[];
  var picks = 0;
  final elsewhere = FocusNode();
  Future<void> mount(
    WidgetTester t, {
    bool reducedMotion = false,
    Size size = const Size(1280, 800),
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    addTearDown(elsewhere.dispose);
    addTearDown(t.view.reset);
    final menu = RaftMenuController();
    addTearDown(menu.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: reducedMotion),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                return Column(
                  children: [
                    RaftWorkspaceTopBar(
                      workspace: RaftServerSwitcher(
                        controller: menu,
                        workspaceName: 'A',
                        label: 'Switch Server',
                        topBar: true,
                        rows: [
                          for (final id in order)
                            RaftServerMenuRow(
                              id: id,
                              name: id.toUpperCase(),
                              slug: id,
                              current: id == 'a',
                              onSelected: () => picks++,
                            ),
                        ],
                        actions: const [],
                        onReorder: (from, to) => update(() {
                          moves.add([from, to]);
                          order.insert(to, order.removeAt(from));
                        }),
                      ),
                      onSearch: () {},
                    ),
                    Focus(focusNode: elsewhere, child: const SizedBox.shrink()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });
  // Source WorkspaceStrip + @dnd-kit/core6.3.1/sortable10: distance6,
  // horizontal/parent restriction, scale110 overlay, opacity30 placeholder,
  // neighbours ease200ms, drop ease250ms; ordinary release never switches.
  for (final platform in [TargetPlatform.linux, TargetPlatform.android]) {
    testWidgets(
      '$platform drag floats, clamps and slides neighbours, then drops',
      (t) async {
        final h = Harness();
        await h.mount(t);
        final before = paintRect(t, item('b'));
        final last = paintRect(t, item('c'));
        final pointer = await t.startGesture(
          before.center,
          kind: platform == TargetPlatform.android
              ? PointerDeviceKind.touch
              : PointerDeviceKind.mouse,
        );
        await pointer.moveBy(const Offset(5, 0));
        await t.pump();
        expect(floating, findsNothing, reason: 'a click stays a click below6');
        await pointer.moveBy(const Offset(1000, 40));
        await t.pump();
        expect(floating, findsOneWidget);
        final overlay = paintRect(t, floating);
        expect(overlay.width, closeTo(35.2, .001));
        expect(overlay.center.dx, closeTo(last.center.dx, .001));
        expect(
          overlay.center.dy,
          closeTo(before.center.dy, .001),
          reason: 'horizontal restriction',
        );
        await t.pump(const Duration(milliseconds: 100));
        final middle = paintRect(t, item('c')).left;
        expect(middle, greaterThan(last.left - 36));
        expect(
          middle,
          lessThan(last.left),
          reason: 'neighbour visibly slides, not just callback',
        );
        await t.pump(const Duration(milliseconds: 101));
        expect(paintRect(t, item('c')).left, closeTo(last.left - 36, .001));
        await pointer.moveTo(before.center + const Offset(24, 30));
        await t.pump();
        final released = paintRect(t, floating);
        await pointer.up();
        await t.pump();
        expect(h.order, ['a', 'c', 'b']);
        expect(h.moves, [
          [1, 2],
        ]);
        expect(h.picks, 0);
        expect(
          floating,
          findsOneWidget,
          reason: 'overlay survives release for drop',
        );
        await t.pump(const Duration(milliseconds: 100));
        expect(paintRect(t, floating).left, greaterThan(released.left));
        expect(paintRect(t, floating).left, lessThan(last.left - 1.6));
        await t.pumpAndSettle();
        expect(floating, findsNothing);
        expect(paintRect(t, item('b')).left, closeTo(last.left, .001));
        await t.tap(item('b'));
        expect(h.picks, 1, reason: 'a later real click is accepted');
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets(
      '$platform pointer Escape is received when focus is elsewhere',
      (t) async {
        final h = Harness();
        await h.mount(
          t,
          size: platform == TargetPlatform.android
              ? const Size(856, 944)
              : const Size(1280, 800),
        );
        final pointer = await t.startGesture(
          t.getCenter(item('b')),
          kind: platform == TargetPlatform.android
              ? PointerDeviceKind.touch
              : PointerDeviceKind.mouse,
        );
        await pointer.moveBy(const Offset(30, 0));
        await t.pump();
        expect(floating, findsOneWidget);
        h.elsewhere.requestFocus();
        await t.pump();
        expect(h.elsewhere.hasFocus, isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(
          floating,
          findsNothing,
          reason:
              'Source PointerSensor listens on document, independent of focus',
        );
        await pointer.up();
        await t.pumpAndSettle();
        expect(h.moves, isEmpty);
        expect(h.picks, 0);
        await t.tap(item('b'));
        expect(h.picks, 1);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
  testWidgets(
    'one sortable head with an outside current is an ordinary button',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(856, 944);
      addTearDown(t.view.reset);
      final menu = RaftMenuController();
      addTearDown(menu.dispose);
      var picks = 0;
      final moves = <List<int>>[];
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 150,
                child: RaftServerSwitcher(
                  controller: menu,
                  workspaceName: 'C',
                  label: 'Switch',
                  topBar: true,
                  rows: [
                    for (final id in ['a', 'b', 'c'])
                      RaftServerMenuRow(
                        id: id,
                        name: id.toUpperCase(),
                        slug: id,
                        current: id == 'c',
                        onSelected: () => picks++,
                      ),
                  ],
                  actions: const [],
                  onReorder: (from, to) => moves.add([from, to]),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(item('a'), findsOneWidget);
      expect(item('b'), findsNothing);
      expect(
        item('c'),
        findsOneWidget,
        reason: 'outside current is separated from head',
      );
      final pointer = await t.startGesture(
        t.getCenter(item('a')),
        kind: PointerDeviceKind.mouse,
      );
      await pointer.moveBy(const Offset(7, 0));
      await t.pump();
      expect(
        floating,
        findsNothing,
        reason: 'Source disables sorting when head length is1',
      );
      await pointer.up();
      await t.pumpAndSettle();
      expect(moves, isEmpty);
      expect(picks, 1);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  testWidgets(
    'pointer Escape/cancel preserve order and unmount removes overlay',
    (t) async {
      final h = Harness();
      await h.mount(t);
      final before = paintRect(t, item('b'));
      for (final dx in [-7.0, -30.0]) {
        final pointer = await t.startGesture(
          before.center,
          kind: PointerDeviceKind.mouse,
        );
        await pointer.moveBy(Offset(dx, 0));
        await t.pump();
        expect(floating, findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(floating, findsNothing);
        await pointer.up();
        expect(h.moves, isEmpty);
        expect(h.order, ['a', 'b', 'c']);
        expect(
          h.picks,
          0,
          reason: 'Escape must consume even a drag below tap slop',
        );
      }
      final next = await t.startGesture(
        before.center,
        kind: PointerDeviceKind.mouse,
      );
      await next.moveBy(const Offset(30, 0));
      await t.pump();
      await next.cancel();
      await t.pumpAndSettle();
      expect(floating, findsNothing);
      expect(h.moves, isEmpty);
      final last = await t.startGesture(
        before.center,
        kind: PointerDeviceKind.mouse,
      );
      await last.moveBy(const Offset(30, 0));
      await t.pump();
      await t.pumpWidget(const SizedBox.shrink());
      await last.cancel();
      expect(floating, findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  testWidgets(
    'keyboard overlay follows slots and reduced motion drops immediately',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        final h = Harness();
        await h.mount(t, reducedMotion: true);
        await t.tap(item('b'));
        final before = paintRect(t, item('b'));
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(floating, findsOneWidget);
        expect(find.bySemanticsLabel('Picked up B.'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await t.pump();
        expect(
          paintRect(t, floating).center.dx,
          closeTo(before.center.dx - 36, .001),
        );
        expect(find.bySemanticsLabel('B is over A.'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(floating, findsNothing);
        expect(h.moves, isEmpty);
        expect(find.bySemanticsLabel('Moving B cancelled.'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(h.moves, [
          [1, 0],
        ]);
        expect(floating, findsNothing);
        expect(h.picks, 1, reason: 'keyboard drag adds no workspace selection');
        await t.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
