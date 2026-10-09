/// Pure ports of useAppNavigate.ts:13–109, 205–231 at Source 26f77ef.
enum RaftNavigationKind { push, pop, replace }

const raftUnknownNavigationEntry = '\u0000unknown-history-entry';

int nextRaftNavigationDepth(int depth, RaftNavigationKind kind) =>
    switch (kind) {
      RaftNavigationKind.push => depth + 1,
      RaftNavigationKind.pop => depth > 0 ? depth - 1 : 0,
      RaftNavigationKind.replace => depth,
    };

List<String> nextRaftNavigationStack(
  List<String> stack,
  RaftNavigationKind kind,
  String path,
) {
  if (kind == RaftNavigationKind.push) return [...stack, path];
  final next = stack.isEmpty ? <String>[] : stack.sublist(0, stack.length - 1);
  if (kind == RaftNavigationKind.pop && next.isNotEmpty && next.last == path) {
    return next;
  }
  return [...next, path];
}

Map<int, String> nextRaftNavigationEntries(
  Map<int, String> entries,
  RaftNavigationKind kind,
  int index,
  String path,
) => {
  for (final entry in entries.entries)
    if (kind != RaftNavigationKind.push || entry.key < index)
      entry.key: entry.value,
  index: path,
};

List<String> raftNavigationStackFromEntries(
  Map<int, String> entries,
  int index,
) => [
  for (var at = 0; at <= index; at++) entries[at] ?? raftUnknownNavigationEntry,
];

bool canUseRaftHistoryBack(String previous, String scope) {
  String? server(String path) =>
      RegExp(r'^/s/([^/?#]+)').firstMatch(path)?.group(1);
  final slug = server(scope);
  return slug == null || server(previous) == slug;
}

/// A null result means Back to the previous observed entry; otherwise replace
/// with this semantic fallback. Unobserved/foreign entries never grant Back.
String? resolveRaftMobileBack(
  List<String> stack,
  String fallback, {
  String? scope,
}) {
  final previous = stack.length < 2 ? null : stack[stack.length - 2];
  return previous != null &&
          previous.isNotEmpty &&
          previous != raftUnknownNavigationEntry &&
          canUseRaftHistoryBack(previous, scope ?? fallback)
      ? null
      : fallback;
}

class RaftSynchronousNavigation {
  const RaftSynchronousNavigation(this.kind, this.path, {this.historyIndex});
  final RaftNavigationKind kind;
  final String path;
  final int? historyIndex;
}

bool shouldConsumeRaftSynchronousNavigation(
  RaftSynchronousNavigation? pending,
  RaftSynchronousNavigation committed,
) =>
    pending != null &&
    pending.path == committed.path &&
    pending.kind == committed.kind &&
    (pending.historyIndex == null ||
        pending.historyIndex == committed.historyIndex);

bool isIdempotentRaftNavigationCommit(
  String previousKey,
  String currentKey,
  int? trackedIndex,
  int? currentIndex,
) =>
    previousKey == currentKey &&
    (trackedIndex == null ||
        currentIndex == null ||
        trackedIndex == currentIndex);
