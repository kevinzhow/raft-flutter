// Web components/agent/stopAgentTurn.ts + store stopAgentTurn: one route,
// `POST /agents/:id/interrupt-turn`, for hosted and Computer agents; the
// outcome (interrupted / restarted / not_running), the two coded refusals
// (computer_upgrade_required, computer_offline) and a failure with Retry.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_hosted_actions.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://raft.example.test',
        sessionStore: MemorySessionStore(),
      );
  final calls = <String>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);

  /// One entry per call: a body, or an exception to throw.
  final replies = <Object>[];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
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
    calls.add('$method $path');
    if (!path.endsWith('/interrupt-turn')) return [];
    final reply = replies.removeAt(0);
    if (reply is Exception) throw reply;
    return reply;
  }
}

RaftApiException _refused(String code) => RaftApiException.response(
  'refused',
  status: 409,
  body: {'error': 'refused', 'code': code},
);

Future<_Client> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final c = _Client()..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => RaftToastHost(child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                unawaited(stopAgentTurnWithFeedback(context, w, 'a 1')),
            child: const Text('stop'),
          ),
        ),
      ),
    ),
  );
  return c;
}

Future<void> _stop(WidgetTester t) async {
  await t.tap(find.text('stop'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('posts interrupt-turn, not the whole-agent stop route', (
    t,
  ) async {
    final c = await _pump(t);
    c.replies.add({'outcome': 'interrupted'});
    await _stop(t);
    expect(c.calls, ['POST /agents/a%201/interrupt-turn']);
    expect(find.text('Stopped the current turn.'), findsOneWidget);
  });

  testWidgets(
    'each outcome has its own message; an unknown one is not running',
    (t) async {
      final c = await _pump(t);
      c.replies.add({'outcome': 'restarted'});
      await _stop(t);
      expect(
        find.text(
          'To stop the turn, the agent was restarted. Its conversation context is kept.',
        ),
        findsOneWidget,
      );
      c.replies.add({'outcome': 'not_running'});
      await _stop(t);
      expect(find.text('Nothing was running.'), findsOneWidget);
      c.replies.add({'outcome': 'something_new'});
      await _stop(t);
      expect(find.text('Nothing was running.'), findsOneWidget);
    },
  );

  testWidgets('the coded refusals say why and offer no Retry', (t) async {
    final c = await _pump(t);
    c.replies.add(_refused('computer_upgrade_required'));
    await _stop(t);
    expect(
      find.text(
        "Upgrade this agent's Computer to stop a single turn. You can stop the whole agent instead.",
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    c.replies.add(_refused('computer_offline'));
    await _stop(t);
    expect(find.text("This agent's Computer is offline."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('any other failure offers Retry, and Retry stops the turn', (
    t,
  ) async {
    final c = await _pump(t);
    c.replies
      ..add(RaftApiException('down', status: 503))
      ..add({'outcome': 'interrupted'});
    await _stop(t);
    expect(find.text("Couldn't stop the current turn."), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(c.calls.where((x) => x.endsWith('/interrupt-turn')), hasLength(2));
    expect(find.text('Stopped the current turn.'), findsOneWidget);
    expect(find.text("Couldn't stop the current turn."), findsNothing);
  });
}
