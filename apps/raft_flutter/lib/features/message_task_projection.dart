import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

/// Accepted channel task references for one mounted chat authority. This is
/// presentation data, never an authorization or a persistent task cache.
class MessageTaskProjection extends ChangeNotifier {
  MessageTaskProjection(this.w) {
    w.addListener(changed);
    events = w.client.events.listen((event) {
      if (event.name == 'connected' ||
          const [
            'task:created',
            'task:updated',
            'task:deleted',
          ].contains(event.name)) {
        refresh();
      }
    });
    changed();
  }
  final WorkspaceController w;
  StreamSubscription<RaftEvent>? events;
  String? scope;
  int revision = 0;
  bool ended = false;
  final Map<String, Map<String, dynamic>> byMessage = {};
  bool get permitted =>
      !ended &&
      w.client.user != null &&
      w.channel != null &&
      w.channel!.type != 'thread' &&
      w.channel!.json['readOnlyReason'] == null &&
      w.can('viewChannel', resource: w.channel);

  void changed() {
    final next = '${workspaceAuthority(w)}:$permitted';
    if (scope == next) return;
    scope = next;
    final ticket = ++revision;
    byMessage.clear();
    notifyListeners();
    if (permitted) unawaited(load(next, ticket, w.channel!.id));
  }

  void refresh() {
    scope = null;
    changed();
  }

  Future<void> load(String authority, int ticket, String channelId) async {
    try {
      final result = await w.query(
        '/tasks/channel/${Uri.encodeComponent(channelId)}',
      );
      if (ended || !permitted || scope != authority || revision != ticket) {
        return;
      }
      if (result is! Map || result['tasks'] is! List) return;
      final accepted = <String, Map<String, dynamic>>{};
      for (final raw in result['tasks'] as List) {
        if (raw is! Map ||
            raw['channelId'] != channelId ||
            raw['messageId'] is! String ||
            raw['id'] is! String ||
            raw['taskNumber'] is! int ||
            raw['title'] is! String ||
            !const [
              'todo',
              'in_progress',
              'in_review',
              'done',
              'closed',
            ].contains(raw['status'])) {
          continue;
        }
        accepted[raw['messageId']] = Map.unmodifiable(
          Map<String, dynamic>.from(raw),
        );
      }
      byMessage.addAll(accepted);
      notifyListeners();
    } catch (_) {
      // An unavailable directory supplies no task reference, never a fake badge.
    }
  }

  Map<String, dynamic>? taskFor(RaftMessage message) =>
      permitted &&
          (message.channelId == w.channel!.id ||
              message.id == w.threadParent?.id)
      ? byMessage[message.id]
      : null;

  @override
  void dispose() {
    ended = true;
    ++revision;
    byMessage.clear();
    w.removeListener(changed);
    unawaited(events?.cancel());
    super.dispose();
  }
}
