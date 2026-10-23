import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_diagnostic_info.dart';

import 'support/agent_panel_fixture.dart';

/// Web utils/agentDiagnosticInfo.ts. The reported time is fixed.
final _at = DateTime.utc(2026, 10, 24, 1, 2, 3);

const _external = <String, dynamic>{
  'id': 'ext-1',
  'name': 'hermes',
  'displayName': 'Hermes',
  'status': 'active',
  'runtime': 'external',
  'model': 'external',
  'external': true,
  'serverId': 's',
  'lastSeenAt': '2026-10-24T01:01:30.000Z',
  'creatorType': 'user',
  'creatorId': 'alice',
  'createdAt': '2026-10-13T08:00:00.000Z',
};

Map<String, dynamic> _diagnostics({bool push = true}) => {
  'agentId': 'ext-1',
  'generatedAt': '2026-10-24T01:02:00.000Z',
  'presence': {
    'lastSeenAt': '2026-10-24T01:01:30.000Z',
    'onlineWindowMs': 120000,
  },
  'status': {
    'activity': 'online',
    'detailKind': 'none',
    'detail': '',
    'observedAt': '2026-10-24T01:01:00.000Z',
    'statusProtocolAdoptedAt': null,
  },
  'provider': {
    'kind': 'hosted',
    'state': 'active',
    'syncPending': true,
    'providerAgentId': 'prov-1',
    'lastErrorCode': 'TIMEOUT',
    'lastErrorAt': '2026-10-24T00:00:00.000Z',
  },
  'push': push
      ? {
          'registered': true,
          'enabled': false,
          'disabledReason': 'too_many_failures',
          'endpointHost': 'hooks.example.com',
          'consecutiveFailures': 3,
          'lastDeliveryAt': null,
          'lastAttemptAt': '2026-10-24T01:00:00.000Z',
          'lastError': 'HTTP 500',
        }
      : {'registered': false},
  'events': {
    'lastCursorPullAt': '2026-10-24T01:01:00.000Z',
    'pendingCursorAckCount': 2,
  },
  'connections': [
    {'provider': 'github', 'state': 'connected', 'account': 'octo'},
    {'provider': 'slack', 'state': 'unavailable', 'reason': 'no_token'},
  ],
};

