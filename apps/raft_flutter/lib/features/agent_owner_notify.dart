// Notify owner to move it, for other people's agents on the person's
// Computers (Web v1.24 features/computer/othersAgentsApi.ts,
// useAgentOwnerNotify.ts, AgentOwnerNotifyActions.tsx). Deleting one Computer
// (computer_delete_dialog.dart) and Delete Account both ask owners to move
// their agents through a notify-agent-owners route; this is the piece they
// share: the wire shapes, what one screen learned from its own calls, and
// the actions drawn under each agent.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import 'resource_cards.dart' show resourceRelativeTime;

/// Who created another member's agent; null when no person did.
typedef AgentOwner = ({String id, String name})?;

/// The owner fields every list of other people's agents carries.
class OthersAgent {
  const OthersAgent({
    required this.id,
    required this.name,
    required this.owner,
    this.ownerNotifiedAt,
    this.ownerNextNotifyAt,
    this.personalAssistant = false,
  });

  final String id, name;
  final AgentOwner owner;

  /// When Raft last reminded that owner to move it.
  final String? ownerNotifiedAt;

  /// When the next reminder is allowed (once a day, shared with Delete
  /// Account); null: it can go now.
  final String? ownerNextNotifyAt;

  /// Its owner's personal assistant: only the owner can move it.
  final bool personalAssistant;

  /// One wire entry; null without a string `id`.
  static OthersAgent? fromJson(Object? entry) {
    if (entry is! Map || entry['id'] is! String) return null;
    final id = entry['id'] as String;
    final owner = entry['owner'];
    return OthersAgent(
      id: id,
      name: entry['name'] is String ? entry['name'] as String : id,
      owner: owner is Map && owner['id'] is String
          ? (
              id: owner['id'] as String,
              name: owner['name'] is String && (owner['name'] as String).isNotEmpty
                  ? owner['name'] as String
                  : owner['id'] as String,
            )
          : null,
      ownerNotifiedAt: _timeOf(entry['ownerNotifiedAt']),
      ownerNextNotifyAt: _timeOf(entry['ownerNextNotifyAt']),
      personalAssistant: entry['personalAssistant'] == true,
    );
  }
}

String? _timeOf(Object? value) =>
    value is String && value.isNotEmpty && DateTime.tryParse(value) != null
    ? value
    : null;

/// Why the server didn't remind an agent's owner. `not_delivered`: the
/// message couldn't be sent; it doesn't count against the daily limit.
const _skipReasons = {
  'rate_limited',
  'not_on_your_computer',
  'no_owner',
  'not_delivered',
};

typedef NotifyAgentOwnersResult = ({
  List<({String agentId, String notifiedAt})> notified,
  List<({String agentId, String reason, String? nextAllowedAt})> skipped,
});

/// The most ids one call may carry (more answers 400 `invalid_agent_ids`).
const notifyAgentIdsMax = 200;

NotifyAgentOwnersResult _resultOf(Object? data) {
  final map = data is Map ? data : const {};
  return (
    notified: [
      if (map['notified'] is List)
        for (final e in (map['notified'] as List).whereType<Map>())
          if (e['agentId'] is String && _timeOf(e['notifiedAt']) != null)
            (
              agentId: e['agentId'] as String,
              notifiedAt: _timeOf(e['notifiedAt'])!,
            ),
    ],
    skipped: [
      if (map['skipped'] is List)
        for (final e in (map['skipped'] as List).whereType<Map>())
          if (e['agentId'] is String && _skipReasons.contains(e['reason']))
            (
              agentId: e['agentId'] as String,
              reason: e['reason'] as String,
              nextAllowedAt: _timeOf(e['nextAllowedAt']),
            ),
    ],
  );
}

/// POST `{agentIds}` to a notify-agent-owners route: Raft sends each agent's
/// owner a system message asking them to move it (once per agent per 24
/// hours). Never sends an empty list or more than 200 ids; more go in
/// batches. Any refusal throws.
Future<NotifyAgentOwnersResult> postNotifyAgentOwners(
  Future<dynamic> Function(String method, String path, {dynamic data}) command,
  String path,
  List<String> agentIds,
) async {
  final ids = {
    for (final id in agentIds)
      if (id.isNotEmpty) id,
  }.toList();
  final notified = <({String agentId, String notifiedAt})>[];
  final skipped = <({String agentId, String reason, String? nextAllowedAt})>[];
  for (var start = 0; start < ids.length; start += notifyAgentIdsMax) {
    final end = start + notifyAgentIdsMax;
    final batch = _resultOf(
      await command(
        'POST',
        path,
        data: {'agentIds': ids.sublist(start, end > ids.length ? ids.length : end)},
      ),
    );
    notified.addAll(batch.notified);
    skipped.addAll(batch.skipped);
  }
  return (notified: notified, skipped: skipped);
}

/// What one screen learned from its own notify calls, ahead of the server's
/// next list (useAgentOwnerNotify.ts).
///
/// A plain [Listenable]: it lives as long as the Delete Computer flow that
/// owns it and has nothing to release but its listeners.
class AgentOwnerNotifier implements Listenable {
  AgentOwnerNotifier({required this.send, this.now = DateTime.now});

  /// The route's notify-agent-owners call.
  final Future<NotifyAgentOwnersResult> Function(List<String> agentIds) send;
  final DateTime Function() now;

  /// When Raft reminded the owner, from the POST's `notified`.
  final notifiedAt = <String, String>{};

  /// `rate_limited`: when the next reminder is allowed (null: not said).
  final nextAllowedAt = <String, String?>{};

