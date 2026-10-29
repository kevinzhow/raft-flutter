import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_selection_filter.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const _filter = ValueKey('fractional-assignee-filter');
const _popup = ValueKey('task-selection-assignee-popover');

Finder _search() => find.descendant(
  of: find.byKey(_popup),
  matching: find.byType(EditableText),
);

class _FilterFixture {
  final registrations = <({MenuController controller, bool attached})>[];
  final toggled = <String>[];
  final outsideEditorFocus = FocusNode();
  var valid = true;
  var outsideTaps = 0;

  void register(MenuController controller, bool attached) =>
      registrations.add((controller: controller, attached: attached));

  void beforeOpen(MenuController current) {
    for (final registration in registrations) {
      if (registration.attached &&
          registration.controller != current &&
          registration.controller.isOpen) {
        registration.controller.close();
      }
    }
  }

  Future<void> mount(
    WidgetTester tester, {
    required bool dark,
    bool closeOnSelect = false,
    bool secondFilter = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 12,
                top: 12,
                child: TextButton(
                  onPressed: () => outsideTaps++,
                  child: const Text('Outside action'),
                ),
              ),
              Positioned(
                left: 12,
                top: 120,
                width: 180,
                child: TextField(
                  key: const ValueKey('outside-editor'),
                  focusNode: outsideEditorFocus,
                ),
              ),
              Positioned(
                left: 253.25,
                top: 74.25,
                child: TaskSelectionFilter(
                  key: _filter,
                  field: 'Assignee',
                  options: const {
                    'user:self': 'Assigned to me',
                    'unassigned': 'Unassigned',
                    'agent:cindy': 'Cindy',
                  },
                  selection: const {},
                  valid: () => valid,
                  onToggle: toggled.add,
                  onClear: () {},
                  onController: register,
                  beforeOpen: beforeOpen,
                  closeOnSelect: closeOnSelect,
                ),
              ),
              if (secondFilter)
                Positioned(
                  left: 500,
                  top: 74,
                  child: TaskSelectionFilter(
                    key: const ValueKey('creator-filter'),
                    field: 'Creator',
                    options: const {'agent:cindy': 'Cindy'},
                    selection: const {},
                    valid: () => valid,
                    onToggle: toggled.add,
                    onClear: () {},
                    onController: register,
                    beforeOpen: beforeOpen,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> retire(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    outsideEditorFocus.dispose();
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_filter));
  await tester.pumpAndSettle();
  expect(find.byKey(_popup), findsOneWidget);
}

void main() {
  // The fixed Web db5e399f Tasks Assignee popup has min-w-[220px], and its
  // real positioner uses whole-pixel translate coordinates. SelectionPopover
  // explicitly uses sideOffset=8 and collisionPadding=8. A fractional
  // trigger must not enlarge the full popup's pixel enclosure to 221px.
  // This uses the real resource filter and its complete keyed popup: no
  // component substitute, screenshot crop correction, or font-width fixture.
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Tasks full popup keeps a 220px enclosure at a fractional anchor; '
      'dark=$dark',
      (tester) async {
        final fixture = _FilterFixture();
        try {
          await fixture.mount(tester, dark: dark);
          final anchor = tester.getRect(find.byKey(_filter));
          expect(anchor.left, closeTo(253.25, .001));
          expect(anchor.top, closeTo(74.25, .001));
          await tester.tap(find.byKey(_filter));
          await tester.pumpAndSettle();
          expect(find.byKey(_popup), findsOneWidget);
          expect(find.text('Cindy').hitTestable(), findsOneWidget);
          final popup = tester.getRect(find.byKey(_popup));
          final diagnostic = 'anchor=$anchor; complete popup=$popup';
          expect(popup.width, closeTo(220, .001), reason: diagnostic);
          expect(
            popup.right.ceil() - popup.left.floor(),
            220,
            reason: 'Web full popup enclosure, without trimming; $diagnostic',
          );
          expect(
            popup.left,
            closeTo(popup.left.roundToDouble(), .001),
            reason: 'Web positioner snaps the final origin; $diagnostic',
          );
          expect(
            popup.top,
            closeTo((anchor.bottom + 8).roundToDouble(), .001),
            reason: 'Web sideOffset8, then whole-pixel placement; $diagnostic',
          );
          expect(fixture.toggled, isEmpty);
        } finally {
          await fixture.retire(tester);
        }
        expect(fixture.registrations, hasLength(2));
        expect(fixture.registrations.first.attached, isTrue);
        expect(fixture.registrations.last.attached, isFalse);
        expect(
          identical(
            fixture.registrations.first.controller,
            fixture.registrations.last.controller,
          ),
          isTrue,
          reason: 'The caller keeps the same MenuController registration.',
        );
      },
      skip: raftLookSkip(raftLookRaft),
    );
  }

