import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/report_issue.dart';
import 'package:raft_ui/raft_ui.dart';

const _agent = <String, dynamic>{
  'id': 'a',
  'name': 'alpha',
  'displayName': 'Alpha Agent',
  'status': 'active',
  'machineId': 'm1',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  int listeners = 0;
  Completer<dynamic>? transcript;
  @override
  Stream<RaftEvent> get events => Stream<RaftEvent>.multi((out) {
    listeners++;
    final sub = stream.stream.listen(out.add);
    out.onCancel = () {
      listeners--;
      return sub.cancel();
    };
  }, isBroadcast: true);
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  String newRandomId() => 'submission-1';
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
    if (path == '/servers/s/scope-attestation') {
      return {'attestation': 'att'};
    }
    if (path == '/product-feedback') return {'id': 'ticket-1'};
    if (path.endsWith('/transcript') && transcript != null) {
      return transcript!.future;
    }
    return {};
  }
}

class _Transport implements ReportIssueTransport {
  @override
  Future<ReportIssueHttpResponse> send(
    String method,
    String url, {
    Map<String, String> headers = const {},
    Object? jsonBody,
    List<int>? bytes,
  }) async {
    if (url.endsWith('/api/reports')) {
      return ReportIssueHttpResponse(
        200,
        jsonEncode({
          'id': 'report-1',
          'completeToken': 'tok',
          'upload': {'method': 'PUT', 'url': 'https://storage.invalid/up'},
        }),
      );
    }
    return const ReportIssueHttpResponse(200, '{}');
  }
}

RaftEvent _push(Object? report, Object? answer) => RaftEvent(
  'feedback_report:session_record',
  {'feedbackReportId': report, 'sessionRecord': answer},
);

void main() {
  late _Client client;
  late WorkspaceController w;
  late ReportIssueSession session;
  setUp(() {
    client = _Client();
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'slug': 'slug', 'name': 'Fixture'});
    session = ReportIssueSession(
      controller: w,
      agent: _agent,
      exportUrl: 'https://feedback.invalid',
      translate: (s) => s,
      locale: 'en',
      browser: const {'url': ''},
      transport: _Transport(),
      confirmCap: const Duration(seconds: 30),
    );
  });
  tearDown(() async {
    w.dispose();
    await client.stream.close();
  });

  const all = RaftReportIssueOptions(
    description: 'it broke',
    includeRecentMessages: false,
    includeActivityLog: false,
    includeTrajectoryLog: false,
    includeSessionTranscript: true,
    includeMachineLogTail: false,
  );

  test(
    'the computer answer is final and only for the requested report',
    () async {
      await session.submit(all);
      await Future<void>.delayed(Duration.zero);
      expect(
        session.transcriptState.value,
        RaftTranscriptRequestState.requested,
      );
      client.stream.add(_push('another-report', 'attached'));
      client.stream.add(_push('report-1', 'maybe'));
      client.stream.add(_push(null, 'attached'));
      await Future<void>.delayed(Duration.zero);
      expect(
        session.transcriptState.value,
        RaftTranscriptRequestState.requested,
      );
      client.stream.add(_push('report-1', 'not_attached'));
      await Future<void>.delayed(Duration.zero);
      expect(
        session.transcriptState.value,
        RaftTranscriptRequestState.notAttached,
      );
      // The answer is final: a later request state does not replace it.
      expect(
        raftNextTranscriptRequestState(
          RaftTranscriptRequestState.notAttached,
          RaftTranscriptRequestState.requestUnconfirmed,
        ),
        RaftTranscriptRequestState.notAttached,
      );
      session.dispose();
    },
  );

  test('an answer before the request has finished is kept', () async {
    client.transcript = Completer<dynamic>();
    await session.submit(all);
    expect(session.transcriptState.value, RaftTranscriptRequestState.pending);
    client.stream.add(_push('report-1', 'attached'));
    await Future<void>.delayed(Duration.zero);
    expect(session.transcriptState.value, RaftTranscriptRequestState.attached);
    // The request's own 202 arrives later and must not replace the answer.
    client.transcript!.complete({});
    await Future<void>.delayed(Duration.zero);
    expect(session.transcriptState.value, RaftTranscriptRequestState.attached);
    session.dispose();
  });

  test('the session stops listening when it is disposed', () async {
    final before = client.listeners;
    await session.submit(all);
    expect(client.listeners, before + 1);
    session.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(client.listeners, before);
  });

  testWidgets('the transcript status line resolves from the socket answer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RaftReportIssueDialog(
              agentName: 'Alpha Agent',
              hasMachine: true,
              canIncludeMachineLog: false,
              transcriptState: session.transcriptState,
              onSubmit: session.submit,
              onViewTicket: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('report-issue-consent')));
    await tester.pump();
    expect(find.text('Report'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('report-issue-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Report submitted'), findsOneWidget);
    expect(find.text('View ticket'), findsOneWidget);
    expect(
      find.text(
        "The agent's computer was asked for its session record. Whether one was attached shows here if it answers.",
      ),
      findsOneWidget,
    );
    client.stream.add(_push('report-1', 'attached'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Session record attached.'), findsOneWidget);
    expect(
      find.textContaining('Whether one was attached shows here'),
      findsNothing,
    );
    session.dispose();
  });
}
