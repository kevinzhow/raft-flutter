import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/member_profile_view.dart';

import 'workspace_entity_directory_test.dart' show agent, computer, member;

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  int disposed = 0;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<void> dispose() async {
    disposed++;
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  bool hold = false;
  final pending = <String, List<Completer<dynamic>>>{};
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (hold) {
      final response = Completer<dynamic>();
      pending.putIfAbsent(path, () => []).add(response);
      return response.future;
    }
    return switch (path) {
      '/agents' => [agent],
      '/servers/s/machines' => {
        'machines': [computer],
      },
      '/servers/s/members' => [member],
      '/agents/a' => agent,
      '/servers/s/members/u/profile' => {
        ...member,
        'description': 'Source detail description',
      },
      _ => [],
    };
  }
}

void main() {
  late _Client client;
  late _Workspace w;
  setUp(() {
    client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s');
    w = _Workspace(client)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  Future<void> host(
    WidgetTester t,
    Widget child,
    RaftFamily family,
    bool dark,
  ) => t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: Scaffold(body: child),
    ),
  );
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final kind in ['agent', 'computer', 'human']) {
      Widget detail(VoidCallback onBack) => kind == 'human'
          ? MemberProfileView(
              controller: w,
              userId: 'u',
              onClose: onBack,
              onBack: onBack,
            )
          : FleetDetail(
              controller: w,
              computers: kind == 'computer',
              initial: {'id': kind == 'computer' ? 'c' : 'a'},
              onClose: onBack,
            );
      final expected = kind == 'agent'
          ? 'Source Agent'
          : kind == 'computer'
          ? 'Source Computer'
          : 'Source Human';
      testWidgets(
        '$family/$dark $kind shows accepted real directory on first frame while HTTP waits',
        (t) async {
          await w.entityDirectory.preload();
          w.hold = true;
          await host(t, detail(() {}), family, dark);
          expect(find.text(expected), findsWidgets);
          expect(find.text('Loading...'), findsNothing);
          expect(find.text('null'), findsNothing);
          expect(w.pending, isNotEmpty);
          expect(t.takeException(), isNull);
        },
      );
      testWidgets(
        '$family/$dark cold $kind uses Source loading shell with working back and no invented facts',
        (t) async {
          w.hold = true;
          var back = 0;
          await host(t, detail(() => back++), family, dark);
          expect(find.text('Loading...'), findsOneWidget);
          expect(find.text(expected), findsNothing);
          expect(find.byType(RaftProfileIdentity), findsNothing);
          for (final invented in ['Default', 'offline', 'Unassigned', 'null']) {
            expect(find.text(invented), findsNothing);
          }
          final height = t.getSize(find.byType(RaftPanelHeaderBar)).height;
          await t.tap(find.byTooltip('Back'));
          expect(back, 1);
          if (kind == 'human') {
            w.pending['/servers/s/members/u/profile']!.single.complete(member);
          } else if (kind == 'computer') {
            w.pending['/servers/s/machines']!.single.complete([computer]);
          } else {
            w.pending['/agents/a']!.single.complete(agent);
            w.pending['/servers/s/machines']!.single.complete([computer]);
          }
          await t.pump();
          expect(find.text(expected), findsWidgets);
          if (kind != 'computer') {
            expect(t.getSize(find.byType(RaftPanelHeaderBar)).height, height);
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'Source live member name and role override fallback while detail-only fields hydrate',
    (t) async {
      await w.entityDirectory.preload();
      w.hold = true;
      await host(
        t,
        MemberProfileView(controller: w, userId: 'u', onClose: () {}),
        RaftFamily.brutal,
        false,
      );
      w.pending['/servers/s/members/u/profile']!.single.complete({
        ...member,
        'name': 'stale fallback',
        'role': 'guest',
        'description': 'Actual accepted description',
      });
      await t.pump();
      expect(find.text('Source Human'), findsWidgets);
      expect(find.text('stale fallback'), findsNothing);
      expect(find.text('Actual accepted description'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
    },
  );
  testWidgets(
    'cold failure shows explicit error shell; refresh failure preserves accepted identity',
    (t) async {
      w.hold = true;
      await host(
        t,
        MemberProfileView(controller: w, userId: 'u', onClose: () {}),
        RaftFamily.brutal,
        false,
      );
      w.pending['/servers/s/members/u/profile']!.single.completeError(
        StateError('failed'),
      );
      await t.pump();
      expect(find.text('Profile could not be loaded.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      w.hold = false;
      await w.entityDirectory.preload();
      w.hold = true;
      await host(
        t,
        MemberProfileView(controller: w, userId: 'u', onClose: () {}),
        RaftFamily.brutal,
        false,
      );
      w.pending['/servers/s/members/u/profile']!.last.completeError(
        StateError('refresh failed'),
      );
      await t.pump();
      expect(find.text('Source Human'), findsWidgets);
      expect(find.text('Profile unavailable'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'same-generation revoked membership removes cached identity and rejects late detail response',
    (t) async {
      await w.entityDirectory.preload();
      w.hold = true;
      await host(
        t,
        MemberProfileView(controller: w, userId: 'u', onClose: () {}),
        RaftFamily.brutal,
        false,
      );
      expect(find.text('Source Human'), findsWidgets);
      final old = w.pending['/servers/s/members/u/profile']!.single;
      final generation = client.generation;
      w.server = RaftRecord({'id': 's', 'role': 'guest'});
      w.notifyListeners();
      await t.pump();
      expect(client.generation, generation);
      expect(find.text('Source Human'), findsNothing);
      old.complete(member);
      await t.pump();
      expect(find.text('Source Human'), findsNothing);
      expect(w.entityDirectory.member('u'), isNull);
    },
  );
  testWidgets('directory row delegates an accepted record to URI navigation', (
    t,
  ) async {
    await w.entityDirectory.preload();
    Map<String, dynamic>? opened;
    await host(
      t,
      FleetView(
        controller: w,
        computers: false,
        onOpenDetail: (row) => opened = row,
      ),
      RaftFamily.brutal,
      false,
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('fleet-a')));
    expect(opened, agent);
    expect(find.byType(FleetDetail), findsNothing);
  });
  testWidgets(
    'accepted Agent tab and real input focus survive directory refresh',
    (t) async {
      await w.entityDirectory.preload();
      w.hold = true;
      final inputFocus = FocusNode();
      addTearDown(inputFocus.dispose);
      await host(
        t,
        Column(
          children: [
            TextField(focusNode: inputFocus),
            Expanded(
              child: FleetDetail(
                controller: w,
                computers: false,
                initial: const {'id': 'a'},
                onClose: () {},
              ),
            ),
          ],
        ),
        RaftFamily.elegant,
        true,
      );
      await t.tap(find.text('Activity'));
      inputFocus.requestFocus();
      await t.pump();
      expect(inputFocus.hasFocus, isTrue);
      final strip = find.byType(RaftPanelTabBar<AgentDetailTab>);
      expect(
        t.widget<RaftPanelTabBar<AgentDetailTab>>(strip).value,
        AgentDetailTab.activity,
      );
      final before = t.getRect(strip);
      final focus = FocusManager.instance.primaryFocus;
      final pending = w.entityDirectory.refresh(WorkspaceEntityKind.agents);
      w.pending['/agents']!.single.complete([
        {...agent, 'displayName': 'Accepted new display'},
      ]);
      await pending;
      await t.pump();
      expect(find.text('Accepted new display'), findsWidgets);
      expect(
        t.widget<RaftPanelTabBar<AgentDetailTab>>(strip).value,
        AgentDetailTab.activity,
      );
      expect(t.getRect(strip), before);
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'denied directory retires private member facts and rejects an older pending detail reply',
    (t) async {
      await w.entityDirectory.preload();
      w.hold = true;
      await host(
        t,
        MemberProfileView(controller: w, userId: 'u', onClose: () {}),
        RaftFamily.brutal,
        false,
      );
      final oldDetail = w.pending['/servers/s/members/u/profile']!.single;
      final pending = w.entityDirectory.refresh(WorkspaceEntityKind.members);
      w.pending['/servers/s/members']!.single.completeError(
        const RaftApiException('Denied', status: 403),
      );
      await pending;
      await t.pump();
      expect(find.text('Source Human'), findsNothing);
      oldDetail.complete({...member, 'description': 'Private delayed bytes'});
      await t.pump();
      expect(find.text('Private delayed bytes'), findsNothing);
      expect(find.text('Source Human'), findsNothing);
      expect(find.text('Profile could not be loaded.'), findsOneWidget);
    },
  );
  test(
    'borrowed editor disposal preserves shared directory and main connection',
    () async {
      await w.entityDirectory.preload();
      final borrowed = WorkspaceController(
        client,
        ownsClient: false,
        entityDirectory: w.entityDirectory,
      )..server = w.server;
      borrowed.server = null;
      borrowed.notifyListeners();
      borrowed.dispose();
      expect(w.entityDirectory.agent('a'), agent);
      expect(client.disposed, 0);
    },
  );
}
