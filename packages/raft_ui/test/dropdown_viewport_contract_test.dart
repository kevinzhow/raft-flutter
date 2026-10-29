import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/dropdown_viewport_previews.dart';

void main() {
  testWidgets('long-dropdown SDK preview opens and selects its last model', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(body: DropdownViewportPreview()),
      ),
    );
    await t.tap(find.byType(RaftAgentSelect<String>));
    await t.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const ValueKey('raft-select-popup')),
      matching: find.byType(Scrollable),
    );
    await t.scrollUntilVisible(
      find.text('Choice 39'),
      180,
      scrollable: list,
      maxScrolls: 40,
    );
    await t.tap(find.text('Choice 39'));
    await t.pumpAndSettle();
    expect(find.text('Selected: Choice 39'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'model menu follows its scrolling form and reacts to resize and keyboard',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: [
                const SizedBox(height: 300),
                RaftAgentSelect<String>(
                  value: 'a',
                  options: const [
                    RaftAgentSelectOption('a', 'Model A'),
                    RaftAgentSelectOption('b', 'Model B'),
                  ],
                  onChanged: (_) {},
                ),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      );
      await t.tap(find.byType(RaftAgentSelect<String>));
      await t.pumpAndSettle();
      final before = t.getRect(find.byKey(const ValueKey('raft-select-popup')));
      scroll.jumpTo(100);
      await t.pumpAndSettle();
      final moved = t.getRect(find.byKey(const ValueKey('raft-select-popup')));
      expect(moved.top, closeTo(before.top - 100, .01));
      t.view.physicalSize = const Size(360, 640);
      t.view.viewInsets = const FakeViewPadding(bottom: 260);
      await t.pumpAndSettle();
      final viewport = t.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey('raft-select-popup')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(viewport.bottom, lessThanOrEqualTo(380));
      expect(find.text('Model B').hitTestable(), findsOneWidget);
      await t.tap(find.text('Model B'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('raft-select-popup')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  for (final kind in ['field', 'actions', 'members']) {
    for (final keyboard in [0.0, 300.0]) {
      testWidgets(
        '$kind dropdown near the bottom can select its last row, IME=$keyboard',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(390, 844);
          t.view.viewInsets = FakeViewPadding(bottom: keyboard);
          addTearDown(t.view.reset);
          var selected = '0';
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: true),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    void choose(String? value) =>
                        setState(() => selected = value!);
                    final trigger = switch (kind) {
                      'field' => RaftSelectField<String>(
                        value: selected,
                        items: [
                          for (var i = 0; i < 40; i++)
                            RaftSelectItem(value: '$i', label: 'Choice $i'),
                        ],
                        onChanged: choose,
                      ),
                      'actions' => RaftOverflowMenuButton(
                        tooltip: 'Choose Action',
                        entries: [
                          for (var i = 0; i < 40; i++)
                            RaftMenuEntry(
                              label: 'Choice $i',
                              onPressed: () => choose('$i'),
                            ),
                        ],
                      ),
                      _ => RaftAdminPrincipalPicker(
                        selectedKey: selected,
                        candidates: [
                          for (var i = 0; i < 40; i++)
                            RaftAdminPrincipal(
                              key: '$i',
                              label: 'Choice $i',
                              agent: true,
                            ),
                        ],
                        onSelect: choose,
                      ),
                    };
                    return Column(
                      children: [
                        const Spacer(),
                        SizedBox(
                          key: const Key('trigger'),
                          width: 280,
                          child: trigger,
                        ),
                        const SizedBox(height: 70),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('trigger')));
          await t.pumpAndSettle();
          final scrolling = find.byType(Scrollable);
          expect(
            scrolling,
            findsWidgets,
            reason: 'Long option lists must scroll.',
          );
          // The active list viewport must fit above the keyboard and window edge.
          final active = scrolling
              .evaluate()
              .where((e) => (e as StatefulElement).state is ScrollableState)
              .where(
                (e) =>
                    ((e as StatefulElement).state as ScrollableState)
                        .position
                        .maxScrollExtent >
                    0,
              )
              .last;
          final list = find.byElementPredicate((e) => identical(e, active));
          final bounds = t.getRect(list);
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(844 - keyboard));
          final last = find.text('Choice 39');
          await t.scrollUntilVisible(
            last,
            180,
            scrollable: list,
            maxScrolls: 40,
          );
          final row = t.getCenter(last);
          expect(row.dy, inInclusiveRange(0, 844 - keyboard));
          await t.tap(last);
          await t.pumpAndSettle();
          expect(selected, '39');
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
