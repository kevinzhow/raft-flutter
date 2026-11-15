import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/computer_runtime_limit_reset_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_auth_fixture.dart';

/// Web v1.24 RuntimeLimitResetDialog + limitResetOutcome + limitResetAttemptKey.
void main() {
  late FakeComputerApi api;
  final outcomes = <RuntimeLimitResetOutcome>[];

  Future<void> open(
    WidgetTester t, {
    String? account = 'ali****@example.com',
    int resets = 2,
    String key = 'attempt-key-0123456789',
  }) async {
    addTearDown(api.dispose);
    await t.pumpWidget(
      fixtureHost(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showComputerRuntimeLimitResetDialog(
              context,
              client: api.auth,
              serverId: 's',
              machineId: 'c',
              runtimeId: 'codex',
              provider: 'codex',
              account: account,
              resetsAvailable: resets,
              idempotencyKey: key,
              onOutcome: outcomes.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await settle(t, 10);
  }

  Future<void> confirm(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('runtime-limit-reset-confirm')));
    await settle(t, 12);
  }

  setUp(() {
    api = FakeComputerApi();
    outcomes.clear();
  });

  testWidgets('names the account and how many resets are left', (t) async {
    await open(t);
    expect(find.text('Use a limit reset?'), findsOneWidget);
    final message = t.widget<Text>(
      find.byKey(const ValueKey('runtime-limit-reset-message')),
    );
    expect(
      message.textSpan?.toPlainText(),
      "This uses one of ali****@example.com's resets to restore its Codex CLI usage limits now. 2 resets left.",
    );
    // One left reads in the singular; an account with no name is "this account".
    await t.pumpWidget(const SizedBox());
    api = FakeComputerApi();
    await open(t, account: null, resets: 1);
    expect(
      t
          .widget<Text>(
            find.byKey(const ValueKey('runtime-limit-reset-message')),
          )
          .textSpan
          ?.toPlainText(),
      "This uses one of this account's resets to restore its Codex CLI usage limits now. 1 reset left.",
    );
  });

  testWidgets('confirm sends the attempt\'s key and closes on a reset', (
    t,
  ) async {
    api.answers['/limit-reset'] = (_) => {
      'result': {'kind': 'reset'},
      'snapshot': usageSnapshot(provider: 'codex')['snapshot'],
    };
    await open(t);
    await confirm(t);
    expect(
      api.bodies.values.single,
      containsPair('idempotencyKey', 'attempt-key-0123456789'),
    );
    expect(find.text('Use a limit reset?'), findsNothing);
    expect(outcomes.single.result?['kind'], 'reset');
    expect(outcomes.single.snapshot, isNotNull);
  });

  for (final kind in ['nothing_to_reset', 'no_reset', 'already_redeemed']) {
    testWidgets('$kind closes the dialog; the card says it', (t) async {
      api.answers['/limit-reset'] = (_) => {
        'result': {'kind': kind},
      };
      await open(t);
      await confirm(t);
      expect(find.text('Use a limit reset?'), findsNothing);
      expect(limitResetNoteSource(outcomes.single.result!), isNotNull);
      expect(limitResetOutcomeIsSettled(outcomes.single.result), isTrue);
    });
  }

  for (final (answer, text) in [
    (
      {'kind': 'reauth_required'},
      'Sign in to Codex CLI again on this Computer. No reset was used.',
    ),
    (
      {'kind': 'unsupported', 'reason': 'version_unsupported'},
      "Codex CLI on this Computer can't use a limit reset from here. No reset was used.",
    ),
    (
      {'kind': 'unsupported', 'reason': 'not_installed'},
      'Codex CLI is not installed on this Computer.',
    ),
    (
      {'kind': 'unknown'},
      "We couldn't confirm whether a reset was used. Try again — it won't use a second one.",
    ),
  ]) {
    testWidgets('${answer['kind']}: the dialog stays open with the reason and '
        'the outcome still reaches the card', (t) async {
      api.answers['/limit-reset'] = (_) => {'result': answer};
      await open(t);
      await confirm(t);
      expect(find.text(text), findsOneWidget);
      expect(find.text('Use a limit reset?'), findsOneWidget);
      expect(outcomes.single.result?['kind'], answer['kind']);
    });
  }

  testWidgets('only an unknown outcome keeps the attempt open', (t) async {
    expect(limitResetOutcomeIsSettled(null), isFalse);
    expect(limitResetOutcomeIsSettled({'kind': 'unknown'}), isFalse);
    for (final kind in [
      'reset',
      'nothing_to_reset',
      'no_reset',
      'already_redeemed',
      'reauth_required',
      'unsupported',
    ]) {
      expect(limitResetOutcomeIsSettled({'kind': kind}), isTrue, reason: kind);
    }
  });

  for (final (error, text) in <(Object, String)>[
    (
      const RaftApiException('x', status: 403),
      'Only the person who connected this Computer, or an owner or admin, can use its resets.',
    ),
    (
      const RaftApiException('x', status: 429),
      'Too many attempts on this Computer. No reset was used. Try again in a few minutes.',
    ),
    (
      const RaftApiException('x', status: 400),
      'This request was refused before it reached the Computer. No reset was used.',
    ),
    (
      const RaftApiException('x', status: 504),
      "We couldn't confirm whether a reset was used. Try again — it won't use a second one.",
    ),
  ]) {
    testWidgets('a failed request (${(error as RaftApiException).status}): '
        'said in words, with a null outcome so the card reads usage again', (
      t,
    ) async {
      api.answers['/limit-reset'] = (_) => throw error;
      await open(t);
      await confirm(t);
      expect(find.text(text), findsOneWidget);
      expect(outcomes.single.result, isNull);
      expect(outcomes.single.snapshot, isNull);
    });
  }

  test('one idempotency key per (server, machine, provider) until the '
      'outcome is settled', () {
    var n = 0;
    final keys = RuntimeLimitResetAttemptKeys(mint: () => 'key-${++n}');
    final codex = RuntimeLimitResetAttemptKeys.subject('s', 'c', 'codex');
    final other = RuntimeLimitResetAttemptKeys.subject('s', 'd', 'codex');
    expect(keys.keyFor(codex), 'key-1');
    // Retrying an attempt whose outcome was never learned: the same key.
    expect(keys.keyFor(codex), 'key-1');
    // Another Computer never inherits it.
    expect(keys.keyFor(other), 'key-2');
    keys.forget(codex);
    expect(keys.keyFor(codex), 'key-3');
    expect(keys.keyFor(other), 'key-2');
  });

  test('a minted key is a UUID the server takes', () {
    final key = RuntimeLimitResetAttemptKeys.instance.keyFor('x');
    expect(RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(key), isTrue);
    expect(key, hasLength(36));
    RuntimeLimitResetAttemptKeys.instance.forget('x');
  });
}
