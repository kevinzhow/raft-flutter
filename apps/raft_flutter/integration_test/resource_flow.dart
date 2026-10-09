import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart'
    show kSecondaryMouseButton, kPrimaryMouseButton;
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';

import 'native_message_menu.dart';

/// Runs real ResourceView controls against the mounted server. The caller owns
/// the already-created message/channel and saved entry; this adds no fixture.
Future<void> verifyAdvancedResources(
  WidgetTester tester,
  WorkspaceController w, {
  required String channelId,
  required String channelName,
  required String messageId,
  required String query,
  required Future<void> Function(String) capture,
  required Future<void> Function(String) navigate,
}) async {
  Future<void> wait(bool Function() ready) async {
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (ready()) return;
    }
    throw TestFailure(
      'Native resource controls did not reach the required state.',
    );
  }

  dynamic state() => tester.state(find.byType(ResourceView));
  Future<void> loaded({bool message = false}) async {
    await wait(
      () =>
          find.byType(ResourceView).evaluate().isNotEmpty &&
          state().loading == false &&
          (!message ||
              (state().rows as List).any(
                (row) =>
                    row['id'] == messageId || row['messageId'] == messageId,
              )),
    );
    expect(state().error, isNull);
  }

  Future<void> section(String value) async {
    await navigate(value);
    await tester.pump(const Duration(milliseconds: 300));
    await loaded();
  }

  Future<void> menu(String title, String value) async {
    await tester.tap(find.byTooltip(title));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(value).last);
    await loaded();
  }

  try {
    await section('search');
    await menu('Filter by channel', '#$channelName');
    await loaded(message: true);
    expect(state().advanced.channelId, channelId);
    expect(
      (tester.widget<TextField>(find.byType(TextField))).controller!.text,
      isEmpty,
    );
    await menu('Search date range', 'Today');
    await loaded(message: true);
    final self = w.client.user!;
    await menu(
      'Filter by sender',
      '${self.name.isEmpty ? 'You' : self.name} · Human',
    );
    await loaded(message: true);
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 210));
    await loaded(message: true);
    await menu('Sort search results', 'Recent');
    await loaded(message: true);
    await capture('native-search-advanced-filters');
    await tester.tap(find.byTooltip('Search scope'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(RaftMenuItem, 'Mentions me'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await loaded();
    expect(state().advanced.scopes.contains('mentioned'), true);
    await capture('native-search-self-mentions-filter');

    await section('saved');
    // Source SavedPanel loads the descending saved list directly. It has no
    // Filters toggle, query box, or sort menu (SavedPanel.tsx:223,252-285).
    // Verify the authoritative saved row and its real navigation instead.
    await loaded(message: true);
    expect(state().advanced.direction, 'desc');
    expect(find.byTooltip('Filters'), findsNothing);
    final savedRow = find.byKey(ValueKey('saved-$messageId'));
    await tester.ensureVisible(savedRow);
    await tester.pumpAndSettle();
    await capture('native-saved-authoritative-row');
    await tester.tap(savedRow);
    await wait(
      () =>
          w.section == 'chat' &&
          w.channel?.id == channelId &&
          w.highlightedMessageId == messageId,
    );
    await capture('native-saved-open-message');

    await section('activity');
    // Pinned Source ThreadsInbox:1588–1604 mounts All/Unread/Mentions when
    // activity_sidebar_inbox_v0 is off. Channel/query/sort facets at1620–1669
    // belong to the separate enabled branch. This verifies the actual classic
    // controls and independent backend readback, not an absent Filters toggle.
    final flagPacket = await w.client.post(
      '/feature-flags/evaluate',
      data: {
        'keys': ['activity_sidebar_inbox_v0'],
        'serverId': w.server!.id,
        'platform': switch (defaultTargetPlatform) {
          TargetPlatform.android || TargetPlatform.iOS => 'mobile',
          _ => 'web',
        },
      },
    );
    expect(flagPacket, isA<Map>());
    expect(flagPacket['evaluations'], isA<List>());
    expect(
      (flagPacket['evaluations'] as List).whereType<Map>().any(
        (entry) =>
            entry['key'] == 'activity_sidebar_inbox_v0' &&
            entry['enabled'] == true,
      ),
      isFalse,
      reason: 'Classic Activity proof requires the actual experimental flag to be off',
    );
    final resource = find.byType(ResourceView);
    expect(find.byTooltip('Filters'), findsNothing);
    expect(
      find.descendant(of: resource, matching: find.byType(TextField)),
      findsNothing,
    );
    final control = find.descendant(
      of: resource,
      matching: find.byWidgetPredicate(
        (widget) => widget is RaftSegmentedControl<String>,
      ),
    );
    expect(control, findsOneWidget);
    expect(
      tester
          .widget<RaftSegmentedControl<String>>(control)
          .items
          .map((item) => item.value),
      ['all', 'unread', 'mentions'],
    );
    String rowKey(Map row) =>
        '${row['kind']}:${row['threadChannelId'] ?? row['channelId'] ?? row['id']}:${row['parentMessageId'] ?? ''}';
    for (final entry in const {
      'all': 'All',
      'unread': 'Unread',
      'mentions': 'Mentions',
    }.entries) {
      await tester.tap(
        find.descendant(of: control, matching: find.text(entry.value)),
      );
      await loaded();
      expect(state().filter, entry.key);
      expect(
        tester.widget<RaftSegmentedControl<String>>(control).value,
        entry.key,
      );
      final backend = await w.client.get(
        '/channels/inbox',
        query: {'filter': entry.key, 'limit': 30, 'offset': 0, 'sort': 'desc'},
      );
      final expected = backend is List ? backend : backend['items'];
      expect(expected, isA<List>());
      expect(
        (state().rows as List).cast<Map>().map(rowKey).toList(),
        (expected as List).cast<Map>().map(rowKey).toList(),
        reason:
            'Painted Activity data must match the independent $entry backend response',
      );
      expect(state().error, isNull);
      await capture('native-activity-classic-${entry.key}');
    }
  } finally {
    await navigate('chat');
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Uses a real task created earlier by the caller's account in its own channel.
Future<void> verifyAdvancedTaskFilters(
  WidgetTester tester,
  WorkspaceController w, {
  required String taskId,
  required String channelName,
  required Future<void> Function(String) capture,
  required Future<void> Function(String) navigate,
}) async {
  dynamic state() => tester.state(find.byType(ResourceView));
  Future<void> loaded() async {
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(ResourceView).evaluate().isNotEmpty &&
          state().loading == false) {
        expect(state().error, isNull);
        return;
      }
    }
    throw TestFailure('Native task filters did not finish loading.');
  }

  Future<void> pick(String field, List<String> labels) async {
    await loaded();
    final reviewedState = state();
    final trigger = find
        .byTooltip('Filter tasks by ${field.toLowerCase()}')
        .hitTestable();
    for (var i = 0; i < 30 && trigger.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(trigger, findsOneWidget);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    for (final label in labels) {
      final dialog = find.byType(RaftMenuPanel);
      if (dialog.evaluate().isEmpty) {
        throw StateError('Task filter authority changed during review.');
      }
      final search = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      await tester.tap(search);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(search, label);
      await tester.pumpAndSettle();
      final option = find.widgetWithText(RaftMenuItem, label);
      if (option.evaluate().isEmpty) {
        final editable = find.descendant(
          of: dialog,
          matching: find.byType(EditableText),
        );
        final entered = editable.evaluate().length == 1
            ? tester.widget<EditableText>(editable).controller.text == label
            : false;
        debugPrint(
          'Native task filter review interrupted: $field / $label; '
          'stateMounted=${reviewedState.mounted}, sameState=${identical(reviewedState, state())}, '
          'section=${w.section}, authorityCurrent=${reviewedState.acceptedAuthority == reviewedState.authority}, '
          'entered=$entered, unassignedVisible=${find.text("Unassigned").evaluate().isNotEmpty}',
        );
        throw StateError('Task filter option unavailable during fresh review.');
      }
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      // A catalog revocation can arrive while scrolling this private review.
      // Reopen against fresh authority; never tap a disposed/previous choice.
      if (!reviewedState.mounted ||
          !identical(reviewedState, state()) ||
          reviewedState.acceptedAuthority != reviewedState.authority ||
          option.evaluate().isEmpty) {
        throw StateError(
          'Task filter authority changed before the actual tap.',
        );
      }
      await tester.tap(option);
      await tester.pumpAndSettle();
    }
    final dialog = find.byType(RaftMenuPanel);
    if (dialog.evaluate().isEmpty) {
      throw StateError('Task filter authority changed during review.');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await loaded();
  }

  try {
    await navigate('tasks');
    await loaded();
    for (
      var page = 0;
      page < 20 &&
          !(state().rows as List).any((row) => row['id'] == taskId) &&
          state().hasMore == true;
      page++
    ) {
      final more = find.widgetWithText(TextButton, 'Load more');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await loaded();
    }
    expect((state().rows as List).any((row) => row['id'] == taskId), true);
    var selected = false;
    for (var retry = 0; retry < 3 && !selected; retry++) {
      try {
        await pick('Channel', ['#$channelName']);
        await pick('Creator', ['Created by me']);
        await pick('Assignee', ['Assigned to me', 'Unassigned']);
        selected =
            state().taskAdvanced.channels.isNotEmpty &&
            state().taskAdvanced.creators.isNotEmpty &&
            state().taskAdvanced.assignees.length == 2;
      } on StateError {
        // A late source revocation closes private reviews. Start a fresh
        // review only after its current-authority reload; never retain callbacks.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await loaded();
      }
    }
    expect(
      selected,
      true,
      reason: 'Task filters require a stable fresh review.',
    );
    expect((state().taskAdvanced.assignees as Set).length, 2);
    expect(
      (state().visibleRows as List).any((row) => row['id'] == taskId),
      true,
    );
    await capture('native-task-typed-multiselect-unassigned');
    await tester.tap(find.widgetWithText(TextButton, 'Clear filters'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(state().taskAdvanced.isEmpty, true);
  } finally {
    await navigate('chat');
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Only changes the thread created by this native run, restoring its follow
/// and active state through the actual product controls and server projections.
Future<void> verifyActivityThreadLifecycle(
  WidgetTester tester,
  WorkspaceController w, {
  required String threadId,
  required String parentId,
  required Future<void> Function(String) capture,
  required Future<void> Function(String) navigate,
}) async {
  dynamic state() => tester.state(find.byType(ResourceView));
  final tile = find.byKey(ValueKey('activity-thread-$threadId'));
  Future<void> loaded() async {
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(ResourceView).evaluate().isNotEmpty && !state().loading) {
        expect(state().error, isNull);
        return;
      }
    }
    throw TestFailure('Activity lifecycle did not finish loading.');
  }

  Future<void> locate() async {
    await loaded();
    bool hasOwnRow() => (state().rows as List).any(
      (row) => row['kind'] == 'thread' && row['threadChannelId'] == threadId,
    );
    for (var page = 0; page < 20 && !hasOwnRow(); page++) {
      final more = find.widgetWithText(TextButton, 'Load more');
      if (more.evaluate().isEmpty) break;
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await loaded();
    }
    for (var retry = 0; retry < 30 && !hasOwnRow(); retry++) {
      // The source's RisingWave list projection converges after its durable
      // acknowledgement. Use the mounted filter controls to reload; do not bypass them with
      // a canonical-only query or manufacture a row from the write receipt.
      await tester.pump(const Duration(milliseconds: 300));
      for (final filter in ['Unread', 'All']) {
        final tab = find.descendant(
          of: find.byType(RaftSegmentedControl<String>),
          matching: find.text(filter),
        );
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await loaded();
      }
    }
    expect(
      hasOwnRow(),
      true,
      reason: 'Activity must project this owned thread.',
    );
    final vertical = find
        .descendant(
          of: find.byType(ResourceView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(
      tile,
      250,
      scrollable: vertical,
      maxScrolls: 150,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(tile, findsOneWidget);
    final row = (state().rows as List).singleWhere(
      (row) => row['kind'] == 'thread' && row['threadChannelId'] == threadId,
    );
    expect(row['parentMessageId'], parentId);
  }

  Future<void> rowAction(String tooltip) async {
    await locate();
    TestGesture? mouse;
    try {
      if (RaftDensityScope.of(tester.element(tile)) == RaftDensity.desktop) {
        mouse = createNativeMouse(
          tester,
          buttons: tooltip == 'Unfollow thread' || tooltip == 'Follow thread'
              ? kSecondaryMouseButton
              : kPrimaryMouseButton,
        );
        await mouse.addPointer(location: tester.getCenter(tile));
        await mouse.moveTo(tester.getCenter(tile));
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Source ThreadsInbox exposes follow/unfollow in the row context menu;
      // the hover action is exclusively done/restore.
      if (tooltip == 'Unfollow thread' || tooltip == 'Follow thread') {
        final point = tester.getTopLeft(tile) + const Offset(16, 16);
        if (defaultTargetPlatform == TargetPlatform.linux) {
          // Reuse this owned hover device for the secondary-button press.
          await mouse!.down(point);
          await mouse.up();
        } else {
          await tester.longPressAt(point);
        }
        await tester.pumpAndSettle();
        final action = find.widgetWithText(
          RaftMenuItem,
          tooltip == 'Unfollow thread' ? 'Unfollow' : 'Follow',
        );
        expect(action, findsOneWidget);
        await tester.tap(action);
        await loaded();
        return;
      }
      final button = find.descendant(
        of: tile,
        matching: find.byTooltip(tooltip),
      );
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await loaded();
    } finally {
      if (mouse != null) await mouse.removePointer();
    }
  }

  Future<void> view(String label) async {
    if (find.byTooltip('Activity actions').evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Filters'));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.byTooltip('Activity actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await loaded();
  }

  Future<void> reset() async {
    final all = find.descendant(
      of: find.byType(RaftSegmentedControl<String>),
      matching: find.text('All'),
    );
    expect(all, findsOneWidget);
    await tester.ensureVisible(all);
    await tester.pumpAndSettle();
    await tester.tap(all);
    await loaded();
    expect(state().filter, 'all');
  }

  try {
    await navigate('activity');
    await locate();
    await rowAction('Mark conversation done');
    await view('Done conversations');
    await locate();
    await capture('activity-thread-done');
    await rowAction('Restore conversation');
    await reset();
    await locate();
    await rowAction('Unfollow thread');
    await view('Unfollowed threads');
    await locate();
    await capture('activity-thread-unfollowed');
    await rowAction('Follow thread');
    await reset();
    await locate();
    final followed = await w.query('/channels/threads/followed');
    expect(
      (followed['threads'] as List).any(
        (row) => row['parentMessageId'] == parentId,
      ),
      true,
    );
    await capture('activity-thread-restored');
  } finally {
    // A failed UI assertion still restores only this run's own thread.
    await w.command(
      'POST',
      '/channels/threads/undone',
      data: {'threadChannelId': threadId},
    );
    await w.command(
      'POST',
      '/channels/threads/follow',
      data: {'parentMessageId': parentId},
    );
    await navigate('chat');
    await tester.pump(const Duration(milliseconds: 300));
  }
}
