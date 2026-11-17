// What one Activity conversation row says (Web v1.24 `InboxRow.tsx`): the title
// rules (task conversations, retracted and saved-copy rows, Lounge and App-bot
// DMs), the excerpt (sender, delegated sender, retracted line), the marks'
// inputs, the Done button's name and the row's accessible name. Pure over the
// row map and the page's own reads; the widget in `activity_inbox_row.dart`
// only draws it.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_lounge.dart' show loungeTitle;
import 'delegated_message.dart' show readDelegatedBy;
import 'message_task_actions.dart' show TaskV2ConversationsFlag;

/// The server's text for a retracted message, kept for servers that have no
/// `latestRetracted` / `parentRetracted` flag (Web `isRetractedPreview`).
const String serverRetractedContent = 'This message was retracted by its sender.';

/// Web `isRetractedPreviewOf`: the server's flag when it sent one, else the
/// placeholder text decides.
bool isRetractedPreviewOf(Object? flag, Object? text) =>
    flag is bool ? flag : text is String && text.trim() == serverRetractedContent;

String _trim(Object? value) => value is String ? value.trim() : '';
String _stripPrefix(String value) => value.replaceFirst(RegExp(r'^[@#]+'), '');

/// Web `formatDelegatedSender`: "Alice (sent by Friday)".
String formatDelegatedSender(
  BuildContext context,
  String sender,
  Object? delegatedBy,
) {
  final by = readDelegatedBy(delegatedBy);
  if (by == null) return sender;
  return by.deleted
      ? raftFormat(context, '{sender} (sent by a deleted assistant)', {
          'sender': sender,
        })
      : raftFormat(context, '{sender} (sent by {name})', {
          'sender': sender,
          'name': by.name,
        });
}

/// Web `formatTaskConversationRef`: `#channel:#7`, `dm:@peer:#7`, or the bare
/// `#7` before the channel is known.
String formatTaskConversationRef({
  required int taskNumber,
  String? channelName,
  String? channelType,
  String? dmPeerName,
}) {
  if (channelType == 'dm') {
    return dmPeerName != null && dmPeerName.isNotEmpty
        ? 'dm:@$dmPeerName:#$taskNumber'
        : '#$taskNumber';
  }
  final name = channelName?.replaceFirst(RegExp(r'^#'), '');
  return name == null || name.isEmpty ? '#$taskNumber' : '#$name:#$taskNumber';
}

/// What the page lends a row to resolve names with.
class ActivityRowLookups {
  const ActivityRowLookups({
    required this.controller,
    required this.agents,
    required this.people,
    required this.directorySenderLabel,
    required this.stableSender,
    this.taskV2,
  });
  final WorkspaceController controller;
  final List<Map<String, dynamic>> agents, people;
  final String Function(dynamic id, dynamic type) directorySenderLabel;
  final String Function(String key, String Function() build) stableSender;

  /// Task v2 is on for this server; null reads the server's flag.
  final bool? taskV2;

  Map<String, dynamic>? agent(Object? id) =>
      agents.where((a) => a['id'] == id).firstOrNull;
}

/// One conversation row's words and flags.
class ActivityRowFacts {
  ActivityRowFacts._({
    required this.title,
    required this.titleMuted,
    required this.channelLabel,
    required this.appBadge,
    required this.legacyTaskNumber,
    required this.taskStatus,
    required this.statusInMarks,
    required this.threadPrefix,
    required this.threadPrefixHidden,
    required this.taskRef,
    required this.senderLabel,
    required this.senderAgentId,
    required this.senderType,
    required this.senderId,
    required this.isSystemSender,
    required this.preview,
    required this.previewRetracted,
    required this.hasPreview,
    required this.retractedLine,
    required this.doneLabel,
    required this.peerSpoke,
    required this.unreadCount,
    required this.marked,
    required this.muted,
    required this.mentionBadge,
    required this.draft,
    required this.dmChannel,
    required this.threadDmChannel,
    required this.loungeAgentId,
    required this.rowChannel,
    required this.titleKind,
    required this.hasDelegate,
  });

  /// The title text: a thread's parent message, a task's title, a channel's
  /// name, a DM's peer, "{Name}'s Lounge".
  final String title;

  /// The title is the muted "This message was retracted." line.
  final bool titleMuted;

