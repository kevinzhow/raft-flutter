// Agent "Report Issue" (Web components/agent/ReportIssueDialog.tsx +
// feedback/agentIssueTicket.ts + feedback/transcriptRequestState.ts +
// utils/feedbackExportBundle.ts): the app side of RaftReportIssueDialog. It
// reads the DM history, builds the diagnostic bundle, files it through the
// feedback-export worker (scope attestation -> create -> upload -> complete),
// asks the agent's computer for its session record and opens the product
// feedback ticket. The entry only exists when the build names a feedback
// export worker (Web `VITE_FEEDBACK_EXPORT_URL`, here `RAFT_FEEDBACK_EXPORT_URL`).
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_client/system_proxy.dart' show createProxiedDio;
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';

/// The build's feedback export worker (Web `VITE_FEEDBACK_EXPORT_URL`).
const reportIssueBuildUrl = String.fromEnvironment('RAFT_FEEDBACK_EXPORT_URL');
const _appVersion = String.fromEnvironment(
  'RAFT_APP_VERSION',
  defaultValue: 'development',
);
const _commitSha = String.fromEnvironment('RAFT_COMMIT_SHA');
// Same default as the computer setup commands and the announcement host.
const _deploymentEnv = String.fromEnvironment(
  'RAFT_DEPLOYMENT_ENV',
  defaultValue: 'production',
);

/// Web `VITE_FEEDBACK_EXPORT_URL?.replace(/\/+$/, "")`.
String reportIssueExportUrl([String raw = reportIssueBuildUrl]) =>
    raw.trim().replaceFirst(RegExp(r'/+$'), '');

/// Web `FEEDBACK_EXPORT_ENABLED`: the Report Issue entry is only offered when
/// the build names a feedback export worker.
bool reportIssueEnabled([String raw = reportIssueBuildUrl]) =>
    reportIssueExportUrl(raw).isNotEmpty;

/// TRANSCRIPT_REQUEST_CONFIRM_CAP_MS: measured from the start of the request.
const reportIssueTranscriptConfirmCap = Duration(seconds: 10);

