// Web v1.24 machineStore.registerMachine runs behind withSecondFactorStepUp:
// with two-step verification on, `POST /servers/:id/machines` answers 403
// `second_factor_step_up_required` until this sign-in passed the second step.
// The app's Register Computer form opens "Verify it's you", steps up and sends
// the registration once more; closing it registers nothing and says nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stepUps = <dynamic>[];

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
      stepUps.add(data);
      return {};
    }
    return {};
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(this.c) : super(c);
  final _Client c;
  final registrations = <dynamic>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path.endsWith('/machines') ? {'machines': []} : <dynamic>[];

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    if (method == 'POST' && path == '/servers/s/machines') {
      registrations.add(data);
      if (c.stepUps.isEmpty) {
        throw RaftApiException.response(
          'Confirm it is you with your second step first.',
          status: 403,
          body: {
            'error': 'Confirm it is you with your second step first.',
            'code': 'second_factor_step_up_required',
            'methods': ['totp', 'backup_code'],
          },
        );
      }
      return {
        'machine': {'id': 'm1'},
        'apiKey': 'TEST_ONLY_NOT_A_CREDENTIAL',
      };
    }
    return <String, dynamic>{};
  }
}

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client();
    w = _Workspace(c)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'fixture'});
  });
  tearDown(() async {
    w.dispose();
    await c.dispose();
  });

  // The submitting form keeps its spinner turning while "Verify it's you" is
  // open, so frames are pumped for the routes' transitions, not settled.
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> register(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showFleetRegistration(context, w, computers: true),
              child: const Text('Start registration'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Start registration'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Lab');
    await t.tap(find.widgetWithText(RaftButton, 'Register Computer'));
    await settle(t);
  }

  testWidgets('a refused registration asks to verify, then registers once', (
    t,
  ) async {
    await register(t);
    expect(find.text("Verify it's you"), findsOneWidget);
    expect(w.registrations, hasLength(1));
    await t.enterText(
      find.descendant(
        of: find.byType(RaftFormDialog).last,
        matching: find.byType(EditableText),
      ),
      '123456',
    );
    // Verify is enabled on the frame after the code is typed.
    await t.pump();
    await t.tap(find.text('Verify'));
    await settle(t);
    expect(c.stepUps.single, {'code': '123456'});
    expect(w.registrations, hasLength(2));
    expect(find.text('Save this credential'), findsOneWidget);
  });

  testWidgets('closing "Verify it\'s you" registers nothing, says nothing', (
    t,
  ) async {
    await register(t);
    await t.tap(find.text('Cancel').last);
    await settle(t);
    expect(find.text("Verify it's you"), findsNothing);
    expect(w.registrations, hasLength(1));
    expect(find.text('Save this credential'), findsNothing);
    expect(find.textContaining('second step'), findsNothing);
    expect(find.textContaining('second_factor'), findsNothing);
    // The registration form closed with nothing registered.
    expect(find.byType(RaftFormDialog), findsNothing);
  });
}
