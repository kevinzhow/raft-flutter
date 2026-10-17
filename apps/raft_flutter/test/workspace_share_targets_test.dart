import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/data/workspace_share_targets.dart';

RaftRecord _server(String id) => RaftRecord({'id': id, 'role': 'owner'});
RaftChannel _channel(String id) =>
    RaftChannel({'id': id, 'name': id, 'type': 'channel', 'joined': true});

void main() {
  test('selected server uses live rows and peers without reading or selecting another server', () async {
    var selected = _server('s');
    var channels = [_channel('first')];
    final trace = <String>[];
    final reads = WorkspaceShareTargets(
      selectedServer: () => selected,
      channels: () => channels,
      dms: () => [],
      peerRows: (kind) => kind == WorkspaceEntityKind.members
          ? [
              {'userId': 'self', 'name': 'Self'},
              {'userId': 'peer', 'name': 'Peer'},
            ]
          : [],
      selfId: () => 'self',
      cachedChannelDirectory: (id) async {
        trace.add('disk:$id');
        return [];
      },
    );
    expect((await reads.cached(selected))!.map((t) => t.key), [
      'first',
      'user:peer:agent:null',
    ]);
    channels = [_channel('second')];
    selected = _server('s');
    expect((await reads.cached(selected))!.first.channel?.id, 'second');
    expect(trace, isEmpty);
  });

  test(
    'other-server seed reads the current principal only after the disk result',
    () async {
      final disk = Completer<List<RaftChannel>?>();
      var principal = 'before';
      final trace = <String>[];
      final reads = WorkspaceShareTargets(
        selectedServer: () => _server('s'),
        channels: () => throw StateError('must not read the selected list'),
        dms: () => throw StateError('must not read the selected DMs'),
        peerRows: (_) =>
            throw StateError('must not read selected-server peers'),
        selfId: () {
          trace.add('self:$principal');
          return principal;
        },
        cachedChannelDirectory: (id) {
          trace.add('disk:$id');
          return disk.future;
        },
      );
      final seed = reads.cached(_server('other'));
      expect(trace, ['disk:other']);
      principal = 'after';
      disk.complete([_channel('cached')]);
      expect((await seed)!.single.channel?.id, 'cached');
      expect(trace, ['disk:other', 'self:after']);
    },
  );

  test(
    'empty selected rows return no seed and never consult peers or disk',
    () {
      final reads = WorkspaceShareTargets(
        selectedServer: () => _server('s'),
        channels: () => [],
        dms: () => [],
        peerRows: (_) => throw StateError('no channel seed'),
        selfId: () => throw StateError('no channel seed'),
        cachedChannelDirectory: (_) => throw StateError('selected server'),
      );
      expect(reads.cached(_server('s')), isNull);
    },
  );

  test(
    'empty disk results do not read principal and disk failures stay failures',
    () async {
      Object? failure;
      final reads = WorkspaceShareTargets(
        selectedServer: () => null,
        channels: () => [],
        dms: () => [],
        peerRows: (_) => [],
        selfId: () => throw StateError('no cached rows'),
        cachedChannelDirectory: (_) async {
        if (failure != null) throw failure;
          return null;
        },
      );
      expect(await reads.cached(_server('other')), isNull);
      failure = StateError('disk unavailable');
      await expectLater(reads.cached(_server('other')), throwsA(same(failure)));
    },
  );
}
