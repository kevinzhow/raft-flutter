import 'resource_row_reconcile.dart' show activityScopeId;

/// The one rule behind every number that says "how much needs me": the app
/// icon badge, the system notification set and the in-app Activity badge.
///
/// Each server contributes its unread conversation messages and its separately
/// reported unread objects, one per object. The server's mobile push badge
/// still counts only conversation messages (pushService.loadMobilePushBadge).
///
/// The server the app has open uses its live inbox window (the number the
/// Activity badge shows); every other member server uses its
/// `/servers/unread-summary` Activity counts. An unknown count is 0: a broader
/// per-conversation count never stands in for it.
int activityBadgeTotal({
  required String? currentServerId,
  required int? currentTotal,
  required Iterable<String> memberServerIds,
  required int? Function(String serverId) summaryCount,
}) {
  var total = 0;
  for (final id in {...memberServerIds, ?currentServerId}) {
    total += id == currentServerId && currentTotal != null
        ? currentTotal
        : (summaryCount(id) ?? 0);
  }
  return total;
}

/// The unread count the accepted Activity window gives the conversation
/// [scopeId] (a thread's own channel for a thread); null when it lists none.
int? activityRowUnread(Iterable<Map> rows, String scopeId) {
  for (final row in rows) {
    if (activityScopeId(row) != scopeId) continue;
    if (row['doneAt'] != null) return 0;
    final count = row['unreadCount'];
    return count is num && count.isFinite && count > 0 ? count.toInt() : 0;
  }
  return null;
}

/// Accept only the Activity field of a complete summary response. Broader
/// channel unread counts never stand in for an unknown Activity count.
Map<String, int?>? activitySummaryCounts(dynamic value) {
  if (value is! List) return null;
  return {
    for (final row in value.whereType<Map>())
      if (row['serverId'] is String && (row['serverId'] as String).isNotEmpty)
        row['serverId'] as String: activitySummaryCount(row),
  };
}

int? activitySummaryCount(Map row) {
  final conversations = _summaryCount(row['activityUnreadCount']);
  if (conversations == null) return null;
  return conversations + (_summaryCount(row['activityObjectUnreadCount']) ?? 0);
}

int? _summaryCount(Object? value) => switch (value) {
  num count
      when count.isFinite &&
          count >= 0 &&
          count % 1 == 0 &&
          count <= 9007199254740991 =>
    count.toInt(),
  _ => null,
};

/// OS badges must not turn an unavailable member count into a smaller total.
///
/// Servers whose notification level is `none` ([silencedServerIds]) do not
/// count (Web v1.24 `notificationBadgeCount`: "Activity unread summed over
/// every server whose level is not none"); their unknown count never blocks
/// the total either.
int? knownActivityBadgeTotal({
  required String? currentServerId,
  required int? currentTotal,
  required Iterable<String> memberServerIds,
  required Map<String, int?> summary,
  Set<String> silencedServerIds = const {},
}) {
  final members = memberServerIds.toSet().difference(silencedServerIds);
  if (members.any(
    (id) =>
        (id == currentServerId ? currentTotal ?? summary[id] : summary[id]) ==
        null,
  )) {
    return null;
  }
  return activityBadgeTotal(
    currentServerId: members.contains(currentServerId) ? currentServerId : null,
    currentTotal: currentTotal,
    memberServerIds: members,
    summaryCount: (id) => summary[id],
  );
}
