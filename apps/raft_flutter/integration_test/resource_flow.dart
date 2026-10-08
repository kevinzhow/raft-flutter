import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';

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
    w.setSection(value);
    await tester.pump(const Duration(milliseconds: 300));
    await loaded();
    if (['saved', 'activity'].contains(value)) {
      await tester.tap(find.byTooltip('Filters'));
      await tester.pump(const Duration(milliseconds: 200));
    }
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
    await tester.testTextInput.receiveAction(TextInputAction.done);
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
    await menu('Filter by channel', '#$channelName');
    await menu('Sort conversations', 'Oldest first');
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await loaded(message: true);
    expect(state().advanced.direction, 'asc');
    await capture('native-saved-channel-query-sort');

    await section('activity');
    // Activity facets may append authoritative counts to the channel label.
    await tester.tap(find.byTooltip('Filter by channel'));
    await tester.pump(const Duration(milliseconds: 300));
    final option = find
        .descendant(
          of: find.byType(PopupMenuItem<String>),
          matching: find.textContaining('#$channelName'),
        )
        .last;
    await tester.tap(option);
    await loaded();
    await menu('Sort conversations', 'Oldest first');
    await tester.tap(find.text('Group by channel'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(state().advanced.groupByChannel, true);
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await loaded();
    await capture('native-activity-channel-query-grouping');
  } finally {
    w.setSection('chat');
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
    w.setSection('tasks');
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
    w.setSection('chat');
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
      // acknowledgement. Use the real refresh action; do not bypass it with
      // a canonical-only query or manufacture a row from the write receipt.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.descendant(
          of: find.byType(ResourceView),
          matching: find.byTooltip('Refresh'),
        ),
      );
      await loaded();
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
    if (RaftDensityScope.of(tester.element(tile)) == RaftDensity.desktop) {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(tile));
      await mouse.moveTo(tester.getCenter(tile));
      await tester.pump(const Duration(milliseconds: 200));
      addTearDown(mouse.removePointer);
    }
    final button = find.descendant(of: tile, matching: find.byTooltip(tooltip));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await loaded();
  }

  Future<void> view(String label) async {
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
    w.setSection('activity');
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
    w.setSection('chat');
    await tester.pump(const Duration(milliseconds: 300));
  }
}
