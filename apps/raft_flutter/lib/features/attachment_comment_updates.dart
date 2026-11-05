import 'dart:async';

import 'package:raft_client/raft_client.dart';

/// Invalidations for one authorized attachment panel, never comment data.
///
/// A parent's thread hint can precede the server's attachment-ref insert. Keep
/// a later delivered event while any GET is pending, but do not poll or invent
/// a commit signal when the server sends none to this receiver.
class AttachmentCommentUpdates {
  AttachmentCommentUpdates({
    required Stream<RaftEvent> events,
    required this.hostMessageId,
    required this.serverId,
    required this.current,
    required this.reload,
  }) {
    subscription = events.listen(receive);
  }

  final String? hostMessageId, serverId;
  final bool Function() current;
  final Future<void> Function() reload;
  late final StreamSubscription<RaftEvent> subscription;
  String? thread, parentThreadHint;
  Set<String> loadedIds = {};
  int reads = 0;
  bool pending = false, draining = false, closed = false;

  void snapshot(String? threadId, Iterable<Map<String, dynamic>> comments) {
    thread = threadId;
    loadedIds = {
      for (final row in comments)
        if (row['id'] is String) row['id'],
    };
    if (threadId != null) parentThreadHint = null;
  }

  void beginRead() => ++reads;

  void endRead() {
    --reads;
    drain();
  }

  void receive(RaftEvent event) {
    if (closed || !current() || event.payload is! Map) return;
    final payload = event.payload as Map;
    if (payload['serverId'] != null && payload['serverId'] != serverId) return;
    final channel = payload['channelId'];
    final knownThread =
        channel is String && (channel == thread || channel == parentThreadHint);
    if (event.name == 'thread:updated') {
      final hint = payload['threadChannelId'];
      if (hostMessageId == null ||
          payload['parentMessageId'] != hostMessageId ||
          hint is! String ||
          hint.isEmpty) {
        return;
      }
      // Routing only: permission and attachment scope still come from GET.
      parentThreadHint = hint;
    } else if (event.name == 'message:new') {
      if (!knownThread) return;
    } else if (event.name == 'message:updated') {
      if (!knownThread && !loadedIds.contains(payload['id'])) return;
    } else {
      return;
    }
    pending = true;
    drain();
  }

  void drain() {
    if (closed || !current() || reads > 0 || draining || !pending) return;
    draining = true;
    unawaited(() async {
      try {
        while (!closed && current() && reads == 0 && pending) {
          pending = false;
          await reload();
        }
      } finally {
        draining = false;
      }
    }());
  }

  void dispose() {
    if (closed) return;
    closed = true;
    pending = false;
    unawaited(subscription.cancel());
  }
}
