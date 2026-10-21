// Field-parity (group `channels`): server-shaped payloads from
// test/fixtures/field_parity/*.json against the Flutter readers. Every
// assertion is the value Web displays (see the audit notes next to each case).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_messages.dart';
import 'package:raft_flutter/features/channel_member_servers.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/joint_channel_views.dart';
import 'package:raft_ui/raft_ui.dart';

dynamic _fixture(String name) => jsonDecode(
  File('test/fixtures/field_parity/$name.json').readAsStringSync(),
);

const _server = 's0000000-0000-4000-8000-000000000001';
const _me = 'u1000000-0000-4000-8000-0000000000c1';

class _Api implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes =
      <String, FutureOr<(int, dynamic)> Function(RequestOptions request)>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final (status, body) = route == null
        ? (404, {'error': 'Unexpected endpoint ${o.path}'})
        : await route(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Api api)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = api,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  bool get connected => true;
  @override
  void connect() {}
  @override
  void joinChannel(String channelId) {}
  void emit(String name, [dynamic payload]) =>
      stream.add(RaftEvent(name, payload));
}

Future<void> _drain() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

Future<(WorkspaceController, _Api, _Client)> _controller({
  List<Map<String, dynamic>> channels = const [],
  Map<String, dynamic> user = const {
    'id': _me,
    'name': 'owner',
    'displayName': 'Server Owner',
  },
}) async {
  final api = _Api();
  api.routes['POST /auth/login'] = (_) => (
    200,
    {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': user,
    },
  );
  api.routes['GET /channels'] = (_) => (200, <dynamic>[]);
  api.routes['GET /channels/dm'] = (_) => (200, <dynamic>[]);
  api.routes['GET /channels/unread'] = (_) => (200, {'channels': {}});
  final client = _Client(api);
  await client.login('fixture', 'fixture');
  client.selectServer(_server);
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': _server, 'role': 'owner', 'plan': 'free'});
  w.channels = [for (final c in channels) RaftChannel(c)];
  w.messageDomain.ledger.switchServer(_server);
  return (w, api, client);
}

Map<String, dynamic> _listRow(int index) => Map<String, dynamic>.from(
  (_fixture('channels-list-regular-and-joint') as List)[index] as Map,
);

class _RosterWorkspace extends WorkspaceController {
  _RosterWorkspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      switch (path) {
        final p when p.startsWith('/channels/') && p.endsWith('/members') =>
          _fixture('channels-members-roster-joint'),
        _ => <dynamic>[],
      };
}

