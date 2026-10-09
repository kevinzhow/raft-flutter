import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/joint_channel_views.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, FutureOr<dynamic> Function(RequestOptions)>{};
  final statuses = <String, int>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    final key = '${o.method} ${o.path}',
        route = routes['${o.method} ${o.path}'];
    return ResponseBody.fromString(
      jsonEncode(
        route == null ? {'error': 'Unexpected request'} : await route(o),
      ),
      statuses[key] ?? (route == null ? 404 : 200),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client({
    required super.origin,
    required super.sessionStore,
    required super.transport,
  });
  final forwarded = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => forwarded.stream;
  @override
  Future<void> dispose() async {
    await forwarded.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  String? selected;
  int refreshes = 0;
  @override
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
  }) async {
    selected = next.id;
  }

  @override
  Future<void> refreshChannels() async {
    refreshes++;
  }
}

Future<(_Workspace, _Adapter)> fixture([String role = 'owner']) async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture',
    'refreshToken': 'fixture',
    'user': {'id': 'alice'},
  };
  final c = _Client(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await c.login('fixture', 'fixture');
  c.selectServer('s1');
  final w = _Workspace(c)..server = RaftRecord({'id': 's1', 'role': role});
  a.routes['GET /channels/joint-invites'] = (_) => {'invites': []};
  a.routes['GET /channels'] = (_) => [];
  a.routes['GET /agents'] = (_) => [
    {'id': 'a1', 'name': 'Cindy'},
    {'id': 'deleted', 'name': 'Deleted', 'deletedAt': '2026'},
  ];
  a.routes['GET /servers/s1/members'] = (_) => [
    {'userId': 'alice', 'name': 'Self'},
    {'userId': 'bob', 'displayName': 'Bob'},
  ];
  return (w, a);
}

Widget host(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: child),
);
Future<void> createForm(WidgetTester t) async {
  await t.tap(find.text('Create joint channel'));
  await t.pumpAndSettle();
}

Future<void> text(WidgetTester t, String key, String value) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.enterText(f, value);
}

