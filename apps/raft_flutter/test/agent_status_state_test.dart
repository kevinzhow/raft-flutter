// Web v1.24.0 AgentStatusBadge.tsx and utils/activity.ts, as pure logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_status_state.dart';

AgentStatusChip chip({
  Map<String, dynamic> row = const {},
  String activity = 'online',
  String detailKind = 'idle',
  String detail = '',
  bool hasState = true,
  bool machineOffline = false,
  bool showDetail = true,
  bool canRestart = true,
  bool canModel = true,
  String? errorCode,
  Map<String, dynamic>? spawnFailure,
  String? spawnText,
}) => resolveAgentStatusChip(
  AgentStatusInput(
    row: {'status': 'active', 'model': 'gpt-5', ...row},
    activity: activity,
    detailKind: detailKind,
    detail: detail,
    hasActivityState: hasState,
    machineOffline: machineOffline,
    showDetail: showDetail,
    canRestart: canRestart,
    canOpenModelSettings: canModel,
    runtimeName: 'Codex CLI',
    modelLabel: (m) => m.toUpperCase(),
    errorCode: errorCode,
    spawnFailure: spawnFailure,
    spawnFailureText: spawnText,
  ),
);

String words(AgentStatusChip c) => c.text.raw
    ? c.text.source
    : c.text.source.replaceAllMapped(
        RegExp(r'\{(\w+)\}'),
        (m) => '${c.text.values[m[1]]}',
      );

