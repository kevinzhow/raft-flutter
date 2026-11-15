// Web v1.24.0 useSecondFactorRecoveryNotification.tsx: Cancel reset is
// `disabled: busy` while its request runs, so a second press sends nothing;
// a failure leaves the entry with Cancel reset ready again.
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

  /// The cancel answers when the test completes it.
  Completer<void> answer = Completer<void>();
  bool fail = false;

  @override
  Future<dynamic> delete(String path, {dynamic data}) async {
    deletes.add(path);
    await answer.future;
    if (fail) throw const RaftApiException('unavailable', status: 503);
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

  Future<_Client> openCenter(WidgetTester t) async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'member'});
    await t.binding.setSurfaceSize(const Size(400, 500));
    addTearDown(() async {
      if (!client.answer.isCompleted) client.answer.complete();
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
    await t.tap(find.byType(RaftMobileNotificationButton));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Cancel reset'), findsOneWidget);
    return client;
  }

  bool cancelEnabled(WidgetTester t) =>
      t
          .widget<RaftControl>(
            find.byWidgetPredicate(
              (w) =>
                  w is RaftControl &&
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.endsWith('-Cancel reset'),
            ),
          )
          .onPressed !=
      null;

  testWidgets('a second press while the cancel runs sends nothing', (t) async {
    final client = await openCenter(t);
    await t.tap(find.text('Cancel reset'));
    await t.pump();
    expect(cancelEnabled(t), isFalse);
    await t.tap(find.text('Cancel reset'), warnIfMissed: false);
    await t.pump();
    expect(client.deletes, ['/auth/second-factor/recovery']);
    client.answer.complete();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(client.deletes, hasLength(1));
    expect(find.text('Reset requested'), findsNothing);
  });

  testWidgets('a failed cancel keeps the entry and Cancel reset works again', (
    t,
  ) async {
    final client = await openCenter(t)
      ..fail = true;
    await t.tap(find.text('Cancel reset'));
    await t.pump();
    expect(cancelEnabled(t), isFalse);
    client.answer.complete();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Reset requested'), findsOneWidget);
    expect(cancelEnabled(t), isTrue);
    expect(client.deletes, hasLength(1));
  });
}
