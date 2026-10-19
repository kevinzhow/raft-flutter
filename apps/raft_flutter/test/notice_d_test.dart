import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Slice D of the transient-notice audit: workspace-level and agent/fleet
/// errors must end with their cause or scope.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final calls = <String>[];

  /// Throws the returned error for a request, or null to answer normally.
  Object? Function(String method, String path)? failure;
  Map<String, Completer<void>> gates = {};
  Object? Function(String method, String path)? answer;
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
    await gates[path]?.future;
    final error = failure?.call(method, path);
    if (error != null) throw error;
    final out = answer?.call(method, path);
    if (out != null) return out;
    if (path.endsWith('/credentials')) return {'credentials': []};
    return [];
  }
}

RaftRecord _server(String id) =>
    RaftRecord({'id': id, 'name': 'Server $id', 'role': 'owner'});

Future<(WorkspaceController, _Client)> _controller() async {
  final c = _Client()..selectServer('s');
  final w = WorkspaceController(c)..server = _server('s');
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  return (w, c);
}

void main() {
  group('workspace error (w.error) is bound to its server', () {
    test('selecting another server drops the previous server error', () async {
      final (w, _) = await _controller();
      final other = _server('t');
      w.servers = [_server('s'), other];
      w.setError('Failed to load channels');
      await w.selectServer(other);
      expect(w.error, isNull);
    });

    test('revoking the open server drops its error', () async {
      final (w, _) = await _controller();
      w.setError('Failed to load channels');
      w.revokeServer('s');
      expect(w.error, isNull);
    });

    test('a join fenced by a server switch reports nothing', () async {
      final (w, c) = await _controller();
      w.channel = RaftChannel({
        'id': 'c1',
        'name': 'general',
        'type': 'public',
      });
      c.failure = (method, path) => path == '/channels/c1/join'
          ? const RaftApiException.staleScope()
          : null;
      await w.messageDomain.joinOpenChannel();
      expect(w.error, isNull);
      // A real failure is still reported.
      c.failure = (method, path) => path == '/channels/c1/join'
          ? const RaftApiException('Nope', status: 500)
          : null;
      await w.messageDomain.joinOpenChannel();
      expect(w.error, isNotNull);
    });

    test(
      'a parent-channel join fenced by a server switch reports nothing',
      () async {
        final (w, c) = await _controller();
        w.messageDomain.state.threadParent = RaftMessage({
          'id': 'm1',
          'channelId': 'c1',
          'content': 'x',
        });
        c.failure = (method, path) => path == '/channels/c1/join'
            ? const RaftApiException.staleScope()
            : null;
        await w.messageDomain.joinThreadParentChannel();
        expect(w.error, isNull);
        c.failure = (method, path) => path == '/channels/c1/join'
            ? const RaftApiException('Nope', status: 500)
            : null;
        await w.messageDomain.joinThreadParentChannel();
        expect(w.error, isNotNull);
      },
    );

    test(
      'a server directory load fenced by a switch reports nothing',
      () async {
        final (w, c) = await _controller();
        c.failure = (method, path) =>
            path == '/servers' ? const RaftApiException.staleScope() : null;
        await w.bootstrap();
        expect(w.error, isNull);
      },
    );
  });

  group('contextLoadError is bound to its channel and server', () {
    test('another channel in the same window does not inherit it', () async {
      final (w, _) = await _controller();
      w.channel = RaftChannel({'id': 'c1', 'name': 'a', 'type': 'public'});
      w.messageDomain.contextLoadError = MessageContextLoadError.notFound;
      expect(
        w.messageDomain.contextLoadError,
        MessageContextLoadError.notFound,
      );
      w.channel = RaftChannel({'id': 'c2', 'name': 'b', 'type': 'public'});
      expect(w.messageDomain.contextLoadError, isNull);
      // Coming back to the first channel does not resurrect the message.
      w.channel = RaftChannel({'id': 'c1', 'name': 'a', 'type': 'public'});
      expect(w.messageDomain.contextLoadError, isNull);
    });

    test('a server switch drops it', () async {
      final (w, _) = await _controller();
      final other = _server('t');
      w.servers = [_server('s'), other];
      w.channel = RaftChannel({'id': 'c1', 'name': 'a', 'type': 'public'});
      w.messageDomain.contextLoadError = MessageContextLoadError.beyondHistory;
      w.server = other;
      expect(w.messageDomain.contextLoadError, isNull);
    });
  });

  group('agent surfaces', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      WorkspaceController w,
      Map<String, dynamic> agent,
    ) => tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: AgentDetailPanel(
            controller: w,
            agent: agent,
            machines: const [],
            actions: const AgentDetailActions(),
            canManage: true,
            canViewPrivate: true,
          ),
        ),
      ),
    );

    Map<String, dynamic> external(String id) => {
      'id': id,
      'name': id,
      'displayName': id,
      'status': 'active',
      'runtime': 'external',
      'model': 'external',
      'external': true,
      'creatorType': 'user',
      'creatorId': 'alice',
    };

    testWidgets('the external setup failure does not follow to another agent', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, c) = await _controller();
      c.gates['/agents/ext-2/external-status'] = Completer<void>();
      c.failure = (method, path) => path == '/agents/ext-1/external-status'
          ? const RaftApiException('Status unavailable', status: 500)
          : null;
      await pumpPanel(tester, w, external('ext-1'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to load external setup status'), findsOneWidget);

      // The panel now shows another agent whose status is still loading.
      await pumpPanel(tester, w, external('ext-2'));
      await tester.pump();
      expect(find.text('Failed to load external setup status'), findsNothing);
      c.gates['/agents/ext-2/external-status']!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('runtime editor', () {
    const agent = <String, dynamic>{
      'id': 'a1',
      'name': 'alpha',
      'displayName': 'Alpha',
      'status': 'inactive',
      'activity': 'offline',
      'runtime': 'codex',
      'model': 'gpt-5-codex',
      'machineId': 'm1',
      'reasoningEffort': 'medium',
      'creatorType': 'user',
      'creatorId': 'alice',
    };

    testWidgets(
      'a protocol-v2 save clears the previous failure when it starts',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, c) = await _controller();
        w.runtimeFormV2WebEnabled = true;
        c.answer = (method, path) {
          if (path == '/agents') return [agent];
          if (path == '/agents/a1') return agent;
          if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
          if (path == '/servers/s/machines') {
            return {
              'machines': [
                {
                  'id': 'm1',
                  'name': 'Box',
                  'status': 'online',
                  'runtimes': ['codex'],
                },
              ],
            };
          }
          if (path == '/agents/a1/runtime-options') {
            return {
              'options': [
                {
                  'runtimeId': 'codex',
                  'canSelectInThisContext': true,
                  'runtimeFormV2': {'protocolVersion': 2},
                },
              ],
            };
          }
          if (path == '/agents/a1/runtime-form') {
            return {
              'protocolVersion': 2,
              'runtimeId': 'codex',
              'dataSchema': {
                'properties': {
                  'fast': {'type': 'boolean', 'title': 'Fast mode extra'},
                },
              },
              'uiSchema': {
                'order': ['fast'],
              },
            };
          }
          return null;
        };
        c.failure = (method, path) => method == 'PATCH'
            ? const RaftApiException('Rejected', status: 400)
            : null;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.brutal),
            home: Scaffold(
              body: FleetDetail(
                controller: w,
                computers: false,
                initial: const {'id': 'a1'},
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('agent-edit-runtime')));
        await tester.pumpAndSettle();
        // A real interaction on the field: the editor must follow the form
        // controller itself (Save is disabled until a value changed).
        expect(
          tester
              .widget<RaftAgentDialogButton>(
                find.byKey(const ValueKey('runtime-editor-save')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byType(RaftSwitch));
        await tester.pump();
        expect(
          tester
              .widget<RaftAgentDialogButton>(
                find.byKey(const ValueKey('runtime-editor-save')),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byKey(const ValueKey('runtime-editor-save')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('runtime-editor-error')),
          findsOneWidget,
        );

        // Save again: the failure of the first attempt is gone while the second
        // one is in flight (Web handleSaveRuntimeConfiguration).
        c.failure = null;
        c.gates['/agents/a1'] = Completer<void>();
        await tester.tap(find.byKey(const ValueKey('runtime-editor-save')));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('runtime-editor-error')),
          findsNothing,
        );
        c.gates['/agents/a1']!.complete();
        await tester.pumpAndSettle();
      },
    );
  });
}