  for (final closeOnSelect in [false, true]) {
    testWidgets(
      'Task selection keeps typed callback and close=$closeOnSelect',
      (tester) async {
        final fixture = _FilterFixture();
        try {
          await fixture.mount(
            tester,
            dark: false,
            closeOnSelect: closeOnSelect,
          );
          await _open(tester);
          await tester.tap(find.text('Cindy'));
          await tester.pumpAndSettle();
          expect(fixture.toggled, ['agent:cindy']);
          expect(
            fixture.registrations.single.controller.isOpen,
            !closeOnSelect,
          );
          expect(
            find.byKey(_popup),
            closeOnSelect ? findsNothing : findsOneWidget,
          );
        } finally {
          await fixture.retire(tester);
        }
      },
      skip: raftLookSkip(raftLookRaft),
    );
  }

  testWidgets('Escape from Task search returns to its keyboard trigger', (
    tester,
  ) async {
    final fixture = _FilterFixture();
    try {
      await fixture.mount(tester, dark: false);
      await _open(tester);
      final input = find.descendant(
        of: find.byKey(_popup),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_popup), findsNothing);
      expect(fixture.registrations.single.controller.isOpen, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(_popup), findsOneWidget);
      expect(fixture.toggled, isEmpty);
    } finally {
      await fixture.retire(tester);
    }
  }, skip: raftLookSkip(raftLookRaft));

  testWidgets(
    'Outside action passes through and stale Task authority is fenced',
    (tester) async {
      final fixture = _FilterFixture();
      try {
        await fixture.mount(tester, dark: false);
        await _open(tester);
        await tester.enterText(_search(), 'Cindy');
        await tester.pumpAndSettle();
        expect(find.text('Unassigned'), findsNothing);
        fixture.valid = false;
        await tester.tap(
          find.byKey(const ValueKey('task-filter-Assignee-agent:cindy')),
        );
        await tester.pumpAndSettle();
        expect(fixture.toggled, isEmpty);
        await tester.tap(find.text('Outside action'));
        await tester.pumpAndSettle();
        expect(fixture.outsideTaps, 1);
        expect(find.byKey(_popup), findsNothing);
        fixture.valid = true;
        await _open(tester);
        expect(tester.widget<EditableText>(_search()).controller.text, isEmpty);
        expect(find.text('Unassigned').hitTestable(), findsOneWidget);
      } finally {
        await fixture.retire(tester);
      }
    },
    skip: raftLookSkip(raftLookRaft),
  );

  testWidgets('Task filter controllers still close siblings and unregister', (
    tester,
  ) async {
    final fixture = _FilterFixture();
    try {
      await fixture.mount(tester, dark: false, secondFilter: true);
      await _open(tester);
      final assignee = fixture.registrations.first.controller;
      await tester.tap(find.byKey(const ValueKey('creator-filter')));
      await tester.pumpAndSettle();
      expect(assignee.isOpen, isFalse);
      expect(find.byKey(_popup), findsNothing);
      expect(fixture.registrations[1].controller.isOpen, isTrue);
      expect(
        find.byKey(const ValueKey('task-selection-creator-popover')),
        findsOneWidget,
      );
      expect(fixture.toggled, isEmpty);
    } finally {
      await fixture.retire(tester);
    }
    expect(fixture.registrations, hasLength(4));
    for (final attached in fixture.registrations.where((r) => r.attached)) {
      expect(
        fixture.registrations.where(
          (r) => !r.attached && identical(r.controller, attached.controller),
        ),
        hasLength(1),
      );
    }
  }, skip: raftLookSkip(raftLookRaft));

  testWidgets('Task outside editor keeps its newly acquired focus', (
    tester,
  ) async {
    final fixture = _FilterFixture();
    try {
      await fixture.mount(tester, dark: false);
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('outside-editor')));
      await tester.pumpAndSettle();
      expect(find.byKey(_popup), findsNothing);
      expect(fixture.outsideEditorFocus.hasFocus, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('outside-editor')),
        'Retained editor input',
      );
      await tester.pumpAndSettle();
      expect(fixture.outsideEditorFocus.hasFocus, isTrue);
      expect(find.text('Retained editor input'), findsOneWidget);
      expect(fixture.toggled, isEmpty);
    } finally {
      await fixture.retire(tester);
    }
  }, skip: raftLookSkip(raftLookRaft));
}
