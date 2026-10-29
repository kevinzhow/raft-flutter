import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/session_scope.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

WorkspaceController _workspace() {
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
  );
  client.user = RaftRecord({'id': 'alice'});
  client.selectServer('s1');
  final w = WorkspaceController(client, ownsClient: false)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await client.dispose();
  });
  return w;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('named phases run synchronously regardless of registration order', () {
    final w = _workspace();
    final trace = <String>[];
    w.sessionScope.onReset(ServerResetStage.messages, (_) => trace.add('last'));
    w.sessionScope.onReset(
      ServerResetStage.projection,
      (_) => trace.add('first'),
    );
    w.sessionScope.onReset(
      ServerResetStage.readState,
      (_) => trace.add('middle'),
    );
    w.sessionScope.resetServer('s2');
    trace.add('returned');
    expect(trace, ['first', 'middle', 'last', 'returned']);
  });

  test('unbinding during dispatch changes the next dispatch only', () {
    final w = _workspace();
    final trace = <String>[];
    late void Function() remove;
    w.sessionScope.onReset(ServerResetStage.projection, (_) {
      trace.add('remove');
      remove();
    });
    remove = w.sessionScope.onReset(
      ServerResetStage.messages,
      (_) => trace.add('last'),
    );
    w.sessionScope.resetServer('s1');
    w.sessionScope.resetServer('s1');
    expect(trace, ['remove', 'last', 'remove']);
  });

  test('listener exceptions propagate without running later phases', () {
    final w = _workspace();
    var later = false;
    final error = StateError('Fixture listener failed');
    w.sessionScope.onReset(ServerResetStage.projection, (_) => throw error);
    w.sessionScope.onReset(ServerResetStage.messages, (_) => later = true);
    expect(() => w.sessionScope.resetServer(null), throwsA(same(error)));
    expect(later, isFalse);
  });

  test(
    'revocation events preserve identity captured before listener changes',
    () {
      final w = _workspace();
      final generation = w.client.generation;
      ServerRevocation? captured;
      w.sessionScope.onServerRevoked(ServerRevocationStage.sharing, (_) {
        w.client.user = RaftRecord({'id': 'bob'});
        w.client.selectServer('s3');
      });
      w.sessionScope.onServerRevoked(ServerRevocationStage.device, (event) {
        captured = event;
      });
      w.revokeServer('s2');
      expect(captured?.origin, 'https://example.invalid');
      expect(captured?.principal, 'alice');
      expect(captured?.serverId, 's2');
      expect(captured?.generation, generation);
      expect(w.client.user?.id, 'bob');
      expect(w.client.serverId, 's3');
    },
  );

  test('disposing one binding leaves another receiver registered', () {
    final first = _workspace(), second = _workspace();
    var ran = false;
    second.sessionScope.onReset(ServerResetStage.messages, (_) => ran = true);
    first.dispose();
    expect(
      () => first.sessionScope.onReset(ServerResetStage.messages, (_) {}),
      throwsStateError,
    );
    second.sessionScope.resetServer(null);
    expect(ran, isTrue);
  });
}