class ReportIssueHttpResponse {
  const ReportIssueHttpResponse(this.status, this.body);
  final int status;
  final String body;
  bool get ok => status >= 200 && status < 300;
  dynamic get json {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

/// The calls to the feedback export worker and its storage (fetch in Web).
abstract class ReportIssueTransport {
  Future<ReportIssueHttpResponse> send(
    String method,
    String url, {
    Map<String, String> headers = const {},
    Object? jsonBody,
    List<int>? bytes,
  });
}

class _DioReportIssueTransport implements ReportIssueTransport {
  final _dio = createProxiedDio(BaseOptions(validateStatus: (_) => true));
  @override
  Future<ReportIssueHttpResponse> send(
    String method,
    String url, {
    Map<String, String> headers = const {},
    Object? jsonBody,
    List<int>? bytes,
  }) async {
    final response = await _dio.request<String>(
      url,
      data: bytes ?? (jsonBody == null ? null : jsonEncode(jsonBody)),
      options: Options(
        method: method,
        headers: {
          if (jsonBody != null) 'Content-Type': 'application/json',
          ...headers,
        },
        responseType: ResponseType.plain,
      ),
    );
    return ReportIssueHttpResponse(
      response.statusCode ?? 0,
      response.data ?? '',
    );
  }
}

/// Web `readNestedErrorMessage`.
String? _nestedMessage(Object? value) {
  if (value is! Map) return null;
  final direct = value['error'] ?? value['message'];
  if (direct is String && direct.trim().isNotEmpty) return direct.trim();
  return _nestedMessage(value['data']);
}

/// The submission, separated from the dialog so it can be exercised alone.
class ReportIssueSession {
  ReportIssueSession({
    required this.controller,
    required this.agent,
    required this.exportUrl,
    required this.translate,
    required this.locale,
    required this.browser,
    this.machine,
    this.dmChannelId,
    this.activityLog,
    ReportIssueTransport? transport,
    this.now = DateTime.now,
    this.confirmCap = reportIssueTranscriptConfirmCap,
  }) : transport = transport ?? _DioReportIssueTransport();

  final WorkspaceController controller;
  final Map<String, dynamic> agent;
  final Map<String, dynamic>? machine;
  final String? dmChannelId;
  final String exportUrl, locale;

  /// Live activity buffer of the agent (Web `getActivityLog`).
  final List<Map<String, dynamic>>? activityLog;

  /// Client environment of the bundle's `browser` block.
  final Map<String, dynamic> browser;
  final String Function(String source) translate;
  final ReportIssueTransport transport;
  final DateTime Function() now;
  final Duration confirmCap;

  /// Session record request state; null until a request started.
  final transcriptState = ValueNotifier<RaftTranscriptRequestState?>(null);

  String get agentId => '${agent['id']}';
  String get agentLabel =>
      '${agent['displayName'] ?? agent['name'] ?? ''}'.isNotEmpty
      ? '${agent['displayName'] ?? agent['name']}'
      : '${agent['name'] ?? ''}';
  String? get machineId =>
      agent['machineId'] is String && '${agent['machineId']}'.isNotEmpty
      ? agent['machineId'] as String
      : null;
  bool get canIncludeMachineLog =>
      machineId != null && machine?['computerAttachedByCurrentUser'] == true;

  String get title => raftFormatPlain(translate('Issue report for {name}'), {
    'name': agentLabel,
  });

  /// Web `describeApiFailure`: `HTTP {status}: {detail}` for a server answer.
  String _apiFailure(Object error) {
    // The detail is the server's own error text or `Unknown error`; a raw
    // exception is logged, never put in the report dialog.
    final detail = translate(
      userErrorText(error, fallback: 'Unknown error', where: 'report issue'),
    );
    if (error is RaftApiException && error.status != null) {
      return raftFormatPlain(translate('HTTP {status}: {detail}'), {
        'status': error.status,
        'detail': detail,
      });
    }
    return detail;
  }

  RaftReportIssueFailure _step(String label, String detail) =>
      RaftReportIssueFailure('${translate(label)}: $detail');

  Future<String> _fetchFailure(
    ReportIssueHttpResponse response,
    String fallback,
  ) async {
    final body = _nestedMessage(response.json);
    final detail =
        body ?? (response.body.isNotEmpty ? response.body : fallback);
    return raftFormatPlain(translate('HTTP {status}: {detail}'), {
      'status': response.status,
      'detail': detail,
    });
  }

  String _exportFilename() {
    final safe = '${agent['displayName'] ?? agent['name'] ?? ''}'
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final stamp = now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    return 'slock-feedback-export-${safe.isEmpty ? 'agent' : safe}-$stamp.json';
  }

  /// Web `ReportIssueDialog.handleSubmit`.
  Future<RaftReportIssueReceipt> submit(RaftReportIssueOptions options) async {
    if (exportUrl.isEmpty) {
      throw RaftReportIssueFailure(
        translate('Feedback export is not configured for this deployment yet.'),
      );
    }
    final server = controller.server;
    if (server == null || server.id.isEmpty) {
      throw RaftReportIssueFailure(translate('Current server is unavailable.'));
    }
    final description = options.description.trim();

    List<dynamic>? recentMessages;
    if (options.includeRecentMessages && dmChannelId != null) {
      try {
        final data = await controller.client.get(
          '/messages/channel/$dmChannelId',
          query: {'limit': 100},
        );
        recentMessages = data is Map && data['messages'] is List
            ? List<dynamic>.of(data['messages'] as List)
            : <dynamic>[];
      } catch (e) {
        throw _step('Collect report bundle failed', _apiFailure(e));
      }
    }

    Map<String, dynamic> bundle;
    List<int> bundleBytes;
    String filename, sha;
    try {
      List<dynamic>? trajectory;
      if (options.includeTrajectoryLog) {
        try {
          final data = await controller.client.get(
            '/agents/$agentId/activity-log',
          );
          trajectory = data is List ? List<dynamic>.of(data) : <dynamic>[];
        } catch (_) {
          trajectory = <dynamic>[];
        }
      }
      final user = controller.client.user;
      bundle = buildFeedbackExportBundle(
        generatedAt: now().toUtc().toIso8601String(),
        appVersion: [
          _appVersion,
          _commitSha.trim(),
        ].where((part) => part.isNotEmpty).join('+'),
        machine: machine,
        description: description,
        reporter: {
          'id': user?.id,
          'email': user?.json['email'],
          'name': user?.json['name'],
          'displayName': user?.json['displayName'],
        },
        server: {
          'id': server.id,
          'slug': server.json['slug'],
          'name': server.json['name'],
        },
        agent: agent,
        recentMessages: recentMessages,
        ephemeralActivityBuffer: options.includeActivityLog
            ? List<dynamic>.of(activityLog ?? const [])
            : null,
        durableTrajectoryLog: trajectory,
        includeRecentMessages: options.includeRecentMessages,
        includeEphemeralActivityBuffer: options.includeActivityLog,
        includeDurableTrajectoryLog: options.includeTrajectoryLog,
        browser: browser,
      );
      bundleBytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(bundle),
      );
      filename = _exportFilename();
      sha = sha256.convert(bundleBytes).toString();
    } catch (e) {
      throw _step('Collect report bundle failed', _apiFailure(e));
    }

    Map<String, dynamic> attestation;
    try {
      final data = await controller.command(
        'POST',
        '/servers/${server.id}/scope-attestation',
        data: {'scope': 'feedback-report:create'},
      );
      attestation = Map<String, dynamic>.from(data as Map);
    } catch (e) {
      throw _step('Create server attestation failed', _apiFailure(e));
    }

    final machineIdValue = machineId;
    final logs = bundle['logs'] as Map;
    final created = await transport.send(
      'POST',
      '$exportUrl/api/reports',
      jsonBody: {
        'attestation': attestation['attestation'],
        'agentId': agentId,
        'agentName': agentLabel,
        'bundleFilename': filename,
        'bundleContentType': 'application/json',
        'bundleSizeBytes': bundleBytes.length,
        'bundleSha256': sha,
        'source': 'slock-web',
        'category': 'bug',
        'title': title,
        if (description.isNotEmpty) 'description': description,
        if (bundle['appVersion'] != null) 'appVersion': bundle['appVersion'],
        if (bundle['daemonVersion'] != null)
          'daemonVersion': bundle['daemonVersion'],
        'metadata': {
          'schemaVersion': bundle['schemaVersion'],
          'reportGeneratedAt': bundle['generatedAt'],
          'dmChannelId': dmChannelId,
          'deploymentEnv': _deploymentEnv.isEmpty ? null : _deploymentEnv,
          'includes': {
            'recentMessages': (logs['recentMessages'] as Map)['included'],
            'activityLog': (logs['ephemeralActivityBuffer'] as Map)['included'],
            'trajectoryLog': (logs['durableTrajectoryLog'] as Map)['included'],
            'ephemeralActivityBuffer':
                (logs['ephemeralActivityBuffer'] as Map)['included'],
            'durableTrajectoryLog':
                (logs['durableTrajectoryLog'] as Map)['included'],
            if (machineIdValue != null)
              'runtimeSessionTranscript': options.includeSessionTranscript,
          },
          if (machineIdValue != null)
            'transcript': {
              'attachmentMode': 'async_trace_bundle',
              'requested': options.includeSessionTranscript,
              'requestable': true,
              'skippedReason': null,
            },
        },
      },
    );
    if (!created.ok) {
      throw _step(
        'Create report upload failed',
        await _fetchFailure(
          created,
          translate('Failed to create feedback report'),
        ),
      );
    }
    final report = Map<String, dynamic>.from(created.json as Map);
    final upload = Map<String, dynamic>.from(report['upload'] as Map);
    final uploaded = await transport.send(
      '${upload['method']}',
      '${upload['url']}',
      headers: {
        for (final e in (upload['headers'] as Map? ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      bytes: bundleBytes,
    );
    if (!uploaded.ok) {
      throw _step(
        'Upload report bundle failed',
        await _fetchFailure(
          uploaded,
          translate('Failed to upload feedback bundle'),
        ),
      );
    }
    final reportId = '${report['id']}';
    final completed = await transport.send(
      'POST',
      '$exportUrl/api/reports/$reportId/complete',
      jsonBody: {'completeToken': report['completeToken']},
    );
    if (!completed.ok) {
      throw _step(
        'Finalize report failed',
        await _fetchFailure(
          completed,
          translate('Failed to finalize feedback report'),
        ),
      );
    }

    final transcriptRequested =
        options.includeSessionTranscript && machineIdValue != null;
    if (transcriptRequested) {
      // Started before the ticket and never awaited by the submission.
      _startTranscriptRequest(
        () => controller.command(
          'POST',
          '/servers/${server.id}/machines/$machineIdValue/agents/$agentId/feedback/$reportId/transcript',
          data: {
            'reportGeneratedAt': bundle['generatedAt'],
            if (canIncludeMachineLog && options.includeMachineLogTail)
              'includeMachineLogTail': true,
          },
        ),
      );
    }
    final message = [
      title,
      description,
    ].where((s) => s.isNotEmpty).join('\n\n');
    final ticketRequest = _TicketRequest(
      message: message,
      feedbackReportId: reportId,
      submissionId: controller.client.newRandomId(),
      locale: locale,
    );
    final ticketId = await _fileTicket(ticketRequest);
    final receipt = RaftReportIssueReceipt(
      reportId: reportId,
      serverId: server.id,
      ticketId: ticketId,
      issueDescription: description.isEmpty ? null : description,
      transcriptAttachmentRequested: transcriptRequested,
    );
    _tickets[receipt.reportId] = ticketRequest;
    return receipt;
  }

  final _tickets = <String, _TicketRequest>{};

  /// Retry with the submission id of the first attempt (the server dedupes).
  Future<String?> retryTicket(RaftReportIssueReceipt receipt) async {
    final request = _tickets[receipt.reportId];
    return request == null ? null : _fileTicket(request);
  }

  /// Web `fileTicket`: null on any failure, the bundle is already uploaded.
  Future<String?> _fileTicket(_TicketRequest request) async {
    try {
      final data = await controller.client.request(
        'POST',
        '/product-feedback',
        data: FormData.fromMap({
          'type': 'problem',
          'message': request.message,
          'metadata': jsonEncode({'locale': request.locale}),
          'submission_id': request.submissionId,
          'may_contact': 'false',
          'feedback_report_id': request.feedbackReportId,
        }),
      );
      return data is Map && data['id'] != null ? '${data['id']}' : null;
    } catch (_) {
      return null;
    }
  }

  /// Web `startTranscriptRequest`: `pending` immediately, `request_unconfirmed`
  /// after the cap without an answer, a later answer still updates the state.
  void _startTranscriptRequest(Future<dynamic> Function() send) {
    if (_disposed) return;
    transcriptState.value = RaftTranscriptRequestState.pending;
    var answered = false;
    final timer = Timer(confirmCap, () {
      if (!answered && !_disposed) {
        transcriptState.value = RaftTranscriptRequestState.requestUnconfirmed;
      }
    });
    Future<dynamic> sent;
    try {
      sent = send();
    } catch (e) {
      sent = Future<dynamic>.error(e);
    }
    unawaited(
      sent
          .then<RaftTranscriptRequestState>(
            (_) => RaftTranscriptRequestState.requested,
            // An HTTP status means the server answered non-2xx; none means the
            // answer never arrived.
            onError: (Object e) => e is RaftApiException && e.status != null
                ? RaftTranscriptRequestState.requestFailed
                : RaftTranscriptRequestState.requestUnconfirmed,
          )
          .then((state) {
            answered = true;
            timer.cancel();
            if (!_disposed) transcriptState.value = state;
          }),
    );
  }

  /// Web `handleCopyReportReference`.
  Future<void> copyReference(RaftReportIssueReceipt receipt) {
    final lines = [
      'reportId: ${receipt.reportId}',
      'serverId: ${receipt.serverId}',
      if (receipt.issueDescription != null)
        'issueDescription:\n${receipt.issueDescription}',
    ];
    return Clipboard.setData(ClipboardData(text: lines.join('\n')));
  }

  bool _disposed = false;
  void dispose() {
    _disposed = true;
    transcriptState.dispose();
  }
}

class _TicketRequest {
  const _TicketRequest({
    required this.message,
    required this.feedbackReportId,
    required this.submissionId,
    required this.locale,
  });
  final String message, feedbackReportId, submissionId, locale;
}

/// `{name}` substitution on an already translated string.
String raftFormatPlain(String text, Map<String, Object?> values) =>
    text.replaceAllMapped(
      RegExp(r'\{([a-zA-Z0-9_]+)\}'),
      (m) => values.containsKey(m[1]) ? '${values[m[1]]}' : m[0]!,
    );

/// `snapshotAgentMachine` + `buildFeedbackExportBundle`.
Map<String, dynamic> buildFeedbackExportBundle({
  required String generatedAt,
  required String appVersion,
  required Map<String, dynamic>? machine,
  required String description,
  required Map<String, dynamic> reporter,
  required Map<String, dynamic> server,
  required Map<String, dynamic> agent,
  required List<dynamic>? recentMessages,
  required List<dynamic>? ephemeralActivityBuffer,
  required List<dynamic>? durableTrajectoryLog,
  required bool includeRecentMessages,
  required bool includeEphemeralActivityBuffer,
  required bool includeDurableTrajectoryLog,
  required Map<String, dynamic> browser,
}) {
  String? reported(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;
  return {
    'schemaVersion': 'slock-feedback-export-v2',
    'generatedAt': generatedAt,
    'appVersion': appVersion.isEmpty ? null : appVersion,
    'daemonVersion': machine?['daemonVersion'],
    'issue': {
      'description': description.trim().isEmpty ? null : description.trim(),
    },
    'reporter': reporter,
    'server': server,
    'agent': {
      'id': agent['id'],
      'name': agent['name'],
      'displayName': agent['displayName'],
      'description': agent['description'],
      'status': agent['status'],
      'runtime': agent['runtime'],
      'model': agent['model'],
      'reasoningEffort': agent['reasoningEffort'],
      'machineId': agent['machineId'],
      'machineName': machine?['name'],
      'machineStatus': machine?['status'],
      'machineOs': reported(machine?['os']),
      'machineComputerVersion': reported(machine?['computerVersion']),
      'machineLastHeartbeat': reported(machine?['lastHeartbeat']),
    },
    'logs': {
      'recentMessages': {
        'included': includeRecentMessages,
        'source': 'server_dm_history',
        'durability': 'durable',
        'entries': recentMessages,
      },
      'ephemeralActivityBuffer': {
        'included': includeEphemeralActivityBuffer,
        'source': 'client_socket_buffer',
        'durability': 'ephemeral',
        'entries': ephemeralActivityBuffer,
      },
      'durableTrajectoryLog': {
        'included': includeDurableTrajectoryLog,
        'source': 'server_activity_log',
        'durability': 'durable',
        'entries': durableTrajectoryLog,
      },
    },
    // Deprecated v1 aliases kept for external/debug tooling.
    'activityLog': ephemeralActivityBuffer,
    'trajectoryLog': durableTrajectoryLog,
    'browser': browser,
  };
}

/// The client facts of the bundle's `browser` block.
Map<String, dynamic> reportIssueBrowserFacts(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  return {
    'url': '',
    'userAgent': 'raft-flutter/$_appVersion (${Platform.operatingSystem})',
    'language': locale,
    'languages': [locale],
    'platform': Platform.operatingSystem,
    'timezone': DateTime.now().timeZoneName,
    'viewport': {'width': size.width.round(), 'height': size.height.round()},
    'screen': {'width': size.width.round(), 'height': size.height.round()},
  };
}

/// Opens the dialog over the workspace (Web `showReportDialog`). [authorized]
/// closes it when the account, workspace or the agent's access changes.
Future<void> showReportIssueDialog(
  BuildContext context, {
  required WorkspaceController controller,
  required Map<String, dynamic> agent,
  Map<String, dynamic>? machine,
  List<Map<String, dynamic>>? activityLog,
  bool Function()? authorized,
  ReportIssueTransport? transport,
  String? exportUrl,
}) async {
  if (!context.mounted || !(authorized?.call() ?? true)) return;
  final w = controller;
  final navigator = Navigator.of(context, rootNavigator: true);
  final peer = w.dms.where((c) => c.json['peerId'] == agent['id']).firstOrNull;
  final session = ReportIssueSession(
    controller: w,
    agent: agent,
    machine: machine,
    dmChannelId: peer?.id,
    exportUrl: reportIssueExportUrl(exportUrl ?? reportIssueBuildUrl),
    activityLog: activityLog,
    translate: (s) => raftText(context, s),
    locale: Localizations.localeOf(context).toLanguageTag(),
    browser: reportIssueBrowserFacts(context),
    transport: transport,
  );
  // A form: a bottom sheet below 768, a centered dialog from 768.
  final route = raftFormRoute<void>(
    context,
    builder: (dialogContext) => RaftReportIssueDialog(
      agentName: session.agentLabel,
      hasMachine: session.machineId != null,
      canIncludeMachineLog: session.canIncludeMachineLog,
      transcriptState: session.transcriptState,
      onSubmit: session.submit,
      onRetryTicket: session.retryTicket,
      onCopyReference: session.copyReference,
      onViewTicket: (id) {
        navigator.pop();
        w.navigation.navigate(
          RaftLocation.at(
            serverSlug: w.location.serverSlug,
            route: RaftRoute.settings,
            settingsPath: ['feedback', 'ticket', id],
          ),
        );
      },
      onClose: () => navigator.pop(),
    ),
  );
  void changed() {
    if (!(authorized?.call() ?? true) && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  w.addListener(changed);
  try {
    await navigator.push(route);
  } finally {
    w.removeListener(changed);
    session.dispose();
  }
}
