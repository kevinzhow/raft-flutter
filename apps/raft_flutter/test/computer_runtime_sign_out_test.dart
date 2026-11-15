import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_auth.dart';
import 'package:raft_flutter/features/computer_runtime_sign_out_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_auth_fixture.dart';

/// Web v1.24 RuntimeSignOutDialog: the confirmation names the agents that use
/// the sign-in, runs the logout on the Computer, and says why it failed.
void main() {
  late FixtureWorkspace w;
  late FakeComputerApi api;

  Future<void> open(
    WidgetTester t, {
    String runtimeId = 'claude',
    String runtime = 'claude',
    RuntimeAuthSignedInProvider? provider,
  }) async {
    w = await fixtureWorkspace(t);
    w.agents = [
      {
        'id': 'a1',
        'name': 'nova',
        'displayName': 'Nova',
        'runtime': 'claude',
        'machineId': 'c',
      },
      {'id': 'a2', 'name': 'zed', 'runtime': 'claude', 'machineId': 'c'},
      // Not this Computer, not this sign-in, deleted: none is listed.
      {'id': 'a3', 'name': 'far', 'runtime': 'claude', 'machineId': 'other'},
      {'id': 'a4', 'name': 'cod', 'runtime': 'codex', 'machineId': 'c'},
      {
        'id': 'a5',
        'name': 'gone',
        'runtime': 'claude',
        'machineId': 'c',
        'deletedAt': 'x',
      },
      {'id': 'a6', 'name': 'cli', 'runtime': 'kimi', 'machineId': 'c'},
      {
        'id': 'a7',
        'name': 'kimi-code',
        'runtime': 'kimi-sdk',
        'machineId': 'c',
      },
    ];
    await w.entityDirectory.preload();
    addTearDown(api.dispose);
    await t.pumpWidget(
      fixtureHost(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showComputerRuntimeSignOutDialog(
              context,
              controller: w,
              client: api.auth,
              serverId: 's',
              machineId: 'c',
              runtimeId: runtimeId,
              runtime: runtime,
              provider: provider,
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
    await t.tap(find.byKey(const ValueKey('runtime-sign-out-confirm')));
    await settle(t, 12);
  }

  setUp(() => api = FakeComputerApi());

  testWidgets('names the Computer and every agent on it that uses the '
      'sign-in', (t) async {
    await open(t);
    expect(find.text('Sign out of Claude Code?'), findsOneWidget);
    expect(find.text('Claude Code will be signed out on build-box.'), findsOne);
    expect(
      find.text(
        'These 2 agents on this Computer use Claude Code. They keep running, but their next start can\'t authenticate until someone signs in again:',
      ),
      findsOneWidget,
    );
    final list = find.byKey(const ValueKey('runtime-sign-out-agents'));
    for (final name in ['Nova', 'zed']) {
      expect(
        find.descendant(of: list, matching: find.text(name)),
        findsOneWidget,
      );
    }
    for (final name in ['far', 'cod', 'gone', 'cli', 'kimi-code']) {
      expect(
        find.descendant(of: list, matching: find.text(name)),
        findsNothing,
      );
    }
  });

  testWidgets('Kimi: Kimi Code\'s agents, not Kimi CLI\'s', (t) async {
    await open(t, runtimeId: 'kimi-sdk', runtime: 'kimi');
    final list = find.byKey(const ValueKey('runtime-sign-out-agents'));
    expect(
      find.descendant(of: list, matching: find.text('kimi-code')),
      findsOne,
    );
    expect(find.descendant(of: list, matching: find.text('cli')), findsNothing);
    expect(
      find.text(
        'This agent on this Computer uses Kimi Code. It keeps running, but its next start can\'t authenticate until someone signs in again:',
      ),
      findsOneWidget,
    );
  });

  testWidgets('no agent uses it: it says so', (t) async {
    await open(t, runtimeId: 'codebuddy', runtime: 'codebuddy');
    expect(find.byKey(const ValueKey('runtime-sign-out-agents')), findsNothing);
    expect(
      find.text('No agents on this Computer use CodeBuddy Code.'),
      findsOneWidget,
    );
  });

  testWidgets('confirm runs the logout, drops the cached view and closes', (
    t,
  ) async {
    api.answers['/claude/logout'] = (_) => {
      'result': {'kind': 'logged_out'},
    };
    await open(t);
    final reads = api.gets.length;
    await api.auth.read('s', 'c');
    await confirm(t);
    expect(api.posts.single, endsWith('/runtime-auth/claude/logout'));
    expect(api.bodies.values.single, isEmpty);
    expect(find.text('Sign out of Claude Code?'), findsNothing);
    // The cached view is dropped: the next read asks the server again.
    final before = api.gets.length;
    await api.auth.read('s', 'c');
    expect(api.gets.length, greaterThan(before));
    expect(reads, lessThan(api.gets.length));
  });

  testWidgets('a Pi provider: only that provider; a key is removed', (t) async {
    api.answers['/pi/logout'] = (_) => {
      'result': {'kind': 'logged_out'},
    };
    await open(
      t,
      runtimeId: 'pi',
      runtime: 'pi',
      provider: const RuntimeAuthSignedInProvider(
        id: 'openai',
        label: 'OpenAI',
        method: 'api_key',
      ),
    );
    expect(find.text('Remove the OpenAI key?'), findsOneWidget);
    expect(
      find.text('The OpenAI key will be removed from Pi on build-box.'),
      findsOneWidget,
    );
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('No agents on this Computer use Pi.'), findsOneWidget);
    await confirm(t);
    expect(api.bodies.values.single, {'providerId': 'openai'});
  });

  for (final (answer, text) in [
    (
      {'kind': 'failed', 'reason': 'still_logged_in'},
      "Still signed in: an API key in that Computer's environment is used",
    ),
    (
      {'kind': 'failed', 'reason': 'timed_out'},
      'The Computer did not answer in time. Try again.',
    ),
    (
      {'kind': 'failed', 'reason': 'busy'},
      'A sign-in is in progress on this Computer. Finish or cancel it, then try again.',
    ),
    (
      {'kind': 'failed', 'reason': 'rejected'},
      'Claude Code could not be signed out. Try again.',
    ),
    (
      {'kind': 'unsupported', 'reason': 'not_installed'},
      'Claude Code is not installed on this Computer.',
    ),
    (
      {'kind': 'unsupported', 'reason': 'version_unsupported'},
      'Claude Code on this Computer is too old to sign in from the web; update it there.',
    ),
  ]) {
    testWidgets('the Computer says ${answer['reason']}: the dialog stays open '
        'with the reason, and the cached view is dropped', (t) async {
      api.answers['/claude/logout'] = (_) => {'result': answer};
      await open(t);
      await confirm(t);
      expect(find.text(text), findsOneWidget);
      expect(find.text('Sign out of Claude Code?'), findsOneWidget);
    });
  }

  testWidgets('a request the server refused: 403 names who may', (t) async {
    api.answers['/claude/logout'] = (_) =>
        throw const RaftApiException('no', status: 403);
    await open(t);
    await confirm(t);
    expect(
      find.text(
        'Only the person who connected this Computer, or an owner or admin, can sign its runtimes in or out.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Cancel closes it without a request', (t) async {
    await open(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(find.text('Sign out of Claude Code?'), findsNothing);
    expect(api.posts, isEmpty);
  });
}
