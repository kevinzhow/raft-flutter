import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'search_memory.dart';
import 'system_notification_projection.dart';
import 'usage_limit_attention.dart';

typedef SystemNotificationGet = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});

/// A receiver-scoped write (`POST`) with no body.
typedef SystemNotificationPost = Future<dynamic> Function(String path);

/// Whether `usage_limit_attention_v0` is on for the current server.
typedef UsageLimitGate = Future<bool> Function();

class SystemNotificationContext {
  const SystemNotificationContext({
    required this.scope,
    required this.origin,
    required this.principal,
    required this.server,
    required this.channels,
    required this.canViewMachines,
    required this.canViewAgents,
    required this.mobile,
  });
  final String scope, origin, principal;
  final Map<String, dynamic>? server;
  final List<Map<String, dynamic>> channels;
  final bool canViewMachines, canViewAgents, mobile;
  String? get storageKey => server == null
      ? null
      : 'raft:notification-center:dismissed:${jsonEncode([origin, principal, server!['id']])}';
}

/// Machines/agents read from a shared, server-scoped directory instead of
/// per-store requests. [ready] mirrors a settled read of every allowed list.
@immutable
class SystemNotificationEntities {
  const SystemNotificationEntities({
    required this.machines,
    required this.agents,
    required this.ready,
  });
  final List<Map<String, dynamic>> machines, agents;
  final bool ready;
}

/// Authenticated projections in memory. Persistent data is limited to the last
/// 100 dismissal fingerprints, never server copy, credentials or machine rows.
class SystemNotificationStore extends ChangeNotifier {
  SystemNotificationStore({
    required this.get,
    SearchMemoryStorage? storage,
    DateTime Function()? clock,
    this.entities,
    this.post,
    this.usageLimitGate,
  }) : storage = storage ?? PreferencesSearchMemoryStorage(),
       clock = clock ?? DateTime.now;
  final SystemNotificationGet get;
  final SearchMemoryStorage storage;
  final DateTime Function() clock;

  /// When set, machines/agents come from the shared directory (which owns
  /// their revalidation) and [refresh] reads only the feedback count.
  final SystemNotificationEntities Function()? entities;

  /// Usage-limit attention (`system-notifications-v2`) needs both: without
  /// them the feed stays off, as when the flag is off.
  final SystemNotificationPost? post;
  final UsageLimitGate? usageLimitGate;
  SystemNotificationContext? context;
  UsageLimitSnapshot? _usage;
  bool? _usageGate;
  int _usageRevision = 0;
  UsageLimitSnapshot? get usageLimits => _usage;
  final dismissed = <String>{};
  List<Map<String, dynamic>> _machines = [], _agents = [];
  List<Map<String, dynamic>> get machines =>
      entities?.call().machines ?? _machines;
  List<Map<String, dynamic>> get agents => entities?.call().agents ?? _agents;
  bool get machineReady => entities?.call().ready ?? _machineReady;
  int feedbackUnread = 0;
  bool _machineReady = false, loading = false, failed = false, closed = false;
  int revision = 0, dismissRevision = 0, feedbackRevision = 0;
  Future<void> writes = Future.value();
  String? _publishedScope;
  List<SystemNotice> _publishedEntries = const [];

  /// Loading and failed reads are bookkeeping, not notification-center content.
  /// Compare with the last publication (not a fresh projection of mutable shared
  /// entities), so directory changes, copy and time-based deadlines still reach
  /// an open popup while unchanged background reads remain silent.
  void _publish() {
    final next = entries;
    if (_publishedScope == context?.scope &&
        next.length == _publishedEntries.length &&
        next.indexed.every((item) {
          final (i, a) = item;
          final b = _publishedEntries[i];
          return a.id == b.id &&
              a.kind == b.kind &&
              a.title == b.title &&
              a.body == b.body &&
              a.destination == b.destination &&
              a.targetId == b.targetId &&
              a.fingerprint == b.fingerprint &&
              a.unread == b.unread &&
              a.incidentId == b.incidentId &&
              mapEquals(a.parameters, b.parameters);
        })) {
      return;
    }
    _publishedScope = context?.scope;
    _publishedEntries = next;
    notifyListeners();
  }

  bool accepts(String scope, int ticket) =>
      !closed && context?.scope == scope && ticket == revision;
  List<SystemNotice> get entries {
    final c = context;
    if (c == null) return const [];
    final shared = entities?.call();
    return [
          if (c.server != null) ...usageLimitNotices(_usage),
          ...projectSystemNotifications(
            server: c.server,
            channels: c.channels,
            machines: shared?.machines ?? _machines,
            agents: shared?.agents ?? _agents,
            machinesReady: shared?.ready ?? _machineReady,
            canViewMachines: c.canViewMachines,
            mobile: c.mobile,
            feedbackUnread: feedbackUnread,
            now: clock(),
          ),
        ]
        .where(
          (n) => n.fingerprint == null || !dismissed.contains(n.fingerprint),
        )
        .toList(growable: false);
  }

