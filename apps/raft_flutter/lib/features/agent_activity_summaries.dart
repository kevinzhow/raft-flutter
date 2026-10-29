// Web components/agent/AgentActivityOverview.tsx, the parts that are not
// widgets: a finished turn as `GET /agents/:id/activity-summaries` returns it,
// and the words for it (duration, trigger, clock range, action counts, problems).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'icu_message.dart';

/// `PAGE_SIZE`.
const activitySummariesPageSize = 30;

/// One problem of a turn (`ActivityTurnSummary['problems']`).
class TurnProblem {
  const TurnProblem({
    required this.at,
    required this.kind,
    required this.reason,
    this.exitCode,
  });
  final num at;
  final String? kind, reason;
  final Object? exitCode;

  /// Web `countsAsProblem`: tests or checks that ran and reported failures are
  /// ordinary work, not a step that went wrong.
  bool get counts => !(reason == 'exit_nonzero' && kind == 'run_checks');
}

/// A turn as the server returns it. A trigger the viewer cannot see comes back
/// hidden (`private_channel` / `dm`).
class TurnSummary {
  const TurnSummary({
    required this.startedAt,
    required this.endedAt,
    required this.outcome,
    required this.problemCount,
    required this.problems,
    required this.actions,
    required this.toolCalls,
    required this.messagesSent,
    this.id,
    this.lastReplyMessageId,
    this.hiddenTrigger,
    this.triggerTarget,
    this.triggerSender,
  });

  static TurnSummary? tryParse(Object? json) {
    if (json is! Map ||
        json['startedAt'] is! num ||
        json['endedAt'] is! num ||
        json['outcome'] is! String) {
      return null;
    }
    final trigger = json['trigger'];
    return TurnSummary(
      id: json['id'] is String ? json['id'] as String : null,
      startedAt: json['startedAt'] as num,
      endedAt: json['endedAt'] as num,
      outcome: json['outcome'] as String,
      problemCount: (json['problemCount'] as num?)?.toInt() ?? 0,
      problems: [
        for (final p in json['problems'] as List? ?? const [])
          if (p is Map && p['at'] is num)
            TurnProblem(
              at: p['at'] as num,
              kind: p['kind'] as String?,
              reason: p['reason'] as String?,
              exitCode: p['exitCode'],
            ),
      ],
      actions: [
        for (final a in json['actions'] as List? ?? const [])
          if (a is Map && a['kind'] is String && a['count'] is num)
            (kind: a['kind'] as String, count: (a['count'] as num).toInt()),
      ],
      toolCalls: (json['toolCalls'] as num?)?.toInt() ?? 0,
      messagesSent: (json['messagesSent'] as num?)?.toInt() ?? 0,
      lastReplyMessageId: json['lastReplyMessageId'] is String
          ? json['lastReplyMessageId'] as String
          : null,
      hiddenTrigger: trigger is Map && trigger['hidden'] is String
          ? trigger['hidden'] as String
          : null,
      triggerTarget: trigger is Map && trigger['target'] is String
          ? trigger['target'] as String
          : null,
      triggerSender: trigger is Map && trigger['sender'] is String
          ? trigger['sender'] as String
          : null,
    );
  }

  final String? id,
      lastReplyMessageId,
      hiddenTrigger,
      triggerTarget,
      triggerSender;
  final num startedAt, endedAt;
  final String outcome;
  final int problemCount, toolCalls, messagesSent;
  final List<TurnProblem> problems;
  final List<({String kind, int count})> actions;

  /// Web `turnProblemCount`.
  int get problemsShown =>
      (problemCount - problems.where((p) => !p.counts).length).clamp(
        0,
        problemCount,
      );
}

/// Web `formatTurnDuration`.
String formatTurnDuration(BuildContext context, num ms) {
  final totalSeconds = (ms / 1000).round().clamp(1, 1 << 40);
  if (totalSeconds < 60) {
    return raftFormat(context, '{seconds}s', {'seconds': totalSeconds});
  }
  final totalMinutes = totalSeconds ~/ 60;
  if (totalMinutes < 60) {
    return raftFormat(context, '{minutes}m {seconds}s', {
      'minutes': totalMinutes,
      'seconds': totalSeconds % 60,
    });
  }
  return raftFormat(context, '{hours}h {minutes}m', {
    'hours': totalMinutes ~/ 60,
    'minutes': totalMinutes % 60,
  });
}

