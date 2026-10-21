// Shared by public_server_settings_test.dart and public_server_panels_test.dart:
// a public server page mounted for a signed-out visitor or for a signed-in
// non-member (an account whose workspace has no current server).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/public_server_settings.dart';
import 'package:raft_flutter/features/public_server_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../announcement_host_test.dart' as host;

const publicBase = '/public/servers/raft-design';
const publicServer = {
  'id': 's',
  'name': 'Raft Design',
  'slug': 'raft-design',
  'avatarUrl': null,
};

class PublicClient extends RaftClient {
  PublicClient({Map<String, dynamic>? user})
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    if (user != null) this.user = RaftRecord(user);
  }
  @override
  void connect() {}
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
  }) async {
    if (method == 'GET' && path == publicBase) {
      return {
        'server': publicServer,
        'channels': [
          {'id': 'c1', 'name': 'general', 'description': null},
        ],
        'canJoinAsGuest': true,
      };
    }
    if (method == 'GET' && path == '$publicBase/channels/c1/messages') {
      return {
        'messages': [
          {
            'id': 'm1',
            'senderType': 'user',
            'sender': {'displayName': 'Wenyi', 'avatarUrl': null},
            'messageType': 'chat',
            'content': 'Hello',
            'createdAt': '2026-06-18T09:12:00.000Z',
            'threadId': 't1',
            'replyCount': 1,
          },
        ],
      };
    }
    if (method == 'GET' && path == '$publicBase/threads/t1/messages') {
      return {'messages': const []};
    }
    throw RaftApiException('Not found', status: 404);
  }
}

/// A visitor signed in to an account that is not a member of the server.
PublicServerAccount nonMemberAccount() {
  final f = host.Fixture();
  // The workspace has no current server: the visitor is a non-member.
  return PublicServerAccount(
    servers: const [],
    onSelect: (_) {},
    settings: PublicSettingsAccount(
      controller: f.w,
      appearance: const RaftAppearance(),
      onAppearance: (_) {},
    ),
  );
}

Future<void> mountPublicServer(
  WidgetTester t, {
  PublicServerAccount? account,
  Size size = const Size(1280, 800),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: PublicServerView(
          client: PublicClient(user: account == null ? null : {'id': 'u1'}),
          slug: 'raft-design',
          account: account,
          onSignIn: () {},
          onRegister: () {},
          onUnavailable: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> openPublicSettings(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('public-rail-settings')));
  await t.pumpAndSettle();
}
