import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/bulk_agent_model_change.dart';

Map<String, dynamic> row([Map<String, dynamic> extra = const {}]) => {
  'id': 'a',
  'runtime': 'codex',
  'model': 'old',
  'reasoningEffort': 'medium',
  'envVars': {'OWN': 'first'},
  ...extra,
};

const target = BulkModelTarget('codex', 'new', 'medium');

void main() {
  test(
    'bulk selection excludes provider/schema and model-ignoring runtimes',
    () {
      for (final runtime in ['builtin', 'pi', 'kimi-sdk', 'antigravity']) {
        expect(bulkSelectableRuntime(runtime), isFalse, reason: runtime);
      }
      for (final runtime in ['codex', 'claude', 'grok', 'cursor', 'copilot']) {
        expect(bulkSelectableRuntime(runtime), isTrue, reason: runtime);
      }
    },
  );

  test(
    'custom settings and external agents never receive a rewritten config',
    () {
      for (final fields in [
        {'external': true},
        {'runtime': 'builtin'},
        {
          'runtimeConfig': {'runtime': 'claude'},
        },
        {
          'runtimeConfig': {
            'runtime': 'codex',
            'model': {'kind': 'custom', 'name': 'mine'},
          },
        },
        {
          'runtimeConfig': {
            'runtime': 'codex',
            'model': {'kind': 'preset', 'id': 'old'},
            'provider': {'kind': 'custom'},
          },
        },
        {
          'runtimeConfig': {
            'runtime': 'codex',
            'model': {'kind': 'preset', 'id': 'old'},
            'command': 'custom --arg',
          },
        },
      ]) {
        final plan = planBulkModelChange([
          BulkModelAgent(row(fields), running: true),
        ], target);
        expect(plan.single.action, BulkModelAction.skip, reason: '$fields');
        expect(plan.single.skip, BulkModelSkip.customSettings);
      }
    },
  );

  test(
    'admission applies to runtime switches; identical targets are skipped',
    () {
      final plan = planBulkModelChange([
        BulkModelAgent(
          row({'runtime': 'claude'}),
          running: true,
          targetRuntimeAllowed: false,
        ),
        BulkModelAgent(row({'model': 'new'}), running: false),
        BulkModelAgent(row(), running: true, targetRuntimeAllowed: false),
      ], target);
      expect(plan.map((e) => e.skip), [
        BulkModelSkip.runtimeUnavailable,
        BulkModelSkip.noChange,
        null,
      ]);
      expect(plan.last.restarts, isTrue);
    },
  );

  test('each agent retains its own environment and same-runtime fast mode', () {
    final input = row({
      'runtimeConfig': {
        'runtime': 'codex',
        'model': {'kind': 'preset', 'id': 'old'},
        'mode': {'kind': 'fast'},
        'envVars': {'OWN': 'structured', 'EMPTY': ''},
      },
    });
    final update = buildBulkAgentUpdate(
      BulkModelAgent(input, running: true),
      target,
    );
    final config = update['runtimeConfig'] as Map;
    expect(config['envVars'], {'OWN': 'structured', 'EMPTY': ''});
    expect(config['mode'], {'kind': 'fast'});
    expect(config['model'], {'kind': 'preset', 'id': 'new'});
    final switched = buildBulkAgentUpdate(
      BulkModelAgent(input, running: true),
      const BulkModelTarget('claude', 'sonnet', null),
    );
    expect((switched['runtimeConfig'] as Map)['mode'], {'kind': 'default'});
    expect(input['model'], 'old');
  });

  test(
    'restart pending is not no-change; a different target becomes a save',
    () {
      final pending = BulkModelAgent(
        row({'model': 'new'}),
        running: false,
        phase: BulkUnfinishedPhase.restartPending,
      );
      expect(
        planBulkModelChange([pending], target).single.action,
        BulkModelAction.restartOnly,
      );
      expect(
        planBulkModelChange([
          pending,
        ], const BulkModelTarget('codex', 'other', 'medium')).single.action,
        BulkModelAction.change,
      );
    },
  );

  test('success, skipped and failed requests have separate outcomes; fresh GET decides retry phase', () async {
    final calls = <(String, String, dynamic)>[];
    final accepted = <Map<String, dynamic>>[];
    final runner = BulkModelExecutor(
      current: () => true,
      acceptAgent: accepted.add,
      request: (method, path, {data}) async {
        calls.add((method, path, data));
        if (path.endsWith('/b') && method == 'PATCH') {
          throw StateError('restart failed');
        }
        return {
          'id': path.split('/').last,
          'runtime': 'codex',
          'model': 'new',
          'reasoningEffort': 'medium',
        };
      },
    );
    final result = await runner.apply(
      planBulkModelChange([
        BulkModelAgent(row(), running: true),
        BulkModelAgent(row({'id': 'b'}), running: true),
        BulkModelAgent(row({'id': 'c', 'model': 'new'}), running: false),
      ], target),
      target,
      now: () => DateTime.utc(2026),
      stateChanged: (_, _) {},
    );
    expect(result!.changed, ['a']);
    expect(result.skipped, ['c']);
    expect(result.unfinished, {'b': BulkUnfinishedPhase.restartPending});
    expect(result.total, 2);
    expect(calls.where((e) => e.$2.endsWith('/c')), isEmpty);
    expect((calls.first.$3 as Map)['restartMode'], 'restart');
    expect(accepted.map((e) => e['id']), containsAll(['a', 'b']));
  });

  for (final freshFails in [false, true]) {
    test(
      'failed save stays unfinished when fresh GET ${freshFails ? 'also fails' : 'shows old config'}',
      () async {
        final runner = BulkModelExecutor(
          current: () => true,
          acceptAgent: (_) {},
          request: (method, path, {data}) async {
            if (method == 'PATCH' || freshFails) throw StateError('failure');
            return row();
          },
        );
        final receipt = await runner.apply(
          planBulkModelChange([BulkModelAgent(row(), running: false)], target),
          target,
          now: DateTime.now,
          stateChanged: (_, _) {},
        );
        expect(receipt!.unfinished, {'a': BulkUnfinishedPhase.saveFailed});
        expect(receipt.changed, isEmpty);
      },
    );
  }

  test('retrying a saved config only restarts; repeated reset/read failure keeps that phase', () async {
    final methods = <String>[];
    var fail = true;
    final runner = BulkModelExecutor(
      current: () => true,
      acceptAgent: (_) {},
      request: (method, path, {data}) async {
        methods.add('$method $path');
        if (fail) throw StateError('offline');
        expect(data, {'mode': 'restart'});
        return {'ok': true};
      },
    );
    final plan = planBulkModelChange([
      BulkModelAgent(
        row({'model': 'new'}),
        running: false,
        phase: BulkUnfinishedPhase.restartPending,
      ),
    ], target);
    final first = await runner.apply(
      plan,
      target,
      now: DateTime.now,
      stateChanged: (_, _) {},
    );
    expect(first!.unfinished, {'a': BulkUnfinishedPhase.restartPending});
    fail = false;
    final second = await runner.apply(
      plan,
      target,
      now: DateTime.now,
      stateChanged: (_, _) {},
    );
    expect(second!.success, isTrue);
    expect(methods, [
      'POST /agents/a/reset',
      'GET /agents/a',
      'POST /agents/a/reset',
    ]);
  });

  test('authority loss during an HTTP response publishes neither rows nor receipts', () async {
    final pending = Completer<dynamic>();
    var current = true;
    final accepted = <Map<String, dynamic>>[];
    final states = <String>[];
    final runner = BulkModelExecutor(
      current: () => current,
      acceptAgent: accepted.add,
      request: (_, _, {data}) => pending.future,
    );
    final operation = runner.apply(
      planBulkModelChange([BulkModelAgent(row(), running: false)], target),
      target,
      now: DateTime.now,
      stateChanged: (_, state) => states.add(state),
    );
    current = false;
    pending.complete(row({'model': 'new'}));
    expect(await operation, isNull);
    expect(accepted, isEmpty);
    expect(states, ['saving']);
  });

  test(
    'success/highlight deadlines do not replay; partial failures stay visible',
    () {
      final now = DateTime.utc(2026);
      BulkModelReceipt receipt(Map<String, BulkUnfinishedPhase> unfinished) =>
          BulkModelReceipt(
            target: target,
            total: 1,
            changed: ['a'],
            skipped: [],
            unfinished: unfinished,
            now: now,
          );
      final success = receipt({});
      expect(success.visibleAt(now), isTrue);
      expect(
        success.highlightsAt(now.add(const Duration(seconds: 3))),
        isEmpty,
      );
      expect(success.visibleAt(now.add(const Duration(seconds: 5))), isFalse);
      expect(
        receipt({'b': BulkUnfinishedPhase.saveFailed})
            .visibleAt(now.add(const Duration(days: 1))),
        isTrue,
      );
    },
  );
}
