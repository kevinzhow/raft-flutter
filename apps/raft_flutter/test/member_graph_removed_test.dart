import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';

// Server v1.24.0 removed GET /servers/:id/member-graph and Web 1.24 deleted
// MemberGraphSection; `/members/graph` is now LegacyMemberGraphRedirect to
// the Members page (components/layout/LegacyRedirects.tsx). The Members list
// has no Graph entry and nothing requests the removed route.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
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
    return [];
  }
}

void main() {
  testWidgets('the desktop Members directory has no Graph entry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _Client()..selectServer('s');
    final w = WorkspaceController(c)
      ..server = RaftRecord({
        'id': 's',
        'slug': 'fixture',
        'name': 'Fixture',
        'role': 'owner',
      });
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: DesktopDirectoryView(controller: w, onSelected: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-directory-graph')), findsNothing);
    expect(find.text('Graph'), findsNothing);
    expect(
      DesktopContentKind.values.map((k) => k.name),
      isNot(contains('graph')),
    );
    expect(c.calls.where((c) => c.contains('member-graph')), isEmpty);
  });

  testWidgets('the phone Members tab has no Graph row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _Client()..selectServer('s');
    final w = WorkspaceController(c, mobileNavigation: true)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
    w.setSection('members');
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(mode: ThemeMode.light),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-directory-graph')), findsNothing);
    expect(find.text('Graph'), findsNothing);
    expect(c.calls.where((c) => c.contains('member-graph')), isEmpty);
  });

  test('the old /members/graph location is folded into /members', () {
    expect(
      RaftLocation.canonicalLegacy(
        Uri.parse('/s/fixture/members/graph?keep=one'),
      ).toString(),
      '/s/fixture/members?keep=one',
    );
    expect(RaftRoute.values.map((r) => r.name), isNot(contains('memberGraph')));
  });
}