void main() {
  group('thread open 404 (threadStore.isThreadAbsentLookupError)', () {
    final body = _fixture('channels-thread-updated-and-followed') as Map;
    RaftApiException failure(Map response) => RaftApiException.response(
      '${response['error']}',
      status: 404,
      body: response,
    );

    test('only THREAD_NOT_FOUND (or the exact legacy text) is "no thread yet"', () {
      expect(
        isThreadAbsentLookupError(
          failure(
            body['GET /channels/:id/threads/:messageId (404 = no thread yet)'],
          ),
        ),
        isTrue,
      );
      expect(
        isThreadAbsentLookupError(
          failure(
            body['GET /channels/:id/threads/:messageId (404 = lookup failure, NOT empty)'],
          ),
        ),
        isFalse,
      );
      // Legacy server: no code, exact text.
      expect(
        isThreadAbsentLookupError(
          failure({'error': 'No thread found for this message'}),
        ),
        isTrue,
      );
      // A code that is not THREAD_NOT_FOUND wins over the text.
      expect(
        isThreadAbsentLookupError(
          failure({
            'code': 'OTHER',
            'error': 'No thread found for this message',
          }),
        ),
        isFalse,
      );
      expect(
        isThreadAbsentLookupError(
          const RaftApiException(
            'No thread found for this message',
            status: 403,
          ),
        ),
        isFalse,
      );
    });

    for (final (name, response, error) in [
      ('a lookup-failure 404 shows the Retry error', 'lookup', true),
      ('THREAD_NOT_FOUND is an empty thread', 'absent', false),
    ]) {
      test(name, () async {
        final (w, api, _) = await _controller(channels: [_listRow(0)]);
        addTearDown(w.dispose);
        final parent = _listRow(0)['id'] as String;
        api.routes['GET /messages/context/m1000000-0000-4000-8000-0000000000f1'] =
            (_) => (404, {'error': 'x'});
        api.routes['GET /channels/$parent/threads/m1000000-0000-4000-8000-0000000000f1'] =
            (_) => (
              404,
              response == 'absent'
                  ? body['GET /channels/:id/threads/:messageId (404 = no thread yet)']
                  : body['GET /channels/:id/threads/:messageId (404 = lookup failure, NOT empty)'],
            );
        await w.openThreadIdentity(
          parentChannelId: parent,
          parentMessageId: 'm1000000-0000-4000-8000-0000000000f1',
        );
        await _drain();
        expect(w.messageDomain.threadResolutionError != null, error);
        expect(w.threadChannelId, isNull);
      });
    }
  });

  group('channel:updated hiding #all', () {
    test('a private channel named all leaves the list', () async {
      final all = {
        ..._listRow(0),
        'id': 'c9000000-0000-4000-8000-000000000009',
        'name': 'all',
        'type': 'channel',
      };
      final (w, api, client) = await _controller(channels: [_listRow(0), all]);
      addTearDown(w.dispose);
      final event = _fixture('channels-updated-hidden-all') as Map;
      final calls = api.calls.length;
      client.emit('channel:updated', {'channel': event['channel']});
      await _drain();
      expect(w.channels.map((c) => c.name), ['engineering']);
      // Web drops it locally; no re-read brings it back.
      expect(
        api.calls.skip(calls).map((c) => c.path),
        isNot(contains('/channels/${all['id']}')),
      );
    });

    test('unhiding re-reads it (type back to channel)', () async {
      final (w, api, client) = await _controller(channels: [_listRow(0)]);
      addTearDown(w.dispose);
      final id = 'c9000000-0000-4000-8000-000000000009';
      api.routes['GET /channels/$id'] = (_) =>
          (200, {..._listRow(0), 'id': id, 'name': 'all', 'type': 'channel'});
      client.emit('channel:updated', {
        'channel': {
          ...(_fixture('channels-updated-hidden-all') as Map)['channel'],
          'type': 'channel',
        },
      });
      await _drain();
      expect(w.channels.map((c) => c.name), ['engineering', 'all']);
    });
  });

  group('server:plan-updated', () {
    test(
      'patches the plan of the server row and asks billing to reload',
      () async {
        final payload =
            (_fixture('members-socket-server-plan-updated') as Map)['payload']
                as Map;
        final (w, _, client) = await _controller();
        addTearDown(w.dispose);
        w.servers = [
          RaftRecord({'id': payload['serverId'], 'plan': 'free'}),
          RaftRecord({'id': 'other', 'plan': 'free'}),
        ];
        w.server = w.servers.first;
        final before = w.planRevision;
        client.emit('server:plan-updated', payload);
        await _drain();
        expect(w.servers.first.string('plan'), 'pro');
        expect(w.server!.string('plan'), 'pro');
        expect(w.servers.last.string('plan'), 'free');
        expect(w.planRevision, before + 1);
      },
    );
  });

  group('message_display_prefs:updated', () {
    Map<String, dynamic> frame(bool collapse, int version) => {
      'serverId': _server,
      'scopeId': _listRow(0)['id'],
      'prefs': {'collapseLongMessages': collapse},
      'prefsVersion': version,
    };

    test(
      'writes collapseLongMessages + displayPrefsVersion on the row',
      () async {
        final (w, _, client) = await _controller(channels: [_listRow(0)]);
        addTearDown(w.dispose);
        w.channel = w.channels.first;
        expect(w.channels.first.json['collapseLongMessages'], false);
        client.emit('message_display_prefs:updated', frame(true, 3));
        await _drain();
        expect(w.channels.first.json['collapseLongMessages'], true);
        expect(w.channels.first.json['displayPrefsVersion'], 3);
        expect(w.channel!.json['collapseLongMessages'], true);
      },
    );

    test('a stale prefsVersion and another server are ignored', () async {
      final (w, _, client) = await _controller(channels: [_listRow(0)]);
      addTearDown(w.dispose);
      client.emit('message_display_prefs:updated', frame(true, 1));
      client.emit('message_display_prefs:updated', {
        ...frame(true, 9),
        'serverId': 'elsewhere',
      });
      client.emit('message_display_prefs:updated', {
        ...frame(true, 9),
        'prefs': {},
      });
      await _drain();
      expect(w.channels.first.json['collapseLongMessages'], false);
      expect(w.channels.first.json['displayPrefsVersion'], 2);
    });
  });

  group('channel roster', () {
    final roster = _fixture('channels-members-roster-joint') as Map;
    final joint = RaftChannel(_listRow(1));

    Map<String, dynamic> member(String list, String name) =>
        Map<String, dynamic>.from(
          (roster[list] as List).firstWhere((m) => m['name'] == name) as Map,
        );

    test('participant count includes Slack externalMembers (5)', () {
      expect(channelRosterCount(roster), 5);
      expect(channelRosterCount(null), 0);
    });

    test('joint server badges and no Remove for non-local members', () {
      expect(isLocalChannelMember(member('agents', 'cindy'), joint), isTrue);
      expect(channelMemberServerLabels(member('agents', 'cindy'), joint), []);
      expect(
        isLocalChannelMember(member('agents', 'acme-bot'), joint),
        isFalse,
      );
      expect(channelMemberServerLabels(member('agents', 'acme-bot'), joint), [
        'Acme Partners',
      ]);
      expect(channelMemberServerLabels(member('humans', 'pat'), joint), [
        'Acme Partners',
      ]);
      expect(channelMemberServerLabels(member('humans', 'owner'), joint), []);
      // serverName missing -> slug; only joint channels show a badge.
      expect(
        channelMemberServerLabels({
          'serverId': 'x',
          'serverName': null,
          'serverSlug': 'acme',
        }, joint),
        ['acme'],
      );
      expect(
        channelMemberServerLabels(
          member('humans', 'pat'),
          RaftChannel(_listRow(0)),
        ),
        isEmpty,
      );
    });

    test('presence follows the live directory row, not only the snapshot', () {
      final now = DateTime.utc(2026, 10, 12, 12);
      final cindy = member('agents', 'cindy');
      final working = channelMemberAgentDisplay(cindy, now: now);
      expect(working.activity, 'working');
      expect(working.detail, 'Editing release notes');
      // The directory says she is thinking now.
      final live = channelMemberAgentDisplay(
        cindy,
        directory: {
          'id': cindy['id'],
          'status': 'active',
          'activityKind': 'thinking',
        },
        now: now,
      );
      expect(live.activity, 'thinking');
      expect(
        channelMemberPresence(
          cindy,
          directory: {'activity': 'error'},
        )!.activity,
        RaftAvatarActivity.error,
      );
    });

    test('a stopped managed agent reads Stopped, not Offline', () {
      final display = channelMemberAgentDisplay(member('agents', 'acme-bot'));
      expect(display.activity, 'offline');
      expect(display.detailKind, 'stopped');
    });

    test('an external agent silent for more than 120 s is offline', () {
      final now = DateTime.utc(2026, 10, 12, 12);
      Map<String, dynamic> external(DateTime seen) => {
        'id': 'e',
        'status': 'active',
        'external': true,
        'activity': 'online',
        'lastSeenAt': seen.toIso8601String(),
      };
      expect(
        channelMemberAgentDisplay(
          external(now.subtract(const Duration(seconds: 60))),
          now: now,
        ).activity,
        'online',
      );
      expect(
        channelMemberAgentDisplay(
          external(now.subtract(const Duration(seconds: 121))),
          now: now,
        ).activity,
        'offline',
      );
    });
  });

  group('dead channel:removed listeners', () {
    test(
      'a 404 channel read revokes the channel and closes its thread',
      () async {
        final row = _listRow(0);
        final id = row['id'] as String;
        final (w, api, client) = await _controller(channels: [row]);
        addTearDown(w.dispose);
        w.channel = w.channels.first;
        api.routes['GET /channels/$id'] = (_) =>
            (404, {'error': 'Channel not found or not visible'});
        api.routes['GET /channels/$id/threads/m1'] = (_) => (
          404,
          {
            'code': 'THREAD_NOT_FOUND',
            'error': 'No thread found for this message',
          },
        );
        await w.openThreadIdentity(parentChannelId: id, parentMessageId: 'm1');
        expect(w.threadIdentity, isNotNull);
        client.emit('channel:members-updated', {'channelId': id});
        await _drain();
        expect(w.channels, isEmpty);
        expect(w.channel, isNull);
        expect(w.threadIdentity, isNull);
      },
    );

    test(
      'an unlisted channel that 403s still closes a thread opened on it',
      () async {
        final id = 'c7777777-0000-4000-8000-000000000007';
        final (w, api, client) = await _controller();
        addTearDown(w.dispose);
        api.routes['GET /channels/$id'] = (_) => (403, {'error': 'No access'});
        api.routes['GET /channels/$id/threads/m1'] = (_) => (
          404,
          {
            'code': 'THREAD_NOT_FOUND',
            'error': 'No thread found for this message',
          },
        );
        await w.openThreadIdentity(parentChannelId: id, parentMessageId: 'm1');
        expect(w.threadIdentity, isNotNull);
        client.emit('channel:members-updated', {'channelId': id});
        await _drain();
        expect(w.threadIdentity, isNull);
      },
    );
  });

  test('optimistic send names the sender displayName || name', () async {
    for (final (displayName, expected) in [
      ('Server Owner', 'Server Owner'),
      ('', 'owner'),
      (null, 'owner'),
    ]) {
      final (w, api, _) = await _controller(
        channels: [_listRow(0)],
        user: {'id': _me, 'name': 'owner', 'displayName': displayName},
      );
      addTearDown(w.dispose);
      w.channel = w.channels.first;
      final channelId = w.channel!.id;
      w.messageDomain.ledger.ingest([
        {
          'id': 'm0',
          'channelId': channelId,
          'seq': '1',
          'senderId': 'bob',
          'senderType': 'user',
          'senderName': 'Bob',
          'content': 'Earlier',
          'createdAt': '2026-10-10T08:00:00.000Z',
        },
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds[channelId] = {'m0'};
      final hold = Completer<(int, dynamic)>();
      api.routes['POST /v2/messages'] = (_) => hold.future;
      unawaited(w.send('hello'));
      await _drain();
      final pending = w.messageDomain.timeline().where(
        WorkspaceMessages.isPendingSend,
      );
      expect(pending, hasLength(1), reason: 'displayName=$displayName');
      expect(pending.single.json['senderName'], expected);
      hold.complete((500, {'error': 'x'}));
      await _drain();
    }
  });

  test('unread summary hasNew becomes a quiet-dot set', () async {
    final (w, api, _) = await _controller();
    addTearDown(w.dispose);
    final fixture = (_fixture('realtime-unread-summary') as Map)['response'];
    api.routes['GET /channels/unread'] = (_) => (200, fixture);
    await w.refreshUnread();
    expect(w.conversationReads.newFlags, {
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    });
    expect(
      w.conversationReads.unread['77777777-7777-4777-8777-777777777777'],
      4,
    );
    expect(
      w.conversationReads.unread['cccccccc-cccc-4ccc-8ccc-cccccccccccc'],
      0,
    );
    // The next summary replaces the set.
    api.routes['GET /channels/unread'] = (_) => (200, {'channels': {}});
    await w.refreshUnread();
    expect(w.conversationReads.newFlags, isEmpty);
  });

  test(
    'upload ceiling is capped to the multipart limit when direct upload is on',
    () {
      final direct = _fixture('messages-upload-capabilities-direct');
      expect(direct['maxBytes'], 209715200);
      expect(
        WorkspaceController.uploadLimitFromCapabilities(direct),
        90 * 1024 * 1024,
      );
      // Legacy-only server: maxBytes is already the multipart ceiling.
      expect(
        WorkspaceController.uploadLimitFromCapabilities({
          'directUploadEnabled': false,
          'maxBytes': 50 * 1024 * 1024,
        }),
        50 * 1024 * 1024,
      );
      expect(
        WorkspaceController.uploadLimitFromCapabilities({
          'directUploadEnabled': true,
          'maxBytes': 20 * 1024 * 1024,
        }),
        20 * 1024 * 1024,
      );
      expect(
        WorkspaceController.uploadLimitFromCapabilities({'maxBytes': 0}),
        isNull,
      );
      expect(WorkspaceController.uploadLimitFromCapabilities(null), isNull);
    },
  );

  test(
    'mute gate is type in {channel,private,joint} && joined (no wire flag)',
    () {
      final channel = _listRow(0)..remove('activityMuteSupported');
      expect(channelCanToggleActivityMute(RaftChannel(channel)), isTrue);
      expect(channelCanToggleActivityMute(RaftChannel(_listRow(1))), isTrue);
      expect(
        channelCanToggleActivityMute(
          RaftChannel({...channel, 'joined': false}),
        ),
        isFalse,
      );
      final dm =
          (_fixture('channels-dm-list') as List).first as Map<String, dynamic>;
      expect(channelCanToggleActivityMute(RaftChannel(dm)), isFalse);
      expect(
        channelCanToggleActivityMute(
          RaftChannel({...channel, 'type': 'thread'}),
        ),
        isFalse,
      );
    },
  );

  testWidgets('roster page: Slack row, peer members have no Remove action', (
    t,
  ) async {
    final api = _Api();
    final client = _Client(api)..user = RaftRecord({'id': _me});
    client.selectServer(_server);
    final w = _RosterWorkspace(client)
      ..server = RaftRecord({'id': _server, 'role': 'owner'});
    final joint = RaftChannel({
      ..._listRow(1),
      'channelCapabilities': {
        'removeChannelMembers': true,
        'viewChannel': true,
      },
    });
    w.channels = [joint];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ChannelMembers(controller: w, channel: joint, page: true),
        ),
      ),
    );
    await t.pumpAndSettle();
    // Dana (Slack) is listed read-only with the provider tag and @handle.
    expect(find.text('Dana (Slack)'), findsOneWidget);
    expect(find.text('@dana'), findsOneWidget);
    expect(find.text('Slack'), findsOneWidget);
    // Local members can be removed; the partner server's cannot.
    expect(
      find.byKey(
        const ValueKey(
          'member-page-row-agent-a1000000-0000-4000-8000-0000000000aa-remove',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(
          'member-page-row-agent-a2000000-0000-4000-8000-0000000000ab-remove',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey(
          'member-page-row-human-u2000000-0000-4000-8000-0000000000c2-remove',
        ),
      ),
      findsNothing,
    );
    // A stopped managed agent reads Stopped.
    expect(find.textContaining('Stopped'), findsOneWidget);
    expect(find.text('Editing release notes'), findsOneWidget);
  });

  testWidgets('joint views: a channelCapabilities change is a policy change', (
    t,
  ) async {
    final api = _Api();
    late final _Client client;
    final jointRow = _listRow(1);
    final id = jointRow['id'] as String;
    api.routes['POST /auth/login'] = (_) => (
      200,
      {
        'accessToken': 'x',
        'refreshToken': 'x',
        'user': {'id': _me},
      },
    );
    api.routes['GET /channels/joint-invites'] = (_) => (200, {'invites': []});
    api.routes['GET /channels'] = (_) => (200, <dynamic>[]);
    api.routes['GET /agents'] = (_) => (200, <dynamic>[]);
    api.routes['GET /servers/$_server/members'] = (_) => (200, <dynamic>[]);
    api.routes['GET /channels/$id'] = (_) => (200, jointRow);
    await t.runAsync(() async {
      client = _Client(api);
      await client.login('x', 'x');
      client.selectServer(_server);
    });
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': _server, 'role': 'owner'});
    w.channels = [RaftChannel(jointRow)];
    addTearDown(() async {
      w.dispose();
      await client.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: JointChannelManagementView(controller: w, channelId: id),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Invite workspace'));
    await t.pumpAndSettle();
    expect(find.byType(RaftFormDialog), findsOneWidget);
    // The server row has no `capabilities`/`isPrivate`: only the real
    // authority keys change what the member may do.
    client.emit('channel:updated', {
      'channel': {
        'id': id,
        'serverId': _server,
        'name': 'partners',
        'channelCapabilities': {'federateChannels': false},
      },
    });
    await t.pumpAndSettle();
    expect(find.byType(RaftFormDialog), findsNothing);
  });
}
