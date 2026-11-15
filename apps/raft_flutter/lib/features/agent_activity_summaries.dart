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

  /// Web `isRoutineHold`: a send held until newer messages are read is the
  /// normal flow; neither shown nor counted.
  bool get routineHold => reason == 'send_held';

  /// Web `countsAsProblem`: a command that exits non-zero (failing tests
  /// included) is ordinary development; only a tool call that itself failed
  /// counts.
  bool get counts => reason != 'exit_nonzero' && !routineHold;

  /// Web `isListedProblem`: a plain command's non-zero exit tells a reader
  /// nothing; failing tests or checks stay as process information.
  bool get listed =>
      !routineHold && !(reason == 'exit_nonzero' && kind != 'run_checks');
}

/// `trigger.display`: where the waking message was posted and who sent it, as
/// the server resolves it (handles without `@`).
class TurnTriggerDisplay {
  const TurnTriggerDisplay({
    required this.kind,
    this.channelName,
    this.senderName,
    this.peerName,
  });
  final String kind;
  final String? channelName, senderName, peerName;
}

/// One app event delivered in a turn (`ActivityTurnAppEventView`).
class TurnAppEvent {
  const TurnAppEvent({
    required this.id,
    required this.appName,
    required this.summary,
    required this.deliveredAt,
  });
  final String id, appName, summary;
  final num deliveredAt;
}

/// A turn as the server returns it. A trigger the viewer cannot see comes back
/// hidden (`private_channel` / `dm`); the turn still running (`current` on the
/// first page) has no outcome yet ([running]) and its `endedAt` is when the
/// server read it.
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
    this.lastText,
    this.hiddenTrigger,
    this.triggerTarget,
    this.triggerSender,
    this.triggerChannelId,
    this.triggerMessageId,
    this.triggerUnresolved = false,
    this.triggerDisplay,
    this.triggerAppEvent,
    this.usageLimit = false,
    this.usageResetsAt,
    this.sentMessageIds = const [],
    this.sentMessageCount,
    this.hiddenSentCount = 0,
    this.appEvents = const [],
    this.appEventCount,
    this.running = false,
  });

  static TurnSummary? tryParse(Object? json, {bool running = false}) {
    if (json is! Map ||
        json['startedAt'] is! num ||
        json['endedAt'] is! num ||
        (!running && json['outcome'] is! String)) {
      return null;
    }
    final trigger = json['trigger'];
    String? triggerString(String key) =>
        trigger is Map && trigger[key] is String
        ? trigger[key] as String
        : null;
    final display = trigger is Map && trigger['display'] is Map
        ? trigger['display'] as Map
        : null;
    final appEvent = trigger is Map && trigger['appEvent'] is Map
        ? trigger['appEvent'] as Map
        : null;
    final limit = json['usageLimit'];
    return TurnSummary(
      id: json['id'] is String ? json['id'] as String : null,
      startedAt: json['startedAt'] as num,
      endedAt: json['endedAt'] as num,
      outcome: running ? 'running' : json['outcome'] as String,
      running: running,
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
      lastText: json['lastText'] is String && '${json['lastText']}'.isNotEmpty
          ? json['lastText'] as String
          : null,
      hiddenTrigger: triggerString('hidden'),
      triggerTarget: triggerString('target'),
      triggerSender: triggerString('sender'),
      triggerChannelId: triggerString('channelId'),
      triggerMessageId: triggerString('messageId'),
      triggerUnresolved: trigger is Map && trigger['unresolved'] == true,
      triggerDisplay: display == null || display['kind'] is! String
          ? null
          : TurnTriggerDisplay(
              kind: display['kind'] as String,
              channelName: display['channelName'] as String?,
              senderName: display['senderName'] as String?,
              peerName: display['peerName'] as String?,
            ),
      triggerAppEvent:
          appEvent == null ||
              appEvent['appName'] is! String ||
              appEvent['summary'] is! String
          ? null
          : (
              appName: appEvent['appName'] as String,
              summary: appEvent['summary'] as String,
            ),
      usageLimit: limit is Map,
      usageResetsAt: limit is Map && limit['resetsAt'] is num
          ? limit['resetsAt'] as num
          : null,
      sentMessageIds: [
        for (final id in json['sentMessageIds'] as List? ?? const [])
          if (id is String) id,
      ],
      sentMessageCount: (json['sentMessageCount'] as num?)?.toInt(),
      hiddenSentCount: (json['hiddenSentCount'] as num?)?.toInt() ?? 0,
      appEvents: [
        for (final e in json['appEvents'] as List? ?? const [])
          if (e is Map &&
              e['id'] is String &&
              e['appName'] is String &&
              e['summary'] is String &&
              e['deliveredAt'] is num)
            TurnAppEvent(
              id: e['id'] as String,
              appName: e['appName'] as String,
              summary: e['summary'] as String,
              deliveredAt: e['deliveredAt'] as num,
            ),
      ],
      appEventCount: (json['appEventCount'] as num?)?.toInt(),
    );
  }

  final String? id,
      lastReplyMessageId,
      lastText,
      hiddenTrigger,
      triggerTarget,
      triggerSender,
      triggerChannelId,
      triggerMessageId;
  final bool triggerUnresolved, running;
  final TurnTriggerDisplay? triggerDisplay;
  final ({String appName, String summary})? triggerAppEvent;

  /// `usageLimit` is present: the turn ended on the provider's usage limit;
  /// [usageResetsAt] is when the runtime said it resets (epoch ms).
  final bool usageLimit;
  final num? usageResetsAt;
  final List<String> sentMessageIds;
  final int? sentMessageCount;
  final int hiddenSentCount;
  final List<TurnAppEvent> appEvents;
  final int? appEventCount;
  final num startedAt, endedAt;
  final String outcome;
  final int problemCount, toolCalls, messagesSent;
  final List<TurnProblem> problems;
  final List<({String kind, int count})> actions;

  /// Web `turnKey`.
  String get key => id ?? '$startedAt-$endedAt';

  /// Web `turnProblemCount`: only the listed problems that count; what lies
  /// past the server's cap is of unknown kind and is not counted.
  int get problemsShown => problems.where((p) => p.counts).length;
}

