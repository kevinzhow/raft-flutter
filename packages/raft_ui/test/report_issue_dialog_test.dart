import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The English framework strings for any locale (only Raft copy is asserted).
class _AnyLocale<T> extends LocalizationsDelegate<T> {
  const _AnyLocale(this.value);
  final T value;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<T> load(Locale locale) => SynchronousFuture<T>(value);
  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

Future<void> _pump(
  WidgetTester tester, {
  bool hasMachine = true,
  bool canIncludeMachineLog = false,
  Future<RaftReportIssueReceipt> Function(RaftReportIssueOptions)? onSubmit,
  Future<String?> Function(RaftReportIssueReceipt)? onRetryTicket,
  Future<void> Function(RaftReportIssueReceipt)? onCopyReference,
  void Function(String)? onViewTicket,
  ValueNotifier<RaftTranscriptRequestState?>? transcript,
  VoidCallback? onClose,
  Locale? locale,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: locale ?? const Locale('en'),
            delegates: const [
              _AnyLocale<MaterialLocalizations>(DefaultMaterialLocalizations()),
              _AnyLocale<WidgetsLocalizations>(DefaultWidgetsLocalizations()),
            ],
            child: RaftReportIssueDialog(
              agentName: 'Product UX Designer',
              hasMachine: hasMachine,
              canIncludeMachineLog: canIncludeMachineLog,
              onSubmit:
                  onSubmit ??
                  (_) async => const RaftReportIssueReceipt(
                    reportId: 'r1',
                    serverId: 's1',
                    ticketId: 't1',
                  ),
              onRetryTicket: onRetryTicket,
              onCopyReference: onCopyReference,
              onViewTicket: onViewTicket,
              transcriptState: transcript,
              onClose: onClose ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _key(String k) => find.byKey(ValueKey(k));

bool _enabled(WidgetTester tester, String key) {
  final button = tester.widget<RaftRecipeButton>(_key(key));
  return !button.disabled;
}

void main() {
  testWidgets('submit stays disabled until the consent box is ticked', (
    tester,
  ) async {
    RaftReportIssueOptions? sent;
    await _pump(
      tester,
      onSubmit: (o) async {
        sent = o;
        return const RaftReportIssueReceipt(
          reportId: 'r1',
          serverId: 's1',
          ticketId: 't1',
        );
      },
    );
    // The dialog title and the submit button share the label.
    expect(find.text('Report Issue'), findsNWidgets(2));
    expect(find.text('Product UX Designer'), findsOneWidget);
    expect(_enabled(tester, 'report-issue-submit'), isFalse);
    await tester.tap(_key('report-issue-submit'));
    await tester.pump();
    expect(sent, isNull);
    await tester.enterText(_key('report-issue-description'), '  it crashed  ');
    await tester.tap(_key('report-issue-consent'));
    await tester.pump();
    expect(_enabled(tester, 'report-issue-submit'), isTrue);
    await tester.tap(_key('report-issue-recent-messages'));
    await tester.pump();
    await tester.tap(_key('report-issue-submit'));
    await tester.pumpAndSettle();
    expect(sent!.description, '  it crashed  ');
    expect(sent!.includeRecentMessages, isFalse);
    expect(sent!.includeActivityLog, isTrue);
    expect(sent!.includeTrajectoryLog, isTrue);
    expect(sent!.includeSessionTranscript, isTrue);
    expect(sent!.includeMachineLogTail, isFalse);
    expect(find.text('Report Submitted'), findsOneWidget);
    expect(
      find.text(
        'We opened a feedback ticket for this report. Replies from the Raft team will show up there.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed submission shows the step message and stays open', (
    tester,
  ) async {
    await _pump(
      tester,
      onSubmit: (_) async => throw const RaftReportIssueFailure(
        'Create report upload failed: HTTP 500: boom',
      ),
    );
    await tester.tap(_key('report-issue-consent'));
    await tester.pump();
    await tester.tap(_key('report-issue-submit'));
    await tester.pumpAndSettle();
    expect(
      find.text('Create report upload failed: HTTP 500: boom'),
      findsOneWidget,
    );
    expect(find.text('Report Issue'), findsNWidgets(2));
    expect(_enabled(tester, 'report-issue-submit'), isTrue);
  });

  testWidgets('an unknown failure falls back to the generic message', (
    tester,
  ) async {
    await _pump(tester, onSubmit: (_) async => throw StateError('x'));
    await tester.tap(_key('report-issue-consent'));
    await tester.pump();
    await tester.tap(_key('report-issue-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to submit issue report'), findsOneWidget);
  });

  testWidgets('without a machine the transcript box is disabled', (
    tester,
  ) async {
    await _pump(tester, hasMachine: false);
    expect(
      find.text(
        'Runtime transcript upload is unavailable until the agent is assigned to a computer.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        "The agent's computer is asked for its session record; it may not have one.",
      ),
      findsNothing,
    );
    final box = tester.widget<RaftCheckbox>(
      find.descendant(
        of: _key('report-issue-transcript'),
        matching: find.byType(RaftCheckbox),
      ),
    );
    expect(box.value, isFalse);
    expect(box.onChanged, isNull);
  });

  testWidgets('the machine log tail follows ownership and the transcript box', (
    tester,
  ) async {
    RaftReportIssueOptions? sent;
    await _pump(
      tester,
      canIncludeMachineLog: true,
      onSubmit: (o) async {
        sent = o;
        return const RaftReportIssueReceipt(reportId: 'r', serverId: 's');
      },
    );
    RaftCheckbox tail() => tester.widget<RaftCheckbox>(
      find.descendant(
        of: _key('report-issue-machine-log'),
        matching: find.byType(RaftCheckbox),
      ),
    );
    // Defaults on for the reporter's own machine.
    expect(tail().value, isTrue);
    await tester.tap(_key('report-issue-transcript'));
    await tester.pump();
    // Requires the runtime transcript above.
    expect(tail().onChanged, isNull);
    await tester.tap(_key('report-issue-transcript'));
    await tester.pump();
    await tester.tap(_key('report-issue-machine-log'));
    await tester.pump();
    expect(tail().value, isFalse);
    await tester.tap(_key('report-issue-machine-log'));
    await tester.pump();
    await tester.tap(_key('report-issue-consent'));
    await tester.pump();
    await tester.tap(_key('report-issue-submit'));
    await tester.pumpAndSettle();
    expect(sent!.includeMachineLogTail, isTrue);
  });

  testWidgets('a missing ticket offers the reference, copy and retry', (
    tester,
  ) async {
    final copied = <String>[];
    var retries = 0;
    String? opened;
    await _pump(
      tester,
      onSubmit: (_) async => const RaftReportIssueReceipt(
        reportId: 'report-9',
        serverId: 'server-3',
      ),
      onRetryTicket: (r) async {
        retries++;
        return retries == 1 ? null : 'ticket-1';
      },
      onCopyReference: (r) async => copied.add(r.reportId),
      onViewTicket: (id) => opened = id,
    );
    await tester.tap(_key('report-issue-consent'));
    await tester.pump();
    await tester.tap(_key('report-issue-submit'));
    await tester.pumpAndSettle();
    expect(find.text('report-9'), findsOneWidget);
    expect(find.text('server-3'), findsOneWidget);
    expect(
      find.text(
        "The report was uploaded, but we couldn't open a feedback ticket for it. Share the reference below with the Raft team.",
      ),
      findsOneWidget,
    );
    expect(_key('report-issue-view-ticket'), findsNothing);
    await tester.tap(_key('report-issue-copy-reference'));
    await tester.pumpAndSettle();
    expect(copied, ['report-9']);
    expect(find.text('Copied'), findsOneWidget);
    await tester.tap(_key('report-issue-retry-ticket'));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(_key('report-issue-reference'), findsOneWidget);
    await tester.tap(_key('report-issue-retry-ticket'));
    await tester.pumpAndSettle();
    expect(retries, 2);
    // The reference card is gone; the ticket can be viewed.
    expect(_key('report-issue-reference'), findsNothing);
    await tester.tap(_key('report-issue-view-ticket'));
    expect(opened, 'ticket-1');
  });

  testWidgets('the session record request state is announced', (tester) async {
    final state = ValueNotifier<RaftTranscriptRequestState?>(null);
    addTearDown(state.dispose);
    await _pump(
      tester,
      transcript: state,
      onSubmit: (_) async => const RaftReportIssueReceipt(
        reportId: 'r',
        serverId: 's',
        ticketId: 't',
        transcriptAttachmentRequested: true,
      ),
    );
    await tester.tap(_key('report-issue-consent'));
    await tester.pump();
    await tester.tap(_key('report-issue-submit'));
    await tester.pumpAndSettle();
    expect(_key('report-issue-transcript-state'), findsNothing);
    state.value = RaftTranscriptRequestState.pending;
    await tester.pump();
    expect(
      find.text("Requesting the session record from the agent's computer…"),
      findsOneWidget,
    );
    state.value = RaftTranscriptRequestState.requestUnconfirmed;
    await tester.pump();
    expect(
      find.text(
        "Couldn't confirm that the session record request reached the server.",
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Cancel and the close button close, Chinese copy follows locale',
    (tester) async {
      var closed = 0;
      await _pump(tester, locale: const Locale('zh'), onClose: () => closed++);
      expect(find.text('报告问题'), findsWidgets);
      expect(find.text('描述问题'), findsNothing); // upper-cased label
      await tester.tap(_key('report-issue-cancel'));
      expect(closed, 1);
    },
  );

  testWidgets('a raw exception never reaches the dialog; a step failure does', (
    tester,
  ) async {
    var attempt = 0;
    await _pump(
      tester,
      onSubmit: (_) async {
        attempt++;
        if (attempt == 1) throw const FormatException('secret://host?token=1');
        throw const RaftReportIssueFailure(
          'Create server attestation failed: HTTP 404: not found',
        );
      },
    );
    await tester.tap(_key('report-issue-consent'));
    await tester.pump();
    await tester.tap(_key('report-issue-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to submit issue report'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.byType(RaftErrorBanner), findsOneWidget);
    await tester.tap(_key('report-issue-submit'));
    await tester.pumpAndSettle();
    expect(
      find.text('Create server attestation failed: HTTP 404: not found'),
      findsOneWidget,
    );
  });
}
