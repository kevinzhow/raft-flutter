import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _themes = [
  (RaftFamily.brutal, false),
  (RaftFamily.elegant, false),
  (RaftFamily.elegant, true),
];

Finder _action(String id, String label) =>
    find.byKey(ValueKey('notification-action-$id-$label'));

FocusNode _actionFocus(WidgetTester tester, String id, String label) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: _action(id, label),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

FocusNode _fallbackFocus(WidgetTester tester) => tester
    .widget<Focus>(find.byKey(const Key('notification-center-focus')))
    .focusNode!;

RaftNotificationEntry _entry(String id, List<RaftNotificationAction> actions) =>
    RaftNotificationEntry(
      id: id,
      kind: RaftNotificationKind.info,
      title: id,
      actions: actions,
    );

class _Fixture extends StatefulWidget {
  const _Fixture({
    super.key,
    required this.entries,
    this.autofocusOnOpen = true,
  });
  final List<RaftNotificationEntry> entries;
  final bool autofocusOnOpen;
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  final bellFocus = FocusNode(debugLabel: 'Bell');
  late List<RaftNotificationEntry> entries = widget.entries;
  bool open = false;
  var dismissals = 0;

  void updateEntries(List<RaftNotificationEntry> value) {
    setState(() => entries = value);
  }

  void close() {
    setState(() {
      open = false;
      dismissals++;
    });
    // The app owns popup dismissal and trigger focus restoration.
    bellFocus.requestFocus();
  }

  @override
  void dispose() {
    bellFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RaftControl(
        key: const Key('bell'),
        focusNode: bellFocus,
        onPressed: () => setState(() => open = !open),
        child: const Text('Bell'),
      ),
      if (open)
        RaftNotificationCenter(
          entries: entries,
          autofocus: widget.autofocusOnOpen,
          onDismiss: close,
        ),
    ],
  );
}