  /// `#channel`, `@peer` or "{Name}'s Lounge": where the row lives.
  final String channelLabel;

  /// A DM whose peer is an App bot: the App badge's owner name ('' unknown).
  final String? appBadge;

  /// A legacy task thread's `#7`, beside the title, with task v2 off.
  final String? legacyTaskNumber;

  /// The task's status, when the row shows one (`taskStatus` row field).
  final String? taskStatus;

  /// The status is a mark (a task conversation, or a legacy task with v2 on).
  final bool statusInMarks;

  /// "{channel} ·" or the task ref over a thread's excerpt; hidden (screen
  /// readers only) over a DM thread's face.
  final String? threadPrefix;
  final bool threadPrefixHidden;
  final String? taskRef;

  final String? senderLabel, senderAgentId;
  final String senderType, senderId;
  final bool isSystemSender, hasDelegate;
  final String preview, retractedLine;
  final bool previewRetracted, hasPreview;
  final String doneLabel;

  /// The DM peer spoke without a delegate: the excerpt is only their words.
  final bool peerSpoke;
  final int unreadCount;
  final bool marked, muted, mentionBadge, draft;
  final RaftChannel? dmChannel, threadDmChannel, rowChannel;
  final String? loungeAgentId;

  /// `thread`, `task`, `dm` or `channel`: the leading tile's kind.
  final String titleKind;

  bool get strong => (unreadCount > 0 || marked) && !muted;

