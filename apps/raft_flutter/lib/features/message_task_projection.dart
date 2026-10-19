import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/message_task_cache.dart';
import '../data/workspace_controller.dart';
import 'private_route_guard.dart' show channelAuthorityReduced;

/// How a message's footer task chip is presented.
enum MessageTaskPresence {
  /// The accepted channel task row.
  accepted,

  /// Built from the message's own task fields until the channel's task rows
  /// are known; the chip is in place from the first frame.
  provisional,

  /// The message says it is a task but its details are not known yet; the
  /// chip's space is reserved so the row never grows later.
  reserved,
}

/// A task row built from the message's own live task projection
/// (messageTaskProjection.ts): `taskNumber`, `taskStatus`, `taskAssigneeName`
/// (the assignee handle) and `taskCurrentProjection.title`. The message wire
/// has no task id, title or claimant-name key besides these.
Map<String, dynamic>? provisionalMessageTask(RaftMessage message) {
  final json = message.json;
  final number = json['taskNumber'], status = json['taskStatus'];
  if (number is! int || !messageTaskStatuses.contains(status)) return null;
  final claimant = json['taskAssigneeName'];
  final projection = json['taskCurrentProjection'];
  final title = projection is Map ? projection['title'] : null;
  return {
    'id': message.id,
    'messageId': message.id,
    'channelId': json['channelId'],
    'taskNumber': number,
    'title': title is String ? title : message.content,
    'status': status,
    if (claimant is String) 'claimedByName': claimant,
  };
}

/// Channel task references for one mounted chat. Reads the client-level
/// [MessageTaskCache], so a revisited channel or an opened thread shows its
/// chips on the first frame; a stale channel is revalidated in the
/// background. This is presentation data, never an authorization.
class MessageTaskProjection extends ChangeNotifier {
  MessageTaskProjection(this.w) : cache = MessageTaskCache.of(w.client) {
    w.addListener(changed);
    cache.addListener(cacheChanged);
    changed();
  }
  final WorkspaceController w;
  final MessageTaskCache cache;
  String? scope;
  RaftChannel? channelRecord;
  bool ended = false;
  bool get permitted =>
      !ended &&
      w.client.user != null &&
      w.channel != null &&
      w.channel!.type != 'thread' &&
      w.channel!.json['readOnlyReason'] == null &&
      w.can('viewChannel', resource: w.channel);

  /// The accepted tasks of the current channel by message id (empty when
  /// not permitted or not yet loaded).
  Map<String, Map<String, dynamic>> get byMessage =>
      permitted ? cache.tasks(w, w.channel!.id) ?? const {} : const {};

  /// Whether the current channel's task rows have been accepted.
  bool get loaded => permitted && cache.tasks(w, w.channel!.id) != null;

  void changed() {
    if (ended) return;
    final channel = w.channel;
    final authority = channel == null
        ? null
        : messageTaskChannelAuthority(w, channel.id);
    final next = jsonEncode([
      messageTaskIdentity(w),
      channel?.id,
      authority,
      permitted,
    ]);
    if (scope == next) return;
    final prior = channelRecord;
    scope = next;
    channelRecord = channel;
    final sameChannel = prior != null && prior.id == channel?.id;
    if (channel != null &&
        channel.type != 'thread' &&
        (!permitted ||
            sameChannel && channelAuthorityReduced(prior.json, channel.json))) {
      // Reduced authority drops the channel's facts, not just the view.
      cache.evict(channel.id);
    } else if (permitted &&
        sameChannel &&
        jsonEncode(prior.json) != jsonEncode(channel!.json)) {
      // Same channel, other authority: keep what is shown, revalidate.
      cache.markStale(channel.id);
    }
    revalidateIfStale();
    notifyListeners();
  }

  void cacheChanged() {
    if (ended) return;
    // A reconnect or an unrecognised task event marks buckets stale.
    revalidateIfStale();
    notifyListeners();
  }

  void revalidateIfStale() {
    if (!permitted) return;
    final id = w.channel!.id;
    if (cache.needsRevalidation(w, id)) unawaited(cache.revalidate(w, id));
  }

  /// Background revalidation (e.g. after the task surface closes). What is
  /// shown stays until the response is accepted.
  void refresh() {
    if (!permitted) return;
    unawaited(cache.revalidate(w, w.channel!.id));
  }

  /// Web MessageItem `taskByNumber` over the loaded channel tasks.
  Map<String, dynamic>? taskByNumber(int number) {
    for (final task in byMessage.values) {
      if (task['taskNumber'] == number) return task;
    }
    return null;
  }

  bool owns(RaftMessage message) =>
      permitted &&
      (message.channelId == w.channel!.id ||
          message.id == w.messageDomain.state.threadParent?.id);

  Map<String, dynamic>? taskFor(RaftMessage message) =>
      owns(message) ? byMessage[message.id] : null;

  /// The footer chip to present for [message], from the first frame: the
  /// accepted task, else (until the channel's rows are accepted) one built
  /// from the message's own task fields, else reserved space when the
  /// message is known to be a task.
  ({MessageTaskPresence presence, Map<String, dynamic>? task})? presentFor(
    RaftMessage message,
  ) {
    if (!owns(message)) return null;
    // [owns] implies [permitted]: one cache read answers byMessage and loaded.
    final channelId = w.channel!.id;
    final tasks = cache.tasks(w, channelId);
    final loaded = tasks != null;
    final accepted = tasks?[message.id];
    if (accepted != null) {
      return (presence: MessageTaskPresence.accepted, task: accepted);
    }
    if (loaded && !cache.needsRevalidation(w, channelId)) return null;
    final json = message.json;
    final number = json['taskNumber'], status = json['taskStatus'];
    final provisional = provisionalMessageTask(message);
    if (provisional != null) {
      return (presence: MessageTaskPresence.provisional, task: provisional);
    }
    if (!loaded &&
        ((number is int && number > 0) ||
            messageTaskStatuses.contains(status))) {
      return (
        presence: MessageTaskPresence.reserved,
        task: number is int ? {'taskNumber': number} : null,
      );
    }
    return null;
  }

  @override
  void dispose() {
    ended = true;
    w.removeListener(changed);
    cache.removeListener(cacheChanged);
    super.dispose();
  }
}
