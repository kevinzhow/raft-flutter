import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture;

class _ChoiceClient extends RaftClient {
  _ChoiceClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );

  final mutations = <({String path, dynamic data})>[];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (method == 'PATCH') mutations.add((path: path, data: data));
    return {};
  }
}

class _BrowserChoiceClient extends RaftClient {
  _BrowserChoiceClient(MessageAdapter adapter)
    : super(
        origin: 'https://api.raft.build',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );

  // All REST requests use MessageAdapter. No real socket/native browser runs.
  @override
  void connect() {}
}

Future<(WorkspaceController, MessageAdapter)> _browserWorkspace(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({});
  final adapter = MessageAdapter();
  adapter.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'viewer'},
  };
  final client = (await tester.runAsync(() async {
    final client = _BrowserChoiceClient(adapter);
    await client.login('fixture', 'fixture');
    return client;
  }))!;
  client.selectServer('s1');
  final workspace = WorkspaceController(client)
    ..loading = false
    ..section = 'home'
    ..server = RaftRecord({
      'id': 's1',
      'slug': 'current',
      'name': 'Current workspace',
      'role': 'owner',
    })
    ..channels = [
      RaftChannel({'id': 'c1', 'name': 'General', 'joined': true}),
    ];
  workspace.channel = workspace.channels.first;
  workspace.servers = [
    workspace.server!,
    RaftRecord({'id': 's2', 'name': 'Other workspace', 'slug': 'stale-slug'}),
  ];
  workspace.messageDomain.ledger.switchServer('s1');
  adapter.routes['GET /channels/inbox'] = (_) => {'items': []};
  adapter.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  adapter.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  adapter.routes['GET /messages/search'] = (_) => {
    'results': [],
    'hasMore': false,
  };
  adapter.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  adapter.routes['GET /agents'] = (_) => [];
  adapter.routes['GET /servers/s1/members'] = (_) => [];
  adapter.routes['POST /channels/c1/read'] = (_) => {};
  addTearDown(() async {
    workspace.dispose();
    await client.dispose();
  });
  return (workspace, adapter);
}

class _ChoiceWorkspace extends WorkspaceController {
  _ChoiceWorkspace(super.client);
  var membersReads = 0;

  @override
  Future<void> refreshUnread() async {}

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/members')) {
      membersReads++;
      return {
        'humans': [
          {'id': 'human', 'userId': 'human', 'displayName': 'Ada'},
        ],
        'agents': [
          {'id': 'agent', 'displayName': 'Writer'},
        ],
      };
    }
    if (path == '/tasks/server') return {'tasks': [], 'next_cursor': null};
    return {'items': [], 'hasMore': false};
  }
}

const _task = <String, dynamic>{
  'id': 'task',
  'channelId': 'channel',
  'title': 'Task',
  'revision': 9,
  'claimedById': 'agent',
  'claimedByType': 'agent',
};

