// Web HostedCindyFailedBanner: a cloud Cindy that could not start says so in
// her DM and offers the computer path; the state is read again every minute.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_dm_header.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
  }
  Object? setup = 'failed';
  final calls = <String>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
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
    calls.add('$method $path');
    if (path == '/agents/cindy-1/hosted-runtime') {
      final out = setup;
      if (out is Exception) throw out;
      return {'onboardingSetup': out};
    }
    if (path.endsWith('/machines')) return {'machines': <Object>[]};
    throw RaftApiException('Not found: $path', status: 404);
  }
}

const _cindy = <String, dynamic>{
  'id': 'cindy-1',
  'name': 'Cindy',
  'displayName': 'Cindy',
  'status': 'active',
  'runtime': 'external',
  'external': true,
};

void main() {
  late _Client c;
  late WorkspaceController w;

  Future<void> mount(
    WidgetTester t, {
    Map<String, dynamic> agent = _cindy,
    String? onboarding = 'cindy-1',
  }) async {
    c = _Client()..selectServer('s');
    w = WorkspaceController(c)
      ..server = RaftRecord({
        'id': 's',
        'role': 'owner',
        'onboardingAgentId': ?onboarding,
      });
    final client = c, controller = w;
    addTearDown(() async {
      controller.dispose();
      await client.stream.close();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: WorkspaceDmHeader(
            headerKey: const Key('header'),
            controller: w,
            channel: RaftChannel({
              'id': 'dm1',
              'type': 'dm',
              'peerId': 'cindy-1',
            }),
            agent: true,
            name: 'Cindy',
            profile: agent,
            avatar: const SizedBox(),
            selectionActive: () => false,
            onSearch: () {},
            onSettings: () {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  const text =
      "Cindy couldn't start in the cloud. Connect a computer to run her there instead.";

  testWidgets('a failed cloud Cindy says so and offers a computer', (t) async {
    await mount(t);
    expect(find.text(text), findsOneWidget);
    expect(find.text('Connect a computer'), findsOneWidget);
    expect(find.byKey(const Key('header')), findsOneWidget);
  });

  testWidgets('usable, still starting or unreadable shows no banner', (
    t,
  ) async {
    for (final setup in <Object?>[
      'usable',
      null,
      RaftApiException('forbidden', status: 403),
    ]) {
      await mount(t);
      c.setup = setup;
      await t.pump(hostedRecheck);
      await t.pumpAndSettle();
      expect(find.text(text), findsNothing, reason: '$setup');
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('it reads again every minute and follows the server', (t) async {
    await mount(t);
    c.setup = 'usable';
    await t.pump(const Duration(seconds: 59));
    expect(find.text(text), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.text(text), findsNothing);
    final reads = c.calls.length;
    await t.pump(const Duration(minutes: 3));
    expect(c.calls.length, greaterThan(reads), reason: 'it keeps watching');
  });

  testWidgets('only the onboarding agent without a computer is asked', (
    t,
  ) async {
    await mount(t, onboarding: 'someone-else');
    expect(c.calls, isEmpty);
    expect(find.text(text), findsNothing);
    await t.pumpWidget(const SizedBox());
    await mount(t, agent: {..._cindy, 'machineId': 'm1'});
    expect(c.calls, isEmpty);
    await t.pumpWidget(const SizedBox());
    await mount(t, agent: {..._cindy, 'external': false});
    expect(c.calls, isEmpty);
  });

  testWidgets('Connect a computer opens the Cindy setup', (t) async {
    t.view.physicalSize = const Size(1280, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await mount(t);
    await t.tap(find.text('Connect a computer'));
    await t.pumpAndSettle();
    expect(find.textContaining('Cindy runs on your computer'), findsOneWidget);
  });
}

const hostedRecheck = Duration(seconds: 60);
