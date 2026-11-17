// The generic selection bar (raft-ui 0.95.3 SelectionToolbar + Dock): count,
// actions, More, x; what does not fit gives way in a fixed order.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/task_page_previews.dart';

class _Log {
  final events = <String>[];
}

List<RaftSelectionBarAction> _actions(_Log log) => [
  RaftSelectionBarAction(
    id: 'status',
    label: 'Status',
    glyph: RaftGlyph.circleDot,
    menuEntries: [
      RaftMenuEntry(label: 'Todo', onPressed: () => log.events.add('todo')),
      RaftMenuEntry(label: 'Done', onPressed: () => log.events.add('done')),
    ],
    moreEntries: [
      RaftMenuEntry(
        label: 'Status: Todo',
        onPressed: () => log.events.add('more-todo'),
      ),
    ],
  ),
  RaftSelectionBarAction(
    id: 'assignee',
    label: 'Assignee',
    glyph: RaftGlyph.user,
    onOpen: (anchor) => log.events.add('assignee'),
    moreEntries: [
      RaftMenuEntry(
        label: 'Assign to me',
        onPressed: () => log.events.add('more-assign'),
      ),
    ],
  ),
  RaftSelectionBarAction(
    id: 'follow',
    label: 'Follow',
    glyph: RaftGlyph.followThread,
    secondary: true,
    onPressed: () => log.events.add('follow'),
  ),
  RaftSelectionBarAction(
    id: 'delete',
    label: 'Delete',
    glyph: RaftGlyph.trash2,
    secondary: true,
    onPressed: () => log.events.add('delete'),
  ),
];

