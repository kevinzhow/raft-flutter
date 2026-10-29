import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;

Map<String, dynamic> _thumbs({bool mine = false}) => {
  'emoji': '👍',
  'count': mine ? 3 : 2,
  'reactorIds': ['bob', 'carol', if (mine) 'alice'],
  'reactorNames': ['Bob', 'Carol', if (mine) 'Alice'],
};

Map<String, dynamic> _fire() => {
  'emoji': '🔥',
  'count': 1,
  'reactorIds': ['alice'],
  'reactorNames': ['Alice'],
};

Map<String, dynamic> _row({List<Map<String, dynamic>>? reactions}) => {
  'id': 'm1',
  'channelId': 'c1',
  'seq': '1',
  'content': 'Frozen reaction contract',
  'senderId': 'bob',
  'senderType': 'user',
  'reactions': reactions ?? [_thumbs()],
};

Map<String, dynamic> _viewer(int version, List<String> emojis) => {
  'serverId': 's1',
  'messageId': 'm1',
  'viewerVersion': version,
  'reactedEmojis': emojis,
};

class _HydrationSpy extends WorkspaceController {
  _HydrationSpy(super.client) : super(ownsClient: false);
  int hydrations = 0;

  @override
  Future<void> hydrateReactionViewer(RaftMessage message) async {
    hydrations++;
  }
}

class _SourceSpy extends _HydrationSpy {
  _SourceSpy(super.client);
  int toggles = 0;

  @override
  Future<void> toggleReaction(RaftMessage message, String emoji) async {
    toggles++;
  }

  @override
  Map<String, bool>? pendingReactionTargets(String messageId) => {'🧪': true};
}