  /// Entries that count toward the bell dot: [SystemNotice.unread] false marks
  /// a seen server-backed entry, every other entry counts while visible.
  int get unreadCount => entries.where((n) => n.unread != false).length;

  Future<void> bind(SystemNotificationContext next) async {
    if (closed) return;
    final changed = next.scope != context?.scope;
    context = next;
    if (!changed) {
      _publish();
      return;
    }
    ++revision;
    ++feedbackRevision;
    final localTicket = ++dismissRevision;
    _machines = [];
    _agents = [];
    _machineReady = false;
    _usage = null;
    _usageGate = null;
    ++_usageRevision;
    feedbackUnread = 0;
    failed = false;
    loading = false;
    dismissed.clear();
    _publish();
    final key = next.storageKey;
    if (key == null) return;
    unawaited(refresh());
    unawaited(refreshUsageLimit());
    try {
      final raw = await storage.read(key);
      if (closed ||
          context?.scope != next.scope ||
          localTicket != dismissRevision) {
        return;
      }
      final parsed = raw == null ? null : jsonDecode(raw);
      if (parsed is List) {
        dismissed.addAll(
          parsed
              .whereType<String>()
              .where(validFingerprint)
              .toList()
              .reversed
              .take(100),
        );
        _publish();
      }
    } catch (_) {
      // Device storage is optional and cannot grant projection authority.
    }
  }

  Future<void> refresh() async {
    final c = context;
    if (closed || c?.server == null) return;
    final current = c!;
    final ticket = ++revision, readTicket = feedbackRevision;
    loading = true;
    failed = false;
    Future<dynamic> safeRead(String path, {Map<String, dynamic>? query}) async {
      try {
        return await get(path, query: query);
      } catch (_) {
        return null;
      }
    }

    final shared = entities;
    if (shared != null) {
      final feedback = await safeRead(
        '/product-feedback/tickets',
        query: {'limit': 1},
      );
      if (!accepts(current.scope, ticket)) return;
      final unread = feedback is Map ? feedback['unread_total'] : null;
      final valid = unread is int && unread >= 0 && unread <= 9007199254740991;
      if (valid && readTicket == feedbackRevision) feedbackUnread = unread;
      failed = !shared().ready || !valid;
      loading = false;
      _publish();
      return;
    }
    final results = await Future.wait([
      if (current.canViewMachines)
        safeRead('/servers/${current.server!['id']}/machines')
      else
        Future.value(const []),
      if (current.canViewMachines && current.canViewAgents)
        safeRead('/agents')
      else
        Future.value(const []),
      safeRead('/product-feedback/tickets', query: {'limit': 1}),
    ]);
    if (!accepts(current.scope, ticket)) return;
    final machineResult = results[0];
    final machineRows = _rows(
          machineResult is Map ? machineResult['machines'] : machineResult,
        ),
        agentRows = _rows(results[1]);
    _machineReady = machineRows != null && agentRows != null;
    _machines = machineRows == null
        ? []
        : [
            for (final raw in machineRows)
              {
                for (final key in [
                  'id',
                  'name',
                  'status',
                  'isComputer',
                  'computerUpgradeAvailable',
                  'computerAttachedByCurrentUser',
                ])
                  if (raw.containsKey(key)) key: raw[key],
                if (raw['computerBroadcastPolicy'] is Map)
                  'computerBroadcastPolicy': {
                    for (final key in ['policyRevision', 'targetVersion'])
                      key: raw['computerBroadcastPolicy'][key],
                  },
                if (raw['diskStatus'] is Map)
                  'diskStatus': {
                    for (final key in ['availableBytes', 'totalBytes'])
                      key: raw['diskStatus'][key],
                  },
              },
          ];
    _agents = agentRows == null
        ? []
        : [
            for (final raw in agentRows)
              {
                for (final key in ['id', 'machineId', 'status', 'deletedAt'])
                  if (raw.containsKey(key)) key: raw[key],
              },
          ];
    final feedback = results[2];
    if (readTicket == feedbackRevision) {
      final count = feedback is Map ? feedback['unread_total'] : null;
      if (count is int && count >= 0 && count <= 9007199254740991) {
        feedbackUnread = count;
      }
    }
    final unread = feedback is Map ? feedback['unread_total'] : null;
    failed =
        !_machineReady ||
        unread is! int ||
        unread < 0 ||
        unread > 9007199254740991;
    loading = false;
    _publish();
  }

