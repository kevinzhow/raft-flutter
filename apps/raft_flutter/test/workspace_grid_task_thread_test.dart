import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_grid_sessions.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_grid_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_task_parent_hydration_test.dart'
    show parentFixture, ParentAdapter, ParentClient;

const tabId = 'thread:c1:task-parent';
final threadTab = find.byKey(const ValueKey('editor-tab-$tabId'));
final channelTab = find.byKey(const ValueKey('editor-tab-c1'));
final badge = find.byKey(const ValueKey('message-task-task-parent'));
final channelBody = find.byKey(const ValueKey('grid-conversation-c1-0'));
final threadBody = find.byKey(const ValueKey('grid-thread-$tabId'));
Finder editor(Finder host) => find.descendant(
  of: host,
  matching: find.descendant(
    of: find.byType(RaftComposer),
    matching: find.byType(TextField),
  ),
);
Finder closeThreadTab() => find.byWidgetPredicate(
  (widget) =>
      widget is RaftInteractive &&
      widget.semanticLabel == 'Close Thread task-par',
);

Future<WorkspaceGridViewState> mountGrid(
  WidgetTester t,
  WorkspaceController w,
  ParentAdapter api,
  RaftFamily family,
  bool dark, {
  bool acceptedSummary = false,
}) async {
  t.view.physicalSize = const Size(1400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  taskRoutes(api, modernTask);
  api.routes['GET /tasks/channel/c1'] = (_) => {
    'tasks': [modernTask],
  };
  api.routes['GET /messages/channel/c1'] = (_) => {
    'messages': [row('task-parent', 'c1', 1)],
    if (acceptedSummary)
      'threadSummariesByParentMessageId': {
        'task-parent': {
          'threadChannelId': 'task-thread',
          'replyCount': 1,
          'parentMessageId': 'task-parent',
          'lastReplySeq': '1',
        },
      },
  };
  api.routes['GET /channels/c1/threads/task-parent'] = (_) => {
    'threadChannelId': 'task-thread',
  };
  w.setSection('chat');
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: WorkspaceView(
        controller: w,
        appearance: RaftAppearance(light: family),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
  await flush(t);
  await t.tap(find.byKey(const Key('workspace-mode-toggle')));
  await flush(t);
  // Wait for the actual accepted Flyer row and its async task projection.
  for (
    var frame = 0;
    frame < 40 && badge.hitTestable().evaluate().isEmpty;
    frame++
  ) {
    await t.pump(const Duration(milliseconds: 16));
  }
  expect(badge.hitTestable(), findsOneWidget);
  return t.state<WorkspaceGridViewState>(find.byType(WorkspaceGridView));
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K10b grid footer] accepted Source summary opens real replies immediately without lookup $family/$dark',
      (t) async {
        final (w, api) = await parentFixture(t);
        final grid = await mountGrid(
          t,
          w,
          api,
          family,
          dark,
          acceptedSummary: true,
        );
        final parent = Completer<Map>(), replies = Completer<Map>();
        api.routes['GET /messages/context/task-parent'] = (_) => parent.future;
        api.routes['GET /messages/channel/task-thread'] = (_) => replies.future;
        api.routes['GET /channels/c1/threads/task-parent'] = (_) {
          fail('An accepted Source summary avoids a thread lookup');
        };
        await t.tap(badge);
        await flush(t);
        final child = grid.sessions.controllers[tabId]!;
        expect(child.threadChannelId, 'task-thread');
        expect(child.threadResolutionLoading, isFalse);
        expect(child.threadParent, isNull);
        expect(child.threadLoading, isTrue);
        expect(editor(threadBody), findsOneWidget);
        expect(
          api.calls.where((r) => r.path == '/messages/channel/task-thread'),
          hasLength(1),
        );
        expect(
          api.calls.where((r) => r.path == '/channels/c1/threads/task-parent'),
          isEmpty,
        );
        replies.complete({
          'messages': [row('known-reply', 'task-thread', 1)],
        });
        await flush(t);
        expect(child.replies.single.id, 'known-reply');
        expect(child.threadParent, isNull);
        parent.complete({
          'messages': [row('task-parent', 'c1', 1)],
        });
        await flush(t);
        expect(child.threadParent!.id, 'task-parent');
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await flush(t);
      },
    );
    testWidgets(
      '[K10b grid footer] real badge opens/deduplicates a separate thread tab and retains both editors $family/$dark',
      (t) async {
        final (w, api) = await parentFixture(t);
        final grid = await mountGrid(t, w, api, family, dark);
        final channel = grid.sessions.controllers['c1']!;
        final mainWindow = channel.messages.map((m) => m.id).toList();
        final mainGeneration = channel.channelGeneration;
        final rootNavigation = w.navigationRevision;
        final rootChannelGeneration = w.channelGeneration;
        final rootThreadGeneration = w.threadGeneration;
        final uri = w.location.uri;
        final generation = w.client.generation;
        await t.enterText(editor(channelBody), 'Retained real channel editor');
        final channelEditor = t
            .widget<TextField>(editor(channelBody))
            .controller!;
        channelEditor.selection = const TextSelection.collapsed(offset: 7);
        final channelEditorState = t.state(editor(channelBody));
        final parent = Completer<Map>(), lookup = Completer<Map>();
        final replies = Completer<Map>();
        api.routes['GET /messages/context/task-parent'] = (_) => parent.future;
        api.routes['GET /channels/c1/threads/task-parent'] = (_) =>
            lookup.future;
        api.routes['GET /messages/channel/task-thread'] = (_) => replies.future;
        await t.tap(badge);
        await flush(t);
        final child = grid.sessions.controllers[tabId]!;
        expect(child, isNot(same(channel)));
        expect(child.client, same(w.client));
        expect(child.entityDirectory, same(w.entityDirectory));
        expect(threadTab, findsOneWidget);
        expect(channelTab, findsOneWidget);
        expect(grid.selected[grid.activeGroup], tabId);
        expect(grid.activeChannelId, 'c1');
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(find.byType(RaftThreadHeader), findsNothing);
        expect(child.threadParentMessageId, 'task-parent');
        expect(channel.threadParentMessageId, isNull);
        expect(w.threadParentMessageId, isNull);
        for (var frame = 0; frame < 8; frame++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(threadTab, findsOneWidget);
          expect(find.text('Message task-parent').hitTestable(), findsNothing);
          expect(w.location.uri, uri);
          expect(channel.messages.map((m) => m.id), mainWindow);
        }
        // Thread resolution and real parent metadata are independent requests.
        lookup.complete({'threadChannelId': 'task-thread'});
        await flush(t);
        expect(child.threadChannelId, 'task-thread');
        expect(child.threadParent, isNull);
        parent.complete({
          'messages': [row('task-parent', 'c1', 1)],
        });
        await flush(t);
        expect(child.threadParent!.id, 'task-parent');
        expect(child.threadLoading, isTrue);
        replies.complete({
          'messages': [row('reply-real', 'task-thread', 1)],
        });
        await flush(t);
        for (
          var frame = 0;
          frame < 40 && editor(threadBody).evaluate().isEmpty;
          frame++
        ) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(child.replies.single.id, 'reply-real');
        await t.enterText(editor(threadBody), 'Independent actual reply draft');
        final replyEditor = t.widget<TextField>(editor(threadBody)).controller!;
        replyEditor.selection = const TextSelection.collapsed(offset: 9);
        final replyEditorState = t.state(editor(threadBody));
        await t.tap(channelTab);
        await flush(t);
        expect(t.state(editor(channelBody)), same(channelEditorState));
        expect(channelEditor.text, 'Retained real channel editor');
        expect(channelEditor.selection.baseOffset, 7);
        expect(child.foreground, isFalse);
        // A second real footer click selects the existing tab without reopening
        // its accepted window or resetting its draft/selection.
        await t.tap(badge);
        await flush(t);
        expect(grid.sessions.controllers[tabId], same(child));
        expect(
          grid.groups.expand((g) => g).where((id) => id == tabId),
          hasLength(1),
        );
        expect(t.state(editor(threadBody)), same(replyEditorState));
        expect(replyEditor.text, 'Independent actual reply draft');
        expect(replyEditor.selection.baseOffset, 9);
        expect(
          api.calls.where((r) => r.path == '/channels/c1/threads/task-parent'),
          hasLength(1),
        );
        expect(
          api.calls.where((r) => r.path == '/messages/context/task-parent'),
          hasLength(1),
        );
        t.view.physicalSize = const Size(1023, 900);
        await flush(t);
        expect(child.foreground, isFalse);
        expect(channel.foreground, isFalse);
        t.view.physicalSize = const Size(1400, 900);
        await flush(t);
        expect(t.state(editor(threadBody)), same(replyEditorState));
        expect(replyEditor.text, 'Independent actual reply draft');
        expect(replyEditor.selection.baseOffset, 9);
        // Re-admitting a visible accepted viewport can acknowledge it; the
        // hidden-completion case below checks the actual no-hidden-read fence.
        await t.tap(closeThreadTab());
        await flush(t);
        expect(threadTab, findsNothing);
        expect(grid.sessions.controllers.containsKey(tabId), isFalse);
        expect(child.server, isNull);
        expect(child.foreground, isFalse);
        expect(t.state(editor(channelBody)), same(channelEditorState));
        expect(channelEditor.text, 'Retained real channel editor');
        expect(channelEditor.selection.baseOffset, 7);
        expect(channel.channelGeneration, mainGeneration);
        expect(w.channelGeneration, rootChannelGeneration);
        expect(w.threadGeneration, rootThreadGeneration);
        expect(w.navigationRevision, rootNavigation);
        expect(w.location.uri, uri);
        expect(w.client.generation, generation);
        expect(w.client.user!.id, 'alice');
        expect(await t.runAsync(() => w.client.get('/agents')), isEmpty);
        expect(
          w.drafts['thread:task-parent'],
          'Independent actual reply draft',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await flush(t);
      },
    );

    for (final retire in [
      'close',
      'server',
      'principal',
      'role',
      'channel',
      'capability',
    ]) {
      testWidgets(
        '[K10b grid footer] $retire retires pending thread authority and rejects late parent/replies/read $family/$dark',
        (t) async {
          final (w, api) = await parentFixture(t);
          final grid = await mountGrid(t, w, api, family, dark);
          final parent = Completer<Map>(), replies = Completer<Map>();
          api.routes['GET /messages/context/task-parent'] = (_) =>
              parent.future;
          api.routes['GET /messages/channel/task-thread'] = (_) =>
              replies.future;
          await t.tap(badge);
          await flush(t);
          final child = grid.sessions.controllers[tabId]!;
          expect(child.threadChannelId, 'task-thread');
          expect(
            api.calls.where((r) => r.path == '/messages/channel/task-thread'),
            hasLength(1),
          );
          switch (retire) {
            case 'close':
              await t.tap(closeThreadTab());
            case 'server':
              w.client.selectServer('other');
              w.notifyListeners();
            case 'principal':
              w.client.user = RaftRecord({'id': 'different-user'});
              w.notifyListeners();
            case 'role':
              w.server = RaftRecord({
                'id': 's1',
                'slug': 'demo',
                'role': 'member',
              });
              w.notifyListeners();
            case 'channel':
              (w.client as ParentClient).eventStream.add(
                const RaftEvent('channel:removed', {'channelId': 'c1'}),
              );
            case 'capability':
              w.channels = [
                RaftChannel({
                  ...w.channel!.json,
                  'channelCapabilities': {'viewChannel': false},
                }),
              ];
              w.notifyListeners();
          }
          await flush(t);
          expect(grid.sessions.controllers.containsKey(tabId), isFalse);
          expect(threadTab, findsNothing);
          parent.complete({
            'messages': [row('task-parent', 'c1', 1)],
          });
          replies.complete({
            'messages': [row('private-late', 'task-thread', 1)],
          });
          await flush(t);
          expect(threadTab, findsNothing);
          expect(find.text('Message private-late'), findsNothing);
          expect(child.server, isNull);
          expect(child.threadParent, isNull);
          expect(
            api.calls.where((r) => r.path == '/channels/task-thread/read'),
            isEmpty,
          );
          expect(find.byType(SourceTaskSurface), findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await flush(t);
        },
      );
    }

    testWidgets(
      '[K10b grid footer] inactive tab keeps accepted reply draft but late replies do not acknowledge $family/$dark',
      (t) async {
        final (w, api) = await parentFixture(t);
        final grid = await mountGrid(t, w, api, family, dark);
        final replies = Completer<Map>();
        api.routes['GET /messages/channel/task-thread'] = (_) => replies.future;
        await t.tap(badge);
        await flush(t);
        final child = grid.sessions.controllers[tabId]!;
        await t.tap(channelTab);
        await flush(t);
        expect(child.foreground, isFalse);
        replies.complete({
          'messages': [row('hidden-real', 'task-thread', 1)],
        });
        await flush(t);
        expect(child.replies.single.id, 'hidden-real');
        expect(
          api.calls.where((r) => r.path == '/channels/task-thread/read'),
          isEmpty,
        );
        expect(find.text('Message hidden-real').hitTestable(), findsNothing);
        // Actual keyboard activation of the retained tab admits its existing
        // timeline; no thread resolution or reply reload is performed.
        final tabControl = find.byWidgetPredicate(
          (widget) =>
              widget is RaftInteractive &&
              widget.semanticLabel == 'Thread task-par',
        );
        t.widget<RaftInteractive>(tabControl).focusNode!.requestFocus();
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await flush(t);
        expect(child.foreground, isTrue);
        expect(
          api.calls.where((r) => r.path == '/messages/channel/task-thread'),
          hasLength(1),
        );
        expect(grid.sessions.threadRefs[tabId], isA<WorkspaceGridThreadRef>());
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await flush(t);
      },
    );
  }
}
