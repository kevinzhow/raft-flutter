import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'search_memory.dart';
import 'system_notification_projection.dart';

typedef SystemNotificationGet = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});

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

/// Authenticated projections in memory. Persistent data is limited to the last
/// 100 dismissal fingerprints, never server copy, credentials or machine rows.
class SystemNotificationStore extends ChangeNotifier {
  SystemNotificationStore({
    required this.get,
    SearchMemoryStorage? storage,
    DateTime Function()? clock,
  }) : storage = storage ?? PreferencesSearchMemoryStorage(),
       clock = clock ?? DateTime.now;
  final SystemNotificationGet get;
  final SearchMemoryStorage storage;
  final DateTime Function() clock;
  SystemNotificationContext? context;
  final dismissed = <String>{};
  List<Map<String, dynamic>> machines = [], agents = [];
  int feedbackUnread = 0;
  bool machineReady = false, loading = false, failed = false, closed = false;
  int revision = 0, dismissRevision = 0, feedbackRevision = 0;
  Future<void> writes = Future.value();
  bool accepts(String scope, int ticket) =>
      !closed && context?.scope == scope && ticket == revision;
  List<SystemNotice> get entries {
    final c = context;
    if (c == null) return const [];
    return projectSystemNotifications(
          server: c.server,
          channels: c.channels,
          machines: machines,
          agents: agents,
          machinesReady: machineReady,
          canViewMachines: c.canViewMachines,
          mobile: c.mobile,
          feedbackUnread: feedbackUnread,
          now: clock(),
        )
        .where(
          (n) => n.fingerprint == null || !dismissed.contains(n.fingerprint),
        )
        .toList(growable: false);
  }

  Future<void> bind(SystemNotificationContext next) async {
    if (closed) return;
    final changed = next.scope != context?.scope;
    context = next;
    if (!changed) {
      notifyListeners();
      return;
    }
    ++revision;
    ++feedbackRevision;
    final localTicket = ++dismissRevision;
    machines = [];
    agents = [];
    machineReady = false;
    feedbackUnread = 0;
    failed = false;
    loading = false;
    dismissed.clear();
    notifyListeners();
    final key = next.storageKey;
    if (key == null) return;
    unawaited(refresh());
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
        notifyListeners();
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
    notifyListeners();
    Future<dynamic> safeRead(String path, {Map<String, dynamic>? query}) async {
      try {
        return await get(path, query: query);
      } catch (_) {
        return null;
      }
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
    machineReady = machineRows != null && agentRows != null;
    machines = machineRows == null
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
    agents = agentRows == null
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
        !machineReady ||
        unread is! int ||
        unread < 0 ||
        unread > 9007199254740991;
    loading = false;
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    closed = true;
    ++revision;
    ++dismissRevision;
    super.dispose();
  }
}
