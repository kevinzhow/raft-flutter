/// A visible row and its distance below the timeline top. A fold handoff has a
/// short lifetime; the active reading position is independent of that handoff.
class ReadingAnchor {
  ReadingAnchor(this.messageKey, this.top) : _saved = Stopwatch()..start();
  final String messageKey;
  final double top;
  final Stopwatch _saved;
  static const lifetime = Duration(seconds: 3);
  bool get fresh => _saved.elapsed <= lifetime;
}

/// Durable position is scoped by the store; an id alone never grants access.
class SavedReadingPosition {
  const SavedReadingPosition(this.messageId, this.sequence, this.top);
  final String messageId;
  final BigInt sequence;
  final double top;
}

/// Owns per-conversation reading positions and one-use fold handoffs.
class ConversationReadingPositions {
  final _positions = <String, ({ReadingAnchor anchor, bool claimed})>{};
  ReadingAnchor? read(String id) => _positions[id]?.anchor;
  void save(String id, ReadingAnchor anchor) =>
      _positions[id] = (anchor: anchor, claimed: false);
  ReadingAnchor? take(String id) {
    final position = _positions[id];
    if (position == null || position.claimed || !position.anchor.fresh) {
      return null;
    }
    _positions[id] = (anchor: position.anchor, claimed: true);
    return position.anchor;
  }

  void clear([String? id]) {
    if (id == null) {
      _positions.clear();
    } else {
      _positions.remove(id);
    }
  }
}
