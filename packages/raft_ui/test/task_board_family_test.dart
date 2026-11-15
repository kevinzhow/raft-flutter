import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The task-board family at raft-ui 0.95.3 (Web v1.24): TaskBoardColumn,
/// TaskSection, TaskBoardColumnEmpty / TaskSectionEmpty, the status pixel and
/// TaskChip, and the TaskCard open button. Raft look only; the frozen looks
/// keep their own drawing.
Future<void> _mount(
  WidgetTester t,
  Widget child, {
  Size size = const Size(1000, 800),
  TargetPlatform platform = TargetPlatform.linux,
  bool dark = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  await t.pump(const Duration(seconds: 1));
}

RaftTokens _tokens(WidgetTester t, Finder f) => RaftTokens.of(t.element(f));

Widget _column({
  bool collapsed = false,
  bool dropActive = false,
  String? blocked,
  VoidCallback? onToggle,
  Widget? body,
}) => RaftTaskBoardColumn(
  status: 'todo',
  count: '0',
  collapsed: collapsed,
  dropActive: dropActive,
  dropBlockedLabel: blocked,
  triggerKey: const ValueKey('trigger'),
  onToggle: onToggle ?? () {},
  body: body ?? const RaftTaskLaneEmpty(board: true, label: 'No Todo tasks'),
);

void main() {
  group('TaskBoardColumn', () {
    testWidgets('trigger is 34px with a mouse from 768px, 32px by touch', (
      t,
    ) async {
      await _mount(t, _column());
      expect(t.getSize(find.byKey(const ValueKey('trigger'))).height, 34);
      await _mount(t, _column(), platform: TargetPlatform.android);
      expect(t.getSize(find.byKey(const ValueKey('trigger'))).height, 32);
      await _mount(t, _column(), size: const Size(600, 800));
      expect(t.getSize(find.byKey(const ValueKey('trigger'))).height, 32);
    });

    testWidgets('the heading always has the chevron, right while collapsed', (
      t,
    ) async {
      double turns() => t
          .widget<AnimatedRotation>(
            find.descendant(
              of: find.byKey(const ValueKey('trigger')),
              matching: find.byType(AnimatedRotation),
            ),
          )
          .turns;
      await _mount(t, _column());
      final chevron = find.byWidgetPredicate(
        (w) => w is RaftIcon && w.glyph == RaftGlyph.chevronDown,
      );
      expect(chevron, findsOneWidget);
      expect(t.getSize(chevron), const Size(14, 14));
      expect(turns(), 0);
      // `justify-between`: the chevron ends the 232px trigger row.
      final trigger = t.getRect(find.byKey(const ValueKey('trigger')));
      expect(trigger.width, 232);
      expect(t.getRect(chevron).right, trigger.right);
      expect(
        t.widget<RaftIcon>(chevron).color,
        _tokens(t, chevron).ui.foregroundHint,
      );
      await _mount(t, _column(collapsed: true));
      expect(turns(), -.25);
    });

    testWidgets('count is foreground-hint mono-meta; label foreground-muted', (
      t,
    ) async {
      await _mount(t, _column());
      final tokens = _tokens(t, find.text('0'));
      final count = t.widget<Text>(find.text('0')).style!;
      expect(count.color, tokens.ui.foregroundHint);
      expect(count.fontSize, 12);
      expect(count.fontFamily, tokens.monoFont);
      final label = t.widget<RichText>(
        find.descendant(
          of: find.byType(RaftTaskSectionBadge),
          matching: find.byType(RichText),
        ),
      );
      expect(label.text.style!.color, tokens.ui.foregroundMuted);
    });

    testWidgets('trigger is a Tab stop that Enter toggles, with the ring', (
      t,
    ) async {
      var toggles = 0;
      await _mount(t, _column(onToggle: () => toggles++));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final ring = find.descendant(
        of: find.byKey(const ValueKey('trigger')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
        ),
      );
      expect(ring, findsOneWidget);
      expect(
        (t.widget<DecoratedBox>(ring).decoration as BoxDecoration).boxShadow,
        _tokens(t, ring).focusShadows,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(toggles, 1);
    });

    testWidgets('drop allowed: no fill, the empty box goes away', (t) async {
      await _mount(t, _column(dropActive: true));
      expect(find.text('No Todo tasks'), findsNothing);
      // "The column itself never changes fill" (Web v1.24 BoardColumn); it
      // used to take `fill-pressed`.
      final pressed = _tokens(
        t,
        find.byType(RaftTaskBoardColumn),
      ).colors['fill-pressed'];
      expect(
        find.descendant(
          of: find.byType(RaftTaskBoardColumn),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == pressed,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('drop blocked: the empty box says why, in foreground-muted', (
      t,
    ) async {
      await _mount(t, _column(blocked: "Can't move to Todo"));
      expect(find.text('No Todo tasks'), findsNothing);
      final text = find.text("Can't move to Todo");
      expect(text, findsOneWidget);
      expect(
        t
            .widget<RichText>(
              find.descendant(of: text, matching: find.byType(RichText)),
            )
            .text
            .style!
            .color,
        _tokens(t, text).ui.foregroundMuted,
      );
    });

    testWidgets('collapsed with a card over it: the dashed outline', (t) async {
      CustomPaint? outline() => t
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(RaftTaskBoardColumn),
              matching: find.byType(CustomPaint),
            ),
          )
          .where((p) => p.foregroundPainter != null)
          .firstOrNull;
      await _mount(t, _column(collapsed: true));
      expect(outline(), isNull);
      await _mount(t, _column(collapsed: true, dropActive: true));
      expect(outline(), isNotNull);
    });
  });

  group('TaskSection', () {
    Widget section({VoidCallback? onToggle}) => RaftTaskSection(
      status: 'in_progress',
      count: 3,
      triggerKey: const ValueKey('trigger'),
      onToggle: onToggle,
      emptyLabel: 'No In progress tasks',
      children: const [],
    );

    testWidgets('trigger 34px with a mouse, 32px by touch; count in hint', (
      t,
    ) async {
      await _mount(t, SizedBox(width: 600, child: section(onToggle: () {})));
      expect(t.getSize(find.byKey(const ValueKey('trigger'))).height, 34);
      final tokens = _tokens(t, find.text('3'));
      expect(
        t.widget<Text>(find.text('3')).style!.color,
        tokens.ui.foregroundHint,
      );
      await _mount(
        t,
        SizedBox(width: 600, child: section(onToggle: () {})),
        platform: TargetPlatform.android,
      );
      expect(t.getSize(find.byKey(const ValueKey('trigger'))).height, 32);
    });

    testWidgets('a trigger with no toggle is not a Tab stop', (t) async {
      await _mount(t, SizedBox(width: 600, child: section()));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trigger')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                (w.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
          ),
        ),
        findsNothing,
      );
    });
  });

  group('lane empty box', () {
    for (final board in [false, true]) {
      testWidgets('${board ? 'board' : 'list'}: 0.95.3 dashed box', (t) async {
        await _mount(
          t,
          SizedBox(
            width: 232,
            child: RaftTaskLaneEmpty(board: board, label: 'No Done tasks'),
          ),
        );
        final box = find.byType(RaftTaskLaneEmpty);
        // `min-h-16 py-3`: 64px for one line.
        expect(t.getSize(box), const Size(232, 64));
        final tokens = _tokens(t, box);
        final text = find.text('No Done tasks');
        final style = t
            .widget<RichText>(
              find.descendant(of: text, matching: find.byType(RichText)),
            )
            .text
            .style!;
        expect(style.color, tokens.ui.foregroundHint);
        // text-footnote on desktop (12/18).
        expect(style.fontSize, 12);
        // `justify-center text-center`.
        expect(t.getCenter(text).dx, closeTo(t.getCenter(box).dx, .5));
        expect(t.getCenter(text).dy, closeTo(t.getCenter(box).dy, .5));
      });
    }
  });

  group('status pixel and TaskChip', () {
    testWidgets('pixel is 10px; Backlog hollow with a line-strong edge', (
      t,
    ) async {
      await _mount(
        t,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftMessageTaskStatusIcon(
              key: ValueKey('todo'),
              status: RaftMessageTaskStatus.todo,
              color: Colors.black,
            ),
            RaftMessageTaskStatusIcon(
              key: ValueKey('backlog'),
              status: RaftMessageTaskStatus.backlog,
              color: Colors.black,
            ),
          ],
        ),
      );
      for (final key in ['todo', 'backlog']) {
        final icon = find.byKey(ValueKey(key));
        expect(t.getSize(icon), const Size(10, 10), reason: key);
        final square = t.widget<Container>(
          find.descendant(of: icon, matching: find.byType(Container)),
        );
        final d = square.decoration! as BoxDecoration;
        expect(square.constraints!.maxWidth, 10, reason: key);
        if (key == 'backlog') {
          expect(d.color, isNull);
          expect(
            (d.border! as Border).top.color,
            _tokens(t, icon).colors['line-strong'],
          );
        }
      }
    });

    testWidgets('TaskChip default is 22px high with px-[7px]', (t) async {
      await _mount(
        t,
        const RaftTaskStatusBadge(
          status: RaftMessageTaskStatus.done,
          label: 'Done',
        ),
      );
      final chip = find.byType(RaftTaskStatusBadge);
      expect(t.getSize(chip).height, 22);
      final icon = find.byType(RaftMessageTaskStatusIcon);
      expect(t.getRect(icon).left - t.getRect(chip).left, 7);
      final label = find.text('Done');
      expect(t.getRect(chip).right - t.getRect(label).right, 7);
      // gap-1.5 after the 10px pixel.
      expect(t.getRect(label).left - t.getRect(icon).right, 6);
    });
  });

  group('TaskCard', () {
    testWidgets('the open area is a Tab stop that Enter opens', (t) async {
      var opened = 0;
      await _mount(
        t,
        SizedBox(
          width: 280,
          child: RaftTaskCard(
            title: 'Ship the board',
            number: '12',
            status: 'todo',
            onTap: () => opened++,
          ),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final ring = find.descendant(
        of: find.byType(RaftTaskCard),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
        ),
      );
      expect(ring, findsOneWidget);
      expect(
        t.getRect(find.text('Ship the board')).overlaps(t.getRect(ring)),
        isTrue,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(opened, 1);
    });
  });
}
