// Generated from Web v1.24 en.ts `upgradeDialog.history.hint*` (historyLimitHint in
// components/billing/upgradeGateCopy.ts): the ICU plurals split per form, so each
// English sentence is a literal catalog key (count one/other x agentTries 0/one/other).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

/// Which conversation the history window hid messages in (Web `HistoryLimitContext`).
enum HistoryLimitScope { channel, thread, conversation }

/// The line under the title of the history notice. [count] is already formatted
/// for the locale; [one] is `count == 1`; [capped] reads "over {count}"; [agentTries]
/// is how often the server's agents reached behind the window in the past 7 days.
String historyLimitCountedHint(
  BuildContext context, {
  required HistoryLimitScope scope,
  required bool capped,
  required bool one,
  required String count,
  required int days,
  String channel = '',
  int agentTries = 0,
}) {
  final values = <String, Object?>{
    'channel': channel,
    'count': count,
    'days': days,
    'agentTries': agentTries,
  };
  final tries = agentTries <= 0 ? 0 : (agentTries == 1 ? 1 : 2);
  final one_ = capped ? false : one;
  return switch ((scope, capped, one_, tries)) {
    (HistoryLimitScope.channel, false, true, 0) => raftFormat(
      context,
      "{channel} has {count} message older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.channel, false, true, 1) => raftFormat(
      context,
      "{channel} has {count} message older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.channel, false, true, 2) => raftFormat(
      context,
      "{channel} has {count} message older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.channel, false, false, 0) => raftFormat(
      context,
      "{channel} has {count} messages older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.channel, false, false, 1) => raftFormat(
      context,
      "{channel} has {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.channel, false, false, 2) => raftFormat(
      context,
      "{channel} has {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.channel, true, false, 0) => raftFormat(
      context,
      "{channel} has over {count} messages older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.channel, true, false, 1) => raftFormat(
      context,
      "{channel} has over {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.channel, true, false, 2) => raftFormat(
      context,
      "{channel} has over {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.thread, false, true, 0) => raftFormat(
      context,
      "This thread has {count} reply older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.thread, false, true, 1) => raftFormat(
      context,
      "This thread has {count} reply older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.thread, false, true, 2) => raftFormat(
      context,
      "This thread has {count} reply older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.thread, false, false, 0) => raftFormat(
      context,
      "This thread has {count} replies older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.thread, false, false, 1) => raftFormat(
      context,
      "This thread has {count} replies older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.thread, false, false, 2) => raftFormat(
      context,
      "This thread has {count} replies older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.thread, true, false, 0) => raftFormat(
      context,
      "This thread has over {count} replies older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.thread, true, false, 1) => raftFormat(
      context,
      "This thread has over {count} replies older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.thread, true, false, 2) => raftFormat(
      context,
      "This thread has over {count} replies older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.conversation, false, true, 0) => raftFormat(
      context,
      "This conversation has {count} message older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.conversation, false, true, 1) => raftFormat(
      context,
      "This conversation has {count} message older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.conversation, false, true, 2) => raftFormat(
      context,
      "This conversation has {count} message older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.conversation, false, false, 0) => raftFormat(
      context,
      "This conversation has {count} messages older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.conversation, false, false, 1) => raftFormat(
      context,
      "This conversation has {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.conversation, false, false, 2) => raftFormat(
      context,
      "This conversation has {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.conversation, true, false, 0) => raftFormat(
      context,
      "This conversation has over {count} messages older than {days} days that you and your agents can't read on Free.",
      values,
    ),
    (HistoryLimitScope.conversation, true, false, 1) => raftFormat(
      context,
      "This conversation has over {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    (HistoryLimitScope.conversation, true, false, 2) => raftFormat(
      context,
      "This conversation has over {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    _ => '',
  };
}

/// "The message you opened was sent on {date}": [date] is formatted by the caller.
String historyLimitTargetHint(
  BuildContext context, {
  required String date,
  required int days,
  int agentTries = 0,
}) {
  final values = <String, Object?>{
    'date': date,
    'days': days,
    'agentTries': agentTries,
  };
  return switch (agentTries <= 0 ? 0 : (agentTries == 1 ? 1 : 2)) {
    0 => raftFormat(
      context,
      "The message you opened was sent on {date}, more than {days} days ago, so you and your agents can't read it on Free.",
      values,
    ),
    1 => raftFormat(
      context,
      "The message you opened was sent on {date}, more than {days} days ago, so you and your agents can't read it on Free, and your agents ran into this once in the past 7 days.",
      values,
    ),
    2 => raftFormat(
      context,
      "The message you opened was sent on {date}, more than {days} days ago, so you and your agents can't read it on Free, and your agents ran into this {agentTries} times in the past 7 days.",
      values,
    ),
    _ => '',
  };
}
