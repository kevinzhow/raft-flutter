// The Tasks page's task rows (Web TaskChipList variant="page" + TaskRowSelection,
// compactRow.ts): the check box in a left gutter, the selection gestures, the
// selected / current cell fill, the trailing group wrapping, text scale.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _rows = [
  RaftTaskChipRow(
    id: 'a',
    number: 11,
    title: 'Write the notes',
    status: 'todo',
    assigneeName: 'Bob',
    ref: '#design:#11',
    channelName: 'design',
    replyCount: 2,
  ),
  RaftTaskChipRow(
    id: 'b',
    number: 12,
    title: 'Park the rest',
    status: 'backlog',
    ref: '#design:#12',
    channelName: 'design',
  ),
  RaftTaskChipRow(
    id: 'c',
    number: 13,
    title: 'Ship it',
    status: 'done',
    ref: '#ops:#13',
    channelName: 'ops',
  ),
];

class _Picks {
  final opened = <String>[];
  final picked = <(String, bool)>[];
}

Future<void> _mount(
  WidgetTester t, {
  required _Picks picks,
  double width = 900,
  bool dark = false,
  bool touch = false,
  bool selecting = false,
  Set<String> selected = const {},
  String? current,
  bool showChannel = false,
  bool showUnassigned = false,
  double textScale = 1,
  List<RaftTaskChipRow> rows = _rows,
}) async {
  t.view.physicalSize = Size(width + 40, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  Widget list = RaftTaskPageList(
    tasks: rows,
    onOpen: (r) => picks.opened.add(r.id),
    showChannel: showChannel,
    showUnassigned: showUnassigned,
    unassignedLabel: 'Unassigned',
    currentTaskId: current,
    selection: RaftTaskRowSelection(
      selecting: selecting,
      isSelected: selected.contains,
      onSelect: (r, {required range}) => picks.picked.add((r.id, range)),
    ),
  );
  list = RaftInteractionScope(
    interaction: touch
        ? RaftInteraction.touchMode
        : RaftInteraction.pointerMode,
    child: list,
  );
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width + 40, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: list),
          ),
        ),
      ),
    ),
  );
  await t.pump();
}

Finder _row(String id) => find.byKey(ValueKey('tasks-page-row-$id'));
Finder _open(String id) => find.byKey(ValueKey('tasks-page-row-open-$id'));
Finder _box(String id) => find.byKey(ValueKey('tasks-page-row-select-$id'));

double _boxOpacity(WidgetTester t, String id) => t
    .widget<Opacity>(
      find.ancestor(of: _box(id), matching: find.byType(Opacity)).first,
    )
    .opacity;

Color? _fill(WidgetTester t, String id) {
  final box = t.widget<DecoratedBox>(
    find.byKey(ValueKey('tasks-page-row-cell-$id')),
  );
  return (box.decoration as BoxDecoration).color;
}

Future<void> _tapWith(
  WidgetTester t,
  Finder at,
  List<LogicalKeyboardKey> keys,
) async {
  for (final k in keys) {
    await t.sendKeyDownEvent(k);
  }
  await t.tap(at);
  await t.pump();
  for (final k in keys.reversed) {
    await t.sendKeyUpEvent(k);
  }
}