Future<void> _mount(
  WidgetTester t, {
  required double width,
  required _Log log,
  bool touch = false,
  bool dark = false,
  double textScale = 1,
}) async {
  // The window stays a desktop (or touch) window; the bar is fitted to the
  // width it floats in, as beside an open task.
  t.view.physicalSize = const Size(1200, 600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(1200, 600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: RaftInteractionScope(
          interaction: touch
              ? RaftInteraction.touchMode
              : RaftInteraction.pointerMode,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: width,
                height: 600,
                child: Stack(
                  children: [
                    RaftSelectionBarDock(
                      child: RaftSelectionBar(
                        count: 3,
                        semanticLabel: 'Selected tasks',
                        actions: _actions(log),
                        onClear: () => log.events.add('clear'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // The fit measures every form of every item in the frame it lays out in,
  // and fits in the next.
  await t.pump();
  await t.pump();
}

Finder _action(String id) => find.byKey(ValueKey('selection-bar-action-$id'));
Finder get _more => find.byKey(const ValueKey('selection-bar-more'));
Finder get _clear => find.byKey(const ValueKey('selection-bar-clear'));

/// Whether the action's label is painted on its button.
bool _labelled(WidgetTester t, String id, String label) => find
    .descendant(of: _action(id), matching: find.text(label))
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('wide: the count, every action with its label, no More, x', (
    t,
  ) async {
    final log = _Log();
    await _mount(t, width: 1200, log: log);
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('selection-bar-count')), findsOneWidget);
    expect(find.textContaining('3 selected', findRichText: true), findsOne);
    for (final (id, label) in [
      ('status', 'Status'),
      ('assignee', 'Assignee'),
      ('follow', 'Follow'),
      ('delete', 'Delete'),
    ]) {
      expect(_action(id), findsOneWidget, reason: id);
      expect(_labelled(t, id, label), isTrue, reason: id);
    }
    expect(_more, findsNothing);
    expect(_clear, findsOneWidget);
  });

  testWidgets('the steps, in order: secondary actions into More (the last '
      'first), then the labels, then the other actions into More', (t) async {
    final log = _Log();
    // [follow, delete present, labelled] -> ... -> only x.
    final seen = <String>[];
    for (var w = 1200.0; w >= 160; w -= 8) {
      await _mount(t, width: w, log: log);
      expect(t.takeException(), isNull, reason: 'width $w');
      String state() {
        final present = [
          for (final id in ['status', 'assignee', 'follow', 'delete'])
            if (_action(id).evaluate().isNotEmpty) id,
        ];
        final labelled = [
          for (final (id, l) in [
            ('status', 'Status'),
            ('assignee', 'Assignee'),
            ('follow', 'Follow'),
            ('delete', 'Delete'),
          ])
            if (present.contains(id) && _labelled(t, id, l)) id,
        ];
        return '${present.join(',')}|${labelled.length}|${_more.evaluate().isNotEmpty}';
      }

      final s = state();
      if (seen.isEmpty || seen.last != s) seen.add(s);
    }
    // Delete (the last secondary) leaves first, then Follow; then labels go
    // (all at once here: one group, one order number); then Assignee, then
    // Status; More shows from the first step on.
    expect(seen, [
      'status,assignee,follow,delete|4|false',
      'status,assignee,follow|3|true',
      'status,assignee|2|true',
      'status,assignee|0|true',
      'status|0|true',
      '|0|true',
    ]);
  });

  testWidgets('More lists what gave way, in order, and runs it', (t) async {
    final log = _Log();
    await _mount(t, width: 600, log: log);
    expect(_action('delete'), findsNothing);
    await t.tap(_more);
    await t.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('Follow')).dy,
      lessThan(t.getTopLeft(find.text('Delete')).dy),
    );
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(log.events, ['delete']);
  });

  testWidgets('a menu action opens its entries upward and runs one', (t) async {
    final log = _Log();
    await _mount(t, width: 1200, log: log);
    final trigger = t.getRect(_action('status'));
    await t.tap(_action('status'));
    await t.pumpAndSettle();
    expect(find.text('Todo'), findsOneWidget);
    expect(t.getRect(find.text('Todo')).bottom, lessThan(trigger.top));
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(log.events, ['done']);
  });

  testWidgets('an opener action hands the app its anchor', (t) async {
    final log = _Log();
    await _mount(t, width: 1200, log: log);
    await t.tap(_action('assignee'));
    expect(log.events, ['assignee']);
  });

  testWidgets('x clears, and so does Escape inside the bar', (t) async {
    final log = _Log();
    await _mount(t, width: 1200, log: log);
    await t.tap(_clear);
    expect(log.events, ['clear']);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(log.events, ['clear', 'clear']);
  });

  testWidgets('one Tab stop with the arrow keys inside, x last', (t) async {
    final log = _Log();
    await _mount(t, width: 1200, log: log);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(log.events, ['assignee']);
    for (var i = 0; i < 3; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(log.events.last, 'clear');
  });

  testWidgets('it is a named toolbar and the count is a live region', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final log = _Log();
    await _mount(t, width: 1200, log: log);
    expect(find.bySemanticsLabel(RegExp('^Selected tasks')), findsOneWidget);
    expect(find.bySemanticsLabel('Clear selection (Esc)'), findsOneWidget);
    final count = find.bySemanticsLabel('3 selected');
    expect(count, findsOneWidget);
    expect(t.getSemantics(count).flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('by touch: icons alone in 44px buttons, no tooltips', (t) async {
    final log = _Log();
    await _mount(t, width: 700, log: log, touch: true);
    expect(_labelled(t, 'status', 'Status'), isFalse);
    expect(t.getSize(_action('status')).height, 44);
    expect(t.getSize(_clear).height, 44);
    expect(t.getSize(find.byKey(const ValueKey('selection-bar'))).height, 56);
  });

  for (final dark in [false, true]) {
    testWidgets('${dark ? 'dark' : 'light'}: the popover surface with a seam '
        'ring', (t) async {
      final log = _Log();
      await _mount(t, width: 1200, log: log, dark: dark);
      final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
      final deco =
          t
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('selection-bar')),
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.color, tokens.colors['layer-popover']);
      expect(
        deco.boxShadow!.any(
          (s) => s.color == tokens.colors['line-seam'] && s.spreadRadius == 1,
        ),
        isTrue,
      );
      // With a mouse the bar is a 44px header tall, centred 12px above the
      // bottom.
      final rect = t.getRect(find.byKey(const ValueKey('selection-bar')));
      expect(rect.height, 44);
      expect(600 - rect.bottom, 12);
      expect(rect.center.dx, 1200 / 2);
    });
  }

  testWidgets('text scale 2x: the bar grows and still fits one row', (t) async {
    final log = _Log();
    for (final scale in [1.0, 2.0]) {
      await _mount(t, width: 700, log: log, textScale: scale);
      expect(t.takeException(), isNull, reason: '${scale}x');
    }
    expect(_clear, findsOneWidget);
  });

  testWidgets('the previews build at their widths', (t) async {
    t.view.physicalSize = const Size(1200, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final build in [
      selectionBarWidePreview,
      selectionBarMediumPreview,
      selectionBarNarrowPreview,
    ]) {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: RaftInteractionScope(
            interaction: RaftInteraction.pointerMode,
            child: Scaffold(body: build()),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      expect(t.takeException(), isNull);
      expect(_clear, findsOneWidget);
    }
  });
}
