import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/task_surface_controller.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;
import 'task_surface_test.dart' show modernTask, taskRoutes;

/// Lets Dio and the controllers finish real async work, then paints.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await t.pump(const Duration(milliseconds: 16));
  }
}

/// Completes a held route response, then lets the result reach the widgets.
Future<void> release(
  WidgetTester t,
  Completer<dynamic> gate,
  dynamic value,
) async {
  gate.complete(value);
  await settle(t);
}

Map<String, dynamic> fileRow(String id, {String name = ''}) => {
  'id': id,
  'messageId': 'message-$id',
  'channelId': 'c1',
  'filename': name.isEmpty ? '$id.txt' : name,
  'mimeType': 'text/plain',
  'sizeBytes': 1024,
  'createdAt': '2026-10-08T01:30:00Z',
  'source': {'type': 'channel', 'channelId': 'c1'},
};

/// Panel text is painted through RaftCssText (RichText).
Finder rich(String text) => find.text(text, findRichText: true);

const _themes = [
  (RaftFamily.brutal, false),
  (RaftFamily.elegant, false),
  (RaftFamily.elegant, true),
];

void main() {
  for (final (family, dark) in _themes) {
    testWidgets(
      '$family/$dark Files tab: revisit and thread open show cached rows at the first frame; refresh replaces in place; identity change drops them',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /tasks/channel/c1'] = (_) => {
          'tasks': [],
          'nextCursor': null,
        };
        final held = <Completer<dynamic>>[];
        var reads = 0;
        api.routes['GET /channels/c1/files'] = (_) {
          reads++;
          if (reads == 1) {
            return {
              'files': [fileRow('a'), fileRow('b')],
              'nextCursor': null,
            };
          }
          final gate = Completer<dynamic>();
          held.add(gate);
          return gate.future;
        };
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: ConversationPanel(controller: w)),
          ),
        );
        await settle(t);
        final tabs = find.byKey(const Key('conversation-tabs'));
        Future<void> openTab(String label) async {
          await t.tap(find.descendant(of: tabs, matching: find.text(label)));
        }

        await openTab('Files');
        await t.pump();
        // First ever visit has nothing to show.
        expect(find.text('Loading files…'), findsOneWidget);
        await settle(t);
        expect(find.text('a.txt'), findsOneWidget);
        expect(find.text('b.txt'), findsOneWidget);
        final a = t.getRect(find.text('a.txt')),
            b = t.getRect(find.text('b.txt'));

        await openTab('Chat');
        await settle(t);
        expect(find.text('a.txt'), findsNothing);

        // Revisit: the very first frame is final, with the refresh pending.
        await openTab('Files');
        await t.pump();
        expect(find.text('Loading files…'), findsNothing);
        expect(find.text('No files yet'), findsNothing);
        expect(t.getRect(find.text('a.txt')), a);
        expect(t.getRect(find.text('b.txt')), b);
        await settle(t);
        expect(held, hasLength(1));
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(find.text('Loading files…'), findsNothing);
          expect(t.getRect(find.text('a.txt')), a);
        }

        // Opening a thread / socket traffic does not re-fence the list.
        w.threadGeneration++;
        w.channelGeneration++;
        w.notifyListeners();
        await t.pump();
        expect(find.text('Loading files…'), findsNothing);
        expect(t.getRect(find.text('a.txt')), a);
        expect(t.getRect(find.text('b.txt')), b);
        expect(held, hasLength(1), reason: 'no refetch for a thread');

        // The refresh replaces in place: shown rows do not move, a new row
        // appears below them, frame by frame.
        held.single.complete({
          'files': [fileRow('a'), fileRow('b'), fileRow('c')],
          'nextCursor': null,
        });
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(find.text('Loading files…'), findsNothing);
          expect(t.getRect(find.text('a.txt')), a);
          expect(t.getRect(find.text('b.txt')), b);
        }
        expect(find.text('c.txt'), findsOneWidget);

        // A failed background refresh keeps what is shown.
        await openTab('Chat');
        await settle(t);
        await openTab('Files');
        await t.pump();
        await settle(t);
        expect(held, hasLength(2));
        held.last.completeError(Exception('offline'));
        await settle(t);
        expect(find.text('a.txt'), findsOneWidget);
        expect(find.text('Could not load files.'), findsNothing);

        // Another role is another identity: nothing carries over.
        await openTab('Chat');
        await settle(t);
        w.server = RaftRecord({'id': 's1', 'role': 'member'});
        w.notifyListeners();
        await t.pump();
        await openTab('Files');
        await t.pump();
        expect(find.text('a.txt'), findsNothing);
        expect(find.text('Loading files…'), findsOneWidget);
        await settle(t);
        expect(held, hasLength(3));
        held.last.complete({'files': [], 'nextCursor': null});
        await settle(t);
        expect(find.text('No files yet'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
  }

  final agent = <String, dynamic>{
    'id': 'a1',
    'name': 'bot',
    'displayName': 'Bot',
    'status': 'active',
    'runtime': 'claude',
    'model': 'sonnet',
  };
  Widget agentPanel(
    dynamic w,
    RaftFamily family,
    bool dark, {
    AgentDetailTab tab = AgentDetailTab.profile,
  }) => MaterialApp(
    theme: raftTheme(family, dark: dark),
    home: Scaffold(
      body: AgentDetailPanel(
        key: const ValueKey('agent-panel'),
        controller: w,
        agent: agent,
        machines: const [],
        actions: const AgentDetailActions(),
        canViewPrivate: true,
        initialTab: tab,
        clock: () => DateTime.utc(2026, 10, 10),
      ),
    ),
  );

  for (final (family, dark) in _themes) {
    testWidgets(
      '$family/$dark agent Chat tab: no 0 counts on revisit, in-place refresh, identity change drops it',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        final held = <Completer<dynamic>>[];
        var reads = 0;
        api.routes['GET /agents/a1/channels'] = (_) {
          if (++reads == 1) {
            return {
              'channels': [
                {'id': 'c1', 'name': 'general'},
              ],
            };
          }
          final gate = Completer<dynamic>();
          held.add(gate);
          return gate.future;
        };
        api.routes['GET /agents/a1/agent-dms'] = (_) => {
          'dms': [
            {'id': 'd1', 'name': 'carol'},
          ],
        };
        await t.pumpWidget(agentPanel(w, family, dark));
        await t.pump();
        final tabs = find.byType(RaftPanelTabBar<AgentDetailTab>);
        Future<void> openTab(String label) =>
            t.tap(find.descendant(of: tabs, matching: rich(label)));
        await openTab('Chat');
        await t.pump();
        // First visit: a loading line, never fabricated zero counts.
        expect(rich('Loading…'), findsOneWidget);
        expect(rich('Channels'), findsNothing);
        await settle(t);
        expect(rich('general'), findsOneWidget);
        expect(rich('carol'), findsOneWidget);
        final general = t.getRect(rich('general'));
        final carol = t.getRect(rich('carol'));

        await openTab('Profile');
        await settle(t);
        await openTab('Chat');
        await t.pump();
        expect(rich('Loading…'), findsNothing);
        expect(rich('general'), findsOneWidget);
        expect(rich('carol'), findsOneWidget);
        expect(t.getRect(rich('general')), general);
        expect(t.getRect(rich('carol')), carol);
        await settle(t);
        expect(held, hasLength(1));
        await release(t, held.single, {
          'channels': [
            {'id': 'c1', 'name': 'general'},
            {'id': 'c2', 'name': 'random'},
          ],
        });
        expect(rich('random'), findsOneWidget);
        expect(t.getRect(rich('general')), general);

        // A different role/account is a different cache.
        await openTab('Profile');
        await settle(t);
        w.server = RaftRecord({'id': 's1', 'role': 'admin'});
        w.notifyListeners();
        await t.pump();
        await openTab('Chat');
        await t.pump();
        expect(rich('general'), findsNothing);
        expect(rich('Loading…'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      '$family/$dark agent Reminders tab: refresh never inserts a Loading line above shown rows',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        final held = <Completer<dynamic>>[];
        var reads = 0;
        Map<String, dynamic> reminder(String id, String title) => {
          'reminderId': id,
          'title': title,
          'ownerAgentId': 'a1',
          'status': 'scheduled',
          'fireAt': '2026-10-11T00:00:00Z',
        };
        api.routes['GET /reminders'] = (_) {
          if (++reads == 1) {
            return {
              'reminders': [reminder('r1', 'Stand-up')],
            };
          }
          final gate = Completer<dynamic>();
          held.add(gate);
          return gate.future;
        };
        await t.pumpWidget(agentPanel(w, family, dark));
        await t.pump();
        final tabs = find.byType(RaftPanelTabBar<AgentDetailTab>);
        Future<void> openTab(String label) =>
            t.tap(find.descendant(of: tabs, matching: rich(label)));
        await openTab('Reminders');
        await t.pump();
        expect(rich('Loading…'), findsOneWidget);
        await settle(t);
        final standup = t.getRect(rich('Stand-up'));

        await openTab('Profile');
        await settle(t);
        await openTab('Reminders');
        await t.pump();
        expect(rich('Loading…'), findsNothing);
        expect(t.getRect(rich('Stand-up')), standup);
        await settle(t);
        expect(held, hasLength(1));
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(rich('Loading…'), findsNothing);
          expect(t.getRect(rich('Stand-up')), standup);
        }
        await release(t, held.single, {
          'reminders': [reminder('r1', 'Stand-up'), reminder('r2', 'Review')],
        });
        expect(rich('Review'), findsOneWidget);
        expect(t.getRect(rich('Stand-up')), standup);

        w.server = RaftRecord({'id': 's1', 'role': 'admin'});
        w.notifyListeners();
        await openTab('Profile');
        await settle(t);
        await openTab('Reminders');
        await t.pump();
        expect(rich('Stand-up'), findsNothing);
        expect(rich('Loading…'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      '$family/$dark agent Workspace tab: expanded folders survive tab switches and the tree refreshes in place',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        final held = <Completer<dynamic>>[];
        var rootReads = 0;
        api.routes['GET /agents/a1/workspace-files'] = (r) {
          final dir = r.queryParameters['dirPath'];
          if (dir == 'src') {
            return {
              'files': [
                {'name': 'main.dart', 'path': 'src/main.dart'},
              ],
            };
          }
          if (++rootReads == 1) {
            return {
              'files': [
                {'name': 'src', 'path': 'src', 'isDirectory': true},
                {'name': 'notes.md', 'path': 'notes.md'},
              ],
            };
          }
          final gate = Completer<dynamic>();
          held.add(gate);
          return gate.future;
        };
        await t.pumpWidget(agentPanel(w, family, dark));
        await t.pump();
        final tabs = find.byType(RaftPanelTabBar<AgentDetailTab>);
        Future<void> openTab(String label) =>
            t.tap(find.descendant(of: tabs, matching: rich(label)));
        await openTab('Workspace');
        await t.pump();
        expect(rich('Loading…'), findsOneWidget);
        await settle(t);
        await t.tap(rich('src'));
        await settle(t);
        expect(rich('main.dart'), findsOneWidget);
        final src = t.getRect(rich('src'));
        final main = t.getRect(rich('main.dart'));
        final notes = t.getRect(rich('notes.md'));

        await openTab('Profile');
        await settle(t);
        await openTab('Workspace');
        await t.pump();
        // First frame: same tree, same open folder, no Loading line.
        expect(rich('Loading…'), findsNothing);
        expect(t.getRect(rich('src')), src);
        expect(t.getRect(rich('main.dart')), main);
        expect(t.getRect(rich('notes.md')), notes);
        await settle(t);
        expect(held, hasLength(1));
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(rich('Loading…'), findsNothing);
          expect(t.getRect(rich('main.dart')), main);
        }
        await release(t, held.single, {
          'files': [
            {'name': 'src', 'path': 'src', 'isDirectory': true},
            {'name': 'notes.md', 'path': 'notes.md'},
            {'name': 'todo.md', 'path': 'todo.md'},
          ],
        });
        expect(rich('todo.md'), findsOneWidget);
        expect(rich('main.dart'), findsOneWidget, reason: 'still open');
        expect(t.getRect(rich('src')), src);
        expect(t.getRect(rich('main.dart')), main);
        expect(t.getRect(rich('notes.md')), notes);

        w.server = RaftRecord({'id': 's1', 'role': 'admin'});
        w.notifyListeners();
        await openTab('Profile');
        await settle(t);
        await openTab('Workspace');
        await t.pump();
        expect(rich('src'), findsNothing);
        expect(rich('main.dart'), findsNothing);
        expect(rich('Loading…'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
  }

  for (final (family, dark) in _themes) {
    testWidgets(
      '$family/$dark task detail: known row and cached history at the first frame, background refresh in place, identity change drops history',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        taskRoutes(api, modernTask);
        final held = <Completer<dynamic>>[];
        var reads = 0;
        Map<String, dynamic> event(String type) => {
          'id': 'e-$type',
          'eventType': type,
          'actorName': 'Alice',
          'createdAt': '2026-10-08T01:30:00Z',
          'payload': {},
        };
        api.routes['GET /tasks/task-1/history'] = (_) {
          if (++reads == 1) {
            return {
              'events': [event('created')],
            };
          }
          final gate = Completer<dynamic>();
          held.add(gate);
          return gate.future;
        };
        final owners = <TaskSurfaceController>[];
        Widget surface() {
          final owner = TaskSurfaceController(
            parent: w,
            row: modernTask,
            valid: () => true,
          );
          owners.add(owner);
          unawaited(owner.start());
          return MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: SourceTaskSurface(owner: owner, onClose: () {}),
            ),
          );
        }

        final skeleton = find.descendant(
          of: find.byType(SourceTaskSurface),
          matching: find.byType(RaftSkeleton),
        );
        Future<void> openHistory() async {
          await t.tap(find.text('History'));
          await t.pump();
        }

        // First ever open: the row is known, only history waits.
        await t.pumpWidget(surface());
        await t.pump();
        expect(find.text('Scoped actual task'), findsOneWidget);
        expect(owners.single.loading, isFalse);
        await openHistory();
        expect(skeleton, findsOneWidget, reason: 'history read pending');
        await settle(t);
        expect(skeleton, findsNothing);
        expect(find.text('Created task'), findsOneWidget);
        final title = t.getRect(find.text('Scoped actual task'));
        final created = t.getRect(find.text('Created task'));
        await t.pumpWidget(const SizedBox());
        owners.single.dispose();

        // Reopen: row and history are final in the first frame.
        await t.pumpWidget(surface());
        await t.pump();
        await openHistory();
        expect(skeleton, findsNothing);
        expect(find.text('Created task'), findsOneWidget);
        expect(t.getRect(find.text('Scoped actual task')), title);
        expect(t.getRect(find.text('Created task')), created);
        await settle(t);
        expect(held, hasLength(1));
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(skeleton, findsNothing);
          expect(t.getRect(find.text('Created task')), created);
        }
        held.single.complete({
          'events': [event('created'), event('status_changed')],
        });
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(skeleton, findsNothing);
          expect(t.getRect(find.text('Created task')), created);
        }
        expect(find.text('Changed status'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        owners.last.dispose();

        // A different role must not see the previous history.
        w.server = RaftRecord({'id': 's1', 'role': 'admin'});
        w.notifyListeners();
        await t.pumpWidget(surface());
        await t.pump();
        await openHistory();
        expect(find.text('Created task'), findsNothing);
        expect(skeleton, findsOneWidget);
        await settle(t);
        expect(held, hasLength(2));
        held.last.complete({'events': <dynamic>[]});
        await settle(t);
        expect(find.text('No history yet.'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        owners.last.dispose();
        expect(t.takeException(), isNull);
      },
    );
  }
}