void main() {
  group('blocked', () {
    test('the server blockedReason maps to the three held states', () {
      expect(
        agentBlockedStateOf('computer_version_unsupported'),
        AgentBlockedState.computerTooOld,
      );
      expect(
        agentBlockedStateOf('computer_version_unknown'),
        AgentBlockedState.computerTooOld,
      );
      expect(
        agentBlockedStateOf('computer_access_revoked'),
        AgentBlockedState.computerAccessRevoked,
      );
      expect(agentBlockedStateOf('something_new'), isNull);
      expect(agentBlockedStateOf(null), isNull);
    });

    test('too old: a warning chip that opens the Computer, no Retry', () {
      final c = chip(row: {'blockedReason': 'computer_version_unsupported'});
      expect(words(c), 'Computer update required');
      expect(c.tone, AgentChipTone.warning);
      expect(c.light, AgentChipLight.error);
      expect(c.opensComputer, isTrue);
      expect(c.showRetry, isFalse);
    });

    test('revoked access wraps and does not open the Computer', () {
      final c = chip(row: {'blockedReason': 'computer_access_revoked'});
      expect(words(c), startsWith('Computer access revoked: move the agent'));
      expect(c.wraps, isTrue);
      expect(c.opensComputer, isFalse);
    });

    test('an offline Computer holds an agent a person did not stop', () {
      final c = chip(machineOffline: true);
      expect(words(c), 'Computer offline');
      expect(c.tone, AgentChipTone.muted);
      expect(c.light, AgentChipLight.offline);
      expect(c.opensComputer, isTrue);
      expect(c.showRetry, isFalse);
    });

    test(
      'derived offline rule leaves stopped, errors and paused wakes alone',
      () {
        bool held({
          String status = 'active',
          String? activity = 'offline',
          String? kind = 'none',
        }) => agentHeldByOfflineComputer(
          status: status,
          activity: activity,
          detailKind: kind,
          machineOffline: true,
        );
        expect(held(), isTrue);
        expect(held(status: 'stopped'), isFalse);
        expect(held(activity: 'error'), isFalse);
        expect(held(kind: 'wake_crash_loop_blocked'), isFalse);
        expect(held(kind: 'terminal_failure_paused'), isFalse);
        expect(
          agentHeldByOfflineComputer(
            status: 'active',
            activity: null,
            detailKind: null,
            machineOffline: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('likely online', () {
    test('no activity state and an active agent reads green', () {
      final c = chip(hasState: false, activity: 'working', detailKind: 'none');
      expect(words(c), 'Likely online');
      expect(c.tone, AgentChipTone.success);
      expect(c.showRetry, isFalse);
    });

    test('a stopped agent with no state is not likely online', () {
      final c = chip(
        row: {'status': 'stopped'},
        hasState: false,
        activity: 'offline',
        detailKind: 'stopped',
      );
      expect(words(c), isNot('Likely online'));
    });
  });

  group('credential', () {
    test('held for another agent: Sign-in needed, error light, Retry', () {
      final c = chip(
        row: {
          'credentialHold': {'reason': 'user_reauth'},
        },
        detail: 'Codex CLI is not logged in',
      );
      expect(words(c), 'Sign-in needed for Codex CLI');
      expect(c.tone, AgentChipTone.warning);
      expect(c.light, AgentChipLight.error);
      expect(c.showRetry, isTrue);
      expect(c.credentialReason, 'user_reauth');
    });

    test('plan model names the model, or says "this model"', () {
      Map<String, dynamic> hold(String? model) => {
        'model': model,
        'credentialHold': {'reason': 'user_model_access'},
      };
      expect(words(chip(row: hold('gpt-5'))), "Plan doesn't include GPT-5");
      expect(words(chip(row: hold(null))), "Plan doesn't include this model");
      expect(words(chip(row: hold('  '))), "Plan doesn't include this model");
    });

    test('own billing error: the typed error names it, then Retry', () {
      final c = chip(
        activity: 'error',
        detailKind: 'runtime_error',
        detail: 'balance gone',
        row: {
          'lastRuntimeError': {
            'message': 'balance gone',
            'errorClass': 'BillingError',
          },
        },
      );
      expect(words(c), 'Provider balance exhausted');
      expect(c.showRetry, isTrue);
    });

    test('a stored error that is not the live one names nothing', () {
      final c = chip(
        activity: 'error',
        detailKind: 'runtime_error',
        detail: 'a newer failure',
        row: {
          'lastRuntimeError': {
            'message': 'balance gone',
            'errorClass': 'BillingError',
          },
        },
      );
      expect(c.credentialReason, isNull);
      expect(words(c), 'Error: a newer failure');
    });

    test('member view: a generic Error, no reason, Retry stays', () {
      final c = chip(
        showDetail: false,
        row: {
          'credentialHold': {'reason': 'user_reauth'},
        },
      );
      expect(words(c), 'Error');
      expect(c.showRetry, isTrue);
      expect(c.detail, isNull);
    });

    test('a hold only counts on an idle online frame', () {
      expect(
        credentialInvalidReasonOf(
          activity: 'working',
          activityDetail: '',
          activityDetailKind: 'idle',
          credentialHold: {'reason': 'billing'},
        ),
        isNull,
      );
      expect(
        credentialInvalidReasonOf(
          activity: 'online',
          activityDetail: '',
          activityDetailKind: 'idle',
          credentialHold: {'reason': 'nonsense'},
        ),
        isNull,
      );
    });

    test('requiredAction first, class second', () {
      String? reason(Map<String, dynamic> error) => credentialInvalidReasonOf(
        activity: 'error',
        activityDetail: 'm',
        activityDetailKind: 'runtime_error',
        lastRuntimeError: {'message': 'm', ...error},
      );
      expect(
        reason({
          'requiredAction': 'user_model_access',
          'errorClass': 'AuthError',
        }),
        'user_model_access',
      );
      expect(reason({'errorClass': 'AuthError'}), 'user_reauth');
      expect(reason({'errorClass': 'TimeoutError'}), isNull);
    });
  });

  group('error code', () {
    test('a coded error reads as its title for a viewer without detail', () {
      final c = chip(
        activity: 'error',
        detailKind: 'runtime_error',
        showDetail: false,
        errorCode: 'usage_limit',
      );
      expect(words(c), 'Usage limit reached');
    });

    test('the code wins over the text for a viewer with detail too', () {
      final c = chip(
        activity: 'error',
        detailKind: 'runtime_error',
        detail: '429 Too Many Requests',
        errorCode: 'usage_limit',
      );
      expect(words(c), 'Usage limit reached');
    });

    test('an unknown code is no code', () {
      final c = chip(
        activity: 'error',
        detailKind: 'runtime_error',
        detail: 'boom',
        errorCode: null,
      );
      expect(words(c), 'Error: boom');
      expect(agentActivityErrorCode({'activityErrorCode': 'new_code'}), isNull);
      expect(
        agentActivityErrorCode({
          'activityErrorCode': 'billing',
        }, activity: 'working'),
        isNull,
      );
      expect(
        agentActivityErrorCode({'activityErrorCode': 'billing'}),
        'billing',
      );
    });

    test('the server generic line reads as the catalog fallback', () {
      final c = chip(
        activity: 'error',
        detailKind: 'runtime_error',
        detail: 'Agent encountered an error',
      );
      expect(words(c), 'Agent encountered an error');
    });
  });

  group('Retry (agentNeedsManualRestart)', () {
    bool needs({
      String activity = 'offline',
      String? kind,
      String? credential,
      String? spawn,
      bool paused = false,
      String? errorClass,
      bool external = false,
      AgentBlockedState? blocked,
      bool likely = false,
    }) => agentNeedsManualRestart(
      activity: activity,
      activityDetailKind: kind,
      credentialReason: credential,
      spawnFailureReason: spawn,
      spawnFailurePaused: paused,
      runtimeErrorClass: errorClass,
      isExternal: external,
      blocked: blocked,
      likelyOnline: likely,
    );

    test('every error but a rate limit', () {
      expect(needs(activity: 'error', kind: 'runtime_error'), isTrue);
      expect(needs(activity: 'error', errorClass: 'RateLimitError'), isFalse);
    });
    test('manual-start detail kinds', () {
      expect(needs(kind: 'wake_crash_loop_blocked'), isTrue);
      expect(needs(kind: 'terminal_failure_paused'), isTrue);
      expect(needs(kind: 'runtime_unavailable'), isTrue);
      expect(needs(kind: 'stopped'), isFalse);
      expect(needs(kind: 'idle'), isFalse);
    });
    test('a failed start only after the server paused automatic restarts', () {
      expect(
        needs(kind: 'runtime_unavailable', spawn: 'runtime_not_found'),
        isFalse,
      );
      expect(
        needs(
          kind: 'runtime_unavailable',
          spawn: 'runtime_not_found',
          paused: true,
        ),
        isTrue,
      );
      expect(
        needs(
          kind: 'runtime_unavailable',
          spawn: 'session_needs_reset',
          paused: true,
        ),
        isFalse,
      );
      expect(
        needs(
          kind: 'runtime_unavailable',
          spawn: 'session_runtime_mismatch',
          paused: true,
        ),
        isFalse,
      );
    });
    test('never for external, blocked or guessed-online agents', () {
      expect(needs(activity: 'error', external: true), isFalse);
      expect(
        needs(activity: 'error', blocked: AgentBlockedState.computerOffline),
        isFalse,
      );
      expect(needs(activity: 'error', likely: true), isFalse);
    });
    test('the chip offers it only to whoever may restart', () {
      final err = chip(
        activity: 'error',
        detailKind: 'runtime_error',
        canRestart: false,
      );
      expect(err.showRetry, isFalse);
      expect(
        chip(activity: 'error', detailKind: 'runtime_error').showRetry,
        isTrue,
      );
    });
  });

  group('Change model and detail lines', () {
    test('model_unsupported and session_needs_reset offer Change model', () {
      for (final reason in ['model_unsupported', 'session_needs_reset']) {
        final c = chip(
          activity: 'offline',
          detailKind: 'runtime_unavailable',
          spawnFailure: {'reason': reason, 'autoRestartPaused': true},
        );
        expect(c.showChangeModel, isTrue, reason: reason);
      }
      final other = chip(
        activity: 'offline',
        detailKind: 'runtime_unavailable',
        spawnFailure: {'reason': 'runtime_not_found'},
      );
      expect(other.showChangeModel, isFalse);
    });

    test('only for whoever may open the model setting, with detail', () {
      final spawn = {'reason': 'model_unsupported', 'autoRestartPaused': true};
      expect(
        chip(
          activity: 'offline',
          detailKind: 'runtime_unavailable',
          spawnFailure: spawn,
          canModel: false,
        ).showChangeModel,
        isFalse,
      );
      expect(
        chip(
          activity: 'offline',
          detailKind: 'runtime_unavailable',
          spawnFailure: spawn,
          showDetail: false,
        ).showChangeModel,
        isFalse,
      );
    });

    test('delivery_unconsumed counts, for viewers with detail', () {
      final row = {
        'deliveryConsumption': {
          'unconsumedDeliveries': 3,
          'episode': 2,
          'lastDeliveryPath': 'stdin_idle_delivery',
        },
      };
      final c = chip(
        activity: 'working',
        detailKind: 'delivery_unconsumed',
        row: row,
      );
      expect(c.detail!.values, {
        'count': 3,
        'episode': 2,
        'path': 'stdin_idle_delivery',
      });
      expect(
        chip(
          activity: 'working',
          detailKind: 'delivery_unconsumed',
          row: row,
          showDetail: false,
        ).detail,
        isNull,
      );
    });

    test('wake_crash_loop_blocked counts, with the signal after the kind', () {
      final c = chip(
        activity: 'offline',
        detailKind: 'wake_crash_loop_blocked',
        row: {
          'wakeCrashLoop': {
            'earlyExitCount': 4,
            'episode': 1,
            'lastExitKind': 'agent_process_exited',
            'lastSignal': 'SIGKILL',
          },
        },
      );
      expect(c.detail!.values['exitKind'], 'agent_process_exited');
      expect(c.detail!.values['signal'], ' SIGKILL');
      expect(c.showRetry, isTrue);
    });
  });

  group('external chip', () {
    AgentStatusChip ext({
      bool online = false,
      bool showDetail = true,
      String? setup,
      bool hasStatus = true,
      String? relative,
    }) => resolveExternalStatusChip(
      online: online,
      showDetail: showDetail,
      setupState: setup,
      hasStatus: hasStatus,
      lastSeenRelative: relative,
      name: 'Hermes',
    );

    test('needing sign-in reads Set up with the long tooltip', () {
      for (final s in [
        'waiting_for_login',
        'login_token_expired',
        'disconnected',
      ]) {
        final c = ext(setup: s);
        expect(c.text.source, 'Set up', reason: s);
        expect(c.tooltip!.values, {'name': 'Hermes'});
        expect(c.tone, AgentChipTone.warning);
        expect(c.light, AgentChipLight.error);
      }
    });
    test('a member sees only External', () {
      expect(
        ext(setup: 'waiting_for_login', showDetail: false).text.source,
        'External',
      );
    });
    test('online, last active, no activity, not configured', () {
      expect(ext(online: true).text.source, 'External · Online');
      expect(
        ext(relative: '3m ago').text.source,
        'External · Last active {time}',
      );
      expect(
        ext(setup: 'connected').text.source,
        'External · No Raft activity yet',
      );
      expect(
        ext(setup: 'connected', hasStatus: true).tone,
        AgentChipTone.information,
      );
      expect(ext().text.source, 'External · Not configured');
      expect(ext(hasStatus: false).text.source, 'External');
    });
  });

  test('chain order: blocked beats likely online beats credential', () {
    final c = chip(
      row: {
        'blockedReason': 'computer_version_unknown',
        'credentialHold': {'reason': 'billing'},
      },
      hasState: false,
    );
    expect(c.blocked, AgentBlockedState.computerTooOld);
  });
}
