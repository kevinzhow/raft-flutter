// Web v1.24.0 SecondFactorStepUpHost / VerifyItsYouDialog: each sensitive
// action says what the step-up is for; a sign-in that can't step up (403
// `session_family_required`) offers Sign in again; two refused requests at
// once share one dialog; Login with Raft's step-up cancel reaches its sheet.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/second_factor_step_up.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/human_login_fake.dart';
import 'support/second_factor_server.dart';

final _refused = secondFactorRefusal(
  403,
  'second_factor_step_up_required',
  extra: {
    'methods': ['totp', 'backup_code'],
  },
);

class _Client extends SecondFactorServerClient {
  bool verified = false, loggedOut = false;
  Object? stepUpFailure;

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
    if (path == '/auth/second-factor/step-up') {
      calls.add((method: method, path: path, data: data));
      if (stepUpFailure case final failure?) throw failure;
      verified = true;
      return null;
    }
    if (path == '/agents/a1/credentials') {
      calls.add((method: method, path: path, data: data));
      if (!verified) throw _refused;
      return {'apiKey': 'sk_agent_x'};
    }
    return super.request(method, path, data: data);
  }

  @override
  Future<void> logout({
    Future<Session?>? revocationSession,
    SessionEndReason reason = SessionEndReason.userRequested,
  }) async {
    loggedOut = true;
  }
}

void main() {
  late _Client client;
  setUp(() => client = _Client());
  tearDown(() => client.dispose());

  Future<BuildContext> mount(WidgetTester t) async {
    late BuildContext captured;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  Future<void> answer(WidgetTester t, String code) async {
    await t.enterText(
      find.descendant(
        of: find.byType(RaftFormDialog),
        matching: find.byType(EditableText),
      ),
      code,
    );
    // Verify is enabled on the frame after the code is typed.
    await t.pump();
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
  }

  testWidgets('an agent key says so; two refusals share one dialog', (t) async {
    final context = await mount(t);
    Future<dynamic> mint() => withSecondFactorStepUp(
      context,
      client,
      () => client.post('/agents/a1/credentials'),
      reason: StepUpReason.agentKey,
    );
    final first = mint(), second = mint();
    await t.pumpAndSettle();
    expect(find.byType(RaftFormDialog), findsOneWidget);
    expect(
      find.text(
        'Generating a login token needs a fresh second step. It lasts 10 minutes.',
      ),
      findsOneWidget,
    );
    await answer(t, '123456');
    expect(await first, {'apiKey': 'sk_agent_x'});
    expect(await second, {'apiKey': 'sk_agent_x'});
    expect(client.to('/auth/second-factor/step-up'), hasLength(1));
    // Each refused request went once more after the step-up.
    expect(client.to('/agents/a1/credentials'), hasLength(4));
  });

  testWidgets('a sign-in that cannot step up offers Sign in again', (t) async {
    client.stepUpFailure = secondFactorRefusal(403, 'session_family_required');
    final context = await mount(t);
    Object? outcome;
    unawaited(
      withSecondFactorStepUp(
        context,
        client,
        () => client.post('/agents/a1/credentials'),
        reason: StepUpReason.secret,
      ).then((v) => outcome = v, onError: (Object e) => outcome = e),
    );
    await t.pumpAndSettle();
    expect(
      find.text(
        'Creating a new secret needs a fresh second step. It lasts 10 minutes.',
      ),
      findsOneWidget,
    );
    await answer(t, '123456');
    expect(
      find.text(
        "This sign-in can't be verified. Sign in again, then try once more.",
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('step-up-sign-in-again')));
    await t.pumpAndSettle();
    expect(find.byType(RaftFormDialog), findsNothing);
    expect(client.loggedOut, isTrue);
    expect(isSecondFactorStepUpCancelled(outcome), isTrue);
  });

  testWidgets('every Web reason has its own description', (t) async {
    expect(StepUpReason.values.map((r) => r.name), [
      'signInMethod',
      'agentKey',
      'appAccess',
      'agentAccess',
      'secret',
      'actionCard',
      'other',
    ]);
    expect(
      StepUpReason.values.map((r) => r.description).toSet(),
      hasLength(StepUpReason.values.length),
    );
  });

  test('Login with Raft passes a closed step-up to its sheet', () async {
    final api = FakeHumanLoginApi();
    final request = HumanLoginRequest(
      clientId: 'artifact-share',
      returnUrl: 'https://artifacts.example.com/auth/callback',
      state: 'st-1',
      scopes: const ['openid'],
      serverHint: '',
    );
    final choice = HumanLoginChoice(
      const HumanLoginServer(id: 'srv-1', slug: 'acme', name: 'Acme'),
      HumanLoginClient.fromJson(FakeHumanLoginApi.app()),
    );
    await expectLater(
      authorizeHumanLogin(
        api,
        request,
        choice,
        guard: (_) async => throw const SecondFactorStepUpCancelled(),
      ),
      throwsA(isA<SecondFactorStepUpCancelled>()),
    );
    // Without a refusal the guard just sends it.
    final location = await authorizeHumanLogin(
      api,
      request,
      choice,
      guard: (send) => send(),
    );
    expect(location.queryParameters['state'], 'st-1');
  });
}
