// Web v1.21.23 AnnouncementModal: a row whose `deliveryScope` names another
// server is never presented, even when the server handed it out.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/announcement_host.dart';
import 'package:raft_ui/raft_ui.dart';

const _s1 = '11111111-1111-4111-8111-111111111111';
const _s2 = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> _row(String id, Map<String, dynamic> scope) => {
  'id': id,
  'title': 'Title $id',
  'pages': [
    {'body': 'Body'},
  ],
  'publishedAt': '2026-10-01T00:00:00.000Z',
  'startsAt': '2026-10-01T00:00:00.000Z',
  'endsAt': null,
  'locale': 'en',
  'deliveryVersion': 2,
  'deliveryScope': scope,
};

Future<void> _mount(WidgetTester t, String rowServer) async {
  final client = _Client((method, path, query) {
    if (path == '/announcements/active') {
      return {
        'announcements': [
          _row('a1', {'type': 'server', 'serverId': rowServer}),
        ],
      };
    }
    if (path.endsWith('/setup-projection')) return {'phase': null};
    return {'ok': true};
  });
  final w = WorkspaceController(client);
  addTearDown(w.dispose);
  final one = RaftRecord({
    'id': _s1,
    'slug': 'one',
    'name': 'One',
    'role': 'owner',
  });
  client.selectServer(_s1);
  w
    ..servers = [one]
    ..server = one;
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => RaftToastHost(child: child!),
      home: AnnouncementHost(
        controller: w,
        deployment: 'production',
        child: const Scaffold(body: Text('workspace')),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('a row delivered for this server is presented', (t) async {
    await _mount(t, _s1);
    expect(find.byKey(const ValueKey('announcement-modal')), findsOneWidget);
  });

  testWidgets('a row delivered for another server is not presented', (t) async {
    await _mount(t, _s2);
    expect(find.byKey(const ValueKey('announcement-modal')), findsNothing);
    expect(find.text('Title a1'), findsNothing);
  });
}

class _Client extends RaftClient {
  _Client(this.route)
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'u1', 'name': 'Kevin', 'displayName': 'Kevin'});
  }
  final FutureOr<dynamic> Function(String, String, Map<String, dynamic>?) route;
  final _events = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => _events.stream;
  @override
  void connect() {}
  @override
  Future<void> dispose() async => _events.close();
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async => route(method, path, query);
}
