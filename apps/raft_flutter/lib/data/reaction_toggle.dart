/// Optimistic reaction toggle, mirroring Web MessageItem
/// `buildOptimisticReactionMessage` / `replaceReactionForEmoji` /
/// `mergeReactionResponsePreservingPending`.
///
/// Reaction entries are either legacy rosters (`reactorIds` + `reactorNames`)
/// or canonical facts (`count` + `previewK`). A toggle changes the count in
/// place and inserts or removes the chip exactly once.
library;

/// One in-flight toggle: the state it is heading for and what to restore.
class PendingReaction {
  PendingReaction({
    required this.target,
    required this.previous,
    required this.previousIndex,
    required this.baseCount,
  });

  /// Whether the viewer reacted once the write lands.
  final bool target;

  /// The emoji's entry before the toggle (null when there was no chip).
  final Map<String, dynamic>? previous;
  final int previousIndex;
  final int baseCount;
}

bool _roster(Map<dynamic, dynamic> reaction) =>
    reaction['reactorIds'] is List && reaction['reactorNames'] is List;

int _index(List<Map<String, dynamic>> reactions, String emoji) =>
    reactions.indexWhere((r) => r['emoji'] == emoji);

List<Map<String, dynamic>> reactionList(Object? raw) => [
  for (final r in raw is List ? raw : const [])
    if (r is Map) Map<String, dynamic>.from(r),
];

/// The viewer's reaction to [emoji] when the row itself says: a roster entry
/// answers, a missing chip means "not reacted"; a canonical entry without a
/// private snapshot is unknown (null).
bool? ownReactionFromRow(Object? rawReactions, String emoji, String? viewerId) {
  final reactions = reactionList(rawReactions);
  final index = _index(reactions, emoji);
  if (index < 0) return false;
  final entry = reactions[index];
  if (viewerId != null && _roster(entry)) {
    return (entry['reactorIds'] as List).contains(viewerId);
  }
  return null;
}

/// [reactions] with the viewer's reaction to [emoji] set to [reacted]. Returns
/// the list unchanged when it already is in that state.
List<Map<String, dynamic>> setOwnReaction(
  List<Map<String, dynamic>> reactions,
  String emoji, {
  required bool reacted,
  required String viewerId,
  required String viewerName,
}) {
  final next = [...reactions];
  final index = _index(next, emoji);
  if (index < 0) {
    if (!reacted) return reactions;
    final canonical = next.any((r) => !_roster(r) && r['previewK'] is List);
    next.add({
      'emoji': emoji,
      'count': 1,
      if (canonical)
        'previewK': const []
      else ...{
        'reactorIds': [viewerId],
        'reactorNames': [viewerName],
      },
    });
    return next;
  }
  final entry = Map<String, dynamic>.from(next[index]);
  final count = entry['count'] is int ? entry['count'] as int : 0;
  if (_roster(entry)) {
    final ids = List<dynamic>.of(entry['reactorIds']);
    final names = List<dynamic>.of(entry['reactorNames']);
    final at = ids.indexOf(viewerId);
    if (reacted == (at >= 0)) return reactions;
    if (reacted) {
      ids.add(viewerId);
      names.add(viewerName);
      entry['count'] = count + 1;
    } else {
      ids.removeAt(at);
      if (at < names.length) names.removeAt(at);
      entry['count'] = count > 0 ? count - 1 : 0;
    }
    entry['reactorIds'] = ids;
    entry['reactorNames'] = names;
  } else {
    entry['count'] = reacted ? count + 1 : (count > 0 ? count - 1 : 0);
  }
  if ((entry['count'] as int) <= 0) {
    next.removeAt(index);
  } else {
    next[index] = entry;
  }
  return next;
}

/// Web `replaceReactionForEmoji`: put [pending]'s prior entry back (or drop
/// the chip it created), leaving every other reaction as it is now.
List<Map<String, dynamic>> restoreReaction(
  List<Map<String, dynamic>> reactions,
  String emoji,
  PendingReaction pending,
) {
  final next = [...reactions];
  final index = _index(next, emoji);
  final previous = pending.previous;
  if (previous == null) {
    if (index >= 0) next.removeAt(index);
  } else if (index >= 0) {
    next[index] = Map<String, dynamic>.from(previous);
  } else {
    next.insert(
      pending.previousIndex.clamp(0, next.length),
      Map<String, dynamic>.from(previous),
    );
  }
  return next;
}

/// Lay the still-pending toggles over [reactions] from the server (a response
/// or a socket row). Idempotent: a roster that already shows the target, or a
/// canonical count that already moved off its base, is left alone.
List<Map<String, dynamic>> overlayPendingReactions(
  List<Map<String, dynamic>> reactions,
  Map<String, PendingReaction> pending, {
  required String viewerId,
  required String viewerName,
}) {
  var next = reactions;
  for (final MapEntry(key: emoji, value: toggle) in pending.entries) {
    final index = _index(next, emoji);
    final entry = index < 0 ? null : next[index];
    final count = entry?['count'] is int ? entry!['count'] as int : 0;
    if (entry != null && !_roster(entry) && count != toggle.baseCount) {
      continue; // The server row already includes the write.
    }
    next = setOwnReaction(
      next,
      emoji,
      reacted: toggle.target,
      viewerId: viewerId,
      viewerName: viewerName,
    );
  }
  return next;
}

/// Entry for [emoji] in [reactions], for recording [PendingReaction.previous].
PendingReaction beginReaction(
  List<Map<String, dynamic>> reactions,
  String emoji, {
  required bool target,
}) {
  final index = _index(reactions, emoji);
  final entry = index < 0 ? null : reactions[index];
  return PendingReaction(
    target: target,
    previous: entry == null ? null : Map<String, dynamic>.from(entry),
    previousIndex: index < 0 ? reactions.length : index,
    baseCount: entry?['count'] is int ? entry!['count'] as int : 0,
  );
}
