// Web HostedRuntimeStatus, AgentHostedRuntimeUsage and stopHostedTurn on a
// cloud agent's profile: the provisioning panel replaces the setup steps, a
// retry (naming the model again after the provider refused it), the seven-day
// usage, and "Stop current turn".
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _hosted(
  String state, {
  Map<String, dynamic>? lastError,
  bool retryNeedsModel = false,
  bool syncPending = false,
  Map<String, dynamic>? push,
}) => {
  'provider': 'antiproton',
  'state': state,
  'providerAgentId': null,
  'syncPending': syncPending,
  'push': push,
  'lastError': lastError,
  'attemptCount': 1,
  'nextAttemptAt': null,
  'activatedAt': null,
  'retryNeedsModel': retryNeedsModel,
};

const _refused = {
  'code': 'unknown_model',
  'message': 'model not offered',
  'httpStatus': 422,
  'at': '2026-10-24T08:00:00.000Z',
};

Map<String, dynamic> _agent(Map<String, dynamic>? hosted, {String? creator}) =>
    {
      'id': 'ext-1',
      'name': 'Cloud-Bot',
      'displayName': 'Cloud Bot',
      'description': 'Runs in the cloud.',
      'status': 'active',
      'runtime': 'external',
      'model': 'external',
      'external': true,
      'creatorType': 'user',
      'creatorId': creator ?? 'alice',
      'hostedRuntime': ?hosted,
    };

class _Client extends RaftClient {
  _Client(this.hosted)
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  Map<String, dynamic>? hosted;

  /// What the status read says when it differs from the (stale) agent row.
  Map<String, dynamic>? statusHosted;
  String creator = 'alice';
  final calls = <String>[];
  final bodies = <String, Object?>{};
  Object? usage = {
    'raftAgentId': 'ext-1',
    'bucket': '1d',
    'from': '2026-10-18T00:00:00.000Z',
    'to': '2026-10-24T09:00:00.000Z',
    'asOf': '2026-10-24T09:00:00.000Z',
    'partial': false,
    'rows': [
      {
        'at': '2026-10-23T00:00:00.000Z',
        'resource': 'model.tokens',
        'dimensions': {'kind': 'input', 'model': 'deepseek-flash'},
        'unit': 'tokens',
        'quantity': 1500,
        'cost': 0.004,
      },
      {
        'at': '2026-10-23T00:00:00.000Z',
        'resource': 'model.tokens',
        'dimensions': {'kind': 'output', 'model': 'deepseek-flash'},
        'unit': 'tokens',
        'quantity': 250,
        'cost': 0.0012,
      },
      {
        'at': '2026-10-23T00:00:00.000Z',
        'resource': 'tool.call',
        'dimensions': {'outcome': 'succeeded'},
        'unit': 'calls',
        'quantity': 3,
        'cost': null,
      },
    ],
  };
  Object? retryResult;
  Object? stopResult = {'result': 'interrupted'};
  int stopFailures = 0;
  Object? models = {
    'models': [
      {'id': 'fast', 'label': 'Fast', 'provider': 'p'},
      {'id': 'smart', 'label': 'Smart', 'provider': 'p'},
    ],
    'default': 'balanced',
    'defaultLabel': 'Balanced',
    'locked': false,
  };
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
    bodies['$method $path'] = data;
    if (path == '/agents') return [_agent(hosted, creator: creator)];
    if (path == '/agents/ext-1') return _agent(hosted, creator: creator);
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    if (path == '/agents/ext-1/external-status') {
      return {
        'setupState': 'credential_minted',
        'hostedRuntime': statusHosted ?? hosted,
      };
    }
    if (path == '/agents/ext-1/hosted-runtime/model') {
      return {
        'models': [],
        'default': 'balanced',
        'defaultLabel': 'Balanced',
        'model': 'balanced',
        'label': 'Balanced',
        'source': 'default',
        'locked': false,
      };
    }
    if (path == '/agents/ext-1/hosted-runtime/usage') {
      queries['usage'] = query;
      final out = usage;
      if (out is Exception) throw out;
      return out;
    }
    if (path == '/agents/ext-1/hosted-runtime/retry') {
      final out = retryResult;
      if (out is Exception) throw out;
      return out ?? {'hostedRuntime': hosted};
    }
    if (path == '/agents/ext-1/stop') {
      if (stopFailures > 0) {
        stopFailures--;
        throw RaftApiException('down', status: 502);
      }
      return stopResult;
    }
    if (path == '/agent-runtime-providers/antiproton/models') {
      final out = models;
      if (out is Exception) throw out;
      return out;
    }
    return [];
  }

  final queries = <String, Object?>{};
}

