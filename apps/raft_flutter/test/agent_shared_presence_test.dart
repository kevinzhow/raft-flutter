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
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    testWidgets(
      'mounted sidebar, detail and mention avatars share reconciliation $family/$dark',
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
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return Row(
                    children: [
                      Expanded(
                        child: DesktopDirectoryView(
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
        void badges(RaftAvatarActivity expected) {
          final values = t
              .widgetList<RaftAvatar>(find.byType(RaftAvatar))
              .map((a) => a.presence?.activity)
              .whereType<RaftAvatarActivity>()
              .toList();
          expect(values, hasLength(lateSidebar ? 3 : 2));
          expect(
            values.every((value) => value == expected),
            isTrue,
            reason: '$values',
          );
        }

        badges(RaftAvatarActivity.working);
        c.activity('offline', 20);
        await t.pumpAndSettle();
        badges(RaftAvatarActivity.offline);
        rebuild(() => lateSidebar = true);
        await t.pumpAndSettle();
        badges(RaftAvatarActivity.offline);
        w.row = {
          ...w.row,
          'activity': 'thinking',
          'activityKind': 'thinking',
          'activityDetail': '',
        };
        await w.entityDirectory.refresh(WorkspaceEntityKind.agents);
        await t.pumpAndSettle();
        badges(RaftAvatarActivity.thinking);
        final identity = t.widget<RaftProfileIdentity>(
          find.descendant(
            of: find.byKey(const Key('profile')),
            matching: find.byType(RaftProfileIdentity),
          ),
        );
        expect(identity.statusText?.toLowerCase(), contains('thinking'));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
