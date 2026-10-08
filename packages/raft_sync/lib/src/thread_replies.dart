/// Mounted 26f77ef threadRepliesSyncDomain.ts and threadRepliesReadModel.ts.
/// The latest-three reply window is sparse. Canonical epoch changes require an
/// authorized HTTP snapshot; legacy summaries keep their compatibility path.
library;

import 'dart:convert';

import 'core.dart';
import 'read_state.dart';

const inlineReplyCap = 3;
const threadRepliesProducer = 'message-service.thread-replies-window.v1';
const threadRepliesDomain = 'threadReplies';

int? _safe(dynamic value) =>
    value is int && value >= 0 && value <= maxSafeInteger ? value : null;
Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// Contains only the source's public preview projection, never transport keys.
Map<String, dynamic>? projectThreadReply(
  dynamic value, {
  bool snapshot = false,
}) {
  final m = _map(value);
  if (m == null || m['id'] is! String || _safe(m['seq']) == null) return null;
  final sender = m['senderType'];
  return {
    'messageId': m['id'],
    'seq': m['seq'],
    'preview': m['content'] is String ? m['content'] : '',
    'senderId': m['senderId'] is String ? m['senderId'] : '',
    'senderType':
        const {
          'user',
          'agent',
          'system',
          'external_projection',
        }.contains(sender)
        ? sender
        : 'user',
    'senderName': m['senderName'] is String ? m['senderName'] : '',
    'senderDisplayName': m['senderDisplayName'] is String
        ? m['senderDisplayName']
        : (m['senderName'] is String ? m['senderName'] : ''),
    'senderAvatarUrl': !snapshot && m['senderAvatarUrl'] is String
        ? m['senderAvatarUrl']
        : null,
    'createdAt': m['createdAt'] is String ? m['createdAt'] : '',
  };
}

Map<String, dynamic>? _preview(dynamic value) {
  final m = _map(value);
  if (m == null || m['messageId'] is! String || _safe(m['seq']) == null) {
    return null;
  }
  return Map<String, dynamic>.unmodifiable(m);
}

class ThreadRepliesScope {
  ThreadRepliesScope({
    required Iterable<Map<String, dynamic>> replies,
    required this.replyCount,
    required this.snapshotSeq,
    this.historyLimited = false,
    this.epoch,
  }) : replies = List<Map<String, dynamic>>.unmodifiable(
         replies.map(Map<String, dynamic>.unmodifiable),
       );
  final List<Map<String, dynamic>> replies;
  final int replyCount, snapshotSeq;
  final bool historyLimited;
  final String? epoch;

  static ThreadRepliesScope empty() =>
      ThreadRepliesScope(replies: [], replyCount: 0, snapshotSeq: 0);

  static ThreadRepliesScope snapshot(
    Iterable<Map<String, dynamic>> replies,
    int count, {
    required String? epoch,
    bool historyLimited = false,
  }) {
    final ordered = replies.toList()
      ..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
    final visible = ordered.where((r) => r['senderType'] != 'system').toList();
    return ThreadRepliesScope(
      replies: visible.skip(
        visible.length > inlineReplyCap ? visible.length - inlineReplyCap : 0,
      ),
      replyCount: count,
      snapshotSeq: ordered.isEmpty ? 0 : ordered.last['seq'] as int,
      historyLimited: historyLimited,
      epoch: epoch,
    );
  }

  ThreadRepliesScope apply(Map<String, dynamic> reply, int count) {
    if ((reply['seq'] as int) <= snapshotSeq) return this;
    final nextCount = count > replyCount ? count : replyCount;
    if (reply['senderType'] == 'system') {
      return nextCount == replyCount
          ? this
          : ThreadRepliesScope(
              replies: replies,
              replyCount: nextCount,
              snapshotSeq: snapshotSeq,
              historyLimited: historyLimited,
              epoch: epoch,
            );
    }
    final ordered = [
      ...replies.where((r) => r['messageId'] != reply['messageId']),
      reply,
    ]..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
    final window = ordered
        .skip(
          ordered.length > inlineReplyCap ? ordered.length - inlineReplyCap : 0,
        )
        .toList();
    if (window.length == replies.length &&
        nextCount == replyCount &&
        List.generate(
          window.length,
          (i) => window[i]['messageId'] == replies[i]['messageId'],
        ).every((v) => v)) {
      return this;
    }
    return ThreadRepliesScope(
      replies: window,
      replyCount: nextCount,
      snapshotSeq: snapshotSeq,
      historyLimited: historyLimited,
      epoch: epoch,
    );
  }
}

