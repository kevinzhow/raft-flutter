// The conversation head's own toggles between Search and Settings (Tasks and
// Files, raft-ui PanelToggleAction): they sit in that order, show a pressed
// state while what they open is open, and carry their label as tooltip and
// accessible name.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  Future<void> mount(
    WidgetTester t, {
    required bool dark,
    required bool tasksOpen,
    List<String>? log,
    bool withToggles = true,
  }) => t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: SizedBox(
          width: 700,
          child: RaftChannelHeader(
            name: 'docs',
            onSearch: () {},
            onSettings: () {},
            middleActions: withToggles
                ? [
                    raftConversationHeaderToggle(
                      key: const Key('tasks'),
                      glyph: RaftGlyph.listTodo,
                      label: tasksOpen ? 'Close Tasks' : 'Open Tasks',
                      pressed: tasksOpen,
                      onPressed: () => log?.add('tasks'),
                    ),
                    raftConversationHeaderToggle(
                      key: const Key('files'),
                      glyph: RaftGlyph.paperclip,
                      label: 'Open files',
                      pressed: false,
                      onPressed: () => log?.add('files'),
                    ),
                  ]
                : const [],
          ),
        ),
      ),
    ),
  );

  Color? fill(WidgetTester t, String key) {
    final box = find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(Container),
    );
    return (t.widget<Container>(box.first).decoration as BoxDecoration?)?.color;
  }

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'}: between Search and Settings, tapped, named and pressed',
      (t) async {
        final semantics = t.ensureSemantics();
        final log = <String>[];
        await mount(t, dark: dark, tasksOpen: true, log: log);
        double x(Finder f) => t.getCenter(f).dx;
        final search = find.byKey(const Key('channel-topbar-search'));
        final settings = find.byKey(const Key('channel-overflow-trigger'));
        expect(x(search), lessThan(x(find.byKey(const Key('tasks')))));
        expect(
          x(find.byKey(const Key('tasks'))),
          lessThan(x(find.byKey(const Key('files')))),
        );
        expect(x(find.byKey(const Key('files'))), lessThan(x(settings)));
        await t.tap(find.byKey(const Key('tasks')));
        await t.tap(find.byKey(const Key('files')));
        expect(log, ['tasks', 'files']);
        final tasks = t.getSemantics(find.byKey(const Key('tasks')));
        expect(tasks.getSemanticsData().label, 'Close Tasks');
        expect(
          tasks.getSemanticsData().flagsCollection.isToggled,
          Tristate.isTrue,
        );
        final files = t.getSemantics(find.byKey(const Key('files')));
        expect(files.getSemanticsData().label, 'Open files');
        expect(
          files.getSemanticsData().flagsCollection.isToggled,
          Tristate.isFalse,
        );
        // Pressed paints differently from not pressed.
        expect(fill(t, 'tasks'), isNot(fill(t, 'files')));
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'each toggle is a square as tall as Search',
    (t) async {
      await mount(t, dark: false, tasksOpen: true);
      final search = t.getSize(find.byKey(const Key('channel-topbar-search')));
      for (final key in ['tasks', 'files']) {
        final box = t.getSize(
          find
              .descendant(
                of: find.byKey(Key(key)),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(box.width, box.height, reason: '$key is square');
        expect(box.height, search.height, reason: '$key as tall as Search');
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.android,
    }),
  );

  testWidgets('without toggles the head is as it was', (t) async {
    await mount(t, dark: false, tasksOpen: false, withToggles: false);
    expect(find.byKey(const Key('tasks')), findsNothing);
    expect(find.byKey(const Key('channel-topbar-search')), findsOne);
    expect(find.byKey(const Key('channel-overflow-trigger')), findsOne);
  });
}
