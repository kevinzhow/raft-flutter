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