/// A page of `GET /agents/:id/activity-summaries`: newest first; the first page
/// also carries the turn still running (`current`).
class TurnSummaryPage {
  const TurnSummaryPage(this.summaries, this.next, this.current);
  final List<TurnSummary> summaries;
  final String? next;
  final TurnSummary? current;

  static TurnSummaryPage parse(Object? result) {
    final map = result is Map ? result : const {};
    return TurnSummaryPage(
      [
        for (final r in map['summaries'] as List? ?? const [])
          ?TurnSummary.tryParse(r),
      ],
      map['next'] is String ? map['next'] as String : null,
      TurnSummary.tryParse(map['current'], running: true),
    );
  }
}

/// Web `mergeTurnPages`: newest first in the server's page order (ended, then
/// id), each turn once, whichever page it came from.
List<TurnSummary> mergeTurnPages(List<List<TurnSummary>> pages) {
  final byKey = <String, TurnSummary>{};
  for (final page in pages) {
    for (final turn in page) {
      byKey.putIfAbsent(turn.key, () => turn);
    }
  }
  return byKey.values.toList()..sort((a, b) {
    final ended = b.endedAt.compareTo(a.endedAt);
    return ended != 0 ? ended : b.key.compareTo(a.key);
  });
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
  // The server could not match the trigger to its channel and message.
  if (turn.triggerUnresolved) return raftText(context, 'woken by a message');
  final display = turn.triggerDisplay;
  if (display != null) {
    if (display.kind == 'dm') {
      final peer = display.senderName ?? display.peerName;
      return peer == null
          ? raftText(context, 'replying to a direct message')
          : raftFormat(context, 'replying to a direct message from {peer}', {
              'peer': '@$peer',
            });
    }
    final channel = '#${display.channelName}';
    if (display.senderName == null) {
      return raftFormat(context, 'woken by a message in {channel}', {
        'channel': channel,
      });
    }
    return raftFormat(
      context,
      display.kind == 'thread'
          ? 'replying to {sender} in a thread in {channel}'
          : 'replying to {sender} in {channel}',
      {'sender': '@${display.senderName}', 'channel': channel},
    );
  }
  final target = turn.triggerTarget;
  if (target == null) return null;
  if (target.startsWith('agent-event:')) {
    final event = turn.triggerAppEvent;
    if (event == null) return raftText(context, 'handling an app event');
    return raftFormat(
      context,
      'handling a notification from {app}: {summary}',
      {'app': event.appName, 'summary': event.summary},
    );
  }
  // An older server: the producer's own text.
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

/// Web `formatCompactTrigger`: who woke a turn and where, short ("@Remy ·
/// #deploy", "DM from @xxchan"); the overview's sentence when it has no place.
String? formatCompactTrigger(BuildContext context, TurnSummary turn) {
  final hidden = turn.hiddenTrigger;
  if (hidden != null) {
    return raftText(context, hidden == 'dm' ? 'a DM' : 'a private channel');
  }
  if (turn.triggerUnresolved) return raftText(context, 'a message');
  final event = turn.triggerAppEvent;
  if (event != null) return event.appName;
  final display = turn.triggerDisplay;
  if (display?.kind == 'dm' &&
      (display!.senderName != null || display.peerName != null)) {
    return raftFormat(context, 'DM from {sender}', {
      'sender': '@${display.senderName ?? display.peerName}',
    });
  }
  if ((display?.kind == 'channel' || display?.kind == 'thread') &&
      display!.senderName != null) {
    return raftFormat(context, '{sender} · #{channel}', {
      'sender': '@${display.senderName}',
      'channel': display.channelName ?? '',
    });
  }
  return formatTurnTrigger(context, turn);
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
  List<({String kind, int count})> actions, {
  int messagesSent = 0,
}) {
  if (actions.isEmpty) return raftText(context, 'No tool calls');
  final chinese = Localizations.localeOf(context).languageCode == 'zh';
  return joinConjunction([
    for (final a in actions)
      icuText(
        context,
        turnActionMessages[a.kind] ?? turnActionMessages['other']!,
        {
          // One send command can post several messages: count what was sent.
          'count': a.kind == 'send_message' && messagesSent > 0
              ? messagesSent
              : a.count,
        },
      ),
  ], chinese: chinese);
}
