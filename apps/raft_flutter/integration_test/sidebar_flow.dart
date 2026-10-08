import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/sidebar_preferences_view.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (ready()) return;
  }
  throw TestFailure('Sidebar state did not become ready.');
}

Future<void> _reveal(WidgetTester tester, Finder target, Finder list) async {
  final scroll = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scroll).position;
  position.jumpTo(0);
  await tester.pumpAndSettle();
  for (var i = 0; i < 60 && target.evaluate().isEmpty; i++) {
    final next = (position.pixels + 250).clamp(0.0, position.maxScrollExtent);
    if (next == position.pixels) break;
    position.jumpTo(next);
    await tester.pumpAndSettle();
  }
  expect(target, findsAtLeastNWidgets(1));
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
}

/// Reversible personal preferences only. Uses current real conversations and
/// restores the snapshot with the server's latest sectionsVersion in finally.
Future<void> verifySidebarFlow(
  WidgetTester tester,
  WorkspaceController w, {
  required Future<void> Function(String) section,
  required Future<void> Function(String) capture,
}) async {
  final path = '/servers/${w.server!.id}/sidebar-order';
  final snapshot = Map<String, dynamic>.from(await w.query(path));
  final marker = 'Native sidebar ${DateTime.now().microsecondsSinceEpoch}';
  final edited = '$marker edited';
  final list = find.byKey(const Key('sidebar-preferences'));
  Future<Map<String, dynamic>> prefs() async =>
      Map<String, dynamic>.from(await w.query(path));
  Future<void> openPreferences() async {
    await section('sidebar-settings');
    await _until(
      tester,
      () =>
          find.byType(SidebarPreferencesView).evaluate().isNotEmpty &&
          list.evaluate().isNotEmpty,
    );
  }

  Future<void> tap(Finder target) async {
    if (find.byType(RaftFormDialog).evaluate().isEmpty) {
      await _reveal(tester, target, list);
    }
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  Future<void> field(String name, String value) async {
    final target = find.byKey(ValueKey('field-$name'));
    await tester.ensureVisible(target);
    await tester.enterText(target, value);
  }

  Future<void> submit() async {
    await tap(
      find.descendant(
        of: find.byType(RaftFormDialog),
        matching: find.text('Save'),
      ),
    );
    await _until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
    // A successful form's transient message must not intercept the next tap.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  try {
    expect(
      w.channels.length,
      greaterThanOrEqualTo(2),
      reason: 'Sidebar order proof needs two actual channels.',
    );
    expect(
      w.dms,
      isNotEmpty,
      reason: 'Sidebar hiding proof needs an actual DM.',
    );
    await openPreferences();
    await tap(find.text('Create sidebar section'));
    await field('name', marker);
    await field('emoji', '🧭');
    await submit();
    var current = await prefs();
    final created = (current['customSections'] as List).cast<Map>().singleWhere(
      (s) => s['name'] == marker,
    );
    final id = created['id'];
    await tap(find.byKey(ValueKey('sidebar-custom-section-$id')));
    await field('name', edited);
    await submit();
    current = await prefs();
    expect(
      (current['customSections'] as List).cast<Map>().singleWhere(
        (s) => s['id'] == id,
      )['name'],
      edited,
    );

    final channel = w.channels.firstWhere((c) => !c.archived);
    await tap(find.byKey(ValueKey('sidebar-item-${channel.id}')));
    await tap(find.byKey(const ValueKey('field-section')));
    await tester.tap(find.text(edited).last);
    await tester.pumpAndSettle();
    await submit();
    current = await prefs();
    expect(
      (current['sectionPlacements'] as List).cast<Map>().singleWhere(
        (p) => p['kind'] == 'channel' && p['id'] == channel.id,
      )['sectionId'],
      id,
    );

    // Native drag uses the actual reorderable handle, including Android's
    // delayed gesture target. Its resulting PATCH is checked independently.
    final currentOrder = (current['channelOrder'] as List? ?? [])
        .whereType<String>()
        .toList();
    final rows = {for (final c in w.channels) c.id: c};
    final ordered = [
      for (final cid in currentOrder)
        if (rows.containsKey(cid)) rows.remove(cid)!,
      ...rows.values,
    ];
    final first = find.byKey(ValueKey('sidebar-item-${ordered[0].id}'));
    final second = find.byKey(ValueKey('sidebar-item-${ordered[1].id}'));
    await _reveal(tester, first, list);
    await tester.ensureVisible(second);
    await tester.pumpAndSettle();
    final handle = find.descendant(
      of: second,
      matching: find.byType(ReorderableDragStartListener),
    );
    final delayed = find.descendant(
      of: second,
      matching: find.byType(ReorderableDelayedDragStartListener),
    );
    final gestureTarget = handle.evaluate().isNotEmpty
        ? handle.first
        : delayed.first;
    final start = tester.getCenter(gestureTarget),
        destination = tester.getCenter(first);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(Offset(start.dx, destination.dy - 10));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    current = await prefs();
    expect((current['channelOrder'] as List).take(2), [
      ordered[1].id,
      ordered[0].id,
    ]);
    expect(current['channelSortMode'], 'manual');

    final dm = w.dms.first;
    final dmRow = find.byKey(ValueKey('sidebar-item-${dm.id}'));
    await _reveal(tester, dmRow, list);
    final hidden = (current['hiddenDmIds'] as List? ?? []).contains(dm.id);
    await tap(
      find.descendant(
        of: dmRow,
        matching: find.byTooltip(
          hidden ? 'Show direct message' : 'Hide direct message',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    current = await prefs();
    expect((current['hiddenDmIds'] as List? ?? []).contains(dm.id), !hidden);
    await section('chat');
    final sidebar = find.byKey(const Key('workspace-sidebar'));
    await _reveal(tester, find.text('🧭 $edited'), sidebar);
    expect(
      find.byKey(ValueKey('sidebar-channel-${dm.id}')),
      hidden ? findsOneWidget : findsNothing,
    );
    await capture('native-sidebar-custom-section');
  } finally {
    final latest = await prefs();
    await w.command(
      'PATCH',
      path,
      data: {
        for (final key in const [
          'channelOrder',
          'dmOrder',
          'channelSortMode',
          'jointChannelSortMode',
          'dmSortMode',
          'pinnedSortMode',
          'hiddenDmIds',
          'pinned',
          'customSections',
          'sectionPlacements',
          'sectionOrder',
        ])
          if (snapshot.containsKey(key)) key: snapshot[key],
        'customSections': snapshot['customSections'] ?? [],
        'sectionPlacements': snapshot['sectionPlacements'] ?? [],
        'sectionOrder': snapshot['sectionOrder'] ?? [],
        'hiddenDmIds': snapshot['hiddenDmIds'] ?? [],
        'sectionsVersion': latest['sectionsVersion'],
      },
    );
    await w.loadSidebar();
    await section('chat');
  }
}
