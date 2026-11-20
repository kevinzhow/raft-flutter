import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:raft_flutter/features/composer_directory.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';
import 'package:raft_flutter/features/message_agent_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      <dynamic>[];
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {
    'evaluations': <dynamic>[],
  };
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  void activity(String kind, int seq) => ingress.add(
    RaftEvent('agent:activity', {
      'agentId': 'a',
      'activity': kind,
      'activityKind': kind,
      'detail': '',
      'detailKind': 'other',
      'serverSeq': '$seq',
    }),
  );
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  Map<String, dynamic> row = {
    'id': 'a',
    'name': 'Alpha',
    'status': 'active',
    'runtime': 'codex',
    'model': 'gpt-6',
    'serverId': 's',
    'activity': 'working',
    'activityKind': 'working',
    'activityDetail': 'Running the original work',
    'activityDetailKind': 'other',
  };
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      switch (path) {
        '/agents' => [Map<String, dynamic>.from(row)],
        '/agents/a' => Map<String, dynamic>.from(row),
        '/servers/s/machines' => {'machines': <dynamic>[]},
        _ => <dynamic>[],
      };
}

void main() {
  late _Client c;
  late _Workspace w;
  final directories = <MessageReferenceDirectory>[];
  final presentations = <MessageAgentPresentation>[];
  setUp(() async {
    c = _Client();
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
    await w.entityDirectory.preload();
  });
  tearDown(() async {
    for (final p in presentations) {
      p.dispose();
    }
    presentations.clear();
    for (final d in directories) {
      d.dispose();
    }
    directories.clear();
    w.dispose();
    await c.ingress.close();
    await c.dispose();
  });
  MessageAgentPresentation mountMessageSurface() {
    final directory = MessageReferenceDirectory(w);
    directories.add(directory);
    final presentation = MessageAgentPresentation(w, directory);
    presentations.add(presentation);
    return presentation;
  }

  String listActivity() =>
      agentRowAmbientDisplay(w.entityDirectory.agent('a')!).activity;

  test('one accepted activity updates list and already-open and newly-opened message surfaces', () {
    final open = mountMessageSurface();
    expect(open.display('a')!.activity, 'working');
    c.activity('offline', 20);
    final newlyOpened = mountMessageSurface();
    expect(w.entityDirectory.agent('a')!['activityKind'], 'offline');
    expect(listActivity(), 'offline');
    expect(open.display('a')!.activity, 'offline');
    expect(newlyOpened.display('a')!.activity, 'offline');
  });

  test('a newly-opened surface shares the accepted sequence and ignores an older frame', () {
    c.activity('offline', 20);
    final newlyOpened = mountMessageSurface();
    c.activity('working', 19);
    expect(w.entityDirectory.agent('a')!['activity'], 'offline');
    expect(newlyOpened.display('a')!.activity, 'offline');
    expect(listActivity(), 'offline');
  });

  test('authoritative reconciliation reaches each existing surface without a second socket frame', () async {
    final open = mountMessageSurface();
    c.activity('offline', 20);
    w.row = {...w.row, 'activity': 'thinking', 'activityKind': 'thinking'};
    await w.entityDirectory.refresh(WorkspaceEntityKind.agents);
    expect(listActivity(), 'thinking');
    expect(open.display('a')!.activity, 'thinking');
    expect(mountMessageSurface().display('a')!.activity, 'thinking');
  });
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'mounted sidebar, detail and mention avatars share reconciliation $dark',
      (t) async {
        await t.binding.setSurfaceSize(const Size(1800, 1400));
        addTearDown(() => t.binding.setSurfaceSize(null));
        w.channel = RaftChannel({
          'id': 'd',
          'serverId': 's',
          'type': 'dm',
          'joined': true,
        });
        final presentation = mountMessageSurface();
        final composer = ComposerDirectory(w, agentPresentation: presentation);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          composer.dispose();
        });
        composer.request('@');
        bool lateSidebar = false;
        late StateSetter rebuild;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return Row(
                    children: [
                      Expanded(
                        child: DesktopDirectoryView(
                          key: const Key('presence-sidebar'),
                          controller: w,
                          onSelected: (_) {},
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: FleetDetail(
                          key: const Key('profile'),
                          controller: w,
                          computers: false,
                          initial: w.row,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              key: const Key('presence-mentions'),
                              animation: composer,
                              builder: (_, _) => Column(
                                children: [
                                  for (final candidate in composer.people)
                                    candidate.avatar!,
                                ],
                              ),
                            ),
                            if (lateSidebar)
                              Expanded(
                                child: DesktopDirectoryView(
                                  key: const Key('late-sidebar'),
                                  controller: w,
                                  onSelected: (_) {},
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        void expectPresence(RaftAvatarActivity expected, String profileText) {
          final offline = expected == RaftAvatarActivity.offline;
          for (final key in [
            const Key('presence-sidebar'),
            const Key('presence-mentions'),
            if (lateSidebar) const Key('late-sidebar'),
          ]) {
            final avatar = find.descendant(
              of: find.byKey(key),
              matching: find.byType(RaftMountedAvatarFrame),
            );
            expect(avatar, findsOneWidget, reason: '$key agent avatar');
            expect(
              t.widget<RaftMountedAvatarFrame>(avatar).presence?.activity,
              expected,
              reason: '$key agent activity',
            );
            final badge = find.descendant(
              of: avatar,
              matching: find.byType(RaftAvatarBadge),
            );
            expect(badge, findsOneWidget, reason: '$key avatar badge');
            expect(
              t.widget<RaftAvatarBadge>(badge).presence,
              offline ? RaftPresence.offline : RaftPresence.busy,
              reason: '$key badge light',
            );
            expect(
              t.getSize(badge).isEmpty,
              isFalse,
              reason: '$key badge size',
            );
          }
          final profile = find.byKey(const Key('profile'));
          final status = t.widget<RaftAgentStatusRow>(
            find.descendant(
              of: profile,
              matching: find.byType(RaftAgentStatusRow),
            ),
          );
          expect(
            status.light,
            offline ? RaftAgentStatusLight.offline : RaftAgentStatusLight.busy,
          );
          expect(status.text.toLowerCase(), contains(profileText));
        }

        expectPresence(RaftAvatarActivity.working, 'running the original work');
        c.activity('offline', 20);
        await t.pumpAndSettle();
        expectPresence(RaftAvatarActivity.offline, 'offline');
        rebuild(() => lateSidebar = true);
        await t.pumpAndSettle();
        expectPresence(RaftAvatarActivity.offline, 'offline');
        w.row = {
          ...w.row,
          'activity': 'thinking',
          'activityKind': 'thinking',
          'activityDetail': '',
        };
        await w.entityDirectory.refresh(WorkspaceEntityKind.agents);
        await t.pumpAndSettle();
        expectPresence(RaftAvatarActivity.thinking, 'thinking');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
