import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/archived_agents_section.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

Map<String, dynamic> _entry(
  String id,
  String name, {
  String? displayName,
  String state = 'on_computer',
  String? pendingOp,
  String archivedAt = '2026-10-20T09:00:00.000Z',
}) => {
  'agentId': id,
  'name': name,
  'displayName': displayName,
  'avatarUrl': null,
  'archivedAt': archivedAt,
  'archivedByUserId': 'alice',
  'workspaceState': state,
  'pendingOp': pendingOp,
  'machineName': state == 'on_computer' ? 'Studio Mac' : null,
};

class _Fixture {
  _Fixture({this.fail = false}) {
    client = ScreenFixtureClient(
      (method, path, query) {
        if (path == '/agents/archived') {
          requests++;
          if (fail) throw const RaftApiException('boom', status: 500);
          return {'agents': rows};
        }
        return <String, dynamic>{};
      },
      user: {'id': 'alice', 'preferredTimezone': 'UTC'},
      server: 's',
    );
    w = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 's',
        'name': 'S',
        'slug': 's',
        'role': 'member',
      });
    addTearDown(w.dispose);
  }
  final bool fail;
  int requests = 0;
  late final ScreenFixtureClient client;
  late final WorkspaceController w;
  List<Map<String, dynamic>> rows = [
    _entry('a1', 'kept', displayName: 'Kept Agent'),
    _entry('a2', 'gone', state: 'deleted'),
    _entry('a3', 'busy', state: 'on_computer', pendingOp: 'delete'),
    _entry('a4', 'lost', state: 'unknown'),
  ];

  Future<void> mount(WidgetTester t, {double width = 1000}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 900);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArchivedAgentsSection(controller: w),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }
}

void main() {
  testWidgets('lists archived agents with where the workspace is', (t) async {
    final f = _Fixture();
    await f.mount(t);
    final header = t.widget<RaftSettingsSectionHeader>(
      find.byType(RaftSettingsSectionHeader),
    );
    expect(header.label, 'Archived agents');
    expect(header.count, 4);
    expect(find.text('Kept Agent'), findsOneWidget);
    expect(find.textContaining('Workspace on Studio Mac'), findsOneWidget);
    expect(find.textContaining('Workspace deleted'), findsOneWidget);
    expect(find.textContaining('Deleting workspace…'), findsOneWidget);
    expect(find.textContaining('Workspace location unknown'), findsOneWidget);
    expect(find.textContaining('Archived Oct 20, 2026'), findsWidgets);
  });

  testWidgets(
    'View workspace shows only while the workspace is on the Computer',
    (t) async {
      final f = _Fixture();
      await f.mount(t);
      // `workspaceState === on_computer` (a pending delete still lists it, as Web).
      expect(
        find.byKey(const ValueKey('archived-agent-workspace-a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('archived-agent-workspace-a2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('archived-agent-workspace-a4')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the name opens the read-only profile and View workspace its workspace tab',
    (t) async {
      final f = _Fixture();
      await f.mount(t);
      await t.tap(find.byKey(const ValueKey('archived-agent-open-a2')));
      await t.pump();
      expect(f.w.location.query('profile'), isNotNull);
      expect(f.w.location.query('profile'), contains('a2'));

      await t.tap(find.byKey(const ValueKey('archived-agent-workspace-a1')));
      await t.pump();
      expect(f.w.location.query('profile'), contains('a1'));
      expect(f.w.location.query('agentTab'), 'workspace');
    },
  );

  testWidgets('nothing archived, or a failed read, shows nothing', (t) async {
    final empty = _Fixture()..rows = [];
    await empty.mount(t);
    expect(find.byType(RaftSettingsSectionHeader), findsNothing);
    await t.pumpWidget(const SizedBox());

    final failing = _Fixture(fail: true);
    await failing.mount(t);
    expect(find.byType(RaftSettingsSectionHeader), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('an archive push re-reads the list', (t) async {
    final f = _Fixture();
    f.rows = [];
    await f.mount(t);
    expect(find.byType(RaftSettingsSectionHeader), findsNothing);
    f.rows = [_entry('a9', 'fresh', displayName: 'Fresh')];
    f.client.emit(const RaftEvent('agent:deleted', {'agentId': 'a9'}));
    await t.pumpAndSettle();
    expect(find.text('Fresh'), findsOneWidget);
    expect(f.requests, 2);
    f.rows = [];
    f.client.emit(const RaftEvent('agent:archive:updated', {'agentId': 'a9'}));
    await t.pumpAndSettle();
    expect(find.byType(RaftSettingsSectionHeader), findsNothing);
  });
}
