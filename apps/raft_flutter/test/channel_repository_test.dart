import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/channel_repository.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final rows = <Completer<dynamic>>[];
  final lists = <Completer<List<RaftChannel>>>[];
  @override
  Stream<RaftEvent> get events =>
      throw StateError('No subscription is allowed');
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    final gate = Completer<dynamic>();
    rows.add(gate);
    return gate.future;
  }

  @override
  Future<List<RaftChannel>> channels({bool dm = false}) {
    final gate = Completer<List<RaftChannel>>();
    lists.add(gate);
    return gate.future;
  }
}

RaftChannel _row(String id) =>
    RaftChannel({'id': id, 'name': id, 'joined': true});

class _Binding {
  _Binding() {
    repository = ChannelRepository(
      client,
      channels: () {
        portReads++;
        return channels;
      },
      dms: () {
        portReads++;
        return dms;
      },
      generation: () {
        portReads++;
        return generation;
      },
      identity: () {
        portReads++;
        return identity;
      },
      isDisposed: () => false,
      revokedChannels: () => revoked,
      acceptLists: (nextChannels, nextDms, {required readmit}) {
        effects.add('accept');
        beforeAccept?.call();
        channels = nextChannels;
        dms = nextDms;
      },
      reloadLists: () async => effects.add('reload-lists'),
      reloadRow: (id) async => effects.add('reload:$id'),
      revokeChannel: (id) {
        revoked.add(id);
        effects.add('revoke:$id');
      },
      closeDeniedThread: (id) => effects.add('close:$id'),
      changed: () => effects.add('notify'),
      setError: (_) => effects.add('error'),
      quietFailure: (_) => false,
    );
    addTearDown(() async {
      for (final gate in client.rows) {
        if (!gate.isCompleted) gate.complete({});
      }
      for (final gate in client.lists) {
        if (!gate.isCompleted) gate.complete([]);
      }
      await client.dispose();
    });
  }
  final client = _Client();
  late final ChannelRepository repository;
  List<RaftChannel> channels = [_row('held')], dms = [];
  final revoked = <String>{};
  final effects = <String>[];
  int generation = 1, portReads = 0;
  String identity = 'receiver-authority';
  void Function()? beforeAccept;
}

void main() {
  test(
    'construction and row-authority bookkeeping do not read ports or I/O',
    () {
      final b = _Binding();
      b.repository.recordRowWrite('held');
      b.repository.resetRowAuthority();
      expect(b.portReads, 0);
      expect(b.client.rows, isEmpty);
      expect(b.client.lists, isEmpty);
      expect(b.effects, isEmpty);
    },
  );

  test(
    'a supplied receiver identity fences rows independently of the client',
    () async {
      final b = _Binding(), held = b.channels;
      final pending = b.repository.refreshChannel('held');
      b.identity = 'receiver-after-role-change';
      b.client.rows.single.complete(_row('held').json);
      await pending;
      expect(identical(b.channels, held), isTrue);
      expect(b.effects, isEmpty);
    },
  );

  test(
    'an unheld denial revokes before closing the receiver and notifying',
    () async {
      final b = _Binding(), held = b.channels;
      final pending = b.repository.refreshChannel('missing');
      b.client.rows.single.completeError(
        const RaftApiException('not found', status: 404),
      );
      await pending;
      expect(b.revoked, {'missing'});
      expect(identical(b.channels, held), isTrue);
      expect(b.effects, ['revoke:missing', 'close:missing', 'notify']);
    },
  );

  test('the row path propagates an acceptance callback failure', () async {
    final b = _Binding();
    b.beforeAccept = () => throw StateError('receiver failed');
    final pending = b.repository.refreshChannel('held');
    b.client.rows.single.complete({..._row('held').json, 'name': 'updated'});
    await expectLater(pending, throwsStateError);
    expect(b.effects, ['accept']);
  });

  test(
    'the full-list path keeps its existing acceptance error reporting',
    () async {
      final b = _Binding();
      b.beforeAccept = () => throw StateError('receiver failed');
      final pending = b.repository.refreshChannels();
      expect(b.client.lists, hasLength(2));
      b.client.lists[0].complete([_row('held')]);
      b.client.lists[1].complete([]);
      await pending;
      expect(b.effects, ['accept', 'error']);
    },
  );
}
