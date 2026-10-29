import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} mobile keeps swiped selection visible',
      (t) async {
        var view = RaftActivityView.all;
        late StateSetter update;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 240,
                  child: StatefulBuilder(
                    builder: (_, setState) {
                      update = setState;
                      return RaftActivityScopeToolbar(
                        view: view,
                        compact: false,
                        onView: (next) => setState(() => view = next),
                        onOpenSwitcher: () {},
                        sort: 'desc',
                        onSort: (_) {},
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        update(() => view = RaftActivityView.done);
        await t.pumpAndSettle();
        final toolbar = t.getRect(find.byType(RaftActivityScopeToolbar));
        final done = t.getRect(
          find.byKey(const ValueKey('activity-view-done')),
        );
        expect(done.left, greaterThanOrEqualTo(toolbar.left));
        expect(done.right, lessThanOrEqualTo(toolbar.right));
        update(() => view = RaftActivityView.all);
        await t.pumpAndSettle();
        final all = t.getRect(find.byKey(const ValueKey('activity-view-all')));
        expect(all.left, greaterThanOrEqualTo(toolbar.left));
        expect(all.right, lessThanOrEqualTo(toolbar.right));
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} Source compact min-height and keyboard switcher',
      (tester) async {
        var opens = 0;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 440,
                  child: RaftActivityScopeToolbar(
                    view: RaftActivityView.all,
                    compact: true,
                    onView: (_) {},
                    onOpenSwitcher: () => opens++,
                    sort: 'desc',
                    onSort: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        final button = find.byKey(const ValueKey('activity-scope-switcher'));
        expect(
          tester.getSize(find.byType(RaftActivityScopeToolbar)).height,
          89,
        );
        final focus = find
            .descendant(of: button, matching: find.byType(Focus))
            .first;
        tester.widget<Focus>(focus).focusNode!.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(opens, 1);
        expect(
          tester
              .getSemantics(
                find.descendant(
                  of: button,
                  matching: find.byType(RaftInteractive),
                ),
              )
              .label,
          'All',
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} Source finder keeps nonempty Escape and closes empty Escape',
      (tester) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        var dismissed = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: RaftActivitySearchInput(
                  controller: controller,
                  focusNode: focus,
                  onChanged: (_) {},
                  onDismissEmpty: () => dismissed++,
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        expect(tester.getSize(find.byType(RaftActivitySearchInput)).height, 32);
        await tester.enterText(find.byType(EditableText), 'kept query');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(dismissed, 0);
        await tester.enterText(find.byType(EditableText), '');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(dismissed, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        focus.dispose();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} Source picker groups independent of Saved and keyboard selection',
      (tester) async {
        final selected = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 440,
                child: RaftActivityScopePicker(
                  view: RaftActivityView.saved,
                  onView: (value) => selected.add(value.name),
                  groups: const [
                    RaftActivityGroup(
                      id: 'dm',
                      label: 'Alice',
                      count: 19,
                      dm: true,
                    ),
                    RaftActivityGroup(id: 'c', label: 'general', count: 11),
                  ],
                  selectedGroup: 'c',
                  onGroup: selected.add,
                  onClearGroup: () => selected.add('clear'),
                ),
              ),
            ),
          ),
        );
        expect(find.text('19'), findsNothing);
        expect(find.text('11'), findsNothing);
        final group = find.byKey(const ValueKey('activity-switcher-group-dm'));
        await tester.tap(group);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(selected, ['dm', 'dm']);
        await tester.tap(
          find.byKey(const ValueKey('activity-clear-channel-filter')),
        );
        await tester.pump();
        expect(selected.last, 'clear');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
