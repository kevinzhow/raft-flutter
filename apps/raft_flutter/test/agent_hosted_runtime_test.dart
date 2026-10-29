// Cloud agents (Web hosted runtime): the pure rules of the wire views, the
// status states and the seven-day usage (Web tests for
// `describeHostedRuntime`, `summarizeHostedRuntimeUsage`, `HostedModelChoice`).
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/agent_hosted_runtime.dart';

Map<String, dynamic> _summary(
  String state, {
  bool syncPending = false,
  Map<String, dynamic>? lastError,
  bool retryNeedsModel = false,
  Map<String, dynamic>? push,
}) => {
  'provider': 'antiproton',
  'state': state,
  'syncPending': syncPending,
  'lastError': ?lastError,
  'retryNeedsModel': retryNeedsModel,
  'push': ?push,
};

const _error = {'code': 'provider_4xx', 'message': 'refused'};

void main() {
  group('status states', () {
    test('each state has its label, progress and retry rule', () {
      HostedRuntimeDescription d(Map<String, dynamic> j) =>
          HostedRuntimeSummary.parse(j)!.describe();
      expect(d(_summary('provisioning')).label, 'Setting up');
      expect(d(_summary('provisioning')).inProgress, isTrue);
      expect(d(_summary('provisioning')).canRetry, isFalse);
      expect(d(_summary('provisioning', lastError: _error)).canRetry, isTrue);
      expect(d(_summary('active')).label, 'Running');
      expect(d(_summary('active')).inProgress, isFalse);
      expect(d(_summary('active', syncPending: true)).label, 'Syncing changes');
      expect(d(_summary('active', syncPending: true)).inProgress, isTrue);
      expect(d(_summary('active', lastError: _error)).canRetry, isTrue);
      expect(d(_summary('failed')).label, 'Setup failed');
      expect(d(_summary('failed')).canRetry, isTrue);
      expect(d(_summary('failed')).presence, HostedStatePresence.error);
      expect(d(_summary('deleting')).label, 'Removing');
      expect(d(_summary('deleting')).inProgress, isTrue);
      expect(d(_summary('deleting')).canRetry, isFalse);
      expect(d(_summary('deleted')).label, 'Removed');
      expect(d(_summary('deleted')).tone, HostedStateTone.muted);
    });

    test('an unknown state or shape is no summary', () {
      expect(HostedRuntimeSummary.parse(_summary('migrating')), isNull);
      expect(HostedRuntimeSummary.parse(null), isNull);
      expect(HostedRuntimeSummary.parse('failed'), isNull);
    });

    test('push, last error and retryNeedsModel are read', () {
      final s = HostedRuntimeSummary.parse(
        _summary(
          'failed',
          lastError: _error,
          retryNeedsModel: true,
          push: {'registered': false, 'error': 'no endpoint'},
        ),
      )!;
      expect(s.lastErrorCode, 'provider_4xx');
      expect(s.lastErrorMessage, 'refused');
      expect(s.retryNeedsModel, isTrue);
      expect(s.pushRegistered, isFalse);
      expect(s.pushError, 'no endpoint');
      final bare = HostedRuntimeSummary.parse(_summary('active'))!;
      expect(bare.hasLastError, isFalse);
      expect(bare.pushRegistered, isNull);
      expect(bare.retryNeedsModel, isFalse);
    });
  });

  group('models list', () {
    test('picker absent means shown; false hides it', () {
      final old = HostedModelsList.parse({
        'models': [
          {'id': 'a', 'label': 'A', 'provider': 'p'},
        ],
        'default': 'a',
        'defaultLabel': 'A',
        'locked': false,
      });
      expect(hostedModelPickerShown(old), isTrue);
      expect(old!.labelOf('a'), 'A');
      expect(old.labelOf('zzz'), 'zzz');
      final off = HostedModelsList.parse({'models': [], 'picker': false});
      expect(hostedModelPickerShown(off), isFalse);
      expect(hostedModelPickerShown(null), isTrue);
    });

    test('a pick is sent only where the server lets people choose', () {
      final open = HostedModelsList.parse({'models': []});
      final locked = HostedModelsList.parse({'models': [], 'locked': true});
      final noPicker = HostedModelsList.parse({'models': [], 'picker': false});
      expect(hostedModelToSend(open, 'fast'), 'fast');
      expect(hostedModelToSend(open, null), isNull);
      expect(hostedModelToSend(locked, 'fast'), isNull);
      expect(hostedModelToSend(noPicker, 'fast'), isNull);
      expect(hostedModelToSend(null, 'fast'), isNull);
    });
  });

  group('usage', () {
    HostedUsageRow row(Map<String, dynamic> j) => HostedUsageRow.parse(j)!;
    final rows = [
      row({
        'at': '2026-10-20T00:00:00Z',
        'resource': 'model.tokens',
        'dimensions': {'kind': 'input', 'model': 'deepseek-flash'},
        'unit': 'tokens',
        'quantity': 1000,
        'cost': 0.004,
      }),
      row({
        'at': '2026-10-20T00:00:00Z',
        'resource': 'model.tokens',
        'dimensions': {'kind': 'output', 'model': 'deepseek-flash'},
        'unit': 'tokens',
        'quantity': 200,
        'cost': 0.001,
      }),
      row({
        'at': '2026-10-21T00:00:00Z',
        'resource': 'model.tokens',
        'dimensions': {'kind': 'cache_write_1h', 'model': 'other'},
        'unit': 'tokens',
        'quantity': 50,
        'cost': 0.002,
      }),
      row({
        'at': '2026-10-21T00:00:00Z',
        'resource': 'model.tokens',
        'dimensions': {'kind': 'cache_write_5m', 'model': 'other'},
        'unit': 'tokens',
        'quantity': 25,
      }),
      row({
        'at': '2026-10-21T00:00:00Z',
        'resource': 'tool.call',
        'dimensions': {'outcome': 'succeeded'},
        'unit': 'calls',
        'quantity': 3,
        'cost': null,
      }),
      row({
        'at': '2026-10-21T00:00:00Z',
        'resource': 'tool.call',
        'dimensions': {'outcome': 'failed'},
        'unit': 'calls',
        'quantity': 1,
      }),
    ];

    test('tokens add up by kind, calls by outcome, models by size', () {
      final s = summarizeHostedUsage(rows);
      expect(s.input, 1000);
      expect(s.output, 200);
      expect(s.cacheWrite, 75);
      expect(s.totalTokens, 1275);
      expect(s.toolTotal, 4);
      expect(s.toolSucceeded, 3);
      expect(s.toolFailed, 1);
      expect(s.hasUsage, isTrue);
      expect(s.topModels.map((m) => m.model), ['deepseek-flash', 'other']);
      expect(s.topModels.first.tokens, 1200);
    });

    test('cost is by UTC day, newest first; unpriced rows add nothing', () {
      final s = summarizeHostedUsage(rows);
      expect(s.hasCost, isTrue);
      expect([for (final d in s.costDays) d.day], ['2026-10-21', '2026-10-20']);
      expect(s.costDays.first.usd, closeTo(.002, 1e-9));
      expect(s.costDays.first.hasUnpriced, isTrue);
      expect(s.costDays.last.usd, closeTo(.005, 1e-9));
      expect(s.costTotal, closeTo(.007, 1e-9));
      expect(s.costPriced, isTrue);
      expect(s.costHasUnpriced, isTrue);
    });

    test('a day of only unpriced usage is "unpriced", not zero', () {
      final s = summarizeHostedUsage([
        row({
          'at': '2026-10-21T00:00:00Z',
          'resource': 'tool.call',
          'dimensions': {'outcome': 'succeeded'},
          'quantity': 2,
          'cost': null,
        }),
      ]);
      expect(s.costPriced, isFalse);
      expect(s.costDays.single.priced, isFalse);
      expect(s.costDays.single.hasUnpriced, isTrue);
    });

    test('no cost carried means no cost block; no rows no usage', () {
      final s = summarizeHostedUsage([
        row({
          'at': '2026-10-21T00:00:00Z',
          'resource': 'model.tokens',
          'dimensions': {'kind': 'input', 'model': 'm'},
          'quantity': 5,
        }),
      ]);
      expect(s.hasCost, isFalse);
      expect(summarizeHostedUsage(const []).hasUsage, isFalse);
    });

    test('rows with a non-finite quantity are dropped', () {
      expect(
        HostedUsageRow.parse({
          'at': '2026-10-21T00:00:00Z',
          'resource': 'model.tokens',
          'quantity': double.nan,
        }),
        isNull,
      );
    });

    test('the window is the last seven whole UTC days', () {
      final w = hostedUsageWindow(DateTime.utc(2026, 10, 24, 15, 30));
      expect(w.from, '2026-10-18T00:00:00.000Z');
      expect(w.to, '2026-10-24T15:30:00.000Z');
    });

    test('dollar amounts: cents, and under one cent is never \$0.00', () {
      String usd(num v, [String l = 'en']) =>
          hostedUsd(v, l, under: (a) => 'under $a');
      expect(usd(1.5), '\$1.50');
      expect(usd(0), '\$0.00');
      expect(usd(0.004), 'under \$0.01');
      expect(usd(0.01), '\$0.01');
    });
  });

  test('paths encode the agent id and the provider kind', () {
    expect(hostedRuntimeUsagePath('a b'), '/agents/a%20b/hosted-runtime/usage');
    expect(hostedRuntimeRetryPath('a/b'), '/agents/a%2Fb/hosted-runtime/retry');
    expect(
      hostedRuntimeModelsListPath('antiproton'),
      '/agent-runtime-providers/antiproton/models',
    );
  });
}
