import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/channel_revocation.dart';
import 'package:raft_flutter/data/session_scope.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

WorkspaceController _workspace({
  Future<void> Function(String, String, String, String?)? discard,
}) {
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({'id': 'alice'});
  client.selectServer('s1');
  final w = WorkspaceController(
    client,
    ownsClient: false,
    discardSharedScope: discard,
  )..server = RaftRecord({'id': 's1', 'role': 'owner'});
  addTearDown(() async {
    await w.flushCache();
    w.dispose();
    await client.dispose();
  });
  return w;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('channel phases are synchronous and follow their named order', () {
    final w = _workspace(), trace = <String>[];
    for (final stage in ChannelRevocationStage.values.reversed) {
      w.sessionScope.onChannelRevoked(stage, (_) => trace.add(stage.name));
    }
    w.messageDomain.rejectHistoryRead('c1');
    trace.add('returned');
    expect(trace, [
      'scopes',
      'parents',
      'projection',
      'readState',
      'device',
      'returned',
    ]);
  });

  test('channel listener removal during dispatch takes effect next time', () {
    final w = _workspace(), trace = <String>[];
    late void Function() remove;
    w.sessionScope.onChannelRevoked(ChannelRevocationStage.scopes, (_) {
      remove();
    });
    remove = w.sessionScope.onChannelRevoked(
      ChannelRevocationStage.device,
      (_) => trace.add('device'),
    );
    w.messageDomain.rejectHistoryRead('c1');
    w.messageDomain.rejectHistoryRead('c1');
    expect(trace, ['device']);
  });

  test('channel handler error propagates and stops subsequent phases', () {
    final w = _workspace(), error = StateError('Fixture listener failed');
    var device = false;
    w.sessionScope.onChannelRevoked(
      ChannelRevocationStage.scopes,
      (_) => throw error,
    );
    w.sessionScope.onChannelRevoked(
      ChannelRevocationStage.device,
      (_) => device = true,
    );
    expect(() => w.messageDomain.rejectHistoryRead('c1'), throwsA(same(error)));
    expect(device, isFalse);
  });

  test('sharing runs before discovery with the original identity captured', () {
    late WorkspaceController w;
    late int generation;
    ChannelRevocation? captured;
    w = _workspace(
      discard: (origin, principal, server, channel) async {
        expect(
          (origin, principal, server, channel),
          ('https://example.invalid', 'alice', 's1', 'c1'),
        );
        w.messageDomain.ledger.ingest([
          {
            'id': 'late-parent',
            'channelId': 'c1',
            'seq': '1',
            'threadChannelId': 'late-thread',
          },
        ], expectedGeneration: w.messageDomain.ledger.generation);
        w.client.user = RaftRecord({'id': 'bob'});
        w.client.selectServer('s2');
      },
    );
    w.messageDomain.ledger.switchServer('s1');
    generation = w.client.generation;
    w.sessionScope.onChannelRevoked(
      ChannelRevocationStage.device,
      (event) => captured = event,
    );
    w.messageDomain.rejectHistoryRead('c1');
    final event = captured!;
    expect(
      (event.origin, event.principal, event.serverId, event.generation),
      ('https://example.invalid', 'alice', 's1', generation),
    );
    expect(event.plan.messageIds, {'late-parent'});
    expect(event.plan.scopes, {'c1', 'late-thread'});
    expect(() => event.plan.threadIds.add('mutable'), throwsUnsupportedError);
  });

  test('channel bindings are receiver-local and disposed separately', () {
    final first = _workspace(), second = _workspace();
    var runs = 0;
    second.sessionScope.onChannelRevoked(
      ChannelRevocationStage.device,
      (_) => runs++,
    );
    first.sessionScope.dispose();
    expect(
      () => first.sessionScope.onChannelRevoked(
        ChannelRevocationStage.scopes,
        (_) {},
      ),
      throwsStateError,
    );
    second.messageDomain.rejectHistoryRead('c1');
    expect(runs, 1);
  });
}
