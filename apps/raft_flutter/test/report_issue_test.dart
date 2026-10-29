import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/report_issue.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _agent = <String, dynamic>{
  'id': 'a',
  'name': 'alpha',
  'displayName': 'Alpha Agent',
  'status': 'active',
  'runtime': 'codex',
  'model': 'gpt',
  'activity': 'online',
  'machineId': 'm1',
  'creatorType': 'user',
  'creatorId': 'alice',
};

/// Records every request and answers from [answers] (`METHOD /path`).
class _Client extends RaftClient {
  _Client(this.answers)
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({
      'id': 'alice',
      'displayName': 'Alice',
      'name': 'alice',
      'email': 'alice@example.test',
    });
  }
  final Map<String, Object? Function(dynamic data)> answers;
  final calls = <(String, String, dynamic)>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
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
    calls.add((method, path, data));
    final answer = answers['$method $path'];
    if (answer == null) {
      throw RaftApiException.response(
        'not found',
        status: 404,
        body: {'error': 'not found'},
      );
    }
    return answer(data);
  }
}

class _Transport implements ReportIssueTransport {
  final calls = <(String, String, Object?, List<int>?)>[];
  int createStatus = 200, uploadStatus = 200, completeStatus = 200;
  @override
  Future<ReportIssueHttpResponse> send(
    String method,
    String url, {
    Map<String, String> headers = const {},
    Object? jsonBody,
    List<int>? bytes,
  }) async {
    calls.add((method, url, jsonBody, bytes));
    if (url.endsWith('/api/reports')) {
      return ReportIssueHttpResponse(
        createStatus,
        createStatus == 200
            ? jsonEncode({
                'id': 'report-1',
                'completeToken': 'tok',
                'upload': {
                  'method': 'PUT',
                  'url': 'https://storage.example.test/up',
                  'headers': {'x-a': 'b'},
                },
              })
            : jsonEncode({'error': 'worker down'}),
      );
    }
    if (url.startsWith('https://storage')) {
      return ReportIssueHttpResponse(uploadStatus, '');
    }
    return ReportIssueHttpResponse(
      completeStatus,
      completeStatus == 200 ? '{}' : '',
    );
  }
}

Map<String, Object? Function(dynamic)> _answers({
  bool ticketFails = false,
  Object? transcript,
}) => {
  'GET /messages/channel/dm1': (_) => {
    'messages': [
      {'id': 'x', 'content': 'hi'},
    ],
  },
  'GET /agents/a/activity-log': (_) => [
    {
      'timestamp': 1,
      'entry': {'kind': 'status'},
    },
  ],
  'POST /servers/s/scope-attestation': (_) => {
    'attestation': 'att',
    'scope': 'feedback-report:create',
    'expiresAt': 'later',
  },
  'POST /servers/s/machines/m1/agents/a/feedback/report-1/transcript': (_) {
    if (transcript is Exception) throw transcript;
    return {};
  },
  'POST /product-feedback': (_) {
    if (ticketFails) {
      throw RaftApiException.response(
        'nope',
        status: 500,
        body: {'error': 'nope'},
      );
    }
    return {'id': 'ticket-1'};
  },
};

class _Fixture {
  _Fixture(
    this.client,
    this.transport, {
    this.confirmCap = const Duration(seconds: 10),
    Map<String, dynamic>? machine,
  }) : machine =
           machine ??
           {
             'id': 'm1',
             'name': 'Box',
             'status': 'online',
             'os': 'linux',
             'computerVersion': '1.2.3',
             'daemonVersion': '0.9',
             'lastHeartbeat': '2026-06-18T09:00:00.000Z',
             'computerAttachedByCurrentUser': true,
           } {
    w = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 's',
        'slug': 'slug',
        'name': 'Fixture',
        'role': 'owner',
      });
    session = ReportIssueSession(
      controller: w,
      agent: _agent,
      machine: this.machine,
      dmChannelId: 'dm1',
      exportUrl: 'https://feedback.example.test',
      translate: (s) => s,
      locale: 'en',
      browser: const {'url': ''},
      activityLog: const [
        {'timestamp': 2},
      ],
      transport: transport,
      now: () => DateTime.utc(2026, 6, 18, 9),
      confirmCap: confirmCap,
    );
  }
  final _Client client;
  final _Transport transport;
  final Duration confirmCap;
  final Map<String, dynamic> machine;
  late final WorkspaceController w;
  late final ReportIssueSession session;
  void dispose() {
    session.dispose();
    w.dispose();
    client.stream.close();
  }
}

