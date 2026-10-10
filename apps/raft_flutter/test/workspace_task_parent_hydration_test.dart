import 'dart:async';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'message_presentation_test.dart' show MessageAdapter;
import 'workspace_source_location_contract_test.dart' show LocalClient;

class ParentAdapter extends MessageAdapter {
  final statuses = <String, int>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final response = await super.fetch(options, stream, cancel);
    return ResponseBody(
      response.stream,
      statuses['${options.method} ${options.path}'] ?? response.statusCode,
      headers: response.headers,
    );
  }
}

class ParentClient extends LocalClient {
  ParentClient(super.adapter);
  final eventStream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => eventStream.stream;
  @override
  Future<void> dispose() async {
    await eventStream.close();
    await super.dispose();
  }
}

Future<(WorkspaceController, ParentAdapter)> parentFixture(
  WidgetTester t,
) async {
  SharedPreferences.setMockInitialValues({});
  DevicePreferences.reset();
  final api = ParentAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = (await t.runAsync(() async {
    final client = ParentClient(api);
    await client.login('fixture', 'fixture');
    return client;
  }))!;
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'slug': 'demo', 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  w.loading = false;
  w.ledger.switchServer('s1');
  w.section = 'tasks';
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  api.routes['GET /channels/inbox'] = (_) => {'items': []};
  api.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  addTearDown(w.dispose);
  return (w, api);
}

