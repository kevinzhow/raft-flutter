import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/section_pager_previews.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'preview paging retains editor and scroll ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(390, 600);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final capture = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RepaintBoundary(key: capture, child: sectionPagerPreview()),
            ),
          ),
        );
        await t.pumpAndSettle();
        final editor = find.byKey(const Key('section-preview-draft'));
        await t.enterText(editor, '中文 draft');
        final state = t.state(editor);
        await t.drag(find.byType(PageView), const Offset(-300, 0));
        await t.pumpAndSettle();
        final pager = find.byType(RaftSectionPager<String>);
        expect(t.widget<RaftSectionPager<String>>(pager).value, 'Tasks');
        final tasks = find.byKey(const PageStorageKey('Tasks'));
        await t.drag(tasks, const Offset(0, -300));
        await t.pumpAndSettle();
        final taskScroll = t
            .state<ScrollableState>(
              find
                  .descendant(of: tasks, matching: find.byType(Scrollable))
                  .first,
            )
            .position
            .pixels;
        expect(taskScroll, greaterThan(100));
        final tabs = find.byType(RaftPanelTabBar<String>);
        await t.tap(find.descendant(of: tabs, matching: find.text('Chat')));
        await t.pumpAndSettle();
        expect(t.state(editor), same(state));
        expect(find.text('中文 draft'), findsOneWidget);
        await t.tap(find.descendant(of: tabs, matching: find.text('Tasks')));
        await t.pumpAndSettle();
        expect(
          t
              .state<ScrollableState>(
                find
                    .descendant(of: tasks, matching: find.byType(Scrollable))
                    .first,
              )
              .position
              .pixels,
          taskScroll,
        );
        await t.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final picture = await boundary.toImage();
          final png = await picture.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '../../.local/section-pager/${dark ? 'dark' : 'light'}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
          picture.dispose();
        });
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'drag frames retain accepted section and do not mount or rebuild bodies',
    (t) async {
      t.view.physicalSize = const Size(390, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var value = 'a';
      final changes = <String>[];
      final builds = <String, int>{};
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return RaftSectionPager<String>(
                  sections: const ['a', 'b', 'c'],
                  value: value,
                  onChanged: (next) {
                    changes.add(next);
                    setState(() => value = next);
                  },
                  builder: (_, id) {
                    builds.update(id, (n) => n + 1, ifAbsent: () => 1);
                    return Text('content-$id');
                  },
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final before = Map.of(builds);
      final gesture = await t.startGesture(const Offset(360, 300));
      await gesture.moveBy(const Offset(-250, 0));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(value, 'a');
        expect(changes, isEmpty);
        expect(builds, before);
      }
      await gesture.up();
      await t.pumpAndSettle();
      expect(value, 'b');
      expect(changes, ['b']);
      expect(builds, contains('b'));

      // A canceled drag crossing the threshold never changes the business tab.
      final canceled = await t.startGesture(const Offset(360, 300));
      await canceled.moveBy(const Offset(-250, 0));
      await t.pump(const Duration(milliseconds: 16));
      await canceled.moveBy(const Offset(250, 0));
      await t.pump(const Duration(milliseconds: 200));
      await canceled.up();
      await t.pumpAndSettle();
      expect(value, 'b');
      expect(changes, ['b']);
      expect(builds, isNot(contains('c')));

      // A route/tab change while a gesture is held remains authoritative.
      final interrupted = await t.startGesture(const Offset(360, 300));
      await interrupted.moveBy(const Offset(250, 0));
      await t.pump(const Duration(milliseconds: 16));
      update(() => value = 'c');
      await t.pump();
      await interrupted.up();
      await t.pumpAndSettle();
      expect(value, 'c');
      expect(changes, ['b']);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'unvisited sections do not mount; distant click skips intermediate reads',
    (t) async {
      var value = 'a';
      final built = <String>{};
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return RaftSectionPager<String>(
                  sections: const ['a', 'b', 'c', 'd'],
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                  builder: (_, id) {
                    built.add(id);
                    return Text(id);
                  },
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(built, {'a'});
      update(() => value = 'd');
      await t.pumpAndSettle();
      expect(value, 'd');
      expect(built, {'a', 'd'});
      await t.drag(find.byType(PageView), const Offset(600, 0));
      await t.pumpAndSettle();
      expect(value, 'c');
      expect(built, contains('c'));
      expect(built, isNot(contains('b')));
    },
  );

  testWidgets(
    'reordered and revoked sections follow accepted selection; desktop rejects swipe',
    (t) async {
      var sections = ['a', 'b', 'c'];
      var value = 'b', enabled = true;
      late StateSetter update;
      final disposed = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return RaftSectionPager<String>(
                  sections: sections,
                  value: value,
                  swipeEnabled: enabled,
                  onChanged: (next) => setState(() => value = next),
                  builder: (_, id) => _Lifetime(id, disposed),
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      update(() => sections = ['c', 'b', 'a']);
      await t.pumpAndSettle();
      expect(value, 'b');
      update(() {
        sections = ['c', 'a'];
        value = 'a';
      });
      await t.pumpAndSettle();
      expect(disposed, contains('b'));
      expect(value, 'a');
      update(() => enabled = false);
      await t.pumpAndSettle();
      await t.drag(find.byType(PageView), const Offset(600, 0));
      await t.pumpAndSettle();
      expect(value, 'a');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard and semantic actions select; horizontal child owns its gesture',
    (t) async {
      var value = 'a';
      final semantics = t.ensureSemantics();

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => RaftSectionPager<String>(
                sections: const ['a', 'b'],
                value: value,
                onChanged: (next) => setState(() => value = next),
                builder: (_, id) => Focus(
                  autofocus: true,
                  child: Column(
                    children: [
                      Text('visible-$id'),
                      SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: const [
                            SizedBox(width: 2000, child: Text('wide content')),
                          ],
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
      await t.drag(find.byType(ListView), const Offset(-400, 0));
      await t.pumpAndSettle();
      expect(value, 'a');
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(value, 'b');
      expect(find.bySemanticsLabel('visible-a'), findsNothing);
      expect(find.bySemanticsLabel('visible-b'), findsOneWidget);
      final node = t.getSemantics(
        find
            .byWidgetPredicate(
              (w) => w is Semantics && w.properties.onDecrease != null,
            )
            .first,
      );
      t.binding.platformDispatcher.onSemanticsActionEvent!(
        ui.SemanticsActionEvent(
          viewId: t.view.viewId,
          nodeId: node.id,
          type: ui.SemanticsAction.decrease,
        ),
      );
      await t.pumpAndSettle();
      expect(value, 'a');
      expect(t.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets('externally controlled paging has no navigation actions', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    var value = 'a';
    late StateSetter update;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return RaftSectionPager<String>(
                sections: const ['a', 'b'],
                value: value,
                onChanged: null,
                swipeEnabled: false,
                builder: (_, id) =>
                    Focus(autofocus: true, child: Text('external-$id')),
              );
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.onIncrease != null ||
                w.properties.onDecrease != null),
      ),
      findsNothing,
    );
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(value, 'a');
    update(() => value = 'b');
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('external-a'), findsNothing);
    expect(find.bySemanticsLabel('external-b'), findsOneWidget);
    expect(t.takeException(), isNull);
    semantics.dispose();
  });
}

class _Lifetime extends StatefulWidget {
  const _Lifetime(this.id, this.disposed);
  final String id;
  final List<String> disposed;
  @override
  State<_Lifetime> createState() => _LifetimeState();
}

class _LifetimeState extends State<_Lifetime> {
  @override
  void dispose() {
    widget.disposed.add(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.id);
}
