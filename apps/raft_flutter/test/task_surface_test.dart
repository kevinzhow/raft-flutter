import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture, MessageAdapter;

import 'package:raft_flutter/data/workspace_controller.dart';

import 'message_context_transition_test.dart' show row;

final modernTask = <String, dynamic>{
  'id': 'task-1',
  'taskNumber': 8,
  'title': 'Scoped actual task',
  'description': 'Accepted task description',
  'channelId': 'c1',
  'channelName': 'test',
  'messageId': 'task-parent',
  'threadChannelId': 'task-thread',
  'status': 'todo',
  'createdByType': 'user',
  'createdById': 'alice',
  'createdByName': 'Alice',
};

Future<void> flush(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void taskRoutes(MessageAdapter api, Map<String, dynamic> task) {
  api.routes['GET /servers/s1/members'] = (_) => <dynamic>[];
  api.routes['GET /agents'] = (_) => <dynamic>[];
  api.routes['GET /tasks/server'] = (r) => {
    'tasks':
        r.queryParameters['status'] == null ||
            r.queryParameters['status'] == task['status']
        ? [task]
        : [],
    'next_cursor': null,
  };
  api.routes['GET /tasks/channel/c1/number/8'] = (_) => {'task': task};
  api.routes['GET /tasks/task-1/history'] = (_) => {'events': <dynamic>[]};
  api.routes['GET /messages/context/task-parent'] = (_) => {
    'messages': [row('task-parent', 'c1', 1)],
  };
  api.routes['GET /messages/channel/task-thread'] = (_) => {
    'messages': <dynamic>[],
  };
  api.routes['POST /channels/task-thread/read'] = (_) => {};
}

Widget taskHost(WorkspaceController w, RaftFamily family, bool dark) =>
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: Scaffold(
        body: ResourceView(
          controller: w,
          section: 'tasks',
          onMessage: (_, _) async {
            fail('No main redirect');
          },
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K10b] legacy accepted metadata remains read-only without discussion/history $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        taskRoutes(api, {...modernTask, 'isLegacy': true});
        await t.pumpWidget(taskHost(w, family, dark));
        await flush(t);
        await t.tap(find.text('Scoped actual task'));
        await flush(t);
        expect(find.byKey(const ValueKey('legacy-task-panel')), findsOneWidget);
        expect(
          find.textContaining('Legacy tasks do not map to a message thread.'),
          findsOneWidget,
        );
        expect(find.text('Task #8 · LEGACY'), findsOneWidget);
        expect(find.text('@Alice'), findsOneWidget);
        expect(find.byType(RaftComposer), findsNothing);
        expect(
          find.descendant(
            of: find.byType(SourceTaskSurface),
            matching: find.byType(RaftInlineBadgeEditor),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('task-properties-assignee')),
          findsNothing,
        );
        expect(
          api.calls.where(
            (r) =>
                r.path.endsWith('/history') ||
                r.path.contains('/messages/') ||
                r.path.contains('/number/'),
          ),
          isEmpty,
        );
        await t.tap(find.byTooltip('Close task'));
        await flush(t);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '[K10c] real task reply/parent late completion cannot reopen or read a retired modal $family/$dark',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        taskRoutes(api, modernTask);
        final replies = Completer<dynamic>(),
            parent = Completer<dynamic>(),
            details = Completer<dynamic>();
        api.routes['GET /messages/context/task-parent'] = (_) => parent.future;
        api.routes['GET /messages/channel/task-thread'] = (_) => replies.future;
        api.routes['GET /tasks/channel/c1/number/8'] = (_) => details.future;
        await t.pumpWidget(taskHost(w, family, dark));
        await flush(t);
        await t.tap(find.text('Scoped actual task'));
        await flush(t);
        final owner = t
            .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
            .owner;
        expect(find.byType(RaftComposer), findsOneWidget);
        await t.tap(find.byTooltip('Close task'));
        await flush(t);
        replies.complete({
          'messages': [row('private-late', 'task-thread', 1)],
        });
        parent.complete({
          'messages': [row('task-parent', 'c1', 1)],
        });
        details.complete({'task': modernTask});
        await flush(t);
        expect(owner.closed, isTrue);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(find.text('Message private-late'), findsNothing);
        expect(
          api.calls.where(
            (r) => r.path.endsWith('/read') || r.path.endsWith('/history'),
          ),
          isEmpty,
        );
        expect(w.client.user!.id, 'alice');
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '[K10b] actual task property writes preserve actor type and done assignee lock $family/$dark',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        final task = {...modernTask, 'revision': 4};
        taskRoutes(api, task);
        api.routes['GET /channels/c1/members'] = (_) => {
          'humans': [
            {'id': 'shared', 'displayName': 'Human owner'},
          ],
          'agents': [
            {'id': 'shared', 'displayName': 'Agent owner'},
          ],
        };
        api.routes['PATCH /tasks/task-1/assignee'] = (r) {
          expect(r.data, {
            'assignee': {'type': 'agent', 'id': 'shared'},
            'expectedRevision': 4,
          });
          return {
            'task': {
              ...task,
              'claimedById': 'shared',
              'claimedByType': 'agent',
              'claimedByName': 'Agent owner',
            },
          };
        };
        api.routes['PATCH /tasks/task-1/status'] = (r) {
          expect(r.data, {'status': 'done'});
          task['status'] = 'done';
          return {
            'task': {
              ...task,
              'status': 'done',
              'claimedById': 'shared',
              'claimedByType': 'agent',
              'claimedByName': 'Agent owner',
            },
          };
        };
        await t.pumpWidget(taskHost(w, family, dark));
        await flush(t);
        await t.tap(find.text('Scoped actual task'));
        await flush(t);
        await t.tap(find.byKey(const ValueKey('task-properties-assignee')));
        await flush(t);
        expect(find.text('Human owner'), findsOneWidget);
        expect(find.text('Agent owner'), findsOneWidget);
        await t.enterText(
          find.byKey(const ValueKey('task-assignee-search')),
          'Agent',
        );
        await t.pump();
        expect(find.text('Human owner'), findsNothing);
        expect(find.text('Unassigned'), findsWidgets);
        await t.tap(find.text('Agent owner'));
        await flush(t);
        expect(find.text('@Agent owner'), findsOneWidget);
        expect(
          t
              .widget<RaftInlineBadgeEditor>(
                find.byKey(const ValueKey('task-properties-status')),
              )
              .enabled,
          isTrue,
        );
        await t.tap(find.byKey(const ValueKey('task-properties-status')));
        await flush(t);
        expect(find.byType(RaftInlineBadgeMenu), findsOneWidget);
        await t.tap(
          find.descendant(
            of: find.byType(RaftInlineBadgeMenu),
            matching: find.byKey(const ValueKey('done')),
          ),
        );
        await flush(t);
        expect(
          t
              .widget<RaftTextButton>(
                find.byKey(const ValueKey('task-properties-assignee')),
              )
              .onPressed,
          isNull,
        );
        expect(api.calls.where((r) => r.method == 'PATCH'), hasLength(2));
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await flush(t);
        expect(t.takeException(), isNull);
      },
    );
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '[K10b] card task owns discussion, properties and history $family/$dark/$width',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = (await t.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.ledger.switchServer('s1');
          w.ledger.ingest([
            row('main-accepted', 'c1', 1),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1'] = {'main-accepted'};
          w.threadParent = RaftMessage(row('side-parent', 'c1', 2));
          w.threadChannelId = 'side-thread';
          w.ledger.ingest([
            row('side-accepted', 'side-thread', 1),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['side-thread'] = {'side-accepted'};
          w.drafts['c1'] = 'Main draft';
          w.drafts['thread:side-parent'] = 'Side draft';
          final before = w.location.toString(), revision = w.navigationRevision;
          final details = Completer<dynamic>(),
              parent = Completer<dynamic>(),
              replies = Completer<dynamic>(),
              history = Completer<dynamic>();
          api.routes['GET /servers/s1/members'] = (_) => <dynamic>[];
          api.routes['GET /agents'] = (_) => <dynamic>[];
          api.routes['GET /tasks/server'] = (request) => {
            'tasks':
                request.queryParameters['status'] == null ||
                    request.queryParameters['status'] == 'todo'
                ? [modernTask]
                : [],
            'next_cursor': null,
          };
          api.routes['GET /tasks/channel/c1/number/8'] = (_) => details.future;
          api.routes['GET /tasks/task-1/history'] = (_) => history.future;
          api.routes['GET /messages/context/task-parent'] = (_) =>
              parent.future;
          api.routes['GET /messages/channel/task-thread'] = (_) =>
              replies.future;
          api.routes['POST /channels/task-thread/read'] = (_) => {};
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: ResourceView(
                  controller: w,
                  section: 'tasks',
                  onMessage: (_, _) async {
                    fail('Task discussion must not redirect main');
                  },
                ),
              ),
            ),
          );
          await flush(t);
          await t.tap(find.text('Scoped actual task'));
          await flush(t);
          final surface = find.byType(SourceTaskSurface);
          expect(surface, findsOneWidget);
          final owner = t.widget<SourceTaskSurface>(surface).owner;
          final child = owner.discussion!;
          expect(child.threadIdentity!.parentMessageId, 'task-parent');
          expect(child.threadChannelId, 'task-thread');
          expect(find.byType(RaftComposer), findsOneWidget);
          expect(
            find.byKey(const ValueKey('task-modal-title')),
            findsOneWidget,
          );
          expect(find.text('Task #8'), findsOneWidget);
          expect(find.text('Discussion'), findsNothing);
          expect(find.text('Claim'), findsNothing);
          expect(find.text('Delete'), findsNothing);
          final bar = t.getRect(find.byKey(const ValueKey('task-modal-bar')));
          final composer = t.getRect(find.byType(RaftComposer));
          expect(bar.height, family == RaftFamily.brutal ? 54 : 53);
          for (var i = 0; i < 4; i++) {
            await t.pump(const Duration(milliseconds: 16));
            expect(
              t.getRect(find.byKey(const ValueKey('task-modal-bar'))),
              bar,
            );
            expect(t.getRect(find.byType(RaftComposer)), composer);
            expect(w.location.toString(), before);
            expect(w.navigationRevision, revision);
            expect(w.messages.single.id, 'main-accepted');
            expect(w.threadChannelId, 'side-thread');
            expect(w.replies.single.id, 'side-accepted');
          }
          details.complete({'task': modernTask});
          await flush(t);
          expect(owner.historyLoading, true);
          await t.tap(find.byKey(const ValueKey('task-properties-history')));
          await flush(t);
          expect(find.text('Scoped actual task'), findsNWidgets(2));
          history.complete({
            'events': [
              {
                'eventType': 'created',
                'actorName': 'Alice',
                'createdAt': '2026-10-10T00:00:00Z',
              },
              {
                'eventType': 'resource_receipt_recorded',
                'actorName': 'Internal receipt',
                'createdAt': '2026-10-10T00:00:00Z',
              },
            ],
          });
          replies.complete({
            'messages': [row('task-reply', 'task-thread', 1)],
          });
          await flush(t);
          expect(owner.historyLoading, false);
          expect(find.text('Created task'), findsOneWidget);
          expect(find.textContaining('Internal receipt'), findsNothing);
          expect(
            find.byKey(const ValueKey('message-task-reply')),
            findsWidgets,
          );
          parent.complete({
            'messages': [row('task-parent', 'c1', 2)],
          });
          await flush(t);
          expect(
            find.byKey(const ValueKey('message-task-parent')),
            findsNothing,
            reason: 'TaskModalHead replaces the repeated message anchor',
          );
          expect(t.getRect(find.byType(RaftComposer)), composer);
          await t.enterText(
            find.descendant(
              of: find.byType(RaftComposer),
              matching: find.byType(EditableText),
            ),
            'Scoped task draft',
          );
          await t.pump();
          expect(child.drafts['thread:task-parent'], 'Scoped task draft');
          expect(w.drafts['c1'], 'Main draft');
          expect(w.drafts['thread:side-parent'], 'Side draft');
          api.routes['POST /v2/messages'] = (r) {
            expect(r.data['channelId'], 'task-thread');
            expect(r.data['content'], 'Scoped task draft');
            return {
              'message': {
                ...row('sent-task-reply', 'task-thread', 2),
                'content': 'Scoped task draft',
              },
            };
          };
          await t.tap(find.byTooltip('Send message (Ctrl+Enter)'));
          await flush(t);
          expect(
            api.calls.where(
              (r) => r.method == 'POST' && r.path == '/v2/messages',
            ),
            hasLength(1),
          );
          expect(w.drafts['c1'], 'Main draft');
          expect(w.drafts['thread:side-parent'], 'Side draft');
          expect(
            api.calls.where((r) => r.path == '/channels/c1/read'),
            isEmpty,
          );

          expect(
            api.calls.where((r) => r.path == '/messages/channel/c1'),
            isEmpty,
          );
          expect(
            api.calls.where(
              (r) => r.path == '/channels/c1/threads/task-parent',
            ),
            isEmpty,
          );
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await flush(t);
          expect(surface, findsNothing);
          expect(owner.closed, true);
          expect(w.threadChannelId, 'side-thread');
          expect(w.messages.single.id, 'main-accepted');
          expect(w.client.user!.id, 'alice');
          expect(t.takeException(), isNull);
          // Flutter chat's deferred initial-scroll timer checks mounted after
          // disposal. Drain teardown after every visible-state assertion;
          // this does not delay, warm up or alter the product input sequence.
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    }
  }
}