class ThreadRebaselineRequest {
  const ThreadRebaselineRequest({
    required this.scopeId,
    required this.generation,
    required this.parentMessageId,
    required this.parentChannelId,
    required this.threadChannelId,
    required this.epoch,
  });
  final String scopeId, parentMessageId, parentChannelId, threadChannelId;
  final int generation;
  final String? epoch;
}

class ThreadRepliesResult {
  const ThreadRepliesResult(this.kind, {this.summary, this.request});
  final String kind;
  final Map<String, dynamic>? summary;
  final ThreadRebaselineRequest? request;
}

class _ReplyFrame {
  const _ReplyFrame(
    this.scopeId,
    this.parentChannelId,
    this.payload,
    this.reply,
    this.epoch,
  );
  final String scopeId, parentChannelId;
  final Map<String, dynamic> payload, reply;
  final String? epoch;
  int get seq => reply['seq'] as int;
  SyncFrame get frame => SyncFrame(
    scopeId: scopeId,
    seq: BigInt.from(seq),
    epoch: epoch,
    event: {'reply': reply, 'replyCount': payload['replyCount']},
  );
}

class _PendingReplies {
  _PendingReplies(this.request, _ReplyFrame frame)
    : frames = [frame],
      latest = frame;
  final ThreadRebaselineRequest request;
  List<_ReplyFrame> frames;
  _ReplyFrame latest;
  void add(_ReplyFrame frame) {
    if (frame.seq >= frames.last.seq) latest = frame;
    if (frames.any((r) => r.seq == frame.seq)) return;
    frames = [...frames, frame]..sort((a, b) => a.seq.compareTo(b.seq));
    if (frames.length > inlineReplyCap)
      frames = frames.sublist(frames.length - inlineReplyCap);
  }
}

class ThreadRepliesSync {
  ThreadRepliesSync() : core = _create();
  SyncCore core;
  final Map<String, String> _canonicalEpoch = {};
  final Map<String, _PendingReplies> _pending = {};
  final Map<String, String> _parents = {};
  final Map<String, ThreadRepliesScope> _legacy = {};
  int _generation = 0;

  static SyncCore _create() => SyncCore(
    domains: [
      SyncDomain(
        name: threadRepliesDomain,
        density: SyncDensity.sparse,
        initialState: ThreadRepliesScope.empty,
        fold: (state, event, _, _) => (state as ThreadRepliesScope).apply(
          event['reply'] as Map<String, dynamic>,
          event['replyCount'] as int,
        ),
        fromSnapshot: (snapshot) => snapshot.state,
        acceptSameWatermarkSnapshot: (current, snapshot) {
          final before = current as ThreadRepliesScope;
          final after = snapshot.state as ThreadRepliesScope;
          if (after.replyCount < before.replyCount) return false;
          if (after.replies.length != before.replies.length) {
            return after.replies.length > before.replies.length;
          }
          for (var i = after.replies.length - 1; i >= 0; i--) {
            final a = after.replies[i]['seq'] as int;
            final b = before.replies[i]['seq'] as int;
            if (a != b) return a > b;
          }
          return false;
        },
      ),
    ],
  );

  String scopeId(
    String server,
    String principal,
    String parent,
    String thread,
  ) => jsonEncode([server, principal, parent, thread]);
  ThreadRepliesScope? scope(String id) =>
      core.state(threadRepliesDomain, id) as ThreadRepliesScope?;

  void reset() {
    core = _create();
    _canonicalEpoch.clear();
    _pending.clear();
    _parents.clear();
    _legacy.clear();
    _generation++;
  }

  Set<String> parentMessageIdsForChannel(String channelId) => {
    for (final id in _parents.keys)
      if (_parents[id] == channelId || (jsonDecode(id) as List)[3] == channelId)
        (jsonDecode(id) as List)[2] as String,
  };

