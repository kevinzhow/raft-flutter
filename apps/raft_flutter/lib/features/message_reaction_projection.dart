/// A complete receiver-private snapshot wins over the legacy message roster.
/// Canonical facts (previewK) never infer the current viewer's own reaction.
/// The caller admits only messages from the current authorized window.
Set<String> projectedOwnReactions({
  required String? principal,
  required List<dynamic> reactions,
  required Set<String>? completeViewer,
}) {
  if (principal == null || principal.isEmpty) return const {};
  if (completeViewer != null) return Set.unmodifiable(completeViewer);
  return {
    for (final reaction in reactions)
      if (reaction is Map &&
          reaction['emoji'] is String &&
          reaction['reactorIds'] is List &&
          reaction['reactorNames'] is List &&
          (reaction['reactorIds'] as List).contains(principal))
        reaction['emoji'] as String,
  };
}

/// [own] with the toggles still in flight applied: the viewer's chip state
/// changes when they tap, not when the server answers.
Set<String> withPendingReactions(Set<String> own, Map<String, bool>? pending) {
  if (pending == null || pending.isEmpty) return own;
  return Set.unmodifiable({
    for (final emoji in own)
      if (pending[emoji] != false) emoji,
    for (final e in pending.entries)
      if (e.value) e.key,
  });
}
