import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('Workspace mode actual checkbox Tab/Space/disabled $theme', (
      t,
    ) async {
      var enabled = false;
      int changes = 0;
      bool disabled = false;
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(theme.$1, dark: theme.$2),
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return RaftWorkspaceModeCard(
                    enabled: enabled,
                    onChanged: disabled
                        ? null
                        : (v) => setState(() {
                            enabled = v;
                            changes++;
                          }),
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('Workspace mode'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(enabled, true);
      expect(changes, 1);
      update(() => disabled = true);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(changes, 1);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });

    testWidgets(
      'Editor groups move preserves panel State; inactive keyboard is excluded $theme',
      (t) async {
        late StateSetter update;
        var moved = false;
        var active = 'a';
        final text = TextEditingController(text: '保留 selection');
        text.selection = const TextSelection.collapsed(offset: 2);
        final focus = FocusNode();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final first = RaftEditorTab(
                    id: 'a',
                    label: 'general',
                    child: TextField(
                      key: const Key('panel-input'),
                      controller: text,
                      focusNode: focus,
                    ),
                  );
                  final second = const RaftEditorTab(
                    id: 'b',
                    label: 'other',
                    child: Text('other panel'),
                  );
                  return RaftEditorGroups(
                    groups: moved
                        ? [
                            RaftEditorGroup(
                              id: 'one',
                              tabs: [second],
                              selected: 'b',
                            ),
                            RaftEditorGroup(
                              id: 'two',
                              tabs: [first],
                              selected: 'a',
                            ),
                          ]
                        : [
                            RaftEditorGroup(
                              id: 'one',
                              tabs: [first, second],
                              selected: active,
                            ),
                          ],
                    onSelect: (g, id) => setState(() => active = id),
                    onClose: (_) {},
                    onMove: (_, __) {},
                  );
                },
              ),
            ),
          ),
        );
        final state = t.state(find.byKey(const Key('panel-input')));
        update(() => active = 'b');
        await t.pump();
        expect(find.byKey(const Key('panel-input')), findsNothing);
        update(() => active = 'a');
        await t.pump();
        expect(t.state(find.byKey(const Key('panel-input'))), same(state));
        update(() => moved = true);
        await t.pump();
        expect(t.state(find.byKey(const Key('panel-input'))), same(state));
        expect(text.selection.baseOffset, 2);
        expect(
          t.getSize(find.byKey(const ValueKey('editor-tab-a'))).height,
          48,
        );
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        text.dispose();
        focus.dispose();
      },
    );

    testWidgets('Editor tabs actual arrows, edge drop and resize $theme', (
      t,
    ) async {
      t.view.physicalSize = const Size(1100, 680);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var split = false;
      var selected = 'a';
      var weights = <double>[1, 1];
      int splitCalls = 0, resizeCalls = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(theme.$1, dark: theme.$2),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                const a = RaftEditorTab(
                  id: 'a',
                  label: 'general',
                  child: Text('A'),
                );
                const b = RaftEditorTab(
                  id: 'b',
                  label: 'second',
                  child: Text('B'),
                );
                return RaftEditorGroups(
                  groups: split
                      ? [
                          const RaftEditorGroup(
                            id: 'one',
                            tabs: [a],
                            selected: 'a',
                          ),
                          const RaftEditorGroup(
                            id: 'two',
                            tabs: [b],
                            selected: 'b',
                          ),
                        ]
                      : [
                          RaftEditorGroup(
                            id: 'one',
                            tabs: [a, b],
                            selected: selected,
                          ),
                        ],
                  onSelect: (_, id) => update(() => selected = id),
                  onClose: (_) {},
                  onMove: (_, __) {},
                  onSplit: (id) => update(() {
                    expect(id, 'b');
                    splitCalls++;
                    split = true;
                  }),
                  weights: weights,
                  onWeightsChanged: (next) => update(() {
                    resizeCalls++;
                    weights = next;
                  }),
                );
              },
            ),
          ),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(selected, 'b');
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(selected, 'a');
      final start = t.getCenter(find.byKey(const ValueKey('editor-tab-b')));
      final drag = await t.startGesture(start);
      await drag.moveTo(const Offset(1088, 320));
      await t.pump();
      await drag.moveTo(const Offset(1088, 340));
      await t.pump();
      await drag.up();
      await t.pump();
      expect(splitCalls, 1);
      final first = find.byKey(const ValueKey('editor-group-one'));
      final initialWidth = t.getSize(first).width;
      await t.drag(
        find.byKey(const ValueKey('editor-splitter-one-two')),
        const Offset(80, 0),
      );
      await t.pump();
      expect(resizeCalls, greaterThan(0));
      expect(t.getSize(first).width, greaterThan(initialWidth));
      expect(
        t.getSize(find.byKey(const ValueKey('editor-group-two'))).width,
        greaterThanOrEqualTo(260),
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }
}
