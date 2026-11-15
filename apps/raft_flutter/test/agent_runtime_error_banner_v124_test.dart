// The runtime error banner of Web v1.24.0 (AgentRuntimeErrorNotice.tsx,
// AgentDetailPanel.tsx `hasRuntimeError`): codes, who reads what, billing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/runtime_error.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_runtime_error_state.dart';

import 'support/agent_panel_fixture.dart';

const _banner = ValueKey('runtime-error-banner');
const _scrubbed =
    '429 Too Many Requests: You have hit your usage limit for this billing period (account [redacted]). Try again after the limit resets.';

Map<String, dynamic> _coded({
  String code = 'usage_limit',
  String text = _scrubbed,
  Map<String, dynamic> extra = const {},
}) => {
  ...agentPanelAgent,
  'activity': 'error',
  'activityDetailKind': 'runtime_error',
  'activityDetail': text,
  'activityErrorCode': code,
  'lastRuntimeError': {
    'message': text,
    'code': code,
    'at': '2026-10-13T08:00:00.000Z',
    'actionRequired': false,
  },
  ...extra,
};

const _billing = {
  'message': 'Codex CLI reported that the provider balance is exhausted.',
  'errorClass': 'BillingError',
  'errorReason': 'billing_exhausted',
  'fingerprint': 'fp',
};

Finder inBanner(Finder f) =>
    find.descendant(of: find.byKey(_banner), matching: f);

