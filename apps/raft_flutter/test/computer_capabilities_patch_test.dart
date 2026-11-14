import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      <dynamic>[];
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      switch (path) {
        '/servers/s/machines' => {
          'machines': [
            {
              'id': 'c',
              'name': 'Studio',
              'isComputer': true,
              'status': 'online',
              'computerVersion': '1.0.46',
              'versionGate': {
                'reason': 'computer_version_unsupported',
                'minVersion': '1.0.47',
                'enforced': false,
              },
            },
          ],
        },
        _ => <dynamic>[],
      };
}

void main() {
  test('machine:capabilities patches the host facts and the floor verdict', () async {
    final client = _Client();
    final w = _Workspace(client)..server = RaftRecord({'id': 's', 'role': 'owner'});
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await w.entityDirectory.preload();
    Map<String, dynamic> row() => w.entityDirectory.computer('c')!;
    expect(row()['versionGate'], isNotNull);
    client.stream.add(
      const RaftEvent('machine:capabilities', {
        'machineId': 'c',
        'hostProvider': 'aws',
        'osRelease': '24.04',
        'deviceClass': 'server',
        'computerVersion': '1.0.47',
        // The Computer upgraded: the server clears the verdict.
        'versionGate': null,
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(row()['hostProvider'], 'aws');
    expect(row()['osRelease'], '24.04');
    expect(row()['deviceClass'], 'server');
    expect(row()['computerVersion'], '1.0.47');
    expect(row().containsKey('versionGate'), isTrue);
    expect(row()['versionGate'], isNull);
    w.entityDirectory.dispose();
  });

  test('a low disk is said with the whole, in decimal units', () {
    final low = {
      'status': 'online',
      'diskStatus': {'availableBytes': 4200000000, 'totalBytes': 460000000000},
    };
    expect(computerDiskLow(low), ('4.2 GB', '460.0 GB'));
    expect(
      computerDiskLow({
        ...low,
        'diskStatus': {'availableBytes': 90e9, 'totalBytes': 460e9},
      }),
      isNull,
    );
    expect(computerDiskLow({...low, 'status': 'offline'}), isNull);
  });
}
