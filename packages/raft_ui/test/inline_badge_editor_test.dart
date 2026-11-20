import 'dart:ui' show PointerDeviceKind, Tristate, SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const options = [
  RaftInlineBadgeOption(id: 'todo', label: 'To do'),
  RaftInlineBadgeOption(id: 'blocked', label: 'Unavailable', disabled: true),
  RaftInlineBadgeOption(id: 'done', label: 'Done'),
];
Widget host(
  Widget child, {
  bool dark = false,
  RaftDensity density = RaftDensity.desktop,
}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: RaftDensityScope(
      density: density,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'InheritedDisplay',
              fontSize: 16,
            ),
            child: child,
          ),
        ),
      ),
    ),
  ),
);
RaftInlineBadgeEditor editor({
  ValueChanged<String>? onSelect,
  bool enabled = true,
}) => RaftInlineBadgeEditor(
  label: 'Status',
  selectedId: 'todo',
  options: options,
  onSelect: onSelect ?? (_) {},
  background: Colors.yellow,
  foreground: Colors.black,
  enabled: enabled,
);
FocusNode node(WidgetTester tester, String label) => tester
    .widget<RaftInteractive>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(RaftInteractive),
      ),
    )
    .focusNode!;

void main() {
  for (final density in RaftDensity.values) {
    testWidgets(
      'assigned person ellipsizes and opens near the edge at $density',
      (tester) async {
        final touch = density == RaftDensity.touch;
        tester.view.physicalSize = const Size(856, 944);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const badgeKey = ValueKey('assignee-test-badge');
        final longName = List.filled(10, 'Workbench Assistant').join(' ');
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 200,
              child: RaftInlineBadgeEditor(
                key: badgeKey,
                personProperty: true,
                indicator: RaftGlyph.chevronDown,
                label: longName,
                selectedId: 'todo',
                options: options,
                onSelect: (_) {},
                background: Colors.transparent,
                foreground: Colors.black,
              ),
            ),
            density: density,
          ),
        );
        final badge = find.byKey(badgeKey);
        final rich = find.descendant(
          of: badge,
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(rich);
        expect(paragraph.didExceedMaxLines, isTrue);
        final arrow = find.descendant(
          of: badge,
          matching: find.byType(RaftIcon),
        );
        final bounds = tester.getRect(badge);
        final paintedBadge = find.descendant(
          of: badge,
          matching: find.byType(Container),
        );
        expect(tester.getSize(paintedBadge).height, 20);
        expect(bounds.height, touch ? 20 : 22);
        expect(tester.getRect(arrow).right, bounds.right - 6);
        final target = find.descendant(
          of: badge,
          matching: find.byType(RaftTouchTarget),
        );
        if (touch) {
          expect(
            tester.renderObject<RenderBox>(target).semanticBounds.height,
            48,
          );
          final targetBox = tester.renderObject<RenderBox>(target);
          final hitRows = [
            for (
              var y = bounds.top.floor() - 15;
              y < bounds.bottom.ceil() + 15;
              y++
            )
              if (tester
                  .hitTestOnBinding(Offset(bounds.center.dx, y + .5))
                  .path
                  .any((entry) => identical(entry.target, targetBox)))
                y,
          ];
          expect(hitRows, isNotEmpty);
          debugPrint(
            'Assignee touch hit rows: ${hitRows.first}–${hitRows.last}',
          );
        } else {
          expect(target, findsNothing);
        }
        await tester.tapAt(
          Offset(tester.getCenter(arrow).dx, bounds.bottom - 1),
          kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(find.byType(RaftInlineBadgeMenu), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(RaftInlineBadgeMenu), findsNothing);
      },
    );
  }

  for (final theme in raftThemeMatrix([(false), (true)])) {
    final (dark) = theme;
    testWidgets(
      '${dark ? 'dark' : 'light'} keyboard selects, skips disabled and restores trigger',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final selections = <String>[];
          await tester.pumpWidget(
            host(editor(onSelect: selections.add), dark: dark),
          );
          expect(
            tester.widget<Text>(find.text('Status')).style!.fontFamily,
            // raft-ui 0.7.0's Badge sets the heading family itself instead of
            // inheriting the mounted shell's.
            raftTheme(dark: dark).extension<RaftTokens>()!.headingFont,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(node(tester, 'Status').hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.byType(RaftInlineBadgeMenu), findsOneWidget);
          expect(node(tester, 'To do').hasFocus, isTrue);
          final toDo = tester.getSemantics(find.bySemanticsLabel('To do'));
          expect(toDo.getSemanticsData().role, SemanticsRole.menuItem);
          expect(toDo.flagsCollection.isFocused, Tristate.isTrue);
          expect(toDo.flagsCollection.isSelected, Tristate.isTrue);
          final disabled = tester.getSemantics(
            find.bySemanticsLabel('Unavailable'),
          );
          expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
          expect(disabled.flagsCollection.isFocused, Tristate.none);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
          expect(node(tester, 'Done').hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
          expect(node(tester, 'To do').hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pump();
          expect(node(tester, 'Done').hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(selections, ['done']);
          expect(find.byType(RaftInlineBadgeMenu), findsNothing);
          expect(node(tester, 'Status').hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expect(node(tester, 'Done').hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(RaftInlineBadgeMenu), findsNothing);
          expect(node(tester, 'Status').hasFocus, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets('pointer-open arrows and disabled pointer selection', (
    tester,
  ) async {
    final selections = <String>[];
    await tester.pumpWidget(host(editor(onSelect: selections.add)));
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unavailable'));
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
    expect(find.byType(RaftInlineBadgeMenu), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(node(tester, 'To do').hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    expect(node(tester, 'Status').hasFocus, isTrue);
  });
  testWidgets(
    'controlled changes reconcile selection and removed focused option',
    (tester) async {
      late StateSetter change;
      bool open = false;
      String selected = 'todo';
      var entries = options;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return RaftInlineBadgeEditor(
                label: 'Status',
                selectedId: selected,
                options: entries,
                open: open,
                onOpenChanged: (value) => change(() => open = value),
                onSelect: (id) => change(() => selected = id),
                background: Colors.yellow,
                foreground: Colors.black,
              );
            },
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(node(tester, 'Done').hasFocus, isTrue);
      change(() => entries = [options.first, options[1]]);
      await tester.pumpAndSettle();
      expect(node(tester, 'To do').hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(open, isFalse);
      expect(selected, 'todo');
      expect(node(tester, 'Status').hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('revocation cancels queued open and leaves no actionable popup', (
    tester,
  ) async {
    late StateSetter change;
    bool enabled = true;
    final selections = <String>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return editor(enabled: enabled, onSelect: selections.add);
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    change(() => enabled = false);
    await tester.pumpAndSettle();
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    await tester.tap(find.text('Status'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    expect(selections, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('open popup revocation and disposal cancel pending focus', (
    tester,
  ) async {
    await tester.pumpWidget(host(editor()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(node(tester, 'To do').hasFocus, isTrue);
    await tester.pumpWidget(host(editor(enabled: false)));
    await tester.pumpAndSettle();
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(host(editor()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('selection callback can retire editor immediately', (
    tester,
  ) async {
    late StateSetter change;
    bool retired = false;
    final selected = <String>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return retired
                ? const Text('Retired')
                : editor(
                    onSelect: (id) {
                      selected.add(id);
                      change(() => retired = true);
                    },
                  );
          },
        ),
      ),
    );
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(selected, ['done']);
    expect(find.text('Retired'), findsOneWidget);
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'focused option becoming disabled moves focus to an enabled row',
    (tester) async {
      late StateSetter change;
      var entries = options;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return RaftInlineBadgeEditor(
                label: 'Status',
                selectedId: 'todo',
                options: entries,
                onSelect: (_) {},
                background: Colors.yellow,
                foreground: Colors.black,
              );
            },
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(node(tester, 'Done').hasFocus, isTrue);
      change(
        () => entries = [
          ...options.take(2),
          const RaftInlineBadgeOption(
            id: 'done',
            label: 'Done',
            disabled: true,
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(node(tester, 'To do').hasFocus, isTrue);
      expect(node(tester, 'Done').canRequestFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(node(tester, 'Status').hasFocus, isTrue);
    },
  );

  testWidgets('external controlled close returns owned keyboard focus', (
    tester,
  ) async {
    late StateSetter change;
    bool open = false;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return RaftInlineBadgeEditor(
              label: 'Status',
              selectedId: 'todo',
              options: options,
              open: open,
              onOpenChanged: (value) => change(() => open = value),
              onSelect: (_) {},
              background: Colors.yellow,
              foreground: Colors.black,
            );
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(node(tester, 'To do').hasFocus, isTrue);
    change(() => open = false);
    await tester.pumpAndSettle();
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    expect(node(tester, 'Status').hasFocus, isTrue);
  });

  testWidgets('Space opens and an all-disabled menu still closes with Escape', (
    tester,
  ) async {
    final selections = <String>[];
    await tester.pumpWidget(
      host(
        RaftInlineBadgeEditor(
          label: 'Status',
          selectedId: 'blocked',
          options: const [
            RaftInlineBadgeOption(
              id: 'blocked',
              label: 'Unavailable',
              disabled: true,
            ),
          ],
          onSelect: selections.add,
          background: Colors.yellow,
          foreground: Colors.black,
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.byType(RaftInlineBadgeMenu), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    expect(node(tester, 'Status').hasFocus, isTrue);
  });
}