void main() {
  group('runtimeErrorCodeCopy', () {
    test('the seven codes have title, member and manager sentences', () {
      for (final code in runtimeErrorCodes) {
        final copy = runtimeErrorCodeCopy(code);
        expect(copy, isNotNull, reason: code);
        expect(copy!.title, isNotEmpty);
        expect(copy.member, isNot(copy.manager));
      }
      expect(runtimeErrorCodes, hasLength(7));
      expect(runtimeErrorCodeCopy('newer_code'), isNull);
      expect(runtimeErrorCodeCopy(null), isNull);
    });

    test('typed classification adds root privileges and billing', () {
      expect(
        classifyTypedRuntimeError({
          'errorClass': 'Whatever',
          'errorReason': 'root_privileges',
        }),
        RuntimeErrorKind.rootPrivileges,
      );
      expect(
        classifyTypedRuntimeError({
          'errorClass': 'BillingError',
          'errorReason': 'billing_exhausted',
        }),
        RuntimeErrorKind.billingExhausted,
      );
      expect(
        classifyTypedRuntimeError({
          'errorClass': 'Unknown',
          'errorReason': 'billing_exhausted',
        }),
        RuntimeErrorKind.billingExhausted,
      );
    });
  });

  group('resolveRuntimeErrorBanner', () {
    RuntimeErrorBannerSpec? spec({
      String activity = 'error',
      String detail = '',
      String? code,
      Object? stored,
      bool view = true,
      bool model = true,
    }) => resolveRuntimeErrorBanner(
      activity: activity,
      activityDetail: detail,
      errorCode: code,
      lastRuntimeError: stored,
      canViewDetails: view,
      canOpenModelSettings: model,
      agentTitle: 'Alpha',
      runtimeName: 'Codex CLI',
    );

    test('a healthy agent has none', () {
      expect(spec(activity: 'online'), isNull);
    });

    test('the code comes from the live error, else the stored one', () {
      expect(spec(code: 'billing')!.code, 'billing');
      expect(
        spec(
          activity: 'online',
          stored: {'message': 'm', 'code': 'usage_limit'},
        )!.code,
        'usage_limit',
      );
      // Live frame wins over the stored error's code.
      expect(
        spec(
          code: 'network_timeout',
          stored: {'message': 'm', 'code': 'usage_limit'},
        )!.code,
        'network_timeout',
      );
      expect(spec(code: 'brand_new'), isNotNull);
      expect(spec(code: 'brand_new')!.code, isNull);
    });

    test('a coded error ignores text patterns', () {
      final s = spec(detail: 'invalid api key', code: 'usage_limit')!;
      expect(s.kind, isNull);
    });

    test('manager: headline is the manager sentence, detail under it', () {
      final s = spec(detail: _scrubbed, code: 'usage_limit')!;
      expect(s.headline.source, runtimeErrorCodeCopy('usage_limit')!.manager);
      expect(s.detail, _scrubbed);
    });

    test('member: the member sentence, no detail, no actions', () {
      final s = spec(detail: _scrubbed, code: 'usage_limit', view: false)!;
      expect(s.headline.source, runtimeErrorCodeCopy('usage_limit')!.member);
      expect(s.detail, isNull);
      expect(s.showCopy, isFalse);
      expect(s.showViewLogs, isFalse);
    });

    test('member without a code reads the generic line', () {
      final s = spec(detail: 'secret text', view: false)!;
      expect(s.headline.source, 'Agent encountered an error');
    });

    test('a JSON error blob shows its message as the detail', () {
      final s = spec(
        detail: '{"error":{"message":"quota gone"}}',
        code: 'usage_limit',
      )!;
      expect(s.detail, 'quota gone');
    });

    test('billing: title, body naming the agent, one action', () {
      final s = spec(stored: _billing, detail: _billing['message']!)!;
      expect(s.billing, isTrue);
      expect(s.headline.source, 'Model service balance too low');
      expect(s.billingBody!.values, {'agent': 'Alpha'});
      expect(s.showModelSettings, isTrue);
      expect(s.showAskAdmin, isFalse);
      expect(s.showViewLogs, isFalse);
      expect(s.showCopy, isTrue);
    });

    test('billing without model settings says who fixes it', () {
      final s = spec(stored: _billing, model: false, view: false)!;
      expect(s.showModelSettings, isFalse);
      expect(s.showAskAdmin, isTrue);
      expect(s.showCopy, isFalse);
    });

    test(
      'a confirmed missing runtime names it; a timeout does not say install',
      () {
        RuntimeErrorBannerSpec s(String? reason) => resolveRuntimeErrorBanner(
          activity: 'error',
          activityDetail: 'codex is not installed',
          errorCode: null,
          lastRuntimeError: null,
          canViewDetails: true,
          canOpenModelSettings: false,
          agentTitle: 'Alpha',
          runtimeName: 'Codex CLI',
          spawnLookupReason: reason,
        )!;
        expect(
          s('not_on_path').headline.source,
          startsWith('{runtimeName} is not installed on this Computer.'),
        );
        expect(s(null).headline.source, contains('Could not confirm'));
        expect(s('lookup_timed_out').headline.source, contains('timed out'));
      },
    );
  });

  testWidgets(
    'manager: sentence headline, two-line scrubbed detail, copy and logs',
    (tester) async {
      await pumpAgentPanel(tester, agent: _coded());
      expect(
        inBanner(
          find.textContaining(
            'The model provider\'s usage limit has been reached',
          ),
        ),
        findsOneWidget,
      );
      final detail = find.byKey(const ValueKey('runtime-error-detail'));
      expect(detail, findsOneWidget);
      expect((tester.widget(detail) as dynamic).maxLines, 2);
      expect(find.byKey(const ValueKey('runtime-error-copy')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('runtime-error-view-logs')),
        findsOneWidget,
      );
    },
  );

  testWidgets('member: the code sentence, no detail, no copy, no logs', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: _coded(text: runtimeErrorCodeCopy('usage_limit')!.member),
      canManage: false,
      canViewPrivate: false,
    );
    expect(
      inBanner(
        find.textContaining(
          "The agent's model provider usage limit has been reached",
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('runtime-error-detail')), findsNothing);
    expect(find.byKey(const ValueKey('runtime-error-copy')), findsNothing);
    expect(find.byKey(const ValueKey('runtime-error-view-logs')), findsNothing);
  });

  testWidgets(
    'billing banner: balance too low, View model settings opens them',
    (tester) async {
      var edits = 0;
      await pumpAgentPanel(
        tester,
        agent: {...agentPanelAgent, 'lastRuntimeError': _billing},
        actions: AgentDetailActions(onEditRuntime: () => edits++),
      );
      expect(
        find.byKey(const ValueKey('agent-billing-banner')),
        findsOneWidget,
      );
      expect(
        inBanner(find.text('Model service balance too low')),
        findsOneWidget,
      );
      expect(
        inBanner(find.textContaining("Alpha Agent can't reply right now.")),
        findsOneWidget,
      );
      // One action next to Copy info; View logs is not offered.
      expect(
        find.byKey(const ValueKey('runtime-error-view-logs')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('runtime-error-copy')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('agent-billing-banner-model-settings')),
      );
      expect(edits, 1);
      expect(find.text('Ask a server admin to fix this.'), findsNothing);
    },
  );

  testWidgets('billing banner for a member: the title and who can fix it', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {...agentPanelAgent, 'lastRuntimeError': _billing},
      canManage: false,
      canViewPrivate: false,
    );
    expect(
      inBanner(find.text('Model service balance too low')),
      findsOneWidget,
    );
    expect(find.text('Ask a server admin to fix this.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-billing-banner-model-settings')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('runtime-error-copy')), findsNothing);
  });

  testWidgets('root privileges read their catalog copy', (tester) async {
    await pumpAgentPanel(
      tester,
      agent: {
        ...agentPanelAgent,
        'lastRuntimeError': {
          'message': 'refusing to run as root',
          'errorClass': 'ConfigError',
          'errorReason': 'root_privileges',
          'fingerprint': 'fp',
        },
      },
    );
    expect(
      inBanner(
        find.textContaining(
          'Claude Code cannot start with root or sudo privileges',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a confirmed missing runtime names it in the banner', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {
        ...agentPanelAgent,
        'activity': 'error',
        'activityDetailKind': 'runtime_unavailable',
        'activityDetail': 'codex is not installed',
        'spawnFailure': {
          'reason': 'runtime_not_found',
          'lookupReason': 'not_on_path',
        },
      },
    );
    expect(
      inBanner(
        find.textContaining(
          'Codex CLI is not installed on this Computer. Install it there',
        ),
      ),
      findsOneWidget,
    );
  });
}