Future<(WorkspaceController, MessageAdapter)> _fixture({
  WorkspaceController Function(RaftClient)? create,
}) async {
  final api = MessageAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice', 'displayName': 'Alice'},
  };
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = api,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w =
      create?.call(client) ?? WorkspaceController(client, ownsClient: false);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  w.messageDomain.ledger.switchServer('s1');
  w.messageDomain.ledger.ingest([
    _row(),
  ], expectedGeneration: w.messageDomain.ledger.generation);
  w.messageDomain.visibleIds['c1'] = {'m1'};
  addTearDown(() async {
    w.dispose();
    await client.dispose();
  });
  return (w, api);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('borrowed reaction commands retain source overrides; independent '
      'receivers sharing the client keep separate viewer state', () async {
    final (source, _) = await _fixture(create: _SourceSpy.new);
    final borrowed = WorkspaceController(
      source.client,
      presentationSource: source,
      ownsClient: false,
    );
    final independent = WorkspaceController(source.client, ownsClient: false);
    addTearDown(borrowed.dispose);
    addTearDown(independent.dispose);
    final message = RaftMessage(_row());
    expect(borrowed.reactionViewer, same(source.reactionViewer));
    expect(independent.reactionViewer, isNot(same(source.reactionViewer)));
    expect(borrowed.pendingReactionTargets('m1'), {'🧪': true});
    expect(independent.pendingReactionTargets('m1'), isNull);
    await borrowed.hydrateReactionViewer(message);
    await borrowed.toggleReaction(message, '👍');
    expect((source as _SourceSpy).hydrations, 1);
    expect(source.toggles, 1);
  });

  test('concurrent viewer hydration makes one request and accepts the '
      'complete private snapshot', () async {
    final (w, api) = await _fixture();
    final response = Completer<dynamic>();
    final started = Completer<void>();
    api.routes['GET /messages/m1/reactions/viewer'] = (_) {
      started.complete();
      return response.future;
    };
    final message = RaftMessage(_row());
    final first = w.hydrateReactionViewer(message);
    final second = w.hydrateReactionViewer(message);
    await started.future.timeout(const Duration(seconds: 3));
    expect(api.calls.where((c) => c.path.endsWith('/viewer')), hasLength(1));
    expect(w.reactionViewer.reacted('m1'), isNull);
    response.complete(_viewer(1, ['👍']));
    await Future.wait([first, second]);
    expect(w.reactionViewer.reacted('m1'), {'👍'});
    await w.hydrateReactionViewer(message);
    expect(api.calls.where((c) => c.path.endsWith('/viewer')), hasLength(1));
  });

  test(
    'a failed viewer read remains unknown and a later call retries',
    () async {
      final (w, api) = await _fixture();
      api.routes['GET /messages/m1/reactions/viewer'] = (_) =>
          throw const RaftApiException('Frozen viewer read failure');
      final message = RaftMessage(_row());
      await w.hydrateReactionViewer(message);
      expect(w.reactionViewer.reacted('m1'), isNull);
      api.routes['GET /messages/m1/reactions/viewer'] = (_) => _viewer(1, []);
      await w.hydrateReactionViewer(message);
      expect(w.reactionViewer.reacted('m1'), isEmpty);
      expect(api.calls.where((c) => c.path.endsWith('/viewer')), hasLength(2));
    },
  );

  test('a viewer read from the retired ledger generation cannot publish '
      'private choices into the next generation', () async {
    final (w, api) = await _fixture();
    final response = Completer<dynamic>();
    final started = Completer<void>();
    api.routes['GET /messages/m1/reactions/viewer'] = (_) {
      started.complete();
      return response.future;
    };
    final pending = w.hydrateReactionViewer(RaftMessage(_row()));
    await started.future.timeout(const Duration(seconds: 3));
    w.messageDomain.ledger.switchServer('replacement');
    response.complete(_viewer(1, ['👍']));
    await pending;
    expect(w.reactionViewer.reacted('m1'), isNull);
  });

  test('one emoji coalesces its in-flight writes while another emoji stays '
      'optimistic through the first confirmation', () async {
    final (w, api) = await _fixture();
    final thumbs = Completer<dynamic>(), fire = Completer<dynamic>();
    final bothStarted = Completer<void>();
    var starts = 0;
    api.routes['POST /messages/m1/reactions'] = (request) {
      if (++starts == 2) bothStarted.complete();
      return (request.data as Map)['emoji'] == '👍'
          ? thumbs.future
          : fire.future;
    };
    final message = RaftMessage(_row());
    final first = w.toggleReaction(message, '👍');
    final duplicate = w.toggleReaction(message, '👍');
    final other = w.toggleReaction(message, '🔥');
    await bothStarted.future.timeout(const Duration(seconds: 3));
    expect(api.calls.where((c) => c.path.endsWith('/reactions')), hasLength(2));
    expect(w.pendingReactionTargets('m1'), {'👍': true, '🔥': true});
    thumbs.complete({
      ..._row(reactions: [_thumbs(mine: true)]),
      'reactionViewer': _viewer(2, ['👍']),
    });
    await Future.wait([first, duplicate]);
    expect(w.pendingReactionTargets('m1'), {'🔥': true});
    expect(w.messageDomain.ledger.message('c1', 'm1')?['reactions'], [
      _thumbs(mine: true),
      _fire(),
    ]);
    fire.complete({
      ..._row(reactions: [_thumbs(mine: true), _fire()]),
      'reactionViewer': _viewer(3, ['👍', '🔥']),
    });
    await other;
    expect(w.pendingReactionTargets('m1'), isNull);
    expect(w.reactionViewer.reacted('m1'), {'👍', '🔥'});
  });

  test('a stale write failure clears its pending target without overwriting '
      'a replacement message generation', () async {
    final (w, api) = await _fixture();
    final response = Completer<dynamic>();
    final started = Completer<void>();
    api.routes['POST /messages/m1/reactions'] = (_) {
      started.complete();
      return response.future;
    };
    final pending = w.toggleReaction(RaftMessage(_row()), '👍');
    final failed = expectLater(pending, throwsA(anything));
    await started.future.timeout(const Duration(seconds: 3));
    w.messageDomain.ledger.switchServer('replacement');
    final replacement = _row(
      reactions: [
        {..._thumbs(), 'count': 42},
      ],
    );
    w.messageDomain.ledger.ingest([
      replacement,
    ], expectedGeneration: w.messageDomain.ledger.generation);
    response.completeError(const RaftApiException('Frozen write failure'));
    await failed;
    expect(w.pendingReactionTargets('m1'), isNull);
    expect(
      w.messageDomain.ledger.message('c1', 'm1')?['reactions'],
      replacement['reactions'],
    );
  });

  test('revalidating a stale private snapshot retains the receiver public '
      'hydration override', () async {
    final (w, api) = await _fixture(create: _HydrationSpy.new);
    w.reactionViewer.accept(_viewer(5, []), serverId: 's1');
    api.routes['POST /messages/m1/reactions'] = (_) => {
      ..._row(reactions: [_thumbs(mine: true)]),
      'reactionViewer': _viewer(4, []),
    };
    await w.toggleReaction(RaftMessage(_row()), '👍');
    expect((w as _HydrationSpy).hydrations, 1);
    expect(w.reactionViewer.reacted('m1'), isNull);
    expect(w.pendingReactionTargets('m1'), isNull);
  });
}