  void revokeChannel(String channelId) {
    for (final id in _parents.keys.toList()) {
      final identity = jsonDecode(id) as List;
      if (_parents[id] != channelId && identity[3] != channelId) continue;
      core.revokeScope(threadRepliesDomain, id);
      _canonicalEpoch.remove(id);
      _pending.remove(id);
      _parents.remove(id);
      _legacy.remove(id);
    }
  }

  Map<String, dynamic> _summary(
    Map<String, dynamic> payload,
    ThreadRepliesScope state,
  ) => {
    ...payload,
    'replyCount': state.replyCount,
    'latestReplies': state.replies,
  };

  _ReplyFrame? _canonical(
    Map<String, dynamic> p,
    String server,
    String principal,
    Map<String, dynamic> reply,
  ) {
    final envelope = _map(p['syncCoreReplyWindow']);
    final discussion = _map(envelope?['discussion']);
    final root = _map(discussion?['root']);
    final relation = _map(discussion?['relation']);
    final parent = _map(discussion?['parentScopeKey']);
    final window = _map(envelope?['window']);
    final latest = _map(p['latestReply']);
    final anchor = _map(latest?['conversationContext']);
    final parentId = p['parentMessageId'], thread = p['threadChannelId'];
    if (envelope == null ||
        discussion == null ||
        root == null ||
        relation == null ||
        parent == null ||
        window == null ||
        anchor == null ||
        root['kind'] != 'message' ||
        root['serverId'] != server ||
        root['id'] != parentId ||
        relation['kind'] != 'replies' ||
        discussion['backing'] != 'sync-scope' ||
        parent['serverId'] != server ||
        parent['scopeId'] is! String ||
        !const {
          'channel',
          'private',
          'joint',
          'dm',
        }.contains(parent['scopeKind']) ||
        window['kind'] != 'sync-scope-window' ||
        !(window['scopeCursor'] == null || window['scopeCursor'] is String) ||
        !(window['epoch'] == null || window['epoch'] is String) ||
        !window.containsKey('scopeCursor') ||
        !window.containsKey('epoch') ||
        anchor['channelType'] != 'thread' ||
        anchor['parentMessageId'] != parentId ||
        anchor['parentChannelId'] != parent['scopeId'] ||
        anchor['parentChannelType'] != parent['scopeKind'] ||
        thread is! String ||
        p['lastReplyAt'] != null && p['lastReplyAt'] is! String ||
        !p.containsKey('lastReplyAt') ||
        p['participantIds'] is! List ||
        !(p['participantIds'] as List).every((v) => v is String) ||
        p.containsKey('unreadCount') && _safe(p['unreadCount']) == null ||
        p['firstUnreadMessageId'] != null &&
            p['firstUnreadMessageId'] is! String) {
      return null;
    }
    final id = scopeId(server, principal, parentId as String, thread);
    return _ReplyFrame(
      id,
      parent['scopeId'] as String,
      p,
      reply,
      window['epoch'] as String?,
    );
  }

  ThreadRepliesResult consume(
    Map<String, dynamic> p, {
    required String serverId,
    required String principalId,
  }) {
    final parent = p['parentMessageId'], thread = p['threadChannelId'];
    if (parent is! String ||
        thread is! String ||
        _safe(p['replyCount']) == null) {
      return const ThreadRepliesResult('dropped');
    }
    final envelope = _map(p['syncCoreReplyWindow']);
    final reply = projectThreadReply(p['latestReply']);
    final id = scopeId(serverId, principalId, parent, thread);
    if (envelope?['producer'] != threadRepliesProducer) {
      // Missing sequence cannot order a reply window, but must not remove a
      // legacy server's count-only summary from the existing native surface.
      if (reply == null)
        return ThreadRepliesResult('legacy', summary: Map.of(p));
      final current = _legacy[id] ?? scope(id) ?? ThreadRepliesScope.empty();
      final next = current.apply(reply, p['replyCount'] as int);
      _legacy[id] = next;
      final anchor = _map(_map(p['latestReply'])?['conversationContext']);
      if (anchor?['parentChannelId'] is String) {
        _parents[id] = anchor!['parentChannelId'] as String;
      }
      return ThreadRepliesResult('legacy', summary: _summary(p, next));
    }
    if (reply == null) return const ThreadRepliesResult('dropped');
    final normalized = _canonical(p, serverId, principalId, reply);
    if (normalized == null) return const ThreadRepliesResult('dropped');
    _parents[id] = normalized.parentChannelId;
    final canonical = _canonicalEpoch[id];
    if (canonical != null &&
        normalized.epoch != null &&
        normalized.epoch != canonical) {
      return _rebaseline(normalized);
    }
    if (canonical == null && normalized.epoch != null) {
      _canonicalEpoch[id] = normalized.epoch!;
    }
    final outcome = core.ingestFrame(threadRepliesDomain, normalized.frame);
    if (outcome['kind'] == 'duplicate_dropped') {
      return const ThreadRepliesResult('duplicate_dropped');
    }
    if (outcome['kind'] == 'epoch_rebaseline_requested') {
      return _rebaseline(normalized);
    }
    final accepted = scope(id)!;
    _legacy[id] = accepted;
    return ThreadRepliesResult('applied', summary: _summary(p, accepted));
  }

