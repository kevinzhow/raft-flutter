// Web `store/hiddenHistoryStore.ts` (the wire shapes and their parse rules): what a Free plan's history cutoff hides in
// a channel or thread. `hiddenHistory` rides a message page that reached the
// start of the visible window; the hidden jump target rides the context
// route's `history_limited` 404. Receiver memory only, keyed by the channel or
// thread the page was read from (like Web, nothing is persisted: a window
// restored from disk shows the uncounted card until the first page lands).

import 'client.dart' show RaftApiException;

/// One of the newest messages the cutoff hides, as the faded glimpse shows it.
class HiddenHistoryMessage {
  const HiddenHistoryMessage({
    required this.id,
    required this.senderType,
    required this.senderId,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
    this.preview,
  });

  final String id, senderType, senderId, createdAt;
  final String? senderName, senderAvatarUrl, preview;

  static const _senderTypes = {'user', 'agent', 'external_projection'};

  /// Web `readHiddenHistoryMessage`: null when a required field is missing.
  static HiddenHistoryMessage? read(Object? value) {
    if (value is! Map) return null;
    final id = value['id'], senderId = value['senderId'];
    final createdAt = value['createdAt'], type = value['senderType'];
    if (id is! String || senderId is! String || createdAt is! String) {
      return null;
    }
    if (type is! String || !_senderTypes.contains(type)) return null;
    String? text(String key) => value[key] is String ? value[key] : null;
    return HiddenHistoryMessage(
      id: id,
      senderType: type,
      senderId: senderId,
      createdAt: createdAt,
      senderName: text('senderName'),
      senderAvatarUrl: text('senderAvatarUrl'),
      preview: text('preview'),
    );
  }

  static List<HiddenHistoryMessage> readList(Object? value) => [
    if (value is List)
      for (final row in value) ?read(row),
  ];
}

/// `hiddenHistory`: how many messages Pro would show (capped by the server),
/// whether a thread's first message is hidden too, and the newest hidden ones.
class HiddenHistory {
  const HiddenHistory({
    required this.hiddenCount,
    required this.hiddenCountCapped,
    required this.parentHidden,
    required this.latest,
  });

  final int hiddenCount;
  final bool hiddenCountCapped, parentHidden;
  final List<HiddenHistoryMessage> latest;

  /// Web `readHiddenHistory`: null unless `hiddenCount` is a number >= 0.
  static HiddenHistory? read(Object? value) {
    if (value is! Map) return null;
    final count = value['hiddenCount'];
    if (count is! num || !count.isFinite || count < 0) return null;
    return HiddenHistory(
      hiddenCount: count.toInt(),
      hiddenCountCapped: value['hiddenCountCapped'] == true,
      parentHidden: value['parentHidden'] == true,
      latest: HiddenHistoryMessage.readList(value['latest']),
    );
  }
}

/// A jump target behind the cutoff: the target (80 characters), the hidden
/// message before it and the two after, the thread's hidden reply counts and
/// the target's own replies when it has a thread.
class HiddenTarget {
  const HiddenTarget({
    required this.target,
    required this.before,
    required this.after,
    this.sequence,
    this.threadCounts,
    this.replies,
  });

  final HiddenHistoryMessage target;
  final BigInt? sequence;
  final List<HiddenHistoryMessage> before, after;
  final HiddenThreadCounts? threadCounts;
  final HiddenTargetReplies? replies;

  /// Web `readHistoryLimitedError`: the target a context 404 with code
  /// `history_limited` carries; null for any other failure.
  static HiddenTarget? fromError(Object error) =>
      error is RaftApiException &&
          error.status == 404 &&
          error.code == 'history_limited'
      ? read(error.details['hiddenTarget'])
      : null;

  /// Web `readHiddenTarget`: the target needs a numeric `seq`.
  static HiddenTarget? read(Object? value) {
    if (value is! Map) return null;
    final target = HiddenHistoryMessage.read(value['target']);
    final raw = value['target'];
    final seq = raw is Map ? raw['seq'] : null;
    if (target == null || seq is! num || !seq.isFinite) return null;
    final replies = value['replies'];
    final latest = replies is Map
        ? HiddenHistoryMessage.read(replies['latest'])
        : null;
    final count = replies is Map ? replies['count'] : null;
    return HiddenTarget(
      target: target,
      sequence: BigInt.from(seq),
      before: HiddenHistoryMessage.readList(value['before']),
      after: HiddenHistoryMessage.readList(value['after']),
      threadCounts: HiddenThreadCounts.read(value['thread']),
      replies: count is num && count > 0 && latest != null
          ? HiddenTargetReplies(count.toInt(), latest)
          : null,
    );
  }
}

class HiddenThreadCounts {
  const HiddenThreadCounts(this.count, this.capped, this.parentHidden);
  final int count;
  final bool capped, parentHidden;

  static HiddenThreadCounts? read(Object? value) {
    if (value is! Map) return null;
    final count = value['hiddenReplyCount'];
    if (count is! num || count < 0) return null;
    return HiddenThreadCounts(
      count.toInt(),
      value['hiddenReplyCountCapped'] == true,
      value['parentHidden'] == true,
    );
  }
}

class HiddenTargetReplies {
  const HiddenTargetReplies(this.count, this.latest);
  final int count;
  final HiddenHistoryMessage latest;
}

/// Web `useHiddenHistoryStore`. Plain receiver memory; the workspace notifies
/// after the page it was read from is accepted.
class HiddenHistoryStore {
  final Map<String, HiddenHistory> _byChannel = {};
  final Map<String, HiddenTarget> _targets = {};

  HiddenHistory? of(String? channelId) => _byChannel[channelId];
  HiddenTarget? targetOf(String? channelId) => _targets[channelId];

  /// Web `recordHiddenHistory`: a page that is not limited clears it; a limited
  /// page without `hiddenHistory` (one that did not reach the start of the
  /// window) leaves the last answer in place.
  void recordPage(String channelId, Map page) {
    if (page['historyLimited'] != true) {
      _byChannel.remove(channelId);
      return;
    }
    final hidden = HiddenHistory.read(page['hiddenHistory']);
    if (hidden != null) _byChannel[channelId] = hidden;
  }

  void recordTarget(String channelId, HiddenTarget target) =>
      _targets[channelId] = target;

  void clearTarget(String channelId) => _targets.remove(channelId);

  void clear() {
    _byChannel.clear();
    _targets.clear();
  }
}