const realParent = {
  'id': 'remote',
  'serverId': 's1',
  'name': 'Real private task parent',
  'type': 'private',
  'joined': true,
};
final realTask = {
  ...modernTask,
  'id': 'remote-task',
  'messageId': 'remote-parent',
  'channelId': 'remote',
  'channelName': realParent['name'],
  'title': 'Real remote task',
};

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '[K10b cold parent] real metadata precedes borrowed discussion and task facts $family/$dark/$width',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await parentFixture(t);
          taskRoutes(api, modernTask);
          final metadata = Completer<Map>(), bucket = Completer<Map>();
          final context = Completer<Map>(), lookup = Completer<Map>();
          final replies = Completer<Map>();
          api.routes['GET /channels/remote'] = (_) => metadata.future;
          api.routes['GET /tasks/channel/remote'] = (_) => bucket.future;
          api.routes['GET /tasks/channel/remote/number/8'] = (_) => {
            'task': realTask,
          };
          api.routes['GET /tasks/remote-task/history'] = (_) => {'events': []};
          api.routes['GET /messages/context/remote-parent'] = (_) =>
              context.future;
          api.routes['GET /channels/remote/threads/remote-parent'] = (_) =>
              lookup.future;
          api.routes['GET /messages/channel/task-thread'] = (_) =>
              replies.future;
          w.ledger.ingest([
            row('accepted-main', 'c1', 1),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1'] = {'accepted-main'};
          w.drafts[w.draftScope()!] = 'Retained real main draft';
          w.navigation.navigateTask(
            w.location.withQuery({
              'task': 'remote:remote-parent',
              'keep': 'yes',
            }),
            kind: RaftNavigationKind.replace,
          );
          final revision = w.navigationRevision;
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
          final surface = find.byType(SourceTaskSurface);
          expect(surface, findsOneWidget);
          final owner = t.widget<SourceTaskSurface>(surface).owner;
          expect(owner.discussion, isNull);
          expect(find.byKey(const ValueKey('task-modal-title')), findsNothing);
          expect(
            api.calls.where((r) => r.path == '/channels/remote'),
            hasLength(1),
          );
          expect(
            api.calls.where(
              (r) =>
                  r.path.contains('/remote/') ||
                  r.path.endsWith('/remote-parent'),
            ),
            isEmpty,
          );
          metadata.complete(realParent);
          await flush(t);
          expect(owner.discussion, isNotNull);
          expect(owner.discussion!.channel!.json, realParent);
          expect(owner.discussion!.ownsClient, isFalse);
          expect(owner.discussion!.entityDirectory, same(w.entityDirectory));
          expect(w.channels.map((c) => c.id), ['c1']);
          expect(w.channel!.id, 'c1');
          expect(w.navigationRevision, revision);
          expect(
            api.calls.where((r) => r.path == '/tasks/channel/remote'),
            hasLength(1),
          );
          expect(
            api.calls.where((r) => r.path == '/messages/context/remote-parent'),
            hasLength(1),
          );
          expect(find.byKey(const ValueKey('task-modal-title')), findsNothing);
          bucket.complete({
            'tasks': [realTask],
          });
          lookup.complete({'threadChannelId': 'task-thread'});
          await flush(t);
          expect(
            find.byKey(const ValueKey('task-modal-title')),
            findsOneWidget,
          );
          expect(find.text('Real remote task'), findsOneWidget);
          expect(owner.joined, isTrue);
          expect(owner.canAssign, isTrue);
          expect(owner.cleanup, isFalse);
          expect(w.channel!.id, 'c1');
          expect(w.messages.single.id, 'accepted-main');
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await flush(t);
          expect(surface, findsNothing);
          expect(owner.closed, isTrue);
          expect(w.location.query('task'), isNull);
          expect(w.location.query('keep'), 'yes');
          expect(w.navigationRevision, revision);
          context.complete({
            'messages': [row('remote-parent', 'remote', 2)],
          });
          replies.complete({
            'messages': [row('remote-reply', 'task-thread', 3)],
          });
          await flush(t);
          expect(w.messages.single.id, 'accepted-main');
          expect(w.drafts[w.draftScope()], 'Retained real main draft');
          expect(
            api.calls.where((r) => r.path == '/channels/task-thread/read'),
            isEmpty,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    }
    for (final denial in ['403', '404', 'wrong-server', 'malformed']) {
      testWidgets(
        '[K10b cold parent] $denial metadata cannot admit task facts or discussion $family/$dark',
        (t) async {
          t.view.physicalSize = const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await parentFixture(t);
          taskRoutes(api, modernTask);
          api.routes['GET /channels/remote'] = (request) {
            if (denial == '403' || denial == '404') {
              api.statuses['GET /channels/remote'] = int.parse(denial);
              return {'error': 'Actual fixture channel unavailable'};
            }
            return denial == 'wrong-server'
                ? {...realParent, 'serverId': 'other-server'}
                : {'id': 'remote', 'serverId': 's1'};
          };
          w.navigation.navigateTask(
            w.location.withQuery({'task': 'remote:remote-parent'}),
            kind: RaftNavigationKind.replace,
          );
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
          final surface = find.byType(SourceTaskSurface);
          expect(surface, findsOneWidget);
          final owner = t.widget<SourceTaskSurface>(surface).owner;
          expect(owner.parentError, isNotNull);
          if (denial == '403' || denial == '404') {
            expect(
              (owner.parentError as RaftApiException).status,
              int.parse(denial),
            );
          }
          expect(owner.discussion, isNull);
          expect(owner.hydrated, isFalse);
          expect(owner.canStatus, isFalse);
          expect(owner.canCleanupDelete, isFalse);
          expect(w.location.query('task'), 'remote:remote-parent');
          expect(find.byKey(const ValueKey('task-modal-title')), findsNothing);
          expect(
            api.calls.where(
              (r) =>
                  r.path == '/tasks/channel/remote' ||
                  r.path == '/channels/remote/threads/remote-parent' ||
                  r.path == '/messages/context/remote-parent' ||
                  r.path == '/messages/channel/task-thread',
            ),
            isEmpty,
          );
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await flush(t);
          expect(surface, findsNothing);
          expect(w.channels.map((c) => c.id), ['c1']);
          expect(t.takeException(), isNull);
        },
      );
    }
    for (final lateError in [false, true]) {
      testWidgets(
        '[K10b cold parent] Back and real new card reject late metadata ${lateError ? 'error' : 'success'} $family/$dark',
        (t) async {
          t.view.physicalSize = const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await parentFixture(t);
          taskRoutes(api, modernTask);
          final metadata = Completer<Map>(), main = Completer<Map>();
          api.routes['GET /channels/remote'] = (_) => metadata.future;
          api.routes['GET /messages/context/pending-main'] = (_) => main.future;
          final pendingMain = w.jumpToMessage(
            'c1',
            'pending-main',
            navigate: false,
          );
          w.navigation.navigateTask(
            w.location.withQuery({'task': 'remote:remote-parent'}),
            kind: RaftNavigationKind.replace,
          );
          final revision = w.navigationRevision;
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
          final retired = t
              .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
              .owner;
          await t.tap(find.byTooltip('Close task'));
          await flush(t);
          expect(retired.closed, isTrue);
          await t.tap(find.text('Scoped actual task'));
          await flush(t);
          expect(w.location.query('task'), 'c1:task-parent');
          if (lateError) {
            metadata.completeError(StateError('Old metadata failed'));
          } else {
            metadata.complete(realParent);
          }
          main.complete({
            'messages': [row('pending-main', 'c1', 2)],
          });
          await flush(t);
          await pendingMain;
          expect(find.text('Scoped actual task'), findsNWidgets(2));
          expect(w.location.query('task'), 'c1:task-parent');
          expect(w.navigationRevision, revision);
          expect(w.highlightedMessageId, 'pending-main');
          expect(w.messages.single.id, 'pending-main');
          expect(
            api.calls.where(
              (r) =>
                  r.path == '/tasks/channel/remote' ||
                  r.path.contains('/remote/'),
            ),
            isEmpty,
          );
          expect(w.channels.map((c) => c.id), ['c1']);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    }
    for (final change in ['principal', 'server', 'role', 'removed']) {
      testWidgets(
        '[K10b cold parent] held metadata is rejected after $change $family/$dark',
        (t) async {
          t.view.physicalSize = const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (w, api) = await parentFixture(t);
          taskRoutes(api, modernTask);
          final metadata = Completer<Map>();
          final newPrincipalMetadata = Completer<Map>();
          var metadataReads = 0;
          api.routes['GET /channels/remote'] = (_) => ++metadataReads == 1
              ? metadata.future
              : newPrincipalMetadata.future;
          w.navigation.navigateTask(
            w.location.withQuery({'task': 'remote:remote-parent'}),
            kind: RaftNavigationKind.replace,
          );
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
          final owner = t
              .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
              .owner;
          switch (change) {
            case 'principal':
              w.client.user = RaftRecord({'id': 'new principal'});
            case 'server':
              w.client.selectServer('other-server');
            case 'role':
              w.server = RaftRecord({...w.server!.json, 'role': 'guest'});
            case 'removed':
              (w.client as ParentClient).eventStream.add(
                const RaftEvent('channel:removed', {
                  'channelId': 'remote',
                  'serverId': 's1',
                }),
              );
          }
          w.notifyListeners();
          await flush(t);
          metadata.complete(realParent);
          await flush(t);
          expect(owner.discussion, isNull);
          expect(owner.hydrated, isFalse);
          expect(owner.canStatus, isFalse);
          expect(find.byKey(const ValueKey('task-modal-title')), findsNothing);
          expect(
            api.calls.where(
              (r) =>
                  r.path == '/tasks/channel/remote' ||
                  r.path == '/channels/remote/threads/remote-parent' ||
                  r.path == '/messages/context/remote-parent' ||
                  r.path == '/messages/channel/task-thread',
            ),
            isEmpty,
            reason:
                'Retired task requests must stay fenced; unrelated main '
                'channel requests may bind the new principal. '
                '${api.calls.map((r) => "${r.method} ${r.path}").toList()}',
          );
          if (change == 'removed') {
            expect(owner.parentRemoved, isTrue);
            expect((owner.parentError as RaftApiException).status, 403);
            await owner.start();
            expect(
              api.calls.where((r) => r.path == '/channels/remote'),
              hasLength(1),
            );
          } else {
            expect(owner.closed, isTrue);
          }
          if (change == 'principal') {
            expect(metadataReads, 2);
            final newOwner = t
                .widget<SourceTaskSurface>(find.byType(SourceTaskSurface))
                .owner;
            expect(newOwner, isNot(same(owner)));
            expect(newOwner.resolvedParent, isNull);
            expect(newOwner.discussion, isNull);
            expect(newOwner.hydrated, isFalse);
            // Its own current request can accept its own explicit denial;
            // the old success never supplies metadata to this principal.
            api.statuses['GET /channels/remote'] = 403;
            newPrincipalMetadata.complete({'error': 'new principal denied'});
            await flush(t);
            expect((newOwner.parentError as RaftApiException).status, 403);
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    }
    testWidgets(
      '[K10b cold parent] accepted private metadata revokes immediately and renewed denial cannot retain composer $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await parentFixture(t);
        taskRoutes(api, modernTask);
        final nextMetadata = Completer<Map>();
        var reads = 0;
        api.routes['GET /channels/remote'] = (_) =>
            ++reads == 1 ? realParent : nextMetadata.future;
        api.routes['GET /tasks/channel/remote'] = (_) => {
          'tasks': [realTask],
        };
        api.routes['GET /tasks/channel/remote/number/8'] = (_) => {
          'task': realTask,
        };
        api.routes['GET /tasks/remote-task/history'] = (_) => {'events': []};
        api.routes['GET /channels/remote/threads/remote-parent'] = (_) => {
          'threadChannelId': 'task-thread',
        };
        final parent = Completer<Map>(), replies = Completer<Map>();
        api.routes['GET /messages/context/remote-parent'] = (_) =>
            parent.future;
        api.routes['GET /messages/channel/task-thread'] = (_) => replies.future;
        w.navigation.navigateTask(
          w.location.withQuery({'task': 'remote:remote-parent'}),
          kind: RaftNavigationKind.replace,
        );
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
        final surface = find.byType(SourceTaskSurface);
        final owner = t.widget<SourceTaskSurface>(surface).owner;
        expect(owner.parentReady, isTrue);
        expect(owner.discussion, isNotNull);
        expect(find.byKey(const ValueKey('task-modal-title')), findsOneWidget);
        final generation = w.client.generation;
        api.routes['GET /channels'] = (_) => {
          'channels': w.channels.map((c) => c.json).toList(),
        };
        api.routes['GET /channels/dm'] = (_) => {'channels': []};
        (w.client as ParentClient).eventStream.add(
          const RaftEvent('channel:authority-updated', {
            'channelId': 'remote',
            'serverId': 's1',
          }),
        );
        await flush(t);
        expect(owner.discussion, isNull);
        expect(owner.parentReady, isFalse);
        expect(owner.canStatus, isFalse);
        expect(find.byKey(const ValueKey('task-modal-title')), findsNothing);
        expect(
          find.descendant(of: surface, matching: find.byType(RaftComposer)),
          findsNothing,
        );
        api.statuses['GET /channels/remote'] = 403;
        nextMetadata.complete({'error': 'Authority revoked'});
        parent.complete({
          'messages': [row('remote-parent', 'remote', 2)],
        });
        replies.complete({
          'messages': [row('remote-reply', 'task-thread', 3)],
        });
        await flush(t);
        expect(owner.discussion, isNull);
        expect((owner.parentError as RaftApiException).status, 403);
        expect(
          api.calls.where((r) => r.path == '/channels/task-thread/read'),
          isEmpty,
        );
        expect(w.client.generation, generation);
        expect(w.channels.map((c) => c.id), ['c1']);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(milliseconds: 300));
      },
    );
  }
}
