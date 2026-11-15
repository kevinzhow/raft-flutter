import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/computer_runtime_sign_in_notice.dart';

import 'support/runtime_auth_fixture.dart';

/// Web v1.24 RuntimeSignInNotice: under a runtime picker, the picked runtime
/// is signed out on the Computer: it says so and offers Sign in.
void main() {
  late FixtureWorkspace w;
  late FakeComputerApi api;
  const notice = ValueKey('runtime-picker-not-signed-in');

  Future<void> mount(
    WidgetTester t,
    String runtimeId, {
    bool enabled = true,
    String? machineId = 'c',
  }) async {
    w = await fixtureWorkspace(t);
    addTearDown(api.dispose);
    await t.pumpWidget(
      fixtureHost(
        SizedBox(
          width: 420,
          child: RuntimeSignInNotice(
            controller: w,
            serverId: 's',
            machineId: machineId,
            machineName: 'build-box',
            runtimeId: runtimeId,
            enabled: enabled,
            client: api.auth,
          ),
        ),
      ),
    );
    await settle(t);
  }

  Map<String, dynamic> out(String runtime) => authView(
    runtimes: {
      runtime: {'kind': 'logged_out'},
    },
  );

  setUp(() => api = FakeComputerApi());

  testWidgets('a signed-out runtime: the warning and Sign in; nothing is '
      'blocked', (t) async {
    api.view = out('claude');
    await mount(t, 'claude');
    expect(find.byKey(notice), findsOneWidget);
    expect(find.text('Claude Code is not signed in on build-box.'), findsOne);
    expect(find.byKey(const ValueKey('runtime-picker-sign-in')), findsOne);
  });

  testWidgets('signed in, or no status yet: no notice', (t) async {
    api.view = authView(
      runtimes: {
        'claude': {'kind': 'logged_in'},
      },
    );
    await mount(t, 'claude');
    expect(find.byKey(notice), findsNothing);
  });

  testWidgets('Sign in ends: the notice reads the Computer again and goes '
      'when it is signed in (the hint is resolved)', (t) async {
    api.view = out('claude');
    await mount(t, 'claude');
    api.view = authView(
      runtimes: {
        'claude': {'kind': 'logged_in'},
      },
    );
    await t.tap(find.byKey(const ValueKey('runtime-picker-sign-in')));
    await settle(t, 6);
    // The dialog is open over the page: close it as a person would.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(t, 10);
    expect(find.byKey(notice), findsNothing);
  });

  testWidgets('the Computer reports a new status: the notice follows it, no '
      'reload', (t) async {
    api.view = authView(
      runtimes: {
        'claude': {'kind': 'logged_in'},
      },
    );
    await mount(t, 'claude');
    expect(find.byKey(notice), findsNothing);
    api.view = out('claude');
    api.events.add(
      const RaftEvent('machine:runtime_auth:updated', {'machineId': 'c'}),
    );
    await settle(t);
    expect(find.byKey(notice), findsOneWidget);
  });

  testWidgets('a person who may not act sees the state without Sign in', (
    t,
  ) async {
    api.view = authView(
      canAct: false,
      runtimes: {
        'claude': {'kind': 'logged_out'},
      },
    );
    await mount(t, 'claude');
    expect(find.byKey(notice), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-picker-sign-in')), findsNothing);
  });

  for (final runtime in ['qwen', 'pi', 'kimi', 'builtin']) {
    testWidgets('$runtime has no single sign-in: no notice, no read', (
      t,
    ) async {
      api.view = authView(
        supported: ['claude', 'codex', 'qwen', 'pi'],
        runtimes: {
          'qwen': {'kind': 'logged_out'},
          'pi': {'kind': 'logged_out'},
        },
      );
      await mount(t, runtime);
      expect(find.byKey(notice), findsNothing);
      expect(api.gets, isEmpty);
    });
  }

  testWidgets('not enabled: the person may not see the state at all, so '
      'nothing is read', (t) async {
    api.view = out('claude');
    await mount(t, 'claude', enabled: false);
    expect(find.byKey(notice), findsNothing);
    expect(api.gets, isEmpty);
  });

  testWidgets('no Computer picked yet: nothing', (t) async {
    api.view = out('claude');
    await mount(t, 'claude', machineId: null);
    expect(find.byKey(notice), findsNothing);
    expect(api.gets, isEmpty);
  });
}
