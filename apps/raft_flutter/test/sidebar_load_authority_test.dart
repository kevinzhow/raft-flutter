import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final pending = Completer<dynamic>();
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      pending.future;
}

void main() {
  test(
    'same-generation role change rejects pending private sidebar metadata',
    () async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      final read = w.loadSidebar();
      await Future<void>.delayed(Duration.zero);
      w.server = RaftRecord({'id': 's', 'role': 'member'});
      w.sidebarOrder = {
        'customSections': [
          {'id': 'public', 'name': 'Current permitted section'},
        ],
      };
      client.pending.complete({
        'customSections': [
          {'id': 'private', 'name': 'Private old section'},
        ],
      });
      await read;
      expect((w.sidebarOrder['customSections'] as List).single['id'], 'public');
      w.dispose();
    },
  );
}