Future<(_ChoiceClient, _ChoiceWorkspace)> _mountResource(
  WidgetTester tester, {
  required ThemeData theme,
}) async {
  final client = _ChoiceClient()
    ..user = RaftRecord({'id': 'viewer', 'displayName': 'Viewer'});
  client.selectServer('server');
  final workspace = _ChoiceWorkspace(client)
    ..server = RaftRecord({'id': 'server', 'role': 'owner'})
    ..channels = [
      RaftChannel({'id': 'channel', 'name': 'General', 'joined': true}),
    ];
  addTearDown(() async {
    workspace.dispose();
    await client.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: ResourceView(
          controller: workspace,
          section: 'tasks',
          onMessage: (_, _) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (client, workspace);
}

void main() {
  for (final revoked in [false, true]) {
    testWidgets(
      'narrow browser action keeps host context through delayed membership; revoked=$revoked',
      (tester) async {
        try {
          final (workspace, adapter) = await _browserWorkspace(tester);
          final launched = <String>[];
          const launcher = MethodChannel('plugins.flutter.io/url_launcher');
          final messenger = tester.binding.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(launcher, (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
            }
            return true;
          });
          addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));
          await mountShell(tester, workspace, false, width: 390);
          final members = Completer<Object>();
          addTearDown(() {
            if (!members.isCompleted) members.complete(<Object>[]);
          });
          adapter.routes['GET /servers'] = (_) => members.future;
          final before = adapter.calls
              .where((call) => call.path == '/servers')
              .length;
          final dynamic owner = tester.state(find.byType(WorkspaceView));
          final Future<void> pending = owner.showWorkspaceSwitcher();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('workspace-browser-s2')));
          await tester.pumpAndSettle();
          await pending;
          expect(find.byType(RaftDialogSurface), findsNothing);
          expect(find.byType(SimpleDialog), findsNothing);
          expect(
            launched,
            isEmpty,
            reason: 'membership response has not arrived',
          );
          expect(
            adapter.calls.where((call) => call.path == '/servers').length,
            before + 1,
          );
          expect(workspace.client.serverId, 's1');
          if (revoked) {
            workspace.server = RaftRecord({
              ...workspace.server!.json,
              'role': 'guest',
            });
            workspace.notifyListeners();
          }
          members.complete([
            {'id': 's2', 'slug': 'fresh-slug'},
          ]);
          await tester.pumpAndSettle();
          expect(
            launched,
            revoked ? isEmpty : ['https://app.raft.build/s/fresh-slug'],
          );
          if (!revoked) {
            expect(Uri.parse(launched.single).query, isEmpty);
            expect(Uri.parse(launched.single).fragment, isEmpty);
          }
          expect(workspace.client.serverId, 's1');
          expect(workspace.server?.id, 's1');
        } finally {
          await retire(tester);
        }
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
  }
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'narrow Switch Server fallback uses canonical Dialog and Escape cancels $dark',
      (tester) async {
        try {
          final (workspace, _) = await pageFixture(tester, section: 'home');
          workspace.servers = [
            workspace.server!,
            RaftRecord({
              'id': 'other',
              'name': 'Other workspace',
              'slug': 'other',
            }),
          ];
          await mountShell(tester, workspace, dark, width: 390);
          final dynamic owner = tester.state(find.byType(WorkspaceView));
          // Exercise the existing non-anchored narrow fallback directly. The normal
          // mobile header already mounts its own anchored ServerSwitcher.
          final Future<void> pending = owner.showWorkspaceSwitcher();
          await tester.pumpAndSettle();
          expect(find.byType(RaftDialogSurface), findsOneWidget);
          expect(find.byType(SimpleDialog), findsNothing);
          expect(find.text('Other workspace'), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          await pending;
          expect(workspace.server?.id, 's1');
          expect(find.byType(RaftDialogSurface), findsNothing);
          final Future<void> second = owner.showWorkspaceSwitcher();
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(2, 2));
          await tester.pumpAndSettle();
          await second;
          expect(workspace.server?.id, 's1');
          expect(find.byType(RaftDialogSurface), findsNothing);
        } finally {
          await retire(tester);
        }
      },
    );
  }

  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    testWidgets(
      'AssignTask direct entry keeps typed human assignment and revision in $id',
      (tester) async {
        try {
          final (client, _) = await _mountResource(
            tester,
            theme: raftTheme(pack: packForThemeId(id)),
          );
          final dynamic owner = tester.state(find.byType(ResourceView));
          // assignTask has no mounted caller in the current source. Exercise its
          // real method without claiming a user-accessible menu journey.
          final Future<void> pending = owner.assignTask(_task);
          await tester.pumpAndSettle();
          expect(
            find.byType(RaftDialogSurface),
            id == raftThemePackId ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(SimpleDialog),
            id == raftThemePackId ? findsNothing : findsOneWidget,
          );
          await tester.tap(find.text('Ada · user'));
          await tester.pumpAndSettle();
          await pending;
          expect(client.mutations, hasLength(1));
          expect(client.mutations.first.path, '/tasks/task/assignee');
          expect(client.mutations.first.data, {
            'assignee': {'type': 'user', 'id': 'human'},
            'expectedRevision': 9,
          });
        } finally {
          await retire(tester);
        }
      },
    );
  }

  testWidgets(
    'AssignTask direct entry distinguishes cancel, unassign and authority loss',
    (tester) async {
      try {
        final (client, workspace) = await _mountResource(
          tester,
          theme: raftTheme(),
        );
        final dynamic owner = tester.state(find.byType(ResourceView));
        Future<void> pending = owner.assignTask(_task);
        await tester.pumpAndSettle();
        // This scoped task route has always required explicit cancellation.
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.byType(RaftDialogSurface), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await pending;
        expect(client.mutations, isEmpty);

        pending = owner.assignTask(_task);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unassign'));
        await tester.pumpAndSettle();
        await pending;
        expect(client.mutations.last.data, {
          'assignee': null,
          'expectedRevision': 9,
        });

        pending = owner.assignTask(_task);
        await tester.pumpAndSettle();
        workspace.server = RaftRecord({
          ...workspace.server!.json,
          'role': 'guest',
        });
        workspace.notifyListeners();
        await tester.pumpAndSettle();
        await pending;
        expect(find.text('Ada · user'), findsNothing);
        expect(client.mutations, hasLength(1));
        final reads = workspace.membersReads;
        await owner.assignTask(_task);
        expect(workspace.membersReads, reads);
        expect(client.mutations, hasLength(1));
      } finally {
        await retire(tester);
      }
    },
  );
}
