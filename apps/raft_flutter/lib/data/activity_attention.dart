import 'resource_row_reconcile.dart' show activityScopeId;

/// The one rule behind every number that says "how much needs me": the app
/// icon badge, the system notification set and the in-app Activity badge.
///
/// The unit is the server's Activity unread count, `totalUnreadCount` of
/// `/channels/inbox` (the sum of each listed conversation's `unreadCount`: unread
/// messages of channels, DMs and followed threads; muted conversations and
/// Done rows are not listed by the server). The server's own mobile push
/// badge is the same number summed over the member servers
/// (pushService.loadMobilePushBadge), so the app icon badge is that sum.
///
/// The server the app has open uses its live inbox window (the number the
/// Activity badge shows); every other member server uses its
/// `/servers/unread-summary` `activityUnreadCount`. An unknown count is 0: a
/// broader per-conversation count never stands in for it.
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
        row['serverId'] as String: switch (row['activityUnreadCount']) {
          num count
              when count.isFinite &&
                  count >= 0 &&
                  count % 1 == 0 &&
                  count <= 9007199254740991 =>
            count.toInt(),
          _ => null,
        },
  };
}

/// OS badges must not turn an unavailable member count into a smaller total.
int? knownActivityBadgeTotal({
  required String? currentServerId,
  required int? currentTotal,
  required Iterable<String> memberServerIds,
  required Map<String, int?> summary,
}) {
  final members = memberServerIds.toSet();
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