void main() {
  testWidgets('a page row: the number, the title, the reply count, no chevron '
      'and the row key', (t) async {
    final p = _Picks();
    await _mount(t, picks: p);
    expect(_row('a'), findsOneWidget);
    expect(find.text('#11'), findsOneWidget);
    expect(find.text('Write the notes'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-task-chip-replies')), findsOne);
    await t.tap(_open('a'));
    expect(p.opened, ['a']);
    expect(p.picked, isEmpty);
  });

  testWidgets('with a pointer the box shows on hover only, and always while '
      'selecting or on a selected row', (t) async {
    final p = _Picks();
    await _mount(t, picks: p);
    expect(_boxOpacity(t, 'a'), 0);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(t.getCenter(_open('a')));
    await t.pump();
    expect(_boxOpacity(t, 'a'), 1);
    expect(_boxOpacity(t, 'b'), 0);
    await mouse.moveTo(const Offset(500, 800));
    await t.pump();
    expect(_boxOpacity(t, 'a'), 0);

    await _mount(t, picks: p, selecting: true, selected: {'b'});
    expect(_boxOpacity(t, 'a'), 1);
    expect(_boxOpacity(t, 'c'), 1);
    await _mount(t, picks: p, selected: {'b'});
    expect(_boxOpacity(t, 'b'), 1);
  });

  testWidgets('the box is not mounted by touch until something is selected', (
    t,
  ) async {
    final p = _Picks();
    await _mount(t, picks: p, touch: true);
    expect(_box('a'), findsNothing);
    await _mount(t, picks: p, touch: true, selecting: true);
    expect(_box('a'), findsOneWidget);
  });

  testWidgets('Cmd-click and Ctrl-click toggle, Shift-click asks for a range, '
      'none of them opens', (t) async {
    final p = _Picks();
    await _mount(t, picks: p);
    await _tapWith(t, _open('a'), [LogicalKeyboardKey.metaLeft]);
    await _tapWith(t, _open('b'), [LogicalKeyboardKey.controlLeft]);
    await _tapWith(t, _open('c'), [LogicalKeyboardKey.shiftLeft]);
    expect(p.picked, [('a', false), ('b', false), ('c', true)]);
    expect(p.opened, isEmpty);
  });

  testWidgets('while selecting a tap toggles instead of opening, the gutter '
      'included', (t) async {
    final p = _Picks();
    await _mount(t, picks: p, selecting: true, selected: {'a'});
    await t.tap(_open('b'));
    await t.tapAt(t.getTopLeft(_row('c')) + const Offset(2, 20));
    expect(p.picked, [('b', false), ('c', false)]);
    expect(p.opened, isEmpty);
  });

  testWidgets('the box toggles its row (Shift: a range) and never opens', (
    t,
  ) async {
    final p = _Picks();
    await _mount(t, picks: p, selecting: true);
    await t.tap(_box('a'));
    await _tapWith(t, _box('c'), [LogicalKeyboardKey.shiftLeft]);
    expect(p.picked, [('a', false), ('c', true)]);
    expect(p.opened, isEmpty);
  });

  testWidgets('the gutter around the box opens the task when not selecting', (
    t,
  ) async {
    final p = _Picks();
    await _mount(t, picks: p);
    await t.tapAt(t.getTopLeft(_row('b')) + const Offset(2, 17));
    expect(p.opened, ['b']);
  });

  testWidgets('a long press by touch selects the row and does not open it', (
    t,
  ) async {
    final p = _Picks();
    await _mount(t, picks: p, touch: true);
    await t.longPress(_open('a'));
    await t.pump(const Duration(milliseconds: 600));
    expect(p.picked, [('a', false)]);
    expect(p.opened, isEmpty);
    // A plain tap still opens.
    await t.tap(_open('b'));
    expect(p.opened, ['b']);
  });

  testWidgets('a long press with a mouse is a slow click, not a selection', (
    t,
  ) async {
    final p = _Picks();
    await _mount(t, picks: p);
    final g = await t.startGesture(
      t.getCenter(_open('a')),
      kind: PointerDeviceKind.mouse,
    );
    await t.pump(const Duration(milliseconds: 700));
    await g.up();
    await t.pump();
    expect(p.picked, isEmpty);
    expect(p.opened, ['a']);
  });

  testWidgets('Enter and Space open the focused row', (t) async {
    final p = _Picks();
    await _mount(t, picks: p);
    // Tab: the first row's box, then its open button.
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(p.opened, ['a']);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(p.opened, ['a', 'a']);
  });

  testWidgets('the row and its box are named for a screen reader and say '
      'whether they are selected or open', (t) async {
    final handle = t.ensureSemantics();
    final p = _Picks();
    await _mount(t, picks: p, selected: {'b'}, current: 'a');
    expect(
      t.getSemantics(_box('b')),
      matchesSemantics(
        label: 'Select #12 Park the rest',
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(t.getSemantics(_box('a')).flagsCollection.isChecked.name, 'isFalse');
    final open = t.getSemantics(_open('a'));
    expect(open.label, contains('Open task #11: Write the notes'));
    expect(open.flagsCollection.isSelected.name, 'isTrue');
    expect(
      t.getSemantics(_open('b')).flagsCollection.isSelected.name,
      'isFalse',
    );
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('${dark ? 'dark' : 'light'}: a selected and the open row take '
        'the cell-selected fill, others none', (t) async {
      final p = _Picks();
      await _mount(t, picks: p, dark: dark, selected: {'b'}, current: 'a');
      final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
      expect(_fill(t, 'a'), tokens.colors['fill-cell-selected']);
      expect(_fill(t, 'b'), tokens.colors['fill-cell-selected']);
      expect(_fill(t, 'c'), isNull);
    });
  }

  testWidgets('the divider is a hairline above every row but the first', (
    t,
  ) async {
    final p = _Picks();
    await _mount(t, picks: p);
    final tokens = raftTheme().extension<RaftTokens>()!;
    BoxDecoration of(String id) =>
        t
                .widget<DecoratedBox>(
                  find.byKey(ValueKey('tasks-page-row-cell-$id')),
                )
                .decoration
            as BoxDecoration;
    expect((of('a').border! as Border).top.style, BorderStyle.none);
    final second = (of('b').border! as Border).top;
    expect(second.color, tokens.colors['line-hairline']);
    expect(second.width, 1);
  });

  testWidgets('wide: the trailing group sits at the right of the title line', (
    t,
  ) async {
    final p = _Picks();
    await _mount(t, picks: p, width: 900);
    final title = t.getRect(
      find.byKey(const ValueKey('message-task-chip-title-group')).first,
    );
    final meta = t.getRect(
      find.byKey(const ValueKey('message-task-chip-meta')).first,
    );
    expect(meta.top, lessThan(title.bottom));
    final row = t.getRect(_row('a'));
    expect(meta.right, row.right - 12);
  });

  testWidgets('narrow: the trailing group wraps, whole, onto a second line '
      'at the right', (t) async {
    final p = _Picks();
    await _mount(t, picks: p, width: 300);
    final title = t.getRect(
      find.byKey(const ValueKey('message-task-chip-title-group')).first,
    );
    final meta = t.getRect(
      find.byKey(const ValueKey('message-task-chip-meta')).first,
    );
    expect(meta.top, greaterThanOrEqualTo(title.bottom));
    expect(meta.right, t.getRect(_row('a')).right - 12);
  });

  testWidgets('across channels: the number names its channel where the list '
      'is wide; under 28rem the channel moves into the trailing group and '
      'the status keeps its pixel', (t) async {
    final p = _Picks();
    await _mount(t, picks: p, width: 600, showChannel: true);
    expect(find.text('#design:#11'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-task-chip-channel')),
      findsNothing,
    );
    expect(find.text('Todo'), findsOneWidget);

    await _mount(t, picks: p, width: 400, showChannel: true);
    expect(find.text('#design:#11'), findsNothing);
    expect(find.text('#11'), findsOneWidget);
    expect(find.text('#design'), findsNWidgets(2));
    expect(find.text('Todo'), findsNothing);
    // The status keeps its accessible name, said after the row's label.
    final handle = t.ensureSemantics();
    expect(t.getSemantics(_open('a')).value, 'Todo');
    handle.dispose();
  });

  testWidgets('unassigned rows say so where asked, assigned ones show the '
      'assignee', (t) async {
    final p = _Picks();
    await _mount(t, picks: p, showUnassigned: true);
    expect(find.text('Unassigned'), findsNWidgets(2));
    expect(find.text('Bob'), findsOneWidget);
    await _mount(t, picks: p);
    expect(find.text('Unassigned'), findsNothing);
  });

  testWidgets('page metadata labels use the same line height as the title', (
    t,
  ) async {
    await _mount(t, picks: _Picks(), showUnassigned: true);
    final row = _row('b');
    Size box(String key) => t.getSize(
      find.descendant(of: row, matching: find.byKey(ValueKey(key))),
    );
    final metadata = box('message-task-chip-unassigned').height;
    final title = box('message-task-chip-title').height;
    await t.pumpWidget(const SizedBox.shrink());
    expect(metadata, closeTo(title, .01));
  });

  testWidgets('text scale 1x and 2x: rows grow with the text, nothing '
      'overflows, the box and the title stay readable', (t) async {
    final p = _Picks();
    final heights = <double>[];
    for (final scale in [1.0, 2.0]) {
      await _mount(
        t,
        picks: p,
        width: 360,
        textScale: scale,
        selecting: true,
        showChannel: true,
        showUnassigned: true,
      );
      expect(t.takeException(), isNull, reason: '${scale}x');
      heights.add(t.getSize(_row('a')).height);
      expect(heights.last, greaterThanOrEqualTo(34));
      expect(_box('a'), findsOneWidget);
    }
    expect(heights[1], greaterThan(heights[0]));
  });
}