Future<(_Client, WorkspaceController)> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? hosted,
  _Client? client,
  String role = 'owner',
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = (client ?? _Client(hosted))..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': role});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => RaftToastHost(child: child!),
      home: Scaffold(
        body: FleetDetail(
          key: UniqueKey(),
          controller: w,
          computers: false,
          initial: _agent(c.hosted),
          onClose: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (c, w);
}

Finder _k(String key) => find.byKey(ValueKey(key));

void main() {
  group('status panel', () {
    testWidgets('replaces the token and the setup steps', (t) async {
      final (c, _) = await _pump(t, hosted: _hosted('provisioning'));
      expect(_k('hosted-runtime-state'), findsOneWidget);
      expect(find.text('Setting up'), findsOneWidget);
      expect(find.text('Runs in the cloud'), findsOneWidget);
      expect(find.text('Free for a limited time'), findsOneWidget);
      expect(find.text('Hermes'), findsNothing);
      expect(find.text('Claude Code'), findsNothing);
      expect(find.text('Other agents'), findsNothing);
      expect(find.text('Generate Token'), findsNothing);
      expect(
        c.calls.where((x) => x.endsWith('/credentials')),
        isEmpty,
        reason: 'a cloud agent has no token manager to load',
      );
    });

    testWidgets('a provider that is still working is re-read every 5 s', (
      t,
    ) async {
      final (c, _) = await _pump(t, hosted: _hosted('provisioning'));
      int reads() =>
          c.calls.where((x) => x == 'GET /agents/ext-1/external-status').length;
      final before = reads();
      await t.pump(const Duration(seconds: 4));
      expect(reads(), before);
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(reads(), before + 1);
      // The provider finished: the panel shows it and stops asking.
      c.hosted = _hosted('active');
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      expect(find.text('Running'), findsOneWidget);
      final after = reads();
      await t.pump(const Duration(seconds: 15));
      expect(reads(), after, reason: 'a settled state is not polled');
    });

    testWidgets('a running agent is not polled at all', (t) async {
      final (c, _) = await _pump(t, hosted: _hosted('active'));
      final before = c.calls.length;
      await t.pump(const Duration(seconds: 20));
      expect(c.calls.length, before);
    });

    testWidgets('syncing changes reads as in progress', (t) async {
      final (_, _) = await _pump(
        t,
        hosted: _hosted('active', syncPending: true),
      );
      expect(find.text('Syncing changes'), findsOneWidget);
    });

    testWidgets('push not registered and the last error are shown', (t) async {
      await _pump(
        t,
        hosted: _hosted(
          'active',
          lastError: _refused,
          push: {'registered': false, 'error': 'no endpoint'},
        ),
      );
      expect(
        find.text(
          'Message delivery to this cloud agent is not registered yet. no endpoint',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Last error (unknown_model): model not offered'),
        findsOneWidget,
      );
    });

    testWidgets('Retry re-reads the state and the panel follows', (t) async {
      final (c, _) = await _pump(
        t,
        hosted: _hosted(
          'failed',
          lastError: {..._refused, 'code': 'provider_5xx'},
        ),
      );
      expect(find.text('Setup failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      c.hosted = _hosted('provisioning');
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      expect(c.calls, contains('POST /agents/ext-1/hosted-runtime/retry'));
      expect(c.bodies['POST /agents/ext-1/hosted-runtime/retry'], isNull);
      expect(find.text('Setting up'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a failed Retry says so and can be tried again', (t) async {
      final (c, _) = await _pump(
        t,
        hosted: _hosted('failed', lastError: _refused),
      );
      c.retryResult = RaftApiException('down', status: 502);
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('Retry failed.'), findsOneWidget);
      c.retryResult = null;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('Retry failed.'), findsNothing);
    });

    testWidgets('after a refused model a retry names the model again', (
      t,
    ) async {
      final (c, _) = await _pump(
        t,
        hosted: _hosted('failed', lastError: _refused, retryNeedsModel: true),
      );
      expect(
        find.text(
          'The provider refused the model this agent was set to start on. Choose a model, then retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Retry with Default (Balanced)'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('hosted-model-choice')));
      await t.pumpAndSettle();
      await t.tap(find.text('Smart'));
      await t.pumpAndSettle();
      expect(find.text('Retry with Smart'), findsOneWidget);
      await t.tap(find.text('Retry with Smart'));
      await t.pumpAndSettle();
      expect(c.bodies['POST /agents/ext-1/hosted-runtime/retry'], {
        'model': 'smart',
      });
    });

    testWidgets('retrying with the default sends an explicit null', (t) async {
      final (c, _) = await _pump(
        t,
        hosted: _hosted('failed', lastError: _refused, retryNeedsModel: true),
      );
      await t.tap(find.text('Retry with Default (Balanced)'));
      await t.pumpAndSettle();
      final body = c.bodies['POST /agents/ext-1/hosted-runtime/retry'] as Map;
      expect(body.containsKey('model'), isTrue);
      expect(body['model'], isNull);
    });

    testWidgets('Retry waits for the model list; a locked list sends null', (
      t,
    ) async {
      final c =
          _Client(_hosted('failed', lastError: _refused, retryNeedsModel: true))
            ..models = {
              'models': [
                {'id': 'fast', 'label': 'Fast', 'provider': 'p'},
              ],
              'default': 'fast',
              'defaultLabel': 'Fast',
              'locked': true,
            };
      await _pump(t, client: c);
      expect(
        find.byKey(const ValueKey('hosted-model-choice-locked')),
        findsOneWidget,
      );
      await t.tap(find.text('Retry with Default (Fast)'));
      await t.pumpAndSettle();
      expect(
        (c.bodies['POST /agents/ext-1/hosted-runtime/retry'] as Map)['model'],
        isNull,
      );
    });

    testWidgets('no model list is read unless the retry needs a model', (
      t,
    ) async {
      final (c, _) = await _pump(
        t,
        hosted: _hosted('failed', lastError: _refused),
      );
      expect(
        c.calls.where((x) => x.contains('/agent-runtime-providers')),
        isEmpty,
      );
    });

    testWidgets('a viewer who cannot manage the agent sees no panel', (
      t,
    ) async {
      final c = _Client(_hosted('failed', lastError: _refused))
        ..creator = 'bob';
      await _pump(t, client: c, role: 'member');
      expect(find.text('Setup failed'), findsNothing);
      expect(find.text('Runs in the cloud'), findsNothing);
      expect(
        c.calls.where((x) => x.contains('hosted-runtime')),
        isEmpty,
        reason: 'nothing of the cloud runtime is read without access',
      );
    });
  });

  group('usage', () {
    testWidgets('shows cost by day, tokens, tool calls and top models', (
      t,
    ) async {
      final (c, _) = await _pump(t, hosted: _hosted('active'));
      expect(find.text('Usage (last 7 days)'), findsOneWidget);
      expect(c.calls, contains('GET /agents/ext-1/hosted-runtime/usage'));
      final q = c.queries['usage'] as Map;
      expect(q['bucket'], '1d');
      expect(DateTime.parse(q['from'] as String).isUtc, isTrue);
      expect(find.text('Oct 23'), findsOneWidget);
      expect(
        find.text('under \$0.01'),
        findsNWidgets(2),
        reason: 'the day and the total are under one cent, never \$0.00',
      );
      expect(find.text('1,500'), findsOneWidget, reason: 'input');
      expect(
        find.text('1,750'),
        findsNWidgets(2),
        reason: 'total tokens and the top model',
      );
      expect(find.text('3 (3 succeeded, 0 failed)'), findsOneWidget);
      expect(find.text('deepseek-flash'), findsOneWidget);
      expect(
        find.text(
          'Some usage, such as tool calls, has no price and is not included.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'In USD by UTC day, as reported by the provider. For reference, not a bill.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no usage reads empty; a 4xx hides the block', (t) async {
      final empty = _Client(_hosted('active'))
        ..usage = {
          'rows': [],
          'partial': false,
          'asOf': '2026-10-24T09:00:00.000Z',
        };
      await _pump(t, client: empty);
      expect(find.text('No usage in the last 7 days'), findsOneWidget);
      final hidden = _Client(_hosted('active'))
        ..usage = RaftApiException('forbidden', status: 403);
      await _pump(t, client: hidden);
      expect(find.text('Usage (last 7 days)'), findsNothing);
    });

    testWidgets('a provider failure or 429 warns instead of hiding', (t) async {
      for (final status in [500, 429, 400]) {
        final c = _Client(_hosted('active'))
          ..usage = RaftApiException('x', status: status);
        await _pump(t, client: c);
        expect(
          find.text('Failed to load usage'),
          findsOneWidget,
          reason: '$status',
        );
      }
    });

    testWidgets('partial data says as of when', (t) async {
      final c = _Client(_hosted('active'));
      (c.usage as Map)['partial'] = true;
      await _pump(t, client: c);
      expect(find.textContaining('Partial data, as of'), findsOneWidget);
    });

    testWidgets('only an active cloud agent shows usage', (t) async {
      final (c, _) = await _pump(t, hosted: _hosted('failed'));
      expect(find.text('Usage (last 7 days)'), findsNothing);
      expect(
        c.calls.where((x) => x.endsWith('/hosted-runtime/usage')),
        isEmpty,
      );
    });
  });

  group('stop current turn', () {
    testWidgets('an active cloud agent has the command and it says what '
        'happened', (t) async {
      final (c, _) = await _pump(t, hosted: _hosted('active'));
      final stop = find.byKey(
        const Key('agent-profile-inline-stop-hosted-turn'),
      );
      expect(stop, findsOneWidget);
      await t.tap(stop);
      await t.pumpAndSettle();
      expect(c.calls, contains('POST /agents/ext-1/stop'));
      expect(find.text('Stopped the current turn.'), findsOneWidget);
      // Not running: the other message.
      c.stopResult = {'result': 'not_running'};
      await t.tap(stop);
      await t.pumpAndSettle();
      expect(find.text('Nothing was running.'), findsOneWidget);
    });

    testWidgets('a failed stop offers Retry and the retry stops it', (t) async {
      final (c, _) = await _pump(t, hosted: _hosted('active'));
      c.stopFailures = 1;
      await t.tap(
        find.byKey(const Key('agent-profile-inline-stop-hosted-turn')),
      );
      await t.pumpAndSettle();
      expect(find.text("Couldn't stop the current turn."), findsOneWidget);
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(
        c.calls.where((x) => x == 'POST /agents/ext-1/stop'),
        hasLength(2),
      );
      expect(find.text('Stopped the current turn.'), findsOneWidget);
    });

    testWidgets('the state just read decides, not the list row it came from', (
      t,
    ) async {
      // The directory row still says provisioning; the status read says active.
      final c = _Client(_hosted('provisioning'))
        ..statusHosted = _hosted('active');
      await _pump(t, client: c);
      expect(
        find.byKey(const Key('agent-profile-inline-stop-hosted-turn')),
        findsOneWidget,
      );
    });

    testWidgets('not offered while setting up, failed, or for a plain agent', (
      t,
    ) async {
      for (final state in ['provisioning', 'failed', 'deleting']) {
        await _pump(t, hosted: _hosted(state));
        expect(
          find.byKey(const Key('agent-profile-inline-stop-hosted-turn')),
          findsNothing,
          reason: state,
        );
      }
      await _pump(t, hosted: null);
      expect(
        find.byKey(const Key('agent-profile-inline-stop-hosted-turn')),
        findsNothing,
      );
    });
  });
}