Future<_FixtureState> _mount(
  WidgetTester tester,
  RaftFamily family,
  bool dark,
  List<RaftNotificationEntry> entries, {
  bool autofocusOnOpen = true,
}) async {
  final key = GlobalKey<_FixtureState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: Center(
            child: _Fixture(
              key: key,
              entries: entries,
              autofocusOnOpen: autofocusOnOpen,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

Future<void> _keyboardOpen(WidgetTester tester, _FixtureState fixture) async {
  // No test requestFocus: actual Tab selects the trigger, actual Enter opens.
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  expect(fixture.bellFocus.hasPrimaryFocus, isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  expect(find.byType(RaftNotificationCenter), findsOneWidget);
}

void main() {
  for (final (family, dark) in _themes) {
    final theme = '$family/$dark';
    testWidgets(
      'keyboard opening focuses first action before another Tab $theme',
      (tester) async {
        var views = 0;
        final fixture = await _mount(tester, family, dark, [
          _entry('computer', [
            RaftNotificationAction(label: 'View', onPressed: () => views++),
            RaftNotificationAction(label: 'Dismiss', onPressed: () {}),
          ]),
        ]);
        await _keyboardOpen(tester, fixture);
        expect(
          _actionFocus(tester, 'computer', 'View').hasPrimaryFocus,
          isTrue,
        );
        expect(views, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(views, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(RaftNotificationCenter), findsNothing);
        expect(fixture.dismissals, 1);
        expect(fixture.bellFocus.hasPrimaryFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'opening skips disabled and callback-less actions in supplied order $theme',
      (tester) async {
        var first = 0, disabled = 0, primary = 0;
        final fixture = await _mount(tester, family, dark, [
          _entry('first', [
            RaftNotificationAction(
              label: 'Disabled',
              enabled: false,
              onPressed: () => disabled++,
            ),
            const RaftNotificationAction(label: 'No callback'),
            RaftNotificationAction(label: 'View', onPressed: () => first++),
          ]),
          _entry('second', [
            RaftNotificationAction(
              label: 'Primary',
              primary: true,
              onPressed: () => primary++,
            ),
          ]),
        ]);
        await _keyboardOpen(tester, fixture);
        expect(_actionFocus(tester, 'first', 'View').hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect([first, disabled, primary], [1, 0, 0]);
        expect(tester.takeException(), isNull);
      },
    );

    for (final empty in [true, false]) {
      testWidgets(
        'keyboard ${empty ? 'empty' : 'all-disabled'} fallback keeps Escape working $theme',
        (tester) async {
          var forbidden = 0;
          final fixture = await _mount(
            tester,
            family,
            dark,
            empty
                ? []
                : [
                    _entry('disabled', [
                      RaftNotificationAction(
                        label: 'View',
                        enabled: false,
                        onPressed: () => forbidden++,
                      ),
                      const RaftNotificationAction(label: 'No callback'),
                    ]),
                  ],
          );
          await _keyboardOpen(tester, fixture);
          final fallback = _fallbackFocus(tester);
          expect(fallback.hasPrimaryFocus, isTrue);
          expect(fallback.skipTraversal, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(forbidden, 0);
          expect(find.byType(RaftNotificationCenter), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(fixture.bellFocus.hasPrimaryFocus, isTrue);
          expect(fixture.dismissals, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'pointer opening leaves trigger focus instead of moving to first action $theme',
      (tester) async {
        final fixture = await _mount(tester, family, dark, [
          _entry('computer', [
            RaftNotificationAction(label: 'View', onPressed: () {}),
          ]),
        ], autofocusOnOpen: false);
        await tester.tap(find.byKey(const Key('bell')));
        await tester.pumpAndSettle();
        expect(fixture.bellFocus.hasPrimaryFocus, isTrue);
        expect(_fallbackFocus(tester).hasFocus, isFalse);
        expect(_actionFocus(tester, 'computer', 'View').hasFocus, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'row reorder and new actions do not steal chosen secondary focus $theme',
      (tester) async {
        var secondary = 0, inserted = 0;
        final original = _entry('original', [
          RaftNotificationAction(label: 'View', onPressed: () {}),
          RaftNotificationAction(
            label: 'Details',
            onPressed: () => secondary++,
          ),
        ]);
        final fixture = await _mount(tester, family, dark, [original]);
        await _keyboardOpen(tester, fixture);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final chosen = _actionFocus(tester, 'original', 'Details');
        expect(chosen.hasPrimaryFocus, isTrue);
        fixture.updateEntries([
          _entry('inserted', [
            RaftNotificationAction(label: 'View', onPressed: () => inserted++),
          ]),
          original,
        ]);
        await tester.pumpAndSettle();
        expect(_actionFocus(tester, 'original', 'Details'), same(chosen));
        expect(chosen.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect([secondary, inserted], [1, 0]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'data arriving after empty keyboard opening does not steal fallback focus $theme',
      (tester) async {
        var views = 0;
        final fixture = await _mount(tester, family, dark, []);
        await _keyboardOpen(tester, fixture);
        final fallback = _fallbackFocus(tester);
        fixture.updateEntries([
          _entry('arrived', [
            RaftNotificationAction(label: 'View', onPressed: () => views++),
          ]),
        ]);
        await tester.pumpAndSettle();
        expect(fallback.hasPrimaryFocus, isTrue);
        expect(_actionFocus(tester, 'arrived', 'View').hasFocus, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(views, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(_actionFocus(tester, 'arrived', 'View').hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(views, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('unmount safely releases a focused popup $theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: RaftNotificationCenter(
              entries: [
                _entry('computer', [
                  RaftNotificationAction(label: 'View', onPressed: () {}),
                ]),
              ],
              autofocus: true,
            ),
          ),
        ),
      );
      await tester.pump();
      final actionFocus = _actionFocus(tester, 'computer', 'View');
      expect(actionFocus.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNot(same(actionFocus)));
      expect(find.byType(RaftNotificationCenter), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