void main() {
  group('buildAgentDiagnosticInfo', () {
    test('a managed agent lists its identity, Computer and live state', () {
      final text = buildAgentDiagnosticInfo(
        agent: {...agentPanelAgent, 'sessionId': 'sess-1', 'status': 'active'},
        title: 'Raft Diagnostic Info',
        serverId: 's',
        machine: {
          'id': 'm1',
          'computerVersion': '1.0.52',
          'daemonVersion': null,
        },
        activity: 'working',
        detailKind: 'none',
        lastActivityAtMs: DateTime.utc(
          2026,
          10,
          24,
          1,
          0,
        ).millisecondsSinceEpoch,
        reportedAt: _at,
      );
      expect(text.split('\n'), [
        'Raft Diagnostic Info',
        'reportedAtUtc: 2026-10-24T01:02:03.000Z',
        'serverId: s',
        'agentId: a',
        'machineId: m1',
        'sessionId: sess-1',
        'runtime: codex',
        'model: alpha-model-1',
        'computerVersion: 1.0.52',
        'daemonVersion: unknown',
        'agentStatus: active',
        'activity: working',
        'activityKind: working',
        'lastActivityAtUtc: 2026-10-24T01:00:00.000Z',
      ]);
    });

    test('unknown values read unknown, and a missing session reads null', () {
      final text = buildAgentDiagnosticInfo(
        agent: {'id': 'x', 'status': 'inactive'},
        title: 'T',
        serverId: null,
        activity: 'offline',
        detailKind: 'runtime_crashed',
        reportedAt: _at,
      );
      expect(text, contains('serverId: unknown'));
      expect(text, contains('machineId: unknown'));
      expect(text, contains('sessionId: null'));
      expect(text, contains('activityKind: runtime_crashed'));
      expect(text, contains('lastActivityAtUtc: unknown'));
    });

    test('the error message is copied only while the agent is in error', () {
      String text(String activity) => buildAgentDiagnosticInfo(
        agent: agentPanelAgent,
        title: 'T',
        serverId: 's',
        activity: activity,
        errorMessage: '  boom  ',
        reportedAt: _at,
      );
      expect(text('error').split('\n')[1], 'errorMessage: boom');
      expect(text('online'), isNot(contains('errorMessage')));
    });

    test('an external agent carries the external diagnostics', () {
      final text = buildAgentDiagnosticInfo(
        agent: _external,
        title: 'Raft Diagnostic Info',
        serverId: 's',
        activity: 'online',
        externalDiagnostics: _diagnostics(),
        reportedAt: _at,
      );
      expect(text.split('\n'), [
        'Raft Diagnostic Info',
        'reportedAtUtc: 2026-10-24T01:02:03.000Z',
        'serverId: s',
        'agentId: ext-1',
        'runtime: external',
        'lastSeenAtUtc: 2026-10-24T01:01:30.000Z',
        'online: yes (window 120s)',
        'activity: online',
        'activityKind: none',
        'activityDetail: null',
        'lastActivityAtUtc: unknown',
        'statusObservedAtUtc: 2026-10-24T01:01:00.000Z',
        'statusProtocolAdoptedAtUtc: none (hook-derived status)',
        'providerKind: hosted',
        'provisioningState: active (sync pending)',
        'providerAgentId: prov-1',
        'provisioningLastError: TIMEOUT at 2026-10-24T00:00:00.000Z',
        'pushWebhook: disabled (too_many_failures)',
        'pushEndpointHost: hooks.example.com',
        'pushConsecutiveFailures: 3',
        'pushLastDeliveryAtUtc: none',
        'pushLastAttemptAtUtc: 2026-10-24T01:00:00.000Z',
        'pushLastError: HTTP 500',
        'eventsLastCursorPullAtUtc: 2026-10-24T01:01:00.000Z',
        'eventsPendingCursorAcks: 2',
        'githubConnection: connected (octo)',
        'slackConnection: unavailable (no_token)',
        'diagnosticsGeneratedAtUtc: 2026-10-24T01:02:00.000Z',
      ]);
    });

    test(
      'an external agent without the view says so, never managed-only fields',
      () {
        final text = buildAgentDiagnosticInfo(
          agent: _external,
          title: 'T',
          serverId: 's',
          activity: 'online',
          reportedAt: _at,
        );
        expect(text, endsWith('externalDiagnostics: unavailable'));
        expect(text, isNot(contains('machineId')));
        expect(text, isNot(contains('daemonVersion')));
      },
    );

    test('a push webhook that is not registered has no endpoint lines', () {
      final text = buildAgentDiagnosticInfo(
        agent: _external,
        title: 'T',
        serverId: 's',
        activity: 'online',
        externalDiagnostics: _diagnostics(push: false),
        reportedAt: _at,
      );
      expect(text, contains('pushWebhook: not_registered'));
      expect(text, isNot(contains('pushEndpointHost')));
    });

    test('a body without the view shape counts as unavailable', () {
      expect(admittedExternalDiagnostics({'presence': {}}), isNull);
      expect(admittedExternalDiagnostics('nope'), isNull);
      expect(admittedExternalDiagnostics(_diagnostics()), isNotNull);
    });
  });

  group('Copy Diagnostic Info', () {
    String? clipboard;
    setUp(() {
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('an external agent copies the external diagnostics', (
      tester,
    ) async {
      await pumpAgentPanel(
        tester,
        agent: _external,
        routes: {'/agents/ext-1/external-diagnostics': () => _diagnostics()},
      );
      final button = find.byKey(const ValueKey('agent-copy-diagnostic'));
      await tester.scrollUntilVisible(
        button,
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('fleet-detail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(button);
      await tester.pump();
      expect(clipboard, startsWith('Raft Diagnostic Info\nreportedAtUtc: '));
      expect(clipboard, contains('pushWebhook: disabled (too_many_failures)'));
      expect(clipboard, contains('githubConnection: connected (octo)'));
    });

    testWidgets('a failed diagnostics read copies "unavailable"', (
      tester,
    ) async {
      await pumpAgentPanel(tester, agent: _external);
      final button = find.byKey(const ValueKey('agent-copy-diagnostic'));
      await tester.scrollUntilVisible(
        button,
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('fleet-detail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(button);
      await tester.pump();
      expect(clipboard, endsWith('externalDiagnostics: unavailable'));
    });

    testWidgets('a managed agent copies the Web managed lines', (tester) async {
      await pumpAgentPanel(tester);
      final button = find.byKey(const ValueKey('agent-copy-diagnostic'));
      await tester.scrollUntilVisible(
        button,
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('fleet-detail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(button);
      await tester.pump();
      expect(clipboard, contains('machineId: m1'));
      expect(clipboard, contains('agentStatus: active'));
      expect(clipboard, contains('activityKind: offline'));
    });
  });
}