  ThreadRepliesResult _rebaseline(_ReplyFrame frame) {
    final old = _pending[frame.scopeId];
    if (old != null && old.request.epoch == frame.epoch) {
      old.add(frame);
      return const ThreadRepliesResult('rebaseline_pending');
    }
    final request = ThreadRebaselineRequest(
      scopeId: frame.scopeId,
      generation: ++_generation,
      parentMessageId: frame.payload['parentMessageId'] as String,
      parentChannelId: frame.parentChannelId,
      threadChannelId: frame.payload['threadChannelId'] as String,
      epoch: frame.epoch,
    );
    _pending[frame.scopeId] = _PendingReplies(request, frame);
    return ThreadRepliesResult('rebaseline_requested', request: request);
  }

  void release(ThreadRebaselineRequest request) {
    if (_pending[request.scopeId]?.request.generation == request.generation) {
      _pending.remove(request.scopeId);
    }
  }

  Map<String, dynamic> hydrateSummary(
    String serverId,
    String principalId,
    String parentChannelId,
    String parentMessageId,
    Map<String, dynamic> summary,
  ) {
    final thread = summary['threadChannelId'], raw = summary['latestReplies'];
    if (thread is! String ||
        raw is! List ||
        _safe(summary['replyCount']) == null) {
      return summary;
    }
    final previews = raw.map(_preview).toList();
    if (previews.any((r) => r == null)) return summary;
    final id = scopeId(serverId, principalId, parentMessageId, thread);
    _parents[id] = parentChannelId;
    final snapshot = ThreadRepliesScope.snapshot(
      previews.cast(),
      summary['replyCount'] as int,
      epoch: _canonicalEpoch[id],
    );
    core.ingestSnapshot(
      threadRepliesDomain,
      SyncSnapshot(
        scopeId: id,
        watermark: BigInt.from(snapshot.snapshotSeq),
        state: snapshot,
        epoch: snapshot.epoch,
      ),
    );
    final accepted = scope(id)!;
    _legacy[id] = accepted;
    return _summary(summary, accepted);
  }

  ThreadRepliesResult completeRebaseline(
    ThreadRebaselineRequest request, {
    required Iterable<Map<String, dynamic>> replies,
    required int replyCount,
    bool historyLimited = false,
  }) {
    final pending = _pending[request.scopeId];
    if (pending == null ||
        pending.request.generation != request.generation ||
        pending.request.epoch != request.epoch) {
      return const ThreadRepliesResult('duplicate_dropped');
    }
    final state = ThreadRepliesScope.snapshot(
      replies,
      replyCount,
      epoch: request.epoch,
      historyLimited: historyLimited,
    );
    final outcome = core.ingestSnapshot(
      threadRepliesDomain,
      SyncSnapshot(
        scopeId: request.scopeId,
        watermark: BigInt.from(state.snapshotSeq),
        state: state,
        epoch: request.epoch,
      ),
    );
    if (outcome['kind'] != 'applied') {
      release(request);
      return const ThreadRepliesResult('duplicate_dropped');
    }
    if (request.epoch != null)
      _canonicalEpoch[request.scopeId] = request.epoch!;
    for (final frame in pending.frames) {
      core.ingestFrame(threadRepliesDomain, frame.frame);
    }
    release(request);
    final accepted = scope(request.scopeId)!;
    _legacy[request.scopeId] = accepted;
    return ThreadRepliesResult(
      'applied',
      summary: _summary(pending.latest.payload, accepted),
    );
  }
}
