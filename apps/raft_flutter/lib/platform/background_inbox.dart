import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:raft_client/raft_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/notification_levels.dart';
import '../data/notification_settings_api.dart';
import 'content_target.dart';
import 'account_activity_unread.dart';

const backgroundInboxTask = 'app.raft.raft_flutter.inbox_refresh';
const backgroundScopeKey = 'raft.background.inbox.scope';

String notificationScope(RaftClient client) =>
    '${client.origin}\n${client.user!.id}\n${client.serverId}';
String notificationPreferenceKey(String scope) =>
    'raft.notifications.${sha256.convert(utf8.encode(scope))}';
int messageNotificationId(String scope, String messageId) {
  final bytes = sha256.convert(utf8.encode('$scope\n$messageId')).bytes;
  return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
      0x7fffffff;
}

/// One notification per conversation (Activity scope id: a thread's own
/// channel for a thread), so a later message replaces it and reading the
/// conversation removes it.
int conversationNotificationId(String scope, String conversation) =>
    messageNotificationId(scope, 'conversation:$conversation');

/// Persist only scope, IDs and activation time; never message text or tokens.
class BackgroundInboxStore {
  Future<void> _writes = Future.value();
  Future<SharedPreferences> _fresh() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return preferences;
  }

  Future<void> recordWake(String mode, DateTime started, bool success) async {
    await (await _fresh()).setString(
      'raft.background.inbox.last-wake',
      jsonEncode({
        'mode': mode,
        'startedAt': started.toUtc().toIso8601String(),
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'success': success,
      }),
    );
  }

  Future<Map<String, dynamic>?> lastWake() async {
    final raw = (await _fresh()).getString('raft.background.inbox.last-wake');
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<String?> scope() async =>
      (await _fresh()).getString(backgroundScopeKey);
  Future<void> select(String? scope) async {
    final p = await _fresh();
    if (scope == null) {
      await p.remove(backgroundScopeKey);
    } else {
      await p.setString(backgroundScopeKey, scope);
    }
  }

  Future<bool> enabled(String scope) async =>
      (await _fresh()).getBool(notificationPreferenceKey(scope)) ?? false;
  String _key(String scope) =>
      'raft.background.inbox.${sha256.convert(utf8.encode(scope))}';
  Future<Map<String, dynamic>?> state(String scope) async {
    final raw = (await _fresh()).getString(_key(scope));
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> activate(String scope) async {
    if (await state(scope) != null) return;
    await save(scope, {
      'since': DateTime.now().toUtc().toIso8601String(),
      'seen': <String>[],
    });
  }

  Future<void> save(String scope, Map<String, dynamic> state) async {
    await (await _fresh()).setString(_key(scope), jsonEncode(state));
  }

  Future<void> forget(String scope) async =>
      (await _fresh()).remove(_key(scope));
  Future<bool> seen(String scope, String id) async {
    await _writes;
    return ((await state(scope))?['seen'] as List? ?? const []).contains(id);
  }

  Future<void> mark(String scope, String id) =>
      _writes = _writes.catchError((Object _) {}).then((_) => _mark(scope, id));
  Future<void> _mark(String scope, String id) async {
    final s = await state(scope);
    if (s == null) return;
    final ids = (s['seen'] as List? ?? const []).whereType<String>().toList();
    if (!ids.contains(id)) ids.add(id);
    s['seen'] = ids.length > 256 ? ids.sublist(ids.length - 256) : ids;
    await save(scope, s);
  }
}

class BackgroundInboxAlert {
  const BackgroundInboxAlert(
    this.target,
    this.title,
    this.body, {
    this.unread = 1,
  });
  final ContentTarget target;
  final String title, body;

  /// The conversation's Activity unread count when the alert was read.
  final int unread;
  static BackgroundInboxAlert? fromRow(
    Map row,
    String serverId,
    DateTime since, {
    bool mentionsOnly = false,
  }) {
    final thread = row['kind'] == 'thread';
    final at = DateTime.tryParse(
      '${row[thread ? 'lastActivityAt' : 'lastMessageAt']}',
    );
    final message = row[thread ? 'latestActivityMessageId' : 'lastMessageId'];
    final channel = row[thread ? 'parentChannelId' : 'channelId'];
    // The server only keeps unread mentions in `hasMention`; its
    // firstMentionMessageId is the OLDEST unread mention (null on the
    // RisingWave path), so it never gates the newest message. The unread
    // count check below completes the `hasMention && unreadCount > 0` rule.
    if (mentionsOnly && row['hasMention'] != true) return null;
    if (row['doneAt'] != null ||
        row['unreadCount'] is! num ||
        (row['unreadCount'] as num) <= 0 ||
        at == null ||
        at.isBefore(since) ||
        message is! String ||
        !ContentTarget.validId(message) ||
        channel is! String ||
        !ContentTarget.validId(channel) ||
        thread &&
            (row['isFollowing'] == false && row['hasMention'] != true ||
                row['threadChannelId'] is! String ||
                !ContentTarget.validId(row['threadChannelId']) ||
                row['parentMessageId'] is! String ||
                !ContentTarget.validId(row['parentMessageId']))) {
      return null;
    }
    String? label(Object? value) {
      if (value is! String) return null;
      final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      return text.isEmpty ? null : text;
    }

    final name = label(row[thread ? 'parentChannelName' : 'channelName']);
    final sender = label(
      row[thread ? 'latestActivitySenderName' : 'lastMessageSenderName'],
    );
    final dm = row['kind'] == 'dm';
    final conversation = name == null
        ? 'Channel'
        : name.startsWith('#')
        ? name
        : '#$name';
    final title = dm
        ? sender ?? name ?? 'Direct message'
        : thread
        ? '$conversation · Thread'
        : conversation;
    final preview =
        label(row[thread ? 'latestActivityPreview' : 'lastMessagePreview']) ??
        'New activity';
    final body = !dm && sender != null ? '$sender: $preview' : preview;
    String bounded(String value, int limit) =>
        String.fromCharCodes(value.runes.take(limit));
    return BackgroundInboxAlert(
      ContentTarget(
        channelId: channel,
        serverId: serverId,
        messageId: message,
        kind: thread
            ? 'thread'
            : row['kind'] == 'dm'
            ? 'dm'
            : 'channel',
        threadId: thread ? row['threadChannelId'] as String : null,
        parentMessageId: thread ? row['parentMessageId'] as String : null,
      ),
      bounded(title, 160),
      bounded(body, 512),
      unread: (row['unreadCount'] as num).toInt(),
    );
  }
}

/// The server's unread Activity projection owns eligibility, mute and Done.
/// A poll never changes read cursors. Each alert rechecks visible context.
/// The account settings and one server's levels a background poll applies
/// (Web v1.24 `resolveEffectiveLevel`, `isNotificationQuiet`).
class BackgroundNotificationPolicy {
  const BackgroundNotificationPolicy({
    required this.server,
    required this.channels,
    required this.account,
  });
  final NotificationLevel server;
  final Map<String, NotificationLevel> channels;
  final NotificationAccountSettings? account;

  /// GET /me/notification-settings and /notification-levels; null when the
  /// server answers neither (an older server keeps its own serverPushMode).
  static Future<BackgroundNotificationPolicy?> read(
    RaftClient client,
    RaftRecord server,
  ) async {
    final api = NotificationSettingsApi(client);
    final levels = await api
        .fetchServerLevels(server.id)
        .catchError((Object _) => null);
    if (levels == null) {
      // A server before the unified notifications: its server-wide mode.
      final legacy = await client
          .get('/servers/${server.id}/notification-settings')
          .catchError((Object _) => null);
      final mode = legacy is Map
          ? NotificationLevel.parse(legacy['serverPushMode'])
          : null;
      if (mode == null) return null;
      return BackgroundNotificationPolicy(
        server: mode,
        channels: const {},
        account: null,
      );
    }
    final account = await api.fetchAccount().catchError((Object _) => null);
    return BackgroundNotificationPolicy(
      server: levels.server,
      channels: levels.channels,
      account: account?.settings,
    );
  }

  bool quiet(DateTime now) => account?.quietAt(now) ?? false;

  bool get anyAll =>
      server == NotificationLevel.all ||
      channels.values.contains(NotificationLevel.all);
  bool get anyMentions =>
      anyAll ||
      server == NotificationLevel.mentions ||
      channels.values.contains(NotificationLevel.mentions);

  /// An Activity row's level: a thread follows its parent channel (threads
  /// have no level of their own); a DM inherits the server's.
  NotificationLevel levelOf(Map row) {
    final channel =
        row[row['kind'] == 'thread' ? 'parentChannelId' : 'channelId'];
    return resolveEffectiveLevel(
      server: server,
      channel: channel is String ? channels[channel] : null,
    );
  }
}

class BackgroundInboxPoller {
  BackgroundInboxPoller({
    required this.client,
    required this.store,
    required this.deliver,
    required this.authorize,
    this.suppress,
    this.clock = DateTime.now,
  });
  final DateTime Function() clock;
  final RaftClient client;
  final BackgroundInboxStore store;
  final Future<bool> Function(BackgroundInboxAlert alert, String scope) deliver;
  final Future<void> Function(ContentTarget target, bool Function() valid)
  authorize;
  final bool Function(ContentTarget target)? suppress;

  /// The account's membership sum. A missing summary leaves the OS badge
  /// unchanged; a selected-server subtotal cannot replace it.
  int? totalUnread;
  Future<bool> run() async {
    final scope = await store.scope();
    if (scope == null ||
        client.user == null ||
        client.serverId == null ||
        notificationScope(client) != scope ||
        !await store.enabled(scope)) {
      return true;
    }
    final generation = client.generation;
    bool valid() =>
        client.generation == generation &&
        client.signedIn &&
        notificationScope(client) == scope;
    Future<bool> current() async =>
        valid() && await store.scope() == scope && await store.enabled(scope);
    final state = await store.state(scope);
    final since = DateTime.tryParse('${state?['since']}');
    if (since == null || !await current()) return true;
    final servers = await client.servers();
    if (!await current()) return true;
    final server = servers.where((s) => s.id == client.serverId).firstOrNull;
    if (server == null) return true;
    // Server v1.24 decides who is notified from the account settings and the
    // levels (docs/contracts/notifications.md §1); a poll that stands in for
    // push applies the same rules: nothing while paused or in quiet hours,
    // then each conversation's effective level.
    final policy = await BackgroundNotificationPolicy.read(client, server);
    if (!await current() || policy == null || policy.quiet(clock())) {
      return true;
    }
    final mode = policy.anyAll
        ? 'all'
        : policy.anyMentions
        ? 'mentions'
        : null;
    if (mode == null) return true;
    // Bounded fetch: latest 100 conversations, at most five alerts per wake.
    final page = await client.get(
      '/channels/inbox',
      query: {
        'filter': mode == 'mentions' ? 'unread_mentions' : 'unread',
        'limit': 100,
      },
    );
    if (!await current() || page is! Map || page['items'] is! List) return true;
    final total = page['totalUnreadCount'];
    totalUnread = await backgroundActivityBadge(
      client,
      selectedTotal: mode == 'all' && total is num && total >= 0
          ? total.toInt()
          : null,
    );
    if (!await current()) return true;
    var count = 0;
    for (final row in (page['items'] as List).whereType<Map>()) {
      final level = policy.levelOf(row);
      if (level == NotificationLevel.none) continue;
      final alert = BackgroundInboxAlert.fromRow(
        row,
        client.serverId!,
        since,
        mentionsOnly: level == NotificationLevel.mentions,
      );
      if (alert == null || await store.seen(scope, alert.target.messageId!)) {
        continue;
      }
      if (!await current()) return true;
      if (suppress?.call(alert.target) == true) {
        await store.mark(scope, alert.target.messageId!);
        continue;
      }
      await authorize(alert.target, valid);
      if (!await current()) return true;
      // Done, mute or unfollow may have changed during the authority checks.
      final latest = await client.get(
        '/channels/inbox',
        query: {
          'filter': mode == 'mentions' ? 'unread_mentions' : 'unread',
          'limit': 100,
          'channelId': alert.target.channelId,
        },
      );
      if (!await current()) return true;
      if (latest is! Map ||
          latest['items'] is! List ||
          !(latest['items'] as List).whereType<Map>().any(
            (r) =>
                BackgroundInboxAlert.fromRow(
                  r,
                  client.serverId!,
                  since,
                  mentionsOnly: level == NotificationLevel.mentions,
                )?.target.messageId ==
                alert.target.messageId,
          )) {
        continue;
      }
      final latestPolicy = await BackgroundNotificationPolicy.read(
        client,
        server,
      );
      if (!await current() ||
          latestPolicy == null ||
          latestPolicy.quiet(clock()) ||
          latestPolicy.levelOf(row) != level) {
        return true;
      }
      if (await deliver(alert, scope)) {
        await store.mark(scope, alert.target.messageId!);
      }
      if (++count >= 5) break;
    }
    return true;
  }
}