const _all = RaftReportIssueOptions(
  description: '  it broke  ',
  includeRecentMessages: true,
  includeActivityLog: true,
  includeTrajectoryLog: true,
  includeSessionTranscript: true,
  includeMachineLogTail: true,
);

void main() {
  test('the entry needs a feedback export worker in the build', () {
    expect(reportIssueEnabled(''), isFalse);
    expect(reportIssueEnabled('  /'), isFalse);
    expect(reportIssueEnabled('https://feedback.example.test/'), isTrue);
    expect(
      reportIssueExportUrl('https://feedback.example.test///'),
      'https://feedback.example.test',
    );
  });

  test(
    'submits the bundle through attestation, create, upload, complete',
    () async {
      final f = _Fixture(_Client(_answers()), _Transport());
      addTearDown(f.dispose);
      final receipt = await f.session.submit(_all);
      expect(receipt.reportId, 'report-1');
      expect(receipt.ticketId, 'ticket-1');
      expect(receipt.serverId, 's');
      expect(receipt.issueDescription, 'it broke');
      expect(receipt.transcriptAttachmentRequested, isTrue);
      final order = [for (final c in f.client.calls) '${c.$1} ${c.$2}'];
      expect(order, [
        'GET /messages/channel/dm1',
        'GET /agents/a/activity-log',
        'POST /servers/s/scope-attestation',
        'POST /servers/s/machines/m1/agents/a/feedback/report-1/transcript',
        'POST /product-feedback',
      ]);
      expect(f.client.calls[2].$3, {'scope': 'feedback-report:create'});
      expect(f.client.calls[3].$3, {
        'reportGeneratedAt': '2026-06-18T09:00:00.000Z',
        'includeMachineLogTail': true,
      });
      final form = f.client.calls[4].$3 as FormData;
      final fields = {for (final e in form.fields) e.key: e.value};
      expect(fields['type'], 'problem');
      expect(fields['message'], 'Issue report for Alpha Agent\n\nit broke');
      expect(fields['submission_id'], 'submission-1');
      expect(fields['feedback_report_id'], 'report-1');
      expect(fields['may_contact'], 'false');
      expect(jsonDecode(fields['metadata']!), {'locale': 'en'});
      // Worker calls: create -> upload -> complete.
      expect(
        [for (final c in f.transport.calls) '${c.$1} ${c.$2}'],
        [
          'POST https://feedback.example.test/api/reports',
          'PUT https://storage.example.test/up',
          'POST https://feedback.example.test/api/reports/report-1/complete',
        ],
      );
      final create = f.transport.calls[0].$3! as Map;
      expect(create['attestation'], 'att');
      expect(create['agentId'], 'a');
      expect(create['category'], 'bug');
      expect(create['title'], 'Issue report for Alpha Agent');
      expect(create['description'], 'it broke');
      final bundle = jsonDecode(utf8.decode(f.transport.calls[1].$4!)) as Map;
      expect(bundle['schemaVersion'], 'slock-feedback-export-v2');
      expect(bundle['issue'], {'description': 'it broke'});
      expect((bundle['agent'] as Map)['machineName'], 'Box');
      expect((bundle['agent'] as Map)['machineOs'], 'linux');
      expect(bundle['daemonVersion'], '0.9');
      final logs = bundle['logs'] as Map;
      expect((logs['recentMessages'] as Map)['entries'], hasLength(1));
      expect((logs['ephemeralActivityBuffer'] as Map)['entries'], hasLength(1));
      expect((logs['durableTrajectoryLog'] as Map)['entries'], hasLength(1));
      expect(create['bundleSha256'], hasLength(64));
      expect(create['bundleSizeBytes'], f.transport.calls[1].$4!.length);
      expect((create['metadata'] as Map)['transcript'], {
        'attachmentMode': 'async_trace_bundle',
        'requested': true,
        'requestable': true,
        'skippedReason': null,
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        f.session.transcriptState.value,
        RaftTranscriptRequestState.requested,
      );
    },
  );

  test('unticked sources are not collected', () async {
    final f = _Fixture(_Client(_answers()), _Transport());
    addTearDown(f.dispose);
    await f.session.submit(
      const RaftReportIssueOptions(
        description: '',
        includeRecentMessages: false,
        includeActivityLog: false,
        includeTrajectoryLog: false,
        includeSessionTranscript: false,
        includeMachineLogTail: false,
      ),
    );
    final order = [for (final c in f.client.calls) '${c.$1} ${c.$2}'];
    expect(order, [
      'POST /servers/s/scope-attestation',
      'POST /product-feedback',
    ]);
    final bundle = jsonDecode(utf8.decode(f.transport.calls[1].$4!)) as Map;
    final logs = bundle['logs'] as Map;
    expect((logs['recentMessages'] as Map)['included'], isFalse);
    expect((logs['recentMessages'] as Map)['entries'], isNull);
    expect(f.session.transcriptState.value, isNull);
  });

  Future<String> failure(_Fixture f) async {
    try {
      await f.session.submit(_all);
    } on RaftReportIssueFailure catch (e) {
      return e.message;
    }
    fail('expected a failure');
  }

  test('each step fails with its own label and detail', () async {
    var f = _Fixture(
      _Client({..._answers()}..remove('POST /servers/s/scope-attestation')),
      _Transport(),
    );
    expect(
      await failure(f),
      'Create server attestation failed: HTTP 404: not found',
    );
    f.dispose();
    f = _Fixture(
      _Client({..._answers()}..remove('GET /messages/channel/dm1')),
      _Transport(),
    );
    expect(
      await failure(f),
      'Collect report bundle failed: HTTP 404: not found',
    );
    f.dispose();
    f = _Fixture(_Client(_answers()), _Transport()..createStatus = 500);
    expect(
      await failure(f),
      'Create report upload failed: HTTP 500: worker down',
    );
    f.dispose();
    f = _Fixture(_Client(_answers()), _Transport()..uploadStatus = 403);
    expect(
      await failure(f),
      'Upload report bundle failed: HTTP 403: Failed to upload feedback bundle',
    );
    f.dispose();
    f = _Fixture(_Client(_answers()), _Transport()..completeStatus = 502);
    expect(
      await failure(f),
      'Finalize report failed: HTTP 502: Failed to finalize feedback report',
    );
    f.dispose();
  });

  test(
    'a missing export worker or server is reported before any request',
    () async {
      final f = _Fixture(_Client(_answers()), _Transport());
      addTearDown(f.dispose);
      final none = ReportIssueSession(
        controller: f.w,
        agent: _agent,
        exportUrl: '',
        translate: (s) => s,
        locale: 'en',
        browser: const {},
      );
      await expectLater(
        none.submit(_all),
        throwsA(
          isA<RaftReportIssueFailure>().having(
            (e) => e.message,
            'message',
            'Feedback export is not configured for this deployment yet.',
          ),
        ),
      );
      f.w.server = null;
      await expectLater(
        f.session.submit(_all),
        throwsA(
          isA<RaftReportIssueFailure>().having(
            (e) => e.message,
            'message',
            'Current server is unavailable.',
          ),
        ),
      );
      expect(f.client.calls, isEmpty);
      none.dispose();
    },
  );

  test(
    'a failed ticket keeps the report and a retry reuses the submission id',
    () async {
      final client = _Client(_answers(ticketFails: true));
      final f = _Fixture(client, _Transport());
      addTearDown(f.dispose);
      final receipt = await f.session.submit(_all);
      expect(receipt.ticketId, isNull);
      expect(receipt.reportId, 'report-1');
      client.answers['POST /product-feedback'] = (_) => {'id': 'ticket-2'};
      expect(await f.session.retryTicket(receipt), 'ticket-2');
      final tickets = [
        for (final c in client.calls)
          if (c.$2 == '/product-feedback') c.$3 as FormData,
      ];
      expect(tickets, hasLength(2));
      for (final form in tickets) {
        expect(
          {for (final e in form.fields) e.key: e.value}['submission_id'],
          'submission-1',
        );
      }
    },
  );

  test('the session record request reports its HTTP result', () async {
    var f = _Fixture(
      _Client(
        _answers(transcript: const RaftApiException('boom', status: 500)),
      ),
      _Transport(),
    );
    await f.session.submit(_all);
    await Future<void>.delayed(Duration.zero);
    expect(
      f.session.transcriptState.value,
      RaftTranscriptRequestState.requestFailed,
    );
    f.dispose();
    // No HTTP status: the answer never arrived.
    f = _Fixture(
      _Client(_answers(transcript: const RaftApiException('offline'))),
      _Transport(),
    );
    await f.session.submit(_all);
    await Future<void>.delayed(Duration.zero);
    expect(
      f.session.transcriptState.value,
      RaftTranscriptRequestState.requestUnconfirmed,
    );
    f.dispose();
  });

  test('a session record request without an answer is unconfirmed at the cap', () async {
    final pending = Completer<Object?>();
    final client = _Client(_answers());
    client.answers['POST /servers/s/machines/m1/agents/a/feedback/report-1/transcript'] =
        (_) => pending.future;
    final f = _Fixture(
      client,
      _Transport(),
      confirmCap: const Duration(milliseconds: 20),
    );
    addTearDown(f.dispose);
    // The dispatcher awaits the request through `command`; the ticket is
    // filed meanwhile because the submission never waits on it.
    await f.session.submit(_all);
    expect(f.session.transcriptState.value, RaftTranscriptRequestState.pending);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(
      f.session.transcriptState.value,
      RaftTranscriptRequestState.requestUnconfirmed,
    );
    pending.complete({});
    await Future<void>.delayed(Duration.zero);
    expect(
      f.session.transcriptState.value,
      RaftTranscriptRequestState.requested,
    );
  });

  test(
    'the machine log option is offered only for the reporter\'s own machine',
    () {
      final own = _Fixture(_Client(_answers()), _Transport());
      addTearDown(own.dispose);
      expect(own.session.canIncludeMachineLog, isTrue);
      final other = _Fixture(
        _Client(_answers()),
        _Transport(),
        machine: {'id': 'm1', 'name': 'Other'},
      );
      addTearDown(other.dispose);
      expect(other.session.canIncludeMachineLog, isFalse);
    },
  );

  test('copy reference puts the report ids on the clipboard', () async {
    final copied = <String>[];
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final f = _Fixture(_Client(_answers()), _Transport());
    addTearDown(f.dispose);
    await f.session.copyReference(
      const RaftReportIssueReceipt(
        reportId: 'r1',
        serverId: 's1',
        issueDescription: 'it broke',
      ),
    );
    expect(
      copied.single,
      'reportId: r1\nserverId: s1\nissueDescription:\nit broke',
    );
  });

  group('agent profile entry', () {
    Future<void> pumpProfile(WidgetTester tester, {String? url}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = _Client({
        ..._answers(),
        'GET /agents': (_) => [_agent],
        'GET /agents/a': (_) => _agent,
        'GET /servers/s/machines': (_) => {'machines': []},
        'GET /agents/a/skills': (_) => {'global': [], 'workspace': []},
      })..selectServer('s');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: FleetDetail(
              controller: w,
              computers: false,
              initial: const {'id': 'a'},
              feedbackExportUrl: url,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden when the build has no feedback export worker', (
      tester,
    ) async {
      await pumpProfile(tester, url: '');
      expect(find.byKey(const ValueKey('agent-report-issue')), findsNothing);
    });

    testWidgets('opens the dialog from the Actions section', (tester) async {
      await pumpProfile(tester, url: 'https://feedback.example.test');
      final button = find.byKey(const ValueKey('agent-report-issue'));
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.descendant(of: button, matching: find.text('Report Issue')),
        findsOneWidget,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(RaftReportIssueDialog), findsOneWidget);
      expect(find.text('Alpha Agent'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('report-issue-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(RaftReportIssueDialog), findsNothing);
    });
  });
}
