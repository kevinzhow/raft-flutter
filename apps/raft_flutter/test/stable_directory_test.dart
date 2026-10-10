import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;

/// A client whose socket events the test drives.
class _EventClient extends RaftClient {
  _EventClient(MessageAdapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

const _cindy = <String, dynamic>{
  'id': 'cindy',
  'name': 'cindy',
  'displayName': 'Cindy',
  'avatarUrl': 'pixel:cat',
  'description': 'Designs the visual system',
  'status': 'active',
  'runtime': 'codex',
  'model': 'gpt-5-codex',
};
const _retired = <String, dynamic>{
  'id': 'retired',
  'name': 'retired',
  'avatarUrl': 'pixel:ghost',
  'status': 'inactive',
  'runtime': 'codex',
  'model': 'gpt-5-codex',
  'deletedAt': '2026-06-22T03:00:00Z',
};

Future<(MessageAdapter, _EventClient)> _login() async {
  final a = MessageAdapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes['GET /agents'] = (_) => [_cindy, _retired];
  a.routes['GET /servers/s1/members'] = (_) => [
    {'userId': 'alice', 'name': 'alice', 'role': 'owner'},
  ];
  final client = _EventClient(a);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  return (a, client);
}

/// The controller is built in the test zone so its timers and request
/// pipelines follow the fake clock.
Future<(WorkspaceController, MessageAdapter, _EventClient)> _fixture(
  WidgetTester t,
) async {
  final (a, client) = (await t.runAsync(_login))!;
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  final c1 = RaftChannel({'id': 'c1', 'name': 'design', 'joined': true});
  final c2 = RaftChannel({'id': 'c2', 'name': 'release', 'joined': true});
  w.channel = c1;
  w.channels = [c1, c2];
  w.ledger.switchServer('s1');
  // No senderDescription / senderAvatarUrl: the subtitle and the pixel avatar
  // can only come from the shared directory.
  w.ledger.ingest([
    for (final (id, channel, sender, seq) in [
      ('m1', 'c1', 'cindy', 1),
      ('m2', 'c1', 'retired', 2),
      ('m3', 'c2', 'cindy', 3),
    ])
      {
        'id': id,
        'channelId': channel,
        'seq': seq,
        'senderId': sender,
        'senderType': 'agent',
        'senderName': sender,
        'sourceServerId': 's1',
        'content': 'Body $id',
        'createdAt': '2026-06-22T02:30:00Z',
      },
  ], expectedGeneration: w.ledger.generation);
  w.visibleIds['c1'] = {'m1', 'm2'};
  w.visibleIds['c2'] = {'m3'};
  return (w, a, client);
}

Finder _row(String id) => find.byKey(ValueKey('message-$id'));

/// Everything the product rule freezes once a row is on screen.
class _Header {
  _Header(WidgetTester t, String id) {
    final row = t.widget<RaftMessageTile>(_row(id));
    final author = find.descendant(
      of: _row(id),
      matching: find.byKey(const ValueKey('message-author')),
    );
    authorType = t.widget(author).runtimeType;
    authorRect = t.getRect(author);
    linkable = row.onAuthor != null;
    subtitle = row.subtitle;
    departure = row.departureLabel;
    final pixels = find.descendant(
      of: _row(id),
      matching: find.byType(RaftPixelAvatar),
    );
    pixel = pixels.evaluate().isEmpty
        ? null
        : t.widget<RaftPixelAvatar>(pixels.first).avatarKey;
  }
  late final Type authorType;
  late final Rect authorRect;
  late final bool linkable;
  late final String? subtitle, departure, pixel;
  List<Object?> get facts => [
    authorType,
    authorRect,
    linkable,
    subtitle,
    departure,
    pixel,
  ];
}

Widget _host(WorkspaceController w, {Key? key}) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(
    body: RaftChatView(key: key, controller: w),
  ),
);

/// Lets fake-zone request pipelines and the real transport both progress.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 10));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await t.pump();
}

/// Pumps frame by frame (no I/O) until the row is first on screen.
Future<void> _firstPaint(WidgetTester t, String id) async {
  for (var i = 0; i < 10 && _row(id).evaluate().isEmpty; i++) {
    await t.pump();
  }
  expect(_row(id), findsOneWidget);
}

int _agentReads(MessageAdapter a) =>
    a.calls.where((c) => c.method == 'GET' && c.path == '/agents').length;

