import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/select_group_previews.dart';

Future<void> _host(WidgetTester tester, bool dark, Widget child) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 320, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Host extends StatefulWidget {
  const _Host({required this.changes, this.showAllCalls});
  final List<String> changes;
  final List<bool>? showAllCalls;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String value = 'a';
  bool showAll = false;
  @override
  Widget build(BuildContext context) => RaftAgentSelect<String>(
    value: value,
    semanticLabel: 'Runtime',
    options: [
      const RaftAgentSelectOption(
        'a',
        'Alpha',
        group: 'Ready',
        description: 'The first one',
        badge: 'Experimental',
      ),
      const RaftAgentSelectOption('b', 'Beta', group: 'Ready'),
      const RaftAgentSelectOption(
        'c',
        'Gamma',
        enabled: false,
        group: 'Needs update',
        suffix: ' · Update required',
        suffixInList: false,
      ),
      if (showAll)
        const RaftAgentSelectOption(
          'd',
          'Delta',
          enabled: false,
          group: 'Not installed',
        ),
      RaftAgentSelectOption.action(
        '__action__',
        showAll ? 'Show installed only' : 'Show all supported',
        onAction: () {
          widget.showAllCalls?.add(!showAll);
          setState(() => showAll = !showAll);
        },
      ),
    ],
    onChanged: (v) {
      widget.changes.add(v);
      setState(() => value = v);
    },
  );
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('groups, description, badge and suffixes dark=$dark', (
      tester,
    ) async {
      await _host(tester, dark, _Host(changes: []));
      // The closed field says everything the row says: name, badge.
      expect(find.text('Alpha'), findsNothing);
      expect(find.textContaining('Alpha'), findsOneWidget);
      await tester.tap(find.byType(RaftSelectField<String>));
      await tester.pumpAndSettle();
      final backend = tester.widget<RaftMenuPopupBackend>(
        find.byType(RaftMenuPopupBackend),
      );
      expect(
        [for (final e in backend.entries) e.kind.name],
        [
          'heading',
          'item',
          'item',
          'separator',
          'heading',
          'item',
          'separator',
          'item',
        ],
      );
      expect(backend.entries.map((e) => e.label).where((l) => l.isNotEmpty), [
        'Ready',
        'Alpha Experimental',
        'Beta',
        'Needs update',
        // The list drops the suffix the heading says; the semantic label of
        // the closed field keeps it.
        'Gamma · Update required',
        'Show all supported',
      ]);
      expect(find.text('The first one'), findsOneWidget);
      expect(find.text('Experimental'), findsWidgets);
      expect(find.textContaining('Update required'), findsNothing);
      expect(backend.entries.last.action, isTrue);
    });
  }

  testWidgets('the action row is never the value and leaves the list open', (
    tester,
  ) async {
    final changes = <String>[];
    final toggles = <bool>[];
    await _host(tester, false, _Host(changes: changes, showAllCalls: toggles));
    await tester.tap(find.byType(RaftSelectField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Delta'), findsNothing);
    await tester.tap(find.text('Show all supported'));
    await tester.pumpAndSettle();
    expect(toggles, [true]);
    expect(changes, isEmpty);
    expect(find.byType(RaftMenuPopupBackend), findsOneWidget);
    expect(find.text('Delta'), findsOneWidget);
    expect(find.text('Show installed only'), findsOneWidget);
    // The closed field still shows the value, not the action label.
    expect(find.text('Show all supported'), findsNothing);
  });

  testWidgets('keyboard reaches the action row and typeahead jumps to it', (
    tester,
  ) async {
    final changes = <String>[];
    final toggles = <bool>[];
    await _host(tester, false, _Host(changes: changes, showAllCalls: toggles));
    await tester.tap(find.byType(RaftSelectField<String>));
    await tester.pumpAndSettle();
    // From Alpha: Beta, then Gamma is disabled, so the action row is next.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(toggles, [true]);
    expect(changes, isEmpty);
    expect(find.byType(RaftMenuPopupBackend), findsOneWidget);
    // Typeahead: "b" reaches Beta (never the heading), Enter picks it.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, ['b']);
    expect(find.byType(RaftMenuPopupBackend), findsNothing);
  });

  testWidgets('headings and separators are not options', (tester) async {
    final handle = tester.ensureSemantics();
    await _host(tester, false, _Host(changes: []));
    await tester.tap(find.byType(RaftSelectField<String>));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Ready')),
      matchesSemantics(label: 'Ready', isHeader: true),
    );
    expect(find.bySemanticsLabel('Alpha Experimental'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('preview builds', (tester) async {
    await _host(tester, false, selectGroupPreview());
    expect(find.byType(RaftSelectField<String>), findsOneWidget);
  });

  testWidgets('a plain select is unchanged: one entry per item', (
    tester,
  ) async {
    await _host(
      tester,
      false,
      RaftSelectField<int>(
        value: 1,
        items: const [
          RaftSelectItem(value: 1, label: 'One'),
          RaftSelectItem(value: 2, label: 'Two'),
        ],
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.byType(RaftSelectField<int>));
    await tester.pumpAndSettle();
    final backend = tester.widget<RaftMenuPopupBackend>(
      find.byType(RaftMenuPopupBackend),
    );
    expect(backend.entries.map((e) => e.kind).toSet(), {
      RaftMenuPopupEntryKind.item,
    });
    expect(backend.entries, hasLength(2));
  });

  testWidgets('long options can wrap to two lines in the popup', (
    tester,
  ) async {
    const label = 'First choices for second-factor authentication';
    await _host(
      tester,
      false,
      RaftSelectField<int>(
        value: 1,
        items: const [
          RaftSelectItem(value: 1, label: 'One'),
          RaftSelectItem(value: 2, label: label),
        ],
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.byType(RaftSelectField<int>));
    await tester.pumpAndSettle();
    final popup = find.byKey(const ValueKey('raft-select-popup'));
    expect(
      tester.getTopLeft(find.text(label)).dx - tester.getTopLeft(popup).dx,
      14,
    );
    expect(
      tester.getSize(find.text(label)).height,
      greaterThan(tester.getSize(find.text('One').last).height),
    );
  });
}