void main() {
  test('name, historical slug and invited-person validation match source', () {
    expect(jointNameError('日语_2'), isNull);
    expect(jointNameError('1team'), isNotNull);
    expect(jointNameError('all'), isNotNull);
    expect(jointNameError('team space'), isNotNull);
    expect(jointTargetError('a'), isNull);
    expect(jointTargetError('Team'), isNotNull);
    expect(jointPeople(' @Bob, @Bob\n alice@example.invalid , '), [
      '@Bob',
      'alice@example.invalid',
    ]);
  });
  testWidgets('member cannot load federation data or create invitations', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    await t.pumpWidget(host(JointChannelsView(controller: w)));
    await t.pumpAndSettle();
    expect(find.text('Create joint channel'), findsNothing);
    expect(a.calls.where((c) => c.path.startsWith('/channels')), isEmpty);
  });
  testWidgets(
    'create uses jointInvites and selected human names with exact source fields',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      a.routes['POST /channels'] = (_) => {
        'id': 'local-joint',
        'name': '团队',
        'type': 'joint',
        'joined': true,
      };
      await t.pumpWidget(host(JointChannelsView(controller: w)));
      await t.pumpAndSettle();
      await createForm(t);
      await text(t, 'joint-name', '团队');
      await text(t, 'joint-description', ' Shared work ');
      await text(t, 'joint-slug-0', 'target');
      await text(t, 'joint-people-0', '@Bob, @Bob\nAlice');
      await t.ensureVisible(find.text('Cindy'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cindy'));
      await t.pump();
      await t.ensureVisible(find.text('Bob'));
      await t.tap(find.text('Bob'));
      await t.pump();
      expect(find.text('Self'), findsNothing);
      expect(find.text('Deleted'), findsNothing);
      expect(find.text('bob'), findsNothing);
      await t.tap(find.byKey(const ValueKey('joint-create-submit')));
      await t.pumpAndSettle();
      expect(
        a.calls
            .singleWhere((c) => c.method == 'POST' && c.path == '/channels')
            .data,
        {
          'name': '团队',
          'description': 'Shared work',
          'visibility': 'joint',
          'agentIds': ['a1'],
          'userIds': ['bob'],
          'jointInvites': [
            {
              'targetServerSlug': 'target',
              'invitedPeople': ['@Bob', 'Alice'],
            },
          ],
        },
      );
      expect(w.selected, 'local-joint');
      expect(w.refreshes, 1);
    },
  );
  testWidgets('delayed people catalog cannot open a form under a new role', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(fixture))!;
    addTearDown(w.dispose);
    final pending = Completer<dynamic>();
    a.routes['GET /agents'] = (_) => pending.future;
    await t.pumpWidget(host(JointChannelsView(controller: w)));
    await t.pumpAndSettle();
    await t.tap(find.text('Create joint channel'));
    await t.pump();
    w.server = RaftRecord({'id': 's1', 'role': 'member'});
    w.notifyListeners();
    await t.pump();
    pending.complete([
      {'id': 'private', 'name': 'Private agent'},
    ]);
    await t.pumpAndSettle();
    expect(find.text('Private agent'), findsNothing);
    expect(find.byKey(const ValueKey('joint-name')), findsNothing);
  });
  testWidgets(
    'accept navigates the returned local projection rather than host id',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /channels/joint-invites'] = (_) => {
        'invites': [
          {
            'id': 'invite1',
            'jointChannelId': 'global-id',
            'fromServerName': 'Partner',
            'fromServerSlug': 'partner',
            'channelName': 'share',
          },
        ],
      };
      a.routes['POST /channels/joint-invites/invite1/accept'] = (_) => {
        'id': 'local-projection',
        'type': 'joint',
        'joined': true,
      };
      await t.pumpWidget(host(JointChannelsView(controller: w)));
      await t.pumpAndSettle();
      await t.tap(find.text('Accept invitation'));
      await t.pumpAndSettle();
      await t.tap(find.text('Accept invitation').last);
      await t.pumpAndSettle();
      expect(w.selected, 'local-projection');
      expect(w.refreshes, 1);
    },
  );
  testWidgets(
    'disconnect uses POST and refreshes channels; never deletes joint',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /channels/c1'] = (_) => {
        'id': 'c1',
        'type': 'joint',
        'name': 'Shared',
        'jointServers': [
          {
            'serverName': 'Partner',
            'serverSlug': 'partner',
            'status': 'active',
          },
        ],
      };
      a.routes['POST /channels/c1/disconnect'] = (_) => {'ok': true};
      await t.pumpWidget(
        host(JointChannelManagementView(controller: w, channelId: 'c1')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Disconnect workspace'));
      await t.pumpAndSettle();
      await t.tap(find.text('Disconnect workspace').last);
      await t.pumpAndSettle();
      expect(a.calls.where((c) => c.method == 'DELETE'), isEmpty);
      expect(
        a.calls
            .where(
              (c) => c.method == 'POST' && c.path == '/channels/c1/disconnect',
            )
            .length,
        1,
      );
      expect(w.refreshes, 1);
    },
  );
  testWidgets(
    'channel revocation closes invitation form and fences retained submit',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /channels/c1'] = (_) => {
        'id': 'c1',
        'type': 'joint',
        'name': 'Private share',
      };
      await t.pumpWidget(
        host(JointChannelManagementView(controller: w, channelId: 'c1')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Invite workspace'));
      await t.pumpAndSettle();
      final retained = t.widget<RaftFormDialog>(find.byType(RaftFormDialog));
      (_client(w)).forwarded
          .add(const RaftEvent('channel:removed', {'channelId': 'c1'}));
      await t.pumpAndSettle();
      expect(find.byType(RaftFormDialog), findsNothing);
      await expectLater(
        retained.onSubmit({
          'targetServerSlug': 'target',
          'invitedPeople': 'Bob',
        }),
        throwsStateError,
      );
      expect(
        a.calls.where(
          (c) => c.method == 'POST' && c.path.endsWith('/joint-invites'),
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'self publication before accept receipt preserves navigation while real policy revocation clears it',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /channels/joint-invites'] = (_) => {
        'invites': [
          {'id': 'i1', 'fromServerName': 'Partner', 'channelName': 'share'},
        ],
      };
      a.routes['POST /channels/joint-invites/i1/accept'] = (_) {
        _client(w).forwarded.add(
          const RaftEvent('channel:updated', {
            'channel': {'id': 'new-local', 'type': 'joint', 'joined': true},
          }),
        );
        w.channels = [
          RaftChannel({'id': 'new-local', 'type': 'joint', 'joined': true}),
        ];
        w.notifyListeners();
        return {'id': 'new-local', 'type': 'joint', 'joined': true};
      };
      await t.pumpWidget(host(JointChannelsView(controller: w)));
      await t.pumpAndSettle();
      await t.tap(find.text('Accept invitation'));
      await t.pumpAndSettle();
      await t.tap(find.text('Accept invitation').last);
      await t.pumpAndSettle();
      expect(w.selected, 'new-local');
    },
  );
  testWidgets(
    'invite and resend use exact contracts and refresh accepted pending metadata',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /channels/c1'] = (_) => {
        'id': 'c1',
        'type': 'joint',
        'name': 'share',
        'jointPendingInvites': [
          {
            'id': 'i1',
            'fromServerId': 's1',
            'serverName': 'Partner',
            'serverSlug': 'partner',
          },
        ],
      };
      a.routes['POST /channels/c1/joint-invites'] = (_) => {
        'id': 'c1',
        'type': 'joint',
      };
      a.routes['POST /channels/c1/joint-invite/resend'] = (_) => {
        'ok': true,
        'resentCount': 1,
      };
      await t.pumpWidget(
        host(JointChannelManagementView(controller: w, channelId: 'c1')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Invite workspace'));
      await t.pumpAndSettle();
      await text(t, 'field-targetServerSlug', 'a');
      await text(t, 'field-invitedPeople', '@Bob, @Bob\nAlice');
      await t.tap(find.text('Send invitation'));
      await t.pumpAndSettle();
      expect(
        a.calls.singleWhere((c) => c.path == '/channels/c1/joint-invites').data,
        {
          'targetServerSlug': 'a',
          'invitedPeople': ['@Bob', 'Alice'],
        },
      );
      await t.tap(find.text('Resend invitations'));
      await t.pumpAndSettle();
      await t.tap(find.text('Resend invitations').last);
      await t.pumpAndSettle();
      expect(
        a.calls
            .singleWhere((c) => c.path == '/channels/c1/joint-invite/resend')
            .method,
        'POST',
      );
      expect(
        a.calls
            .where((c) => c.method == 'GET' && c.path == '/channels/c1')
            .length,
        3,
      );
    },
  );
  testWidgets(
    'unarchive restores an actual archived joint without creating a replacement',
    (t) async {
      final (w, a) = (await t.runAsync(fixture))!;
      addTearDown(w.dispose);
      a.routes['GET /channels'] = (_) => [
        {
          'id': 'archived',
          'type': 'joint',
          'name': 'Archived shared',
          'archivedAt': '2026',
        },
      ];
      a.routes['POST /channels/archived/unarchive'] = (_) => {
        'id': 'archived',
        'type': 'joint',
      };
      await t.pumpWidget(host(JointChannelsView(controller: w)));
      await t.pumpAndSettle();
      expect(
        a.calls.singleWhere((c) => c.path == '/channels').queryParameters,
        {'archived': 'include'},
      );
      await t.tap(find.text('Unarchive'));
      await t.pumpAndSettle();
      await t.tap(find.text('Unarchive').last);
      await t.pumpAndSettle();
      expect(
        a.calls
            .where(
              (c) =>
                  c.method == 'POST' &&
                  c.path == '/channels/archived/unarchive',
            )
            .length,
        1,
      );
      expect(
        a.calls.where((c) => c.method == 'POST' && c.path == '/channels'),
        isEmpty,
      );
    },
  );
  testWidgets('backend forbidden clears private metadata and rejects form', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(fixture))!;
    addTearDown(w.dispose);
    a.routes['GET /channels/c1'] = (_) => {
      'id': 'c1',
      'type': 'joint',
      'name': 'Private share',
    };
    a.routes['POST /channels/c1/joint-invites'] = (_) => {
      'error': 'Access revoked',
    };
    a.statuses['POST /channels/c1/joint-invites'] = 403;
    await t.pumpWidget(
      host(JointChannelManagementView(controller: w, channelId: 'c1')),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Invite workspace'));
    await t.pumpAndSettle();
    await text(t, 'field-targetServerSlug', 'target');
    await text(t, 'field-invitedPeople', 'Bob');
    await t.tap(find.text('Send invitation'));
    await t.pumpAndSettle();
    expect(find.text('#Private share'), findsNothing);
    expect(find.byType(RaftFormDialog), findsNothing);
    expect(find.textContaining('Access revoked'), findsOneWidget);
  });
}

_Client _client(_Workspace w) => w.client as _Client;