  bool _acceptsUsage(String scope, int ticket) =>
      !closed && context?.scope == scope && ticket == _usageRevision;

  void _setUsage(UsageLimitSnapshot? next) {
    _usage = next;
    _publish();
  }

  /// Reads the replace-snapshot of usage-limit attention. Like Web
  /// `useUsageLimitAttention`: a flag that is off or unresolved, or a failed
  /// read, clears the feed (a stale card never outlives the authority), and a
  /// snapshot with another contract version is ignored.
  Future<void> refreshUsageLimit() async {
    final c = context, gate = usageLimitGate;
    if (closed || c?.server == null || gate == null || post == null) return;
    final scope = c!.scope, ticket = ++_usageRevision;
    final serverId = c.server!['id'];
    try {
      _usageGate ??= await gate();
      if (!_acceptsUsage(scope, ticket)) return;
      if (_usageGate != true) {
        _setUsage(null);
        return;
      }
      final raw = await get('/servers/$serverId/system-notifications-v2');
      if (!_acceptsUsage(scope, ticket)) return;
      final next = parseUsageLimitSnapshot(raw);
      if (next != null) _setUsage(next);
    } catch (_) {
      if (_acceptsUsage(scope, ticket)) _setUsage(null);
    }
  }

  Future<bool> _receipt(String scope, String incidentId, String action) async {
    final c = context, send = post;
    if (closed || send == null || c?.scope != scope || c?.server == null) {
      return false;
    }
    if (!(_usage?.incidents.any((i) => i.id == incidentId) ?? false)) {
      return false;
    }
    try {
      await send(
        '/servers/${c!.server!['id']}/system-notifications-v2/$incidentId/$action',
      );
    } catch (_) {
      return false;
    }
    if (closed || context?.scope != scope) return false;
    // A read that started before this receipt would restore the old state.
    ++_usageRevision;
    return true;
  }

  /// Marks one incident seen on the server, then locally. A failed write
  /// leaves it unread so the next opening retries.
  Future<void> markUsageLimitSeen(String scope, String incidentId) async {
    if (!await _receipt(scope, incidentId, 'seen')) return;
    final now = clock().toUtc().toIso8601String();
    _setUsage(_usage?.markSeen(incidentId, now));
  }

  /// Marks every unread server-backed entry seen: the notification center
  /// opened (Web `NotificationTrigger.handleOpenChange` -> `onSeen`).
  Future<void> markUsageLimitsSeen(String scope) => Future.wait([
    for (final i in _usage?.incidents ?? const <UsageLimitIncident>[])
      if (!i.seen) markUsageLimitSeen(scope, i.id),
  ]);

  Future<void> dismissUsageLimit(String scope, String incidentId) async {
    if (!await _receipt(scope, incidentId, 'dismiss')) return;
    _setUsage(_usage?.without(incidentId));
  }

  static List<Map>? _rows(dynamic value) =>
      value is List && value.every((row) => row is Map)
      ? value.cast<Map>()
      : null;

  static bool validFingerprint(String value) =>
      value.length <= 4096 &&
      RegExp(
        r'^(plan-downgrade|joint-over-limit|computer-attention|machine-offline|machine-disk-low):[a-zA-Z0-9_:.,+=\-]+$',
      ).hasMatch(value);

  bool reconcileFeedback(String scope, int unread) {
    if (closed ||
        context?.scope != scope ||
        unread < 0 ||
        unread > 9007199254740991) {
      return false;
    }
    ++feedbackRevision;
    feedbackUnread = unread;
    _publish();
    return true;
  }

  bool dismiss(String scope, String fingerprint) {
    final c = context;
    if (closed ||
        c?.scope != scope ||
        c?.storageKey == null ||
        fingerprint.length > 4096) {
      return false;
    }
    if (!entries.any((entry) => entry.fingerprint == fingerprint)) return false;
    ++dismissRevision;
    dismissed.add(fingerprint);
    final key = c!.storageKey!;
    final encoded = jsonEncode(
      dismissed.toList().reversed.take(100).toList().reversed.toList(),
    );
    writes = writes.then((_) async {
      try {
        await storage.write(key, encoded);
      } catch (_) {
        /* accepted memory choice remains */
      }
    });
    _publish();
    return true;
  }

  @override
  void dispose() {
    closed = true;
    ++revision;
    ++_usageRevision;
    ++dismissRevision;
    super.dispose();
  }
}
