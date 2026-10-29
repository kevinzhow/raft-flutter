import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final keyboard in [0.0, 120.0]) {
    testWidgets(
      'oversized popup respects window insets after SafeArea/IME $keyboard',
      (t) async {
        t.view.physicalSize = const Size(320, 300);
        t.view.devicePixelRatio = 1;
        t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
        t.view.padding = FakeViewPadding(
          top: 24,
          bottom: keyboard == 0 ? 48 : 0,
        );
        t.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(t.view.reset);
        String? selected;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: SafeArea(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: RaftInlineBadgeEditor(
                    label: 'Status',
                    selectedId: '0',
                    background: Colors.yellow,
                    foreground: Colors.black,
                    options: [
                      for (var i = 0; i < 20; i++)
                        RaftInlineBadgeOption(id: '$i', label: 'Option $i'),
                    ],
                    onSelect: (id) => selected = id,
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Status'));
        await t.pumpAndSettle();
        final viewport = t.getRect(find.byType(SingleChildScrollView));
        expect(viewport.top, greaterThanOrEqualTo(24 + 8));
        expect(
          viewport.bottom,
          lessThanOrEqualTo(300 - (keyboard == 0 ? 48 : keyboard) - 8),
        );
        // A portal below SafeArea must react even to consumed inset changes.
        if (keyboard == 0) {
          t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 72);
          t.view.padding = const FakeViewPadding(top: 24, bottom: 72);
        } else {
          t.view.viewInsets = const FakeViewPadding(bottom: 160);
        }
        await t.pumpAndSettle();
        expect(
          t.getRect(find.byType(SingleChildScrollView)).bottom,
          lessThanOrEqualTo(300 - (keyboard == 0 ? 72 : 160) - 8),
        );
        await t.scrollUntilVisible(
          find.text('Option 19'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Option 19').hitTestable(), findsOneWidget);
        await t.tap(find.text('Option 19'));
        await t.pumpAndSettle();
        expect(selected, '19');
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final dark in raftThemeMatrix([false, true])) {
    for (final inline in [true, false]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} ${inline ? 'badge' : 'dropdown'} bottom anchor flips before actual option click',
        (t) async {
          t.view.physicalSize = const Size(320, 720);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          String? selected;
          final trigger = inline
              ? RaftInlineBadgeEditor(
                  label: 'Status',
                  selectedId: 'todo',
                  background: Colors.yellow,
                  foreground: Colors.black,
                  options: const [
                    RaftInlineBadgeOption(id: 'todo', label: 'To do'),
                    RaftInlineBadgeOption(id: 'review', label: 'In Review'),
                    RaftInlineBadgeOption(id: 'done', label: 'Done'),
                  ],
                  onSelect: (id) => selected = id,
                )
              : RaftDropdownMenu(
                  label: 'Status',
                  entries: [
                    RaftMenuEntry(
                      label: 'To do',
                      onPressed: () => selected = 'todo',
                    ),
                    RaftMenuEntry(
                      label: 'In Review',
                      onPressed: () => selected = 'review',
                    ),
                    RaftMenuEntry(
                      label: 'Done',
                      onPressed: () => selected = 'done',
                    ),
                  ],
                );
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: RaftDensityScope(
                  density: RaftDensity.desktop,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: trigger,
                  ),
                ),
              ),
            ),
          );
          final anchor = t.getRect(find.text('Status'));
          await t.tap(find.text('Status'));
          await t.pumpAndSettle();
          final popup = t.getRect(
            find.byType(inline ? RaftInlineBadgeMenu : RaftMenuPanel),
          );
          expect(popup.bottom, lessThanOrEqualTo(anchor.top));
          expect(popup.top, greaterThanOrEqualTo(inline ? 8 : 5));
          expect(popup.right, lessThanOrEqualTo(inline ? 312 : 315));
          expect(popup.left, greaterThanOrEqualTo(inline ? 8 : 5));
          expect(find.text('In Review').hitTestable(), findsOneWidget);
          await t.tap(find.text('In Review'));
          await t.pumpAndSettle();
          expect(selected, 'review');
          expect(find.text('In Review'), findsNothing);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'open badge follows actual scroll and resize without stale anchor placement',
    (t) async {
      t.view.physicalSize = const Size(320, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftDensityScope(
              density: RaftDensity.desktop,
              child: ListView(
                controller: scroll,
                children: [
                  const SizedBox(height: 300),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RaftInlineBadgeEditor(
                      label: 'Status',
                      selectedId: 'todo',
                      background: Colors.yellow,
                      foreground: Colors.black,
                      options: const [
                        RaftInlineBadgeOption(id: 'review', label: 'In Review'),
                      ],
                      onSelect: (_) {},
                    ),
                  ),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Status'));
      await t.pumpAndSettle();
      final before = t.getRect(find.byType(RaftInlineBadgeMenu));
      scroll.jumpTo(100);
      await t.pumpAndSettle();
      final after = t.getRect(find.byType(RaftInlineBadgeMenu));
      expect(after.top, closeTo(before.top - 100, .01));
      t.view.physicalSize = const Size(320, 240);
      await t.pumpAndSettle();
      final resized = t.getRect(find.byType(RaftInlineBadgeMenu));
      expect(resized.bottom, lessThanOrEqualTo(232));
      expect(find.text('In Review').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'oversized badge menu caps viewport then genuinely scrolls to final action',
    (t) async {
      t.view.physicalSize = const Size(320, 240);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      String? selected;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: RaftInlineBadgeEditor(
                label: 'Status',
                selectedId: '0',
                background: Colors.yellow,
                foreground: Colors.black,
                options: [
                  for (var i = 0; i < 20; i++)
                    RaftInlineBadgeOption(id: '$i', label: 'Option $i'),
                ],
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Status'));
      await t.pumpAndSettle();
      // Portal children live outside the trigger's element descendants.
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Option 19'),
        150,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Option 19').hitTestable(), findsOneWidget);
      await t.tap(find.text('Option 19'));
      await t.pumpAndSettle();
      expect(selected, '19');
      expect(t.takeException(), isNull);
    },
  );
}
