import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

List<RaftMenuEntry> _entries(List<int> calls) => [
  for (var i = 0; i < 30; i++)
    RaftMenuEntry(
      label: 'Action $i',
      onPressed: i == 0 || i == 29 ? null : () => calls.add(i),
    ),
];

Widget _host({required Widget child, required ScrollController outerScroll}) =>
    MaterialApp(
      theme: raftTheme(platform: TargetPlatform.linux),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: SingleChildScrollView(
            controller: outerScroll,
            child: SizedBox(
              height: 800,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(padding: const EdgeInsets.all(16), child: child),
              ),
            ),
          ),
        ),
      ),
    );

Finder _row(String label) => find.widgetWithText(RaftMenuItem, label);

void _expectFocusedAndVisible(WidgetTester tester, String label) {
  final finder = _row(label);
  final row = tester.widget<RaftMenuItem>(finder);
  expect(row.focusNode!.hasFocus, isTrue, reason: '$label owns keyboard focus');
  final viewport =
      RenderAbstractViewport.of(tester.renderObject(finder)) as RenderBox;
  final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
  final bounds = tester.getRect(finder);
  expect(
    bounds.top,
    greaterThanOrEqualTo(visible.top - .01),
    reason: '$label must be revealed above the local popup viewport edge',
  );
  expect(
    bounds.bottom,
    lessThanOrEqualTo(visible.bottom + .01),
    reason: '$label must be revealed below the local popup viewport edge',
  );
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  for (final kind in [RaftMenuKind.dropdown, RaftMenuKind.dropdownMenu]) {
    testWidgets(
      'long $kind keyboard reveals both ends and wrapped enabled rows locally',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 240);
        final outer = ScrollController();
        final controller = RaftMenuController();
        final calls = <int>[];
        try {
          await tester.pumpWidget(
            _host(
              outerScroll: outer,
              child: RaftDropdownMenu(
                label: 'Long actions',
                kind: kind,
                controller: controller,
                header: const Text('Action header'),
                entries: _entries(calls),
              ),
            ),
          );
          await _key(tester, LogicalKeyboardKey.tab);
          await _key(tester, LogicalKeyboardKey.arrowDown);
          expect(controller.isOpen, isTrue);
          _expectFocusedAndVisible(tester, 'Action 1');
          await _key(tester, LogicalKeyboardKey.end);
          _expectFocusedAndVisible(tester, 'Action 28');
          await _key(tester, LogicalKeyboardKey.home);
          _expectFocusedAndVisible(tester, 'Action 1');
          await _key(tester, LogicalKeyboardKey.arrowUp);
          _expectFocusedAndVisible(tester, 'Action 28');
          await _key(tester, LogicalKeyboardKey.arrowDown);
          _expectFocusedAndVisible(tester, 'Action 1');
          expect(outer.offset, 0, reason: 'keyboard must not scroll the page');
          expect(calls, isEmpty);
          await _key(tester, LogicalKeyboardKey.enter);
          expect(calls, [1]);
          expect(controller.isOpen, isFalse);
          expect(find.byType(RaftMenuItem), findsNothing);
          expect(
            tester
                .widget<RaftControl>(find.byType(RaftControl))
                .focusNode!
                .hasFocus,
            isTrue,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          controller.dispose();
          outer.dispose();
          tester.view.reset();
        }
      },
    );
  }

  testWidgets(
    'long dropdown reacquires reordered enabled edges and latest callback',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 240);
      final outer = ScrollController();
      final controller = RaftMenuController();
      final calls = <int>[];
      var entries = _entries(calls);
      late StateSetter update;
      try {
        await tester.pumpWidget(
          _host(
            outerScroll: outer,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return RaftDropdownMenu(
                  label: 'Reordered actions',
                  kind: RaftMenuKind.dropdownMenu,
                  controller: controller,
                  entries: entries,
                );
              },
            ),
          ),
        );
        await _key(tester, LogicalKeyboardKey.tab);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        _expectFocusedAndVisible(tester, 'Action 1');
        update(() => entries = entries.reversed.toList());
        await tester.pumpAndSettle();
        // Entries have no identity key. Reacquire the latest enabled edge,
        // preserving the existing index-based input/callback contract.
        await _key(tester, LogicalKeyboardKey.home);
        _expectFocusedAndVisible(tester, 'Action 28');
        await _key(tester, LogicalKeyboardKey.end);
        _expectFocusedAndVisible(tester, 'Action 1');
        expect(outer.offset, 0);
        await _key(tester, LogicalKeyboardKey.enter);
        expect(calls, [1]);
        expect(controller.isOpen, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        controller.dispose();
        outer.dispose();
        tester.view.reset();
      }
    },
  );
}
