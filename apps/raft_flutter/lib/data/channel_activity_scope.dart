import 'dart:convert';

import 'resource_snapshot_cache.dart';

/// Mounted ThreadsInbox contracts in Web 1.21.12 (a98ae003).
///
/// DMs uses the normal inbox policy within a server-side scope. Its rows and
/// count belong to that view; its metadata cannot replace the unscoped inbox.
class ChannelActivityScope {
  const ChannelActivityScope(this.view, {this.savedEnabled = true});

  final String view;
  final bool savedEnabled;

  bool get directMessages => view == 'dms';
  bool get globalInbox => !['saved', 'done', 'dms'].contains(view);

  static bool _dmWindow(String? key) {
    if (key == null) return false;
    final shape = jsonDecode(key) as List;
    return shape.first == '/channels/inbox' &&
        (shape[1] as Map)['scope'] == 'dms';
  }

  /// The last accepted scoped count lives with its cached window, including
  /// across page navigation. It is never the unscoped inbox's total.
  static int directMessagesTotal(
    String? currentView,
    int? current,
    Map<String, ResourceViewWindow> windows,
  ) {
    if (_dmWindow(currentView)) return current ?? 0;
    for (final entry in windows.entries.toList().reversed) {
      if (_dmWindow(entry.key)) return entry.value.totalCount ?? 0;
    }
    return 0;
  }

  /// Keep the latest independent DMs source within the existing bounded cache.
  /// Other filter visits must not erase its count before it is opened again.
  static String evictionKey(Map<String, ResourceViewWindow> windows) {
    final dm = windows.keys.where(_dmWindow).lastOrNull;
    return windows.keys.firstWhere((key) => key != dm);
  }

  static List<Map<String, dynamic>> groups(
    Map value,
    List<Map<String, dynamic>> previous,
    String? selectedId,
  ) {
    if (value['groups'] is! List) return previous;
    final selected = previous
        .where((g) => g['channelId'] == selectedId)
        .firstOrNull;
    final next = (value['groups'] as List)
        .whereType<Map>()
        .map((g) => Map<String, dynamic>.from(g))
        .toList();
    if (selected != null && !next.any((g) => g['channelId'] == selectedId)) {
      next.add({...selected, 'count': 0});
    }
    return next;
  }

  String get path => switch (view) {
    'saved' when savedEnabled => '/channels/saved',
    'done' => '/channels/inbox/done',
    'unfollowed' => '/channels/inbox/unfollowed',
    _ => '/channels/inbox',
  };

  Map<String, dynamic> parameters(Map<String, dynamic> base) => {
    ...base,
    if (!['saved', 'done', 'unfollowed'].contains(view))
      'filter': directMessages ? 'all' : view,
    if (directMessages) 'scope': 'dms',
  };

  ({String title, String detail}) emptyState({String? channelLabel}) => (
    title: switch (view) {
      'saved' => 'No saved threads yet',
      'done' => 'Nothing completed yet',
      'mentions' => 'No mentions yet',
      'unread' => 'No unread chats',
      'dms' when channelLabel == null => 'No DM activity',
      _ =>
        channelLabel == null
            ? 'Activity is empty'
            : 'No activity in $channelLabel',
    },
    detail: switch (view) {
      'saved' => 'Save a thread or message from Activity to keep it here.',
      'done' => 'Items you mark done appear here and can be restored.',
      _ when channelLabel != null =>
        'Try another channel or clear the channel filter.',
      'mentions' => 'Channels, DMs, and threads where someone @mentions you will appear here.',
      'dms' =>
        'DMs and threads in DMs show up here when they have new activity.',
      _ => 'Channels, DMs, and followed threads stay here until they are done.',
    },
  );
}
