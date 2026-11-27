import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/feedback_unread.dart';

class _AccountClient extends RaftClient {
  _AccountClient()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );

  final socket = StreamController<RaftEvent>.broadcast(sync: true);
  final reads = <Completer<Object?>>[];
  @override
  Stream<RaftEvent> get events => socket.stream;

  @override
  Future<dynamic> getForAccount(String path, {Map<String, dynamic>? query}) {
    expect(path, '/product-feedback/tickets');
    expect(query, {'limit': 1, 'degraded_ok': 1});
    final read = Completer<Object?>();
    reads.add(read);
    return read.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'FeedbackUnreadState applies only the current account count push',
    () async {
      final client = _AccountClient()
        ..serverId = 'workspace'
        ..user = RaftRecord({'id': 'alice'});
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 'workspace', 'role': 'member'});
      addTearDown(() async {
        workspace.dispose();
        await client.socket.close();
      });

      final unread = FeedbackUnreadState.of(workspace);
      final release = unread.retain();
      addTearDown(release);
      client.reads.single.complete({'unread_total': 1});
      await Future<void>.delayed(Duration.zero);
      client.socket.add(
        const RaftEvent('product_feedback:app_unread', {
          'source': 'android',
          'unreadTotal': 7,
        }),
      );
      client.socket.add(
        const RaftEvent('product_feedback:unread', {
          'userId': 'bob',
          'unreadTotal': 8,
        }),
      );
      expect(unread.count, 1);
      client.socket.add(const RaftEvent('connected', {}));
      final listRead = unread.capture(list: true);
      client.socket.add(
        const RaftEvent('product_feedback:unread', {
          'userId': 'alice',
          'unreadTotal': 3,
        }),
      );
      expect(unread.count, 3);
      client.reads.last.complete({'unread_total': 1});
      listRead(2);
      await Future<void>.delayed(Duration.zero);
      expect(unread.count, 3);
      client.socket.add(const RaftEvent('connected', {}));
      client.reads.last.complete({'unread_total': 4});
      await Future<void>.delayed(Duration.zero);
      expect(unread.count, 4);
    },
  );
}
