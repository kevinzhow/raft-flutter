import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/runtime_usage_chip.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_auth_fixture.dart';

/// Web v1.24 RuntimeAccountUsageChip + RuntimeUsageSurface: the runtime chip's
/// sign-in state and the card's actions, against a fake Computer.
void main() {
  late FixtureWorkspace w;
  late FakeComputerApi api;
  const key = ValueKey('x');

  Future<void> mount(
    WidgetTester t,
    String runtimeId, {
    String name = 'Claude Code',
    bool touch = false,
    Widget Function(RuntimeChipState state)? chipBuilder,
  }) async {
    w = await fixtureWorkspace(t);
    addTearDown(api.dispose);
    await t.pumpWidget(
      fixtureHost(
        touch: touch,
        runtimeUsageGateChip(
          controller: w,
          enabled: true,
          runtimeId: runtimeId,
          machineId: 'c',
          label: name,
          runtimeVersion: '2.1.0',
          client: api.usageClient,
          authClient: api.auth,
          chipBuilder: chipBuilder,
          chip: (status) => RaftRuntimeChip(
            key: key,
            label: name,
            detected: true,
            trailing: status,
          ),
        ),
      ),
    );
    await settle(t);
  }

  /// Opens the card with a pointer hover (a finger: a tap, the sheet).
  TestGesture? hovering;
  Future<TestGesture?> open(WidgetTester t, {bool touch = false}) async {
    await hovering?.removePointer();
    hovering = null;
    if (touch) {
      await t.tap(find.byType(RaftRuntimeUsageChip));
      await settle(t, 10);
      return null;
    }
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.byType(RaftRuntimeUsageChip)));
    await t.pump(const Duration(milliseconds: 210));
    await settle(t);
    hovering = mouse;
    addTearDown(mouse.removePointer);
    return mouse;
  }

  Future<void> tapKey(WidgetTester t, String id) async {
    await t.tap(find.byKey(ValueKey(id)));
    await settle(t, 10);
  }

  setUp(() => api = FakeComputerApi());

  testWidgets('signed out: a warning chip in words without the dot; the card '
      'offers only Sign in, with no usage', (t) async {
    api
      ..view = authView(
        runtimes: {
          'claude': {'kind': 'logged_out'},
        },
      )
      ..usage = usageSnapshot();
    await mount(t, 'claude');
    // The chip is a warning Badge, ends " (not signed in)", has no dot.
    expect(find.text('Claude Code (not signed in)'), findsOneWidget);
    expect(find.byType(RaftRuntimeUsageStatus), findsNothing);
    await open(t);
    expect(find.byKey(const ValueKey('runtime-auth-logged-out')), findsOne);
    expect(find.text('Signed out'), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-auth-sign-in')), findsOne);
    // No usage, no Refresh: signed out there is only the way to sign in.
    expect(find.byKey(const ValueKey('runtime-usage-refresh')), findsNothing);
    expect(find.text('Claude Code'), findsWidgets);
    expect(find.text('Claude Code usage'), findsNothing);
  });

  testWidgets('Sign in closes the card, and the view is read again once the '
      'dialog ends: the chip and the card follow it', (t) async {
    api
      ..view = authView(
        runtimes: {
          'claude': {'kind': 'logged_out'},
        },
      )
      ..usage = usageSnapshot();
    await mount(t, 'claude');
    await open(t);
    final reads = api.gets.where((p) => p.endsWith('/runtime-auth')).length;
    // The Computer reports the sign-in done (the dialog's own job).
    api.view = authView(
      runtimes: {
        'claude': {
          'kind': 'logged_in',
          'account': {'maskedLabel': 'ali****@example.com'},
        },
      },
    );
    await tapKey(t, 'runtime-auth-sign-in');
    // A dialog takes over from the card: the card is gone.
    expect(find.byKey(const ValueKey('runtime-usage-card')), findsNothing);
    // The person closes the dialog: the card reads the Computer's state.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(t, 12);
    expect(
      api.gets.where((p) => p.endsWith('/runtime-auth')).length,
      greaterThan(reads),
    );
    expect(find.text('Claude Code (not signed in)'), findsNothing);
    expect(find.byType(RaftRuntimeUsageStatus), findsOneWidget);
  });

  testWidgets('signed in: Sign out is a ghost action; its confirmation signs '
      'out and the card shows the signed-out state (and no usage)', (t) async {
    api
      ..view = authView(
        runtimes: {
          'claude': {'kind': 'logged_in'},
        },
      )
      ..usage = usageSnapshot()
      ..answers['/claude/logout'] = (_) {
        // The Computer now says it is signed out.
        api.view = authView(
          runtimes: {
            'claude': {'kind': 'logged_out'},
          },
        );
        return {
          'result': {'kind': 'logged_out'},
        };
      };
    await mount(t, 'claude');
    expect(find.byType(RaftRuntimeUsageStatus), findsOneWidget);
    await open(t);
    expect(find.text('Claude Code usage'), findsOneWidget);
    await tapKey(t, 'runtime-auth-sign-out');
    expect(find.byKey(const ValueKey('runtime-usage-card')), findsNothing);
    expect(find.text('Sign out of Claude Code?'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('runtime-sign-out-confirm')));
    await settle(t, 12);
    expect(api.posts.any((p) => p.endsWith('/claude/logout')), isTrue);
    // The dialog closed, the chip now says it in words.
    expect(find.text('Sign out of Claude Code?'), findsNothing);
    expect(find.text('Claude Code (not signed in)'), findsOneWidget);
  });

  testWidgets('a person who may not act sees the state, never a button; '
      'availability says why there is none', (t) async {
    api
      ..view = authView(
        canAct: false,
        runtimes: {
          'claude': {'kind': 'logged_out'},
        },
      )
      ..usage = usageSnapshot();
    await mount(t, 'claude');
    await open(t);
    expect(find.text('Signed out'), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-auth-sign-in')), findsNothing);
    expect(find.byKey(const ValueKey('runtime-auth-unavailable')), findsNothing);
  });

  for (final (availability, text) in [
    (
      'computer_upgrade_required',
      'Upgrade this Computer to sign in from here',
    ),
    (
      'computer_not_attached',
      "This Computer has no owner, so its runtimes can't be signed in from here",
    ),
  ]) {
    testWidgets('availability $availability: the hint, not the button', (
      t,
    ) async {
      api
        ..view = authView(
          availability: availability,
          runtimes: {
            'qoder': {'kind': 'logged_out'},
          },
        )
        ..usage = usageSnapshot();
      await mount(t, 'qoder', name: 'Qoder');
      await open(t);
      expect(find.text(text), findsOneWidget);
      expect(find.byKey(const ValueKey('runtime-auth-sign-in')), findsNothing);
    });
  }

  testWidgets('a Computer from before the runtime\'s sign-in: the upgrade '
      'hint (Qoder is not in its list)', (t) async {
    api.view = authView(
      supported: ['claude', 'codex'],
      runtimes: {
        'qoder': {'kind': 'logged_out'},
      },
    );
    await mount(t, 'qoder', name: 'Qoder');
    await open(t);
    expect(
      find.text('Upgrade this Computer to sign in from here'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('runtime-auth-sign-in')), findsNothing);
  });

  testWidgets('the CLI is missing: the reason and its install command; an '
      'installation that cannot be signed in gets the sentence alone', (
    t,
  ) async {
    api
      ..view = authView(
        runtimes: {
          'claude': {'kind': 'unavailable', 'reason': 'not_installed'},
        },
      )
      ..usage = usageSnapshot();
    await mount(t, 'claude');
    await open(t);
    expect(find.byKey(const ValueKey('runtime-auth-cli-unavailable')), findsOne);
    expect(
      find.text(
        "Install this runtime's command-line tool on the Computer, then use Rescan runtimes on the Computer's page.",
      ),
      findsOneWidget,
    );
    expect(find.text('On macOS or Linux:'), findsOneWidget);
    // The command, in its copyable code box (word-break marks aside).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('runtime-auth-install-line')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').replaceAll('\u200b', '') ==
                  'npm install -g @anthropic-ai/claude-code',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('runtime-auth-sign-in')), findsNothing);
  });

  testWidgets('an installation the Computer cannot use: no install command', (
    t,
  ) async {
    api
      ..view = authView(
        runtimes: {
          'claude': {
            'kind': 'unavailable',
            'reason': 'unsupported_installation',
          },
        },
      )
      ..usage = usageSnapshot();
    await mount(t, 'claude');
    await open(t);
    expect(
      find.text('Sign in to this runtime on the Computer itself.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('runtime-auth-install-line')), findsNothing);
  });

  testWidgets('Qoder has no usage: an auth-only card titled by the runtime, '
      'saying signed in, with no Sign out and no Refresh', (t) async {
    api.view = authView(
      supported: ['qoder'],
      runtimes: {
        'qoder': {'kind': 'logged_in'},
      },
    );
    await mount(t, 'qoder', name: 'Qoder');
    // No usage: no health dot on the chip either.
    expect(find.byType(RaftRuntimeUsageStatus), findsNothing);
    await open(t);
    expect(find.text('Qoder'), findsWidgets);
    expect(find.text('Qoder usage'), findsNothing);
    expect(find.byKey(const ValueKey('runtime-auth-logged-in')), findsOne);
    expect(find.byKey(const ValueKey('runtime-auth-sign-out')), findsNothing);
    expect(find.byKey(const ValueKey('runtime-usage-refresh')), findsNothing);
    expect(api.gets.any((p) => p.contains('runtime-account-usage')), isFalse);
  });

  testWidgets('Pi: one row per stored provider with its own Sign out / '
      'Remove, and Add provider; no provider is no "not signed in" chip', (
    t,
  ) async {
    api.view = authView(
      supported: ['claude', 'codex', 'pi'],
      runtimes: {
        'pi': {
          'kind': 'logged_in',
          'providers': [
            {
              'id': 'anthropic',
              'label': 'Anthropic',
              'method': 'oauth',
              'subscription': true,
            },
            {'id': 'openai', 'label': 'OpenAI', 'method': 'api_key'},
          ],
        },
      },
    );
    await mount(t, 'pi', name: 'Pi');
    await open(t);
    expect(find.byKey(const ValueKey('runtime-auth-providers')), findsOne);
    expect(find.text('Subscription account'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-auth-add-provider')), findsOne);
    expect(find.text('Remove'), findsOneWidget);
    await tapKey(t, 'runtime-auth-provider-sign-out-openai');
    expect(find.byKey(const ValueKey('runtime-usage-card')), findsNothing);
    expect(find.text('Remove the OpenAI key?'), findsOneWidget);
  });

  testWidgets('Pi with no stored sign-in: the plain chip (a key in the '
      'environment may still serve it) and "No provider signed in"', (
    t,
  ) async {
    api.view = authView(
      supported: ['claude', 'codex', 'pi'],
      runtimes: {
        'pi': {'kind': 'logged_out'},
      },
    );
    await mount(t, 'pi', name: 'Pi');
    expect(find.text('Pi (not signed in)'), findsNothing);
    await open(t);
    expect(find.byKey(const ValueKey('runtime-auth-no-providers')), findsOne);
    expect(find.byKey(const ValueKey('runtime-auth-add-provider')), findsOne);
  });

  testWidgets('Qwen: provider configured or not, never "signed out"; Connect '
      'provider opens the dialog and closes the card', (t) async {
    api.view = authView(
      supported: ['claude', 'codex', 'qwen'],
      runtimes: {
        'qwen': {'kind': 'logged_out'},
      },
    );
    await mount(t, 'qwen', name: 'Qwen Code');
    expect(find.text('Qwen Code (not signed in)'), findsNothing);
    await open(t);
    expect(find.text('No provider configured'), findsOneWidget);
    api.answers['GET /qwen/providers'] = (_) => {
      'kind': 'listed',
      'providers': <Object>[],
    };
    await tapKey(t, 'runtime-auth-connect-provider');
    expect(find.byKey(const ValueKey('runtime-usage-card')), findsNothing);
    expect(find.text('Connect Qwen Code to a provider'), findsOneWidget);
  });

  testWidgets('Antigravity is offered only where the server lists it', (
    t,
  ) async {
    api.view = authView(
      supported: ['claude', 'codex'],
      runtimes: {
        'antigravity': {'kind': 'logged_out'},
      },
    );
    await mount(t, 'antigravity', name: 'Antigravity CLI');
    // Not listed for this Computer: its badge stays as it was.
    expect(find.byType(RaftRuntimeUsageChip), findsNothing);
    expect(find.text('Antigravity CLI'), findsOneWidget);
    expect(api.gets.any((p) => p.contains('runtime-account-usage')), isFalse);
  });

  testWidgets('Antigravity listed by the server: the chip, its sign-in and '
      'usage', (t) async {
    api
      ..view = authView(
        supported: ['claude', 'codex', 'antigravity'],
        runtimes: {
          'antigravity': {'kind': 'logged_out'},
        },
      )
      ..usage = usageSnapshot(provider: 'antigravity');
    await mount(t, 'antigravity', name: 'Antigravity CLI');
    expect(find.byType(RaftRuntimeUsageChip), findsOneWidget);
    expect(find.text('Antigravity CLI (not signed in)'), findsOneWidget);
    expect(
      api.gets.any((p) => p.endsWith('/runtime-account-usage/antigravity')),
      isTrue,
    );
  });

  testWidgets('`unsupported` usage is "no usage": no attention, no refresh, '
      'the card is its sign-in alone', (t) async {
    api
      ..view = authView(
        runtimes: {
          'codex': {'kind': 'logged_in'},
        },
      )
      ..usage = {'state': 'unsupported'};
    await mount(t, 'codex', name: 'Codex CLI');
    expect(find.byType(RaftRuntimeUsageStatus), findsNothing);
    // Only a stale or missing snapshot is refreshed in the background.
    expect(api.posts.where((p) => p.endsWith('/refresh')), isEmpty);
    await open(t);
    expect(find.text('Codex CLI'), findsWidgets);
    expect(find.text('Codex CLI usage'), findsNothing);
    expect(find.byKey(const ValueKey('runtime-usage-refresh')), findsNothing);
    expect(find.byKey(const ValueKey('runtime-auth-logged-in')), findsOne);
  });

  group('Codex limit reset', () {
    setUp(() {
      api.usage = usageSnapshot(
        provider: 'codex',
        health: 'rate_limited',
        resets: 2,
        windowStatus: 'limit_reached',
        used: 1,
      );
    });

    Future<void> codex(WidgetTester t, {Map<String, dynamic>? view}) async {
      api.view =
          view ??
          authView(
            runtimes: {
              'codex': {'kind': 'logged_in'},
            },
          );
      await mount(t, 'codex', name: 'Codex CLI');
      await open(t);
    }

    testWidgets('shown beside the account that holds resets; the primary '
        'action while rate-limited', (t) async {
      await codex(t);
      expect(find.text('2 resets left'), findsOneWidget);
      expect(find.byKey(const ValueKey('runtime-limit-reset-action')), findsOne);
      expect(find.text('Used up · back in 3 hours'), findsOneWidget);
    });

    testWidgets('outline (not primary) while the account is healthy', (
      t,
    ) async {
      api.usage = usageSnapshot(provider: 'codex', resets: 1);
      await codex(t);
      expect(find.text('1 reset left'), findsOneWidget);
      expect(find.byKey(const ValueKey('runtime-limit-reset-action')), findsOne);
    });

    testWidgets('absent for a person who may not act, a signed-out runtime '
        'and an account with no reset', (t) async {
      await codex(t, view: authView(canAct: false));
      expect(
        find.byKey(const ValueKey('runtime-limit-reset-action')),
        findsNothing,
      );
    });

    testWidgets('no reset left: it says so and offers no button', (t) async {
      api.usage = usageSnapshot(provider: 'codex', resets: 0);
      await codex(t);
      expect(find.text('No resets left'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('runtime-limit-reset-action')),
        findsNothing,
      );
    });

    testWidgets('Use a reset: the confirmation, then the usage the Computer '
        'read after it is shown, with its note once in the action row', (
      t,
    ) async {
      api.answers['/runtime-account-usage/codex/limit-reset'] = (body) => {
        'result': {'kind': 'reset'},
        'snapshot': usageSnapshot(provider: 'codex', used: .1)['snapshot'],
      };
      await codex(t);
      await tapKey(t, 'runtime-limit-reset-action');
      expect(find.byKey(const ValueKey('runtime-usage-card')), findsNothing);
      expect(find.text('Use a limit reset?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('runtime-limit-reset-confirm')));
      await settle(t, 12);
      expect(find.text('Use a limit reset?'), findsNothing);
      // Reopen the card: the new usage and the note.
      await open(t);
      expect(find.text('Limits reset.'), findsOneWidget);
      expect(find.text('Used up · back in 3 hours'), findsNothing);
      expect(find.text('10% used · resets in 3 hours'), findsOneWidget);
      // The hint is resolved: the next manual refresh drops the note.
      await tapKey(t, 'runtime-usage-refresh');
      expect(find.text('Limits reset.'), findsNothing);
    });
  });

  testWidgets('a readiness that holds the runtime: the chip says it in words '
      'and the card leads with the notice', (t) async {
    api
      ..view = authView(
        runtimes: {
          'claude': {'kind': 'logged_in'},
        },
      )
      ..usage = usageSnapshot();
    w = await fixtureWorkspace(t);
    w.readiness = {
      'runtimes': {
        'claude': {
          'state': 'blocked',
          'scope': 'computer',
          'actor': 'computer_owner',
          'primary': {
            'code': 'runtime_missing',
            'behaviour': 'blocked',
            'resource': {'kind': 'runtime', 'runtime': 'claude'},
          },
        },
      },
    };
    await w.entityDirectory.preload();
    await t.pumpWidget(
      fixtureHost(
        runtimeUsageGateChip(
          controller: w,
          enabled: true,
          runtimeId: 'claude',
          machineId: 'c',
          label: 'Claude Code',
          client: api.usageClient,
          authClient: api.auth,
          chip: (status) =>
              RaftRuntimeChip(label: 'Claude Code', detected: true),
        ),
      ),
    );
    await settle(t);
    addTearDown(api.dispose);
    expect(find.text('Claude Code (Claude Code not installed)'), findsOne);
    await open(t);
    expect(find.byKey(const ValueKey('runtime-readiness-notice')), findsOne);
    expect(
      find.textContaining("This Computer's problem: Claude Code not installed"),
      findsOneWidget,
    );
  });

  testWidgets('on a finger the card is a bottom sheet; an action closes it '
      'before its dialog opens', (t) async {
    api
      ..view = authView(
        runtimes: {
          'claude': {'kind': 'logged_out'},
        },
      )
      ..usage = usageSnapshot();
    await mount(t, 'claude', touch: true);
    await open(t, touch: true);
    expect(find.byKey(const ValueKey('runtime-usage-sheet')), findsOneWidget);
    await tapKey(t, 'runtime-auth-sign-in');
    expect(find.byKey(const ValueKey('runtime-usage-sheet')), findsNothing);
  });

  testWidgets('a chip drawn by chipBuilder gets the whole state', (t) async {
    api
      ..view = authView(
        runtimes: {
          'claude': {'kind': 'logged_out'},
        },
      )
      ..usage = usageSnapshot();
    RuntimeChipState? seen;
    await mount(
      t,
      'claude',
      chipBuilder: (state) {
        seen = state;
        return const Text('custom chip');
      },
    );
    expect(find.text('custom chip'), findsOneWidget);
    expect(seen?.signedOut, isTrue);
    expect(seen?.attention, isTrue);
    expect(seen?.suffix, ' (not signed in)');
    expect(seen?.status, isNull);
  });
}
