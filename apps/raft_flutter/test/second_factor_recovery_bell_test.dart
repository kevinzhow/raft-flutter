// Web v1.24.0 NotificationTrigger + useSecondFactorRecoveryNotification: while
// a two-step reset by email waits, the Bell wears a shield (not the unread
// dot) and says "security alert"; the center lists "Reset requested" first
// with Cancel reset and no Dismiss; cancelling removes both.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    serverId = 's';
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  bool pending = true;
  final deletes = <String>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/auth/second-factor/recovery') {
      return {
        'recovery': pending
            ? {
                'status': 'waiting',
                'requestedAt': '2026-11-10T00:00:00.000Z',
                'eligibleAt': '2026-11-13T00:00:00.000Z',
                'expiresAt': '2026-11-20T00:00:00.000Z',
                'firstFactorRequired': null,
              }
            : null,
      };
    }
    if (path == '/product-feedback/tickets') return {'unread_total': 0};
    return [];
  }

  @override
  Future<dynamic> delete(String path, {dynamic data}) async {
    deletes.add(path);
    pending = false;
    return {'cancelled': true, 'recovery': null};
  }

  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<void> dispose() async {
    await stream.close();
    await super.dispose();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a waiting reset is a security alert with Cancel reset', (
    t,
  ) async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'member'});
    await t.binding.setSurfaceSize(const Size(400, 500));
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      w.dispose();
      await client.dispose();
      await t.binding.setSurfaceSize(null);
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(platform: TargetPlatform.android),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SystemNotificationBell(
              controller: w,
              onBilling: () {},
              mobile: true,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('notification-security-alert')),
      findsOneWidget,
    );
    // The shield replaces the unread dot.
    expect(find.byType(RaftNotificationAttention), findsNothing);
    expect(
      find.bySemanticsLabel('Notification center (1 active), security alert'),
      findsOneWidget,
    );

    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Reset requested'), findsOneWidget);
    expect(find.textContaining('Signing in can finish it after'), findsOne);
    expect(find.text('Cancel reset'), findsOneWidget);
    expect(find.text('Dismiss'), findsNothing);

    await t.tap(find.text('Cancel reset'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(client.deletes, ['/auth/second-factor/recovery']);
    expect(find.text('Reset requested'), findsNothing);
    expect(
      find.byKey(const ValueKey('notification-security-alert')),
      findsNothing,
    );
  });
}