  /// `no_owner`: nobody to notify after all.
  final ownerless = <String>{};

  /// A call in flight for these agents.
  final busy = <String>{};

  /// The call failed for these agents.
  final failed = <String>{};

  /// `not_delivered`: it can be tried again now.
  final undelivered = <String>{};
  bool _disposed = false;
  final _listeners = <VoidCallback>{};

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Calls the listeners of a copy, so one may remove itself.
  void notifyListeners() {
    for (final listener in _listeners.toList()) {
      if (_listeners.contains(listener)) listener();
    }
  }

  /// The agent's owner, unless a notify call found it has none.
  AgentOwner ownerNow(OthersAgent agent) =>
      ownerless.contains(agent.id) ? null : agent.owner;

  /// Still waiting out the once-a-day limit: the list's `ownerNextNotifyAt`,
  /// or this screen's own `rate_limited` answer (an unknown time waits until
  /// the screen is opened again). `at`: when the next one is allowed, if known.
  ({bool limited, String? at}) nextReminder(OthersAgent agent) {
    final time = now();
    if (nextAllowedAt.containsKey(agent.id)) {
      final at = nextAllowedAt[agent.id];
      if (at == null || DateTime.parse(at).isAfter(time)) {
        return (limited: true, at: at);
      }
    }
    final fromList = agent.ownerNextNotifyAt;
    if (fromList != null && DateTime.parse(fromList).isAfter(time)) {
      return (limited: true, at: fromList);
    }
    return (limited: false, at: null);
  }

  void notify(List<String> agentIds) {
    if (agentIds.isEmpty || _disposed) return;
    busy.addAll(agentIds);
    failed.removeAll(agentIds);
    undelivered.removeAll(agentIds);
    notifyListeners();
    unawaited(_run(agentIds));
  }

  Future<void> _run(List<String> agentIds) async {
    try {
      final result = await send(agentIds);
      if (_disposed) return;
      for (final e in result.notified) {
        notifiedAt[e.agentId] = e.notifiedAt;
        nextAllowedAt.remove(e.agentId);
      }
      for (final e in result.skipped) {
        switch (e.reason) {
          case 'rate_limited':
            nextAllowedAt[e.agentId] = e.nextAllowedAt;
          case 'no_owner':
            ownerless.add(e.agentId);
          case 'not_delivered':
            undelivered.add(e.agentId);
          // not_on_your_computer: it has left; the next list drops it.
        }
      }
      busy.removeAll(agentIds);
    } catch (error) {
      if (_disposed) return;
      logUserError(error, where: 'notify agent owners');
      busy.removeAll(agentIds);
      failed.addAll(agentIds);
    }
    notifyListeners();
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}

String _later(String? a, String? b) {
  if (a == null) return b ?? '';
  if (b == null) return a;
  return DateTime.parse(a).isAfter(DateTime.parse(b)) ? a : b;
}

/// Notify owner to move it / Remind again, under one agent; rebuilds with
/// [notifier]. [testIdPrefix]: the screen's key prefix (`computer-notify-<id>`).
class AgentOwnerNotifyActions extends StatelessWidget {
  const AgentOwnerNotifyActions({
    super.key,
    required this.agent,
    required this.notifier,
    required this.testIdPrefix,
  });
  final OthersAgent agent;
  final AgentOwnerNotifier notifier;
  final String testIdPrefix;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: notifier,
    builder: (context, _) {
      final owner = notifier.ownerNow(agent);
      final notified = _later(
        agent.ownerNotifiedAt,
        notifier.notifiedAt[agent.id],
      );
      final (:limited, at: nextAt) = notifier.nextReminder(agent);
      final chinese = Localizations.localeOf(context).languageCode == 'zh';
      String relative(String iso) => resourceRelativeTime(iso, chinese: chinese);
      final failed = notifier.failed.contains(agent.id);
      final undelivered = notifier.undelivered.contains(agent.id);
      return RaftAgentOwnerNotifyActions(
        agentId: agent.id,
        testIdPrefix: testIdPrefix,
        buttonLabel: raftText(
          context,
          notified.isNotEmpty && owner != null
              ? 'Remind again'
              : 'Notify owner to move it',
        ),
        busyLabel: raftText(context, 'Notifying…'),
        busy: notifier.busy.contains(agent.id),
        enabled: owner != null && !limited,
        notifiedLine: owner != null && notified.isNotEmpty
            ? raftFormat(context, 'Notified · {time}', {
                'time': relative(notified),
              })
            : null,
        reminderLine: owner != null && limited
            ? nextAt != null
                  ? raftFormat(context, 'You can remind again {time}', {
                      'time': relative(nextAt),
                    })
                  : raftText(context, 'You can remind once every 24 hours')
            : null,
        errorLine: failed || undelivered
            ? raftText(
                context,
                undelivered
                    ? "The reminder wasn't sent. Try again."
                    : "Couldn't notify the owner. Try again.",
              )
            : null,
        contactLine: raftText(
          context,
          agent.personalAssistant
              ? owner != null
                    ? "It's a personal assistant: only its owner can move it. A server admin can only stop it."
                    : "It's a personal assistant whose owner has left: a server admin can delete it."
              : owner != null
              ? "If the owner never does, contact this server's owner or an admin: they can delete it, or on Pro, move it to another computer."
              : "There's no owner to notify. Contact this server's owner or an admin: they can delete it, or on Pro, move it to another computer.",
        ),
        onNotify: () => notifier.notify([agent.id]),
      );
    },
  );
}
