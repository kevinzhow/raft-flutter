import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _live = <String, dynamic>{
  'id': 'a',
  'name': 'alpha',
  'displayName': 'Alpha Agent',
  'status': 'active',
  'runtime': 'codex',
  'model': 'alpha-model-1',
  'activity': 'offline',
  'machineId': 'm1',
  'creatorType': 'user',
  'creatorId': 'alice',
  'createdAt': '2026-10-13T08:00:00.000Z',
};
const _machine = <String, dynamic>{
  'id': 'm1',
  'name': 'Studio Mac',
  'status': 'online',
  'isComputer': true,
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
}

/// The server side of archiving: DELETE /agents/:id flips the agent to its
/// archived shape (it leaves the list; GET /agents/:id keeps answering).
class _Workspace extends WorkspaceController {
  _Workspace(
    super.client, {
    Map<String, dynamic> agent = _live,
    Map<String, dynamic>? archive,
    this.archiveFailure,
    this.workspaceFailureCode,
  }) : agent = Map.of(agent),
       archive = archive == null ? null : Map.of(archive);
  Map<String, dynamic> agent;
  Map<String, dynamic>? archive;
  final RaftApiException? archiveFailure;

  /// The `code` of the 409 the archived workspace read answers with.
  final String? workspaceFailureCode;
  final calls = <(String, String, dynamic)>[];
  bool get archived => agent['deletedAt'] != null;

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/agents') return archived ? [] : [agent];
    if (path == '/servers/s/machines') {
      return {
        'machines': [_machine],
      };
    }
    if (path == '/agents/a') return agent;
    if (path == '/agents/a/archive') return {'archive': archive};
    if (path == '/agents/a/workspace-files' && workspaceFailureCode != null) {
      throw RaftApiException.response(
        'The Computer that holds this workspace is offline.',
        status: 409,
        body: {
          'error': 'The Computer that holds this workspace is offline.',
          'code': workspaceFailureCode,
        },
      );
    }
    if (path == '/agents/a/workspace-files') {
      return {'files': []};
    }
    if (path == '/agents/a/skills') return {'global': [], 'workspace': []};
    return [];
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    calls.add((method, path, data));
    if (method == 'DELETE' && path == '/agents/a') {
      if (archiveFailure != null) throw archiveFailure!;
      agent = {
        ...agent,
        'deletedAt': '2026-10-24T01:00:00.000Z',
        'status': 'inactive',
        'machineId': null,
      };
      archive = {
        'agentId': 'a',
        'archivedAt': '2026-10-24T01:00:00.000Z',
        'machineId': 'm1',
        'machineName': 'Studio Mac',
        'workspaceState': data['workspace'] == 'delete'
            ? 'deleted'
            : 'on_computer',
        'pendingOp': null,
        'waitingForComputer': false,
      };
      return {'ok': true};
    }
    if (method == 'POST' && path == '/agents/a/archive/workspace') {
      archive = {
        ...archive!,
        'workspaceState': 'on_computer',
        'pendingOp': 'delete',
      };
      return {'archive': archive};
    }
    return {};
  }
}