/// Web `formatTurnTrigger`: who woke the turn, in words, or null.
String? formatTurnTrigger(BuildContext context, TurnSummary turn) {
  final hidden = turn.hiddenTrigger;
  if (hidden != null) {
    return raftText(
      context,
      hidden == 'dm'
          ? 'replying to a direct message'
          : 'replying to a message in a private channel',
    );
  }
  final target = turn.triggerTarget;
  if (target == null) return null;
  if (target.startsWith('agent-event:')) {
    return raftText(context, 'handling an app event');
  }
  final sender = turn.triggerSender == null ? null : '@${turn.triggerSender}';
  final dm = RegExp(r'^dm:(@[^:]+)').firstMatch(target);
  if (dm != null) {
    return raftFormat(context, 'replying to a direct message from {peer}', {
      'peer': dm[1],
    });
  }
  final parts = target.split(':');
  final channel = parts.first.isEmpty ? target : parts.first;
  final thread = parts.length > 1 && parts[1].isNotEmpty;
  if (sender == null) {
    return raftFormat(context, 'woken by a message in {channel}', {
      'channel': channel,
    });
  }
  return raftFormat(
    context,
    thread
        ? 'replying to {sender} in a thread in {channel}'
        : 'replying to {sender} in {channel}',
    {'sender': sender, 'channel': channel},
  );
}

/// Web `formatClockRange`: "02:38–02:44" from two clock strings; one time when
/// both are the same minute, a shared day-period word written once.
({String start, String? end}) formatClockRange(String start, String end) {
  if (start == end) return (start: start, end: null);
  final prefix = RegExp(r'^\D+').firstMatch(start)?[0];
  if (prefix != null && end.startsWith(prefix)) {
    return (start: start, end: end.substring(prefix.length));
  }
  final suffix = RegExp(r'\D+$').firstMatch(start)?[0];
  if (suffix != null && end.endsWith(suffix)) {
    return (start: start.substring(0, start.length - suffix.length), end: end);
  }
  return (start: start, end: end);
}

/// The English ICU message of each action kind (`activity.overview.action.*`).
const turnActionMessages = <String, String>{
  'run_command': 'ran {count, plural, one {a command} other {# commands}}',
  'read_file': 'read {count, plural, one {a file} other {files # times}}',
  'edit_file': 'edited {count, plural, one {a file} other {files # times}}',
  'search': 'searched {count, plural, one {once} other {# times}}',
  'web': 'searched the web {count, plural, one {once} other {# times}}',
  'fetch': 'opened {count, plural, one {a web page} other {# web pages}}',
  'subagent': 'started {count, plural, one {a subagent} other {# subagents}}',
  'mcp': 'used {count, plural, one {an MCP tool} other {MCP tools # times}}',
  'wait': 'waited {count, plural, one {once} other {# times}}',
  'other': 'used {count, plural, one {a tool} other {tools # times}}',
  'send_message': 'sent {count, plural, one {a message} other {# messages}}',
  'read_messages': 'read messages {count, plural, one {once} other {# times}}',
  'raft_action':
      'made {count, plural, one {a Raft change} other {# Raft changes}}',
  'version_control': 'used git {count, plural, one {once} other {# times}}',
  'run_checks':
      'ran tests or checks {count, plural, one {once} other {# times}}',
};

/// `Intl.ListFormat` conjunction.
String joinConjunction(List<String> parts, {required bool chinese}) {
  if (parts.length < 2) return parts.join();
  if (chinese) {
    return parts.length == 2
        ? '${parts[0]}和${parts[1]}'
        : '${parts.sublist(0, parts.length - 1).join('、')}和${parts.last}';
  }
  return parts.length == 2
      ? '${parts[0]} and ${parts[1]}'
      : '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
}

/// Web `formatTurnActions`: "ran 3 commands, read a file".
String formatTurnActions(
  BuildContext context,
  List<({String kind, int count})> actions,
) {
  if (actions.isEmpty) return raftText(context, 'No tool calls');
  final chinese = Localizations.localeOf(context).languageCode == 'zh';
  return joinConjunction([
    for (final a in actions)
      icuText(
        context,
        turnActionMessages[a.kind] ?? turnActionMessages['other']!,
        {'count': a.count},
      ),
  ], chinese: chinese);
}
