import 'dart:ui' show Tristate, SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const options = [
  RaftInlineBadgeOption(id: 'todo', label: 'To do'),
  RaftInlineBadgeOption(id: 'blocked', label: 'Unavailable', disabled: true),
  RaftInlineBadgeOption(id: 'done', label: 'Done'),
];
Widget host(Widget child, RaftFamily family, {bool dark = false}) =>
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
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
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    final (family, dark) = theme;
    testWidgets(
      '$family/$dark keyboard selects, skips disabled and restores trigger',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final selections = <String>[];
          await tester.pumpWidget(
            host(editor(onSelect: selections.add), family, dark: dark),
          );
          expect(
            tester.widget<Text>(find.text('Status')).style!.fontFamily,
            'InheritedDisplay',
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
    await tester.pumpWidget(
      host(editor(onSelect: selections.add), RaftFamily.elegant),
    );
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
          RaftFamily.elegant,
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
        RaftFamily.elegant,
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
    await tester.pumpWidget(host(editor(), RaftFamily.elegant));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(node(tester, 'To do').hasFocus, isTrue);
    await tester.pumpWidget(host(editor(enabled: false), RaftFamily.elegant));
    await tester.pumpAndSettle();
    expect(find.byType(RaftInlineBadgeMenu), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(host(editor(), RaftFamily.elegant));
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
        RaftFamily.elegant,
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
          RaftFamily.elegant,
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
        RaftFamily.elegant,
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
        RaftFamily.brutal,
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
