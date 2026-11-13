// Server v1.24.0 step-up (services/secondFactor/stepUpGate.ts): with two-step
// verification on, changing the password answers 403
// `second_factor_step_up_required` until this sign-in passed the second step.
// Web opens "Verify it's you", steps up and sends the change once more.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_password_editor.dart';
import 'package:raft_ui/raft_ui.dart';

RaftApiException _refusal(int status, String code, [String? error]) =>
    RaftApiException.response(
      error ?? code,
      status: status,
      body: {
        'error': error ?? code,
        'code': code,
        if (code == 'second_factor_step_up_required')
          'methods': ['totp', 'backup_code'],
      },
    );

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );

  /// Until a step-up passes, sensitive writes are refused.
  bool verified = false;
  final stepUpAnswers = <Object>[];
  final calls = <({String method, String path, dynamic data})>[];

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
    calls.add((method: method, path: path, data: data));
    if (path == '/auth/second-factor/step-up') {
      final answer = stepUpAnswers.isEmpty ? true : stepUpAnswers.removeAt(0);
      if (answer is RaftApiException) throw answer;
      verified = true;
      return {};
    }
    if (path == '/auth/me' && method == 'PATCH' && !verified) {
      throw _refusal(
        403,
        'second_factor_step_up_required',
        'Confirm it is you with your second step before changing your password.',
      );
    }
    return {};
  }

  List<String> get patches => [
    for (final c in calls)
      if (c.method == 'PATCH' && c.path == '/auth/me') c.path,
  ];
}

void main() {
  late _Client client;
  late WorkspaceController w;
  setUp(() {
    client = _Client()
      ..user = RaftRecord({'id': 'owner', 'email': 'fixture@example.invalid'});
    w = WorkspaceController(client);
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> changePassword(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountPasswordEditor(controller: w),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('account-change-password')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('account-current-password')),
      'fixture-current',
    );
    await t.enterText(
      find.byKey(const ValueKey('account-new-password')),
      'fixture-updated',
    );
    await t.enterText(
      find.byKey(const ValueKey('account-confirm-password')),
      'fixture-updated',
    );
    await t.ensureVisible(
      find.byKey(const ValueKey('account-password-submit')),
    );
    await t.tap(find.byKey(const ValueKey('account-password-submit')));
    await t.pumpAndSettle();
  }

  Future<void> answer(WidgetTester t, String code) async {
    await t.enterText(
      find.descendant(
        of: find.byType(RaftFormDialog),
        matching: find.byType(EditableText),
      ),
      code,
    );
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
  }

  testWidgets('a step-up refusal asks to verify, then changes the password', (
    t,
  ) async {
    await changePassword(t);
    expect(find.text("Verify it's you"), findsOneWidget);
    expect(
      find.text(
        'Changing how you sign in needs a fresh second step. It lasts 10 minutes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Authenticator code'), findsOneWidget);
    expect(client.patches, hasLength(1));

    await answer(t, '123 456');
    final stepUp = client.calls.where(
      (c) => c.path == '/auth/second-factor/step-up',
    );
    expect(stepUp.single.data, {'code': '123456'});
    expect(client.patches, hasLength(2));
    expect(find.text("Verify it's you"), findsNothing);
    expect(find.text('Password updated!'), findsOneWidget);
  });

  testWidgets('a wrong code stays in the dialog; a backup code works', (
    t,
  ) async {
    client.stepUpAnswers.add(_refusal(400, 'second_factor_code_invalid'));
    await changePassword(t);
    await answer(t, '000000');
    expect(
      find.text(
        "That code didn't work. Check the time on your phone is set automatically, then try the newest code.",
      ),
      findsOneWidget,
    );
    expect(client.patches, hasLength(1));

    await t.tap(find.byKey(const ValueKey('step-up-use-backup_code')));
    await t.pumpAndSettle();
    expect(find.text('Backup code'), findsOneWidget);
    await answer(t, 'abcde-12345');
    expect(
      client.calls
          .lastWhere((c) => c.path == '/auth/second-factor/step-up')
          .data,
      {'backupCode': 'abcde-12345'},
    );
    expect(find.text('Password updated!'), findsOneWidget);
  });

  testWidgets('closing the dialog sends nothing more and shows no error', (
    t,
  ) async {
    await changePassword(t);
    expect(find.text("Verify it's you"), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text("Verify it's you"), findsNothing);
    expect(client.patches, hasLength(1));
    expect(find.textContaining('second step'), findsNothing);
    expect(find.textContaining('Failed to change password'), findsNothing);
    expect(find.text('Password updated!'), findsNothing);
  });
}