Future<(_Workspace, _Client)> _open(
  WidgetTester tester, {
  Map<String, dynamic> agent = _live,
  Map<String, dynamic>? archive,
  RaftApiException? archiveFailure,
  String? workspaceFailureCode,
  String role = 'owner',
}) async {
  SharedPreferences.setMockInitialValues({});
  // The test face is wider than the real one: a long confirm label overflows.
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed by')) return;
    onError?.call(details);
  };
  addTearDown(() => FlutterError.onError = onError);
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = _Client()..selectServer('s');
  final w = _Workspace(
    client,
    agent: agent,
    archive: archive,
    archiveFailure: archiveFailure,
    workspaceFailureCode: workspaceFailureCode,
  )..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': role});
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: FleetDetail(
          controller: w,
          computers: false,
          initial: const {'id': 'a'},
          onClose: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (w, client);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final _archivedAgent = <String, dynamic>{
  ..._live,
  'deletedAt': '2026-10-24T01:00:00.000Z',
  'status': 'inactive',
  'machineId': null,
};
final _onComputer = <String, dynamic>{
  'agentId': 'a',
  'archivedAt': '2026-10-24T01:00:00.000Z',
  'archivedByUserId': 'alice',
  'machineId': 'm1',
  'machineName': 'Studio Mac',
  'workspaceState': 'on_computer',
  'pendingOp': null,
  'waitingForComputer': false,
};

void main() {
  group('archive dialog', () {
    testWidgets(
      'the profile offers Archive, not Delete, and keeps the workspace by default',
      (tester) async {
        final (w, _) = await _open(tester);
        expect(find.text('Delete Agent'), findsNothing);
        expect(find.text('Archive Agent'), findsOneWidget);

        await _tapText(tester, 'Archive Agent');
        expect(find.text('Archive Alpha Agent?'), findsOneWidget);
        expect(find.text('Keep it on the Computer'), findsOneWidget);
        expect(
          find.textContaining('browse it read-only while Studio Mac is online'),
          findsOneWidget,
        );
        expect(
          find.text('Deleting the workspace cannot be undone.'),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('agent-archive-confirm')));
        await tester.pumpAndSettle();
        final delete = w.calls.where((c) => c.$1 == 'DELETE').single;
        expect(delete.$2, '/agents/a');
        expect(delete.$3, {'workspace': 'keep'});
      },
    );

    testWidgets('choosing to delete the workspace warns and sends delete', (
      tester,
    ) async {
      final (w, _) = await _open(tester);
      await _tapText(tester, 'Archive Agent');
      await tester.tap(
        find.byKey(const ValueKey('agent-archive-option-delete')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Deleting the workspace cannot be undone.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('agent-archive-confirm')));
      await tester.pumpAndSettle();
      expect(w.calls.where((c) => c.$1 == 'DELETE').single.$3, {
        'workspace': 'delete',
      });
    });

    testWidgets(
      'an agent that is migrating shows the catalog copy and stays open',
      (tester) async {
        final (w, _) = await _open(
          tester,
          archiveFailure: RaftApiException.response(
            'This agent is being migrated. Wait for the migration to finish or cancel it first.',
            status: 409,
            body: {
              'error': 'This agent is being migrated.',
              'code': 'archive_migration_active',
            },
          ),
        );
        await _tapText(tester, 'Archive Agent');
        await tester.tap(find.byKey(const ValueKey('agent-archive-confirm')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This agent is being migrated. Wait for the migration to finish or cancel it, then archive it.',
          ),
          findsOneWidget,
        );
        expect(find.text('Archive Alpha Agent?'), findsOneWidget);
        expect(w.agent['deletedAt'], isNull);
      },
    );

    testWidgets(
      'an agent without a Computer workspace gets no workspace choice',
      (tester) async {
        final (w, _) = await _open(
          tester,
          agent: {..._live, 'machineId': null},
        );
        await _tapText(tester, 'Archive Agent');
        expect(
          find.byKey(const ValueKey('agent-archive-option-keep')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('agent-archive-confirm')));
        await tester.pumpAndSettle();
        expect(w.calls.where((c) => c.$1 == 'DELETE').single.$3, {
          'workspace': 'keep',
        });
      },
    );
  });

  group('archived profile', () {
    testWidgets(
      'after archiving the profile stays as the read-only archived profile',
      (tester) async {
        final (w, _) = await _open(tester);
        await _tapText(tester, 'Archive Agent');
        await tester.tap(find.byKey(const ValueKey('agent-archive-confirm')));
        await tester.pumpAndSettle();

        // Not closed, not "Agent unavailable".
        expect(find.byType(AgentDetailPanel), findsOneWidget);
        expect(find.text('Agent unavailable'), findsNothing);
        expect(find.text('Alpha Agent'), findsWidgets);
        // Only Profile and Workspace remain; no actions.
        expect(
          find.byKey(const ValueKey('panel-tab-workspace')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('panel-tab-profile')), findsOneWidget);
        for (final gone in ['activity', 'chat', 'reminders', 'apps', 'mcp']) {
          expect(
            find.byKey(ValueKey('panel-tab-$gone')),
            findsNothing,
            reason: gone,
          );
        }
        expect(find.text('Archive Agent'), findsNothing);
        expect(
          find.byKey(const Key('agent-profile-inline-start-stop')),
          findsNothing,
        );
        // The archive section: where the workspace is, and where it last ran.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('agent-archive-section')),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('On Studio Mac'), findsOneWidget);
        expect(find.text('Last on Studio Mac'), findsOneWidget);
        expect(w.calls.where((c) => c.$1 == 'DELETE'), hasLength(1));
      },
    );

    testWidgets('a kept workspace can be deleted later, after a confirmation', (
      tester,
    ) async {
      final (w, _) = await _open(
        tester,
        agent: _archivedAgent,
        archive: _onComputer,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('agent-archive-delete-workspace-button')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-archive-delete-workspace-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The workspace is deleted from Studio Mac. This cannot be undone.',
        ),
        findsOneWidget,
      );
      // Cancel changes nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(w.calls.where((c) => c.$1 == 'POST'), isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('agent-archive-delete-workspace-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('agent-archive-delete-workspace-confirm')),
      );
      await tester.pumpAndSettle();
      final post = w.calls.where((c) => c.$1 == 'POST').single;
      expect(post.$2, '/agents/a/archive/workspace');
      expect(post.$3, {'action': 'delete'});
      // Pending: the state line says so and the button is gone.
      expect(find.text('Deleting from Studio Mac…'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-archive-delete-workspace-button')),
        findsNothing,
      );
    });

    testWidgets(
      'a push for this agent re-reads the archive; one for another does not',
      (tester) async {
        final (w, client) = await _open(
          tester,
          agent: _archivedAgent,
          archive: _onComputer,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('agent-archive-section')),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('On Studio Mac'), findsOneWidget);
        w.archive = {
          ..._onComputer,
          'workspaceState': 'deleted',
          'waitingForComputer': false,
        };
        client.stream.add(
          const RaftEvent(agentArchiveUpdatedEventName, {'agentId': 'other'}),
        );
        await tester.pumpAndSettle();
        expect(find.text('On Studio Mac'), findsOneWidget);
        client.stream.add(
          const RaftEvent(agentArchiveUpdatedEventName, {'agentId': 'a'}),
        );
        await tester.pumpAndSettle();
        expect(find.text('Deleted from the Computer'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-archive-delete-workspace-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a member without delete authority cannot delete the workspace',
      (tester) async {
        await _open(
          tester,
          agent: {
            ..._archivedAgent,
            'creatorId': 'someone',
            'creatorType': 'user',
          },
          archive: _onComputer,
          role: 'guest',
        );
        // The Archive section is a private surface: a guest sees none of it.
        expect(
          find.byKey(const ValueKey('agent-archive-section')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('agent-archive-delete-workspace-button')),
          findsNothing,
        );
      },
    );

    testWidgets('failed deletes show their plain-language reason', (
      tester,
    ) async {
      await _open(
        tester,
        agent: _archivedAgent,
        archive: {..._onComputer, 'lastErrorCode': 'ARCHIVE_WORKSPACE_MISSING'},
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('agent-archive-error')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.text('The workspace was not found on the Computer.'),
        findsOneWidget,
      );
    });
  });

  group('archived workspace', () {
    testWidgets(
      'a workspace deleted from its Computer says so, with no path bar and no Retry',
      (tester) async {
        await _open(
          tester,
          agent: _archivedAgent,
          archive: {..._onComputer, 'workspaceState': 'deleted'},
          workspaceFailureCode: 'archive_workspace_unavailable',
        );
        await tester.tap(find.byKey(const ValueKey('panel-tab-workspace')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This workspace was deleted from its Computer, so there is nothing to browse.',
          ),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
        expect(find.text('Copy path'), findsNothing);
      },
    );

    testWidgets('an offline Computer explains it and offers Retry', (
      tester,
    ) async {
      await _open(
        tester,
        agent: _archivedAgent,
        archive: _onComputer,
        workspaceFailureCode: 'machine_offline',
      );
      await tester.tap(find.byKey(const ValueKey('panel-tab-workspace')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The Computer that holds this workspace is offline. Files can be browsed again when it reconnects.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

const agentArchiveUpdatedEventName = 'agent:archive:updated';