void main() {
  testWidgets(
    'a new chat mount (thread open) and a channel switch paint the final author at the first frame',
    (t) async {
      final (w, a, client) = await _fixture(t);
      addTearDown(w.dispose);
      // The workspace preloads the shared directory before any chat paints.
      w.entityDirectory.ensureAuthors();
      await _settle(t);
      expect(w.entityDirectory.authorsLoading, isFalse);
      final reads = _agentReads(a);

      // First frame of a fresh mount: no placeholder author/avatar/badge.
      await t.pumpWidget(_host(w, key: const ValueKey('first')));
      await _firstPaint(t, 'm1');
      final fresh = _Header(t, 'm1');
      expect(fresh.subtitle, 'Designs the visual system');
      expect(fresh.pixel, 'cat');
      expect(fresh.linkable, isTrue);
      expect(_Header(t, 'm2').departure, 'Deleted');
      expect(_Header(t, 'm2').pixel, 'ghost');
      await _settle(t);
      expect(_Header(t, 'm1').facts, fresh.facts);

      // Channel switch: the first frame of the next channel is final too, and
      // the shared directory is neither cleared nor refetched.
      w.channel = w.channels[1];
      w.notifyListeners();
      await _firstPaint(t, 'm3');
      final switched = _Header(t, 'm3');
      expect(switched.subtitle, 'Designs the visual system');
      expect(switched.pixel, 'cat');
      expect(switched.linkable, isTrue);
      expect(w.entityDirectory.authorsLoading, isFalse);
      await _settle(t);
      expect(_Header(t, 'm3').facts, switched.facts);
      expect(_agentReads(a), reads);

      await t.pumpWidget(const SizedBox());
      await t.runAsync(client.stream.close);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'agent:updated revalidates in place: the row header is identical every frame until new data lands',
    (t) async {
      final (w, a, client) = await _fixture(t);
      addTearDown(w.dispose);
      await t.pumpWidget(_host(w));
      await _settle(t);
      await _settle(t);
      final before = _Header(t, 'm1');
      expect(before.subtitle, 'Designs the visual system');
      expect(before.linkable, isTrue);
      final reads = _agentReads(a);

      final response = Completer<dynamic>();
      a.routes['GET /agents'] = (_) => response.future;
      client.stream.add(const RaftEvent('agent:updated', {'agentId': 'cindy'}));
      // The debounced refresh starts; the request stays in flight.
      for (var frame = 0; frame < 12; frame++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        expect(_Header(t, 'm1').facts, before.facts, reason: 'frame $frame');
        expect(_Header(t, 'm2').departure, 'Deleted');
        expect(w.entityDirectory.authorsLoading, isFalse);
      }
      expect(_agentReads(a), reads + 1);

      response.complete([
        {..._cindy, 'description': 'Owns the release notes'},
        _retired,
      ]);
      await _settle(t);
      await _settle(t);
      final after = _Header(t, 'm1');
      // A real live update replaces the subtitle in place; the author widget
      // and its rect are unchanged.
      expect(after.subtitle, 'Owns the release notes');
      expect(after.authorType, before.authorType);
      expect(after.authorRect, before.authorRect);
      expect(after.pixel, 'cat');

      await t.pumpWidget(const SizedBox());
      await t.runAsync(client.stream.close);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'an identity change (role) clears the shared directory and a stale response is never applied',
    (t) async {
      final (w, a, client) = await _fixture(t);
      addTearDown(w.dispose);
      await t.pumpWidget(_host(w));
      await _settle(t);
      await _settle(t);
      expect(_Header(t, 'm1').linkable, isTrue);
      expect(w.entityDirectory.authorAgents, isNotEmpty);

      // Revalidation in flight under the owner identity…
      final stale = Completer<dynamic>();
      a.routes['GET /agents'] = (_) => stale.future;
      w.entityDirectory.revalidateAuthors();
      // …then the role drops to guest (no viewAgents/viewMembers).
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      w.notifyListeners();
      await t.pump();
      expect(w.entityDirectory.authorAgents, isEmpty);
      expect(w.entityDirectory.authorMembers, isEmpty);
      final guest = _Header(t, 'm1');
      expect(guest.linkable, isFalse);
      expect(guest.subtitle, isNull);
      expect(_Header(t, 'm2').departure, isNull);

      stale.complete([_cindy, _retired]);
      await _settle(t);
      expect(w.entityDirectory.authorAgents, isEmpty);
      expect(_Header(t, 'm1').facts, guest.facts);

      await t.pumpWidget(const SizedBox());
      await t.runAsync(client.stream.close);
      expect(t.takeException(), isNull);
    },
  );
}