  /// Web `InboxRow`'s facts for [row].
  factory ActivityRowFacts.of(
    BuildContext context,
    Map<String, dynamic> row, {
    required ActivityRowLookups lookups,
    required String filter,
    required bool marked,
  }) {
    final w = lookups.controller;
    final kind = '${row['kind']}';
    final thread = kind == 'thread', mention = kind == 'mention_action';
    final dmRow = kind == 'dm' || (mention && row['channelType'] == 'dm');
    final channels = [...w.channels, ...w.dms];
    RaftChannel? find(Object? id) =>
        id == null ? null : channels.where((c) => c.id == id).firstOrNull;

    final taskConversation = thread && row['conversationKind'] == 'task';
    final taskV2 = lookups.taskV2 ?? TaskV2ConversationsFlag.of(w).enabled;
    final unread = (row['unreadCount'] as num? ?? 0).toInt();

    final conversationId = thread ? row['parentChannelId'] : row['channelId'];
    final rowChannel = find(conversationId);
    final loungeAgentId = dmRow || kind == 'dm'
        ? null
        : rowChannel?.loungeAgentId ??
              (row['loungeAgentId'] is String &&
                      (row['loungeAgentId'] as String).isNotEmpty
                  ? row['loungeAgentId'] as String
                  : null);
    final loungeName = loungeAgentId != null && rowChannel != null
        ? loungeTitle(context, w, rowChannel)
        : null;

    String peerLabel(RaftChannel? c, Object? fallback) {
      final label = c?.firstNonEmpty(const ['peerDisplayName', 'peerName']);
      return label != null && label.isNotEmpty ? label : '$fallback';
    }

    // itemFilterChannelLabel
    final channelLabel =
        loungeName ??
        (thread
            ? (row['parentChannelType'] == 'dm'
                  ? '@${peerLabel(find(row['parentChannelId']), row['parentChannelName'])}'
                  : '#${row['parentChannelName'] ?? ''}')
            : mention
            ? (row['channelType'] == 'dm'
                  ? '@${row['channelName'] ?? ''}'
                  : '#${row['channelName'] ?? ''}')
            : kind == 'dm'
            ? '@${peerLabel(w.dms.where((c) => c.id == row['channelId']).firstOrNull, row['channelName'])}'
            : '#${row['channelName'] ?? ''}');

    final dmChannel = dmRow
        ? w.dms.where((c) => c.id == row['channelId']).firstOrNull
        : null;
    final threadDmChannel = thread && row['parentChannelType'] == 'dm'
        ? w.dms.where((c) => c.id == row['parentChannelId']).firstOrNull
        : null;

    final String? titleLabel = thread
        ? null
        : loungeName ??
              (mention
                  ? _stripPrefix('${row['channelName'] ?? ''}')
                  : kind == 'dm'
                  ? _stripPrefix(peerLabel(dmChannel, row['channelName']))
                  : _stripPrefix('${row['channelName'] ?? ''}'));

    // The sender.
    final senderType = mention
        ? 'system'
        : '${row[thread ? 'latestActivitySenderType' : 'lastMessageSenderType'] ?? ''}';
    final senderId = mention
        ? ''
        : '${row[thread ? 'latestActivitySenderId' : 'lastMessageSenderId'] ?? ''}';
    final system = senderType == 'system' || senderId == 'system';
    String? senderName;
    if (senderType == 'agent') {
      final agent = lookups.agent(senderId);
      final name = agent == null
          ? null
          : '${agent['displayName'] ?? ''}'.trim().isNotEmpty
          ? '${agent['displayName']}'
          : '${agent['name'] ?? ''}';
      senderName = name != null && name.isNotEmpty ? name : null;
    } else if (senderType == 'user') {
      final member = lookups.people
          .where((p) => p['userId'] == senderId || p['id'] == senderId)
          .firstOrNull;
      final name = member == null
          ? null
          : '${member['displayName'] ?? ''}'.trim().isNotEmpty
          ? '${member['displayName']}'
          : '${member['name'] ?? ''}';
      senderName = name != null && name.isNotEmpty ? name : null;
    }
    final carried =
        row[thread ? 'latestActivitySenderName' : 'lastMessageSenderName'];
    senderName ??= carried is String && carried.isNotEmpty ? carried : null;
    senderName ??= system
        ? null
        : () {
            final label = lookups.stableSender(
              'activity:$senderType:$senderId',
              () => lookups.directorySenderLabel(senderId, senderType),
            );
            return label.isEmpty ? null : label;
          }();
    final delegatedBy = system || mention ? null : row['latestDelegatedBy'];
    final delegate = readDelegatedBy(delegatedBy);
    final senderLabel = system
        ? raftText(context, 'System')
        : senderName == null
        ? null
        : formatDelegatedSender(context, senderName, delegatedBy);

    // Retracted and saved-copy rows.
    final retractedLine = raftText(context, 'This message was retracted.');
    final activityPreview = thread
        ? row['latestActivityPreview']
        : mention
        ? row['messagePreview']
        : row['lastMessagePreview'];
    final previewRetracted =
        !mention && isRetractedPreviewOf(row['latestRetracted'], activityPreview);
    final hasPreview = previewRetracted || _trim(activityPreview).isNotEmpty;
    final parentRetracted =
        thread &&
        isRetractedPreviewOf(row['parentRetracted'], row['parentMessagePreview']);

    // Tasks.
    final parentPreview = _trim(row['parentMessagePreview']);
    final taskNumber = (row['taskNumber'] as num?)?.toInt();
    final taskStatus = row['taskStatus'] is String
        ? row['taskStatus'] as String
        : null;
    String? taskRef, taskTitle, taskNoTitle;
    if (taskConversation) {
      taskRef = taskNumber == null
          ? null
          : formatTaskConversationRef(
              taskNumber: taskNumber,
              channelName: '${row['parentChannelName'] ?? ''}',
              channelType: '${row['parentChannelType'] ?? ''}',
              dmPeerName: threadDmChannel?.firstNonEmpty(const ['peerName']),
            );
      final title = _trim(row['taskTitle']);
      taskTitle = title.isNotEmpty
          ? title
          : parentPreview.isNotEmpty
          ? parentPreview
          : null;
      taskNoTitle = taskTitle == null && taskV2
          ? raftFormat(context, '{channel} task', {'channel': channelLabel})
          : null;
    }
    final legacyTaskRow = !taskConversation && taskNumber != null && taskStatus != null;
    final legacyBadge = legacyTaskRow && !taskV2;
    final statusInMarks =
        taskStatus != null && (taskConversation || (legacyTaskRow && taskV2));

    var titleMuted = false;
    String title;
    if (taskConversation) {
      title = taskTitle ?? taskNoTitle ?? taskRef ?? '';
    } else if (thread) {
      if (parentRetracted) {
        title = retractedLine;
        titleMuted = true;
      } else if (parentPreview.isEmpty) {
        title = raftFormat(context, 'Thread in {conversation}', {
          'conversation': channelLabel,
        });
      } else {
        title = '${row['parentMessagePreview']}';
      }
    } else {
      title = titleLabel ?? '';
    }

    // The App badge: a DM whose peer is an App bot.
    String? appBadge;
    if (titleLabel != null && dmChannel?.json['peerType'] == 'agent') {
      final peer = lookups.agent('${dmChannel!.json['peerId']}');
      if (peer != null && peer['managedByAppInstallId'] != null) {
        final app = peer['managedByApp'];
        appBadge = app is Map && app['name'] is String ? app['name'] as String : '';
      }
    }

    final titleKind = taskConversation
        ? 'task'
        : thread
        ? 'thread'
        : dmRow
        ? 'dm'
        : 'channel';
    final taskRefInBody = !taskV2 && taskConversation && taskTitle != null
        ? taskRef
        : null;
    final channelInBody =
        thread && (!taskConversation || (taskV2 && taskNoTitle == null));
    final threadPrefix = taskRefInBody != null
        ? raftFormat(context, '{channel} ·', {'channel': taskRefInBody})
        : channelInBody
        ? raftFormat(context, '{channel} ·', {'channel': channelLabel})
        : null;

    final doneName = taskV2
        ? (taskConversation ? (taskTitle ?? taskNoTitle ?? taskRef) : null)
        : (taskConversation ? taskRef : null);
    final doneLabel = doneName != null
        ? raftFormat(context, 'Mark {conversation} as Done', {
            'conversation': doneName,
          })
        : thread
        ? raftFormat(context, 'Mark the thread in {conversation} as Done', {
            'conversation': channelLabel,
          })
        : raftFormat(context, 'Mark {conversation} as Done', {
            'conversation': channelLabel,
          });

    final mutedId = thread ? row['parentChannelId'] : row['channelId'];
    final muted = (find(mutedId) ?? dmChannel ?? threadDmChannel)?.flag(
          'activityMuted',
        ) ==
        true;

    final peerSpoke =
        dmChannel != null &&
        senderId == '${dmChannel.json['peerId']}' &&
        delegate == null &&
        hasPreview;

    return ActivityRowFacts._(
      title: title,
      titleMuted: titleMuted,
      channelLabel: channelLabel,
      appBadge: appBadge,
      legacyTaskNumber: legacyBadge
          ? raftFormat(context, '#{number}', {'number': taskNumber})
          : null,
      taskStatus: taskStatus,
      statusInMarks: statusInMarks,
      threadPrefix: threadPrefix,
      threadPrefixHidden: threadDmChannel != null,
      taskRef: taskRefInBody,
      senderLabel: senderLabel,
      senderAgentId: senderType == 'agent' ? senderId : null,
      senderType: senderType,
      senderId: senderId,
      isSystemSender: system,
      preview: previewRetracted ? retractedLine : _trim(activityPreview) == '' ? '' : '$activityPreview',
      previewRetracted: previewRetracted,
      hasPreview: hasPreview,
      retractedLine: retractedLine,
      doneLabel: doneLabel,
      peerSpoke: peerSpoke,
      unreadCount: unread,
      marked: marked && unread == 0,
      muted: muted,
      mentionBadge:
          filter != 'mentions' && row['hasMention'] == true && unread > 0,
      draft: thread && (w.drafts['${row['threadChannelId']}'] ?? '').trim().isNotEmpty,
      dmChannel: dmChannel,
      threadDmChannel: threadDmChannel,
      loungeAgentId: loungeAgentId,
      rowChannel: rowChannel,
      titleKind: titleKind,
      hasDelegate: delegate != null,
    );
  }

  /// The row's accessible name, as Web's `aria-labelledby` reads it: title,
  /// the App badge, the excerpt (with its channel prefix), the task status and
  /// the time in words. The count, @, draft, bell and dot are not in it.
  String semanticLabel(
    BuildContext context, {
    required String? timeWords,
    String? statusWord,
  }) {
    final body = [
      ?threadPrefix,
      if (!peerSpoke && senderLabel != null)
        hasPreview ? '$senderLabel:' : senderLabel!,
      if (hasPreview) preview,
    ].join(' ');
    return [
      title,
      if (appBadge != null) raftText(context, 'App'),
      if (body.isNotEmpty) body,
      if (statusInMarks && statusWord != null) statusWord,
      ?timeWords,
    ].where((part) => part.isNotEmpty).join(' ');
  }
}
