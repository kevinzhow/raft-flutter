// Web HostedCindyFailedBanner (startVisiblePoll): the poll is paused while the
// page is hidden and one recheck runs when it shows again.
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

  testWidgets('one recheck runs when the app shows again, none while hidden', (
    t,
  ) async {
    await mount(t);
    int reads() => c.calls.where((x) => x.endsWith('/hosted-runtime')).length;
    final before = reads();
    c.setup = 'usable';
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await t.pump(const Duration(minutes: 3));
    expect(reads(), before);
    expect(find.text('Connect a computer'), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(reads(), before + 1);
    expect(find.text('Connect a computer'), findsNothing);
  });
}
