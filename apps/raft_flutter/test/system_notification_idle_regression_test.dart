import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/system_notification_store.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('server');
  }
  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => [];
  @override
  Future<void> dispose() async {
    await bus.close();
    await super.dispose();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(_Client, SystemNotificationStore)> boot(
    WidgetTester tester,
    bool mobile,
  ) async {
    final client = _Client();
    final controller = WorkspaceController(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner', 'plan': 'pro'});
    final store = SystemNotificationStore(
      entities: () => const SystemNotificationEntities(
        machines: [],
        agents: [],
        ready: true,
      ),
      get: (_, {query}) async => {'unread_total': 0},
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await client.dispose();
      store.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Center(
            child: SystemNotificationBell(
              controller: controller,
              onBilling: () {},
              store: store,
              mobile: mobile,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(tester.binding.hasScheduledFrame, isFalse);
    return (client, store);
  }

  for (final mobile in [false, true]) {
    testWidgets('unchanged background notification read is quiet ($mobile)', (
      tester,
    ) async {
      final (_, store) = await boot(tester, mobile);
      await tester.runAsync(store.refresh);
      expect(store.entries, isEmpty);
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'a closed bell has no changed content or loading indicator',
      );
    });

    testWidgets(
      'unrelated message leaves the notification bell quiet ($mobile)',
      (tester) async {
        final (client, store) = await boot(tester, mobile);
        client.bus.add(
          const RaftEvent('message:new', {
            'id': 'plain',
            'channelId': 'elsewhere',
            'seq': '2',
            'content': 'No notification-center fact changed.',
          }),
        );
        expect(store.entries, isEmpty);
        expect(
          tester.binding.hasScheduledFrame,
          isFalse,
          reason: 'message arrival must not redraw an unchanged closed bell',
        );
      },
    );
  }
}
