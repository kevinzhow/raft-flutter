// The Computers attention dot (Web v1.24 utils/computerAttentionSeen.ts,
// hooks/useComputerAttentionDot.ts; raft-design #620 "Attention dots"): it
// marks a change you have not seen, not a lasting state.
//
// A "seen" set of (computerId, attentionState) pairs per user and server,
// kept on this device: the dot is lit while a current pair is unseen;
// opening the Computers page marks every current pair seen; a pair that is no
// longer current is dropped (only on a loaded list), so a computer that comes
// back online and later goes offline again lights the dot again. Seeing only
// hides the dot; the page's rows and counts never read this.
import 'dart:convert';

import '../../data/device_preferences.dart';
import '../../data/workspace_controller.dart';
import '../../data/workspace_entity_directory.dart';
import 'computers_rack_model.dart';

const _pairSeparator = '\u0000';

/// Every (id, state) pair the machines are in now, sorted.
List<String> computerAttentionPairs(Iterable<RackMachine> machines) {
  final pairs = <String>[];
  for (final m in machines) {
    final id = m['id'];
    if (id is! String) continue;
    // #68: the server's summary, when sent, is the one attention state.
    final needs = serverNeedsAttention(m);
    if (needs != null) {
      if (needs) pairs.add('$id${_pairSeparator}attention');
      continue;
    }
    if (m['isComputer'] == true && m['computerUpgradeAvailable'] == true) {
      pairs.add('$id${_pairSeparator}upgrade');
    }
    if (m['status'] == 'offline') pairs.add('$id${_pairSeparator}offline');
  }
  return pairs..sort();
}

String computerAttentionSeenStorageKey(String userId, String serverId) =>
    'slock:computers-attention:seen:$userId:$serverId';

/// Best effort: a storage failure falls to "unseen" (a dot that reappears),
/// never to a dot that cannot show.
List<String> readComputerAttentionSeen(String key) {
  final raw = DevicePreferences.current?.getString(key);
  if (raw == null) return const [];
  try {
    final value = jsonDecode(raw);
    return value is List
        ? [
            for (final p in value)
              if (p is String) p,
          ]
        : const [];
  } catch (_) {
    return const [];
  }
}

void writeComputerAttentionSeen(String key, List<String> pairs) {
  final prefs = DevicePreferences.current;
  if (prefs == null) return;
  if (pairs.isEmpty) {
    prefs.remove(key);
  } else {
    prefs.setString(key, jsonEncode(pairs));
  }
}

/// In-memory mirror of the kept sets, so a session without preferences
/// (tests, a failed load) still hides the dot once seen.
final _seenByKey = <String, List<String>>{};

List<String> _seen(String key) =>
    _seenByKey[key] ?? readComputerAttentionSeen(key);

void _setSeen(String key, List<String> pairs) {
  _seenByKey[key] = pairs;
  writeComputerAttentionSeen(key, pairs);
}

bool _same(List<String> a, List<String> b) =>
    a.length == b.length && b.every(a.toSet().contains);

/// Whether the Computers dot is lit for [userId] on [serverId]. Guests
/// cannot open Computers: never lit. On a [loaded] list, seen pairs that are
/// no longer current are forgotten first.
bool computerAttentionDot({
  required String? userId,
  required String? serverId,
  required bool guest,
  required bool loaded,
  required Iterable<RackMachine> machines,
}) {
  if (guest || userId == null || serverId == null) return false;
  final key = computerAttentionSeenStorageKey(userId, serverId);
  final current = computerAttentionPairs(machines);
  var seen = _seen(key);
  if (loaded) {
    final pruned = [
      for (final p in seen)
        if (current.contains(p)) p,
    ];
    if (pruned.length != seen.length) _setSeen(key, seen = pruned);
  }
  if (current.isEmpty) return false;
  final seenSet = seen.toSet();
  return current.any((p) => !seenSet.contains(p));
}

/// The Computers page is open: every current pair counts as seen.
void markComputerAttentionSeen({
  required String? userId,
  required String? serverId,
  required bool guest,
  required bool loaded,
  required Iterable<RackMachine> machines,
}) {
  if (guest || !loaded || userId == null || serverId == null) return;
  final key = computerAttentionSeenStorageKey(userId, serverId);
  final next = computerAttentionPairs(machines);
  if (_same(_seen(key), next)) return;
  _setSeen(key, next);
}

/// The rail's (and the phone server tab's) Computers dot for [w]'s viewer
/// on its server, from the entity directory's computers.
bool computerAttentionDotFor(WorkspaceController w) {
  final directory = w.services.entityDirectory;
  return computerAttentionDot(
    userId: w.client.user?.id,
    serverId: w.server?.id,
    guest: w.server?.string('role') == 'guest',
    loaded:
        directory.state(WorkspaceEntityKind.computers).loaded &&
        directory.settled(WorkspaceEntityKind.computers),
    machines: directory.rows(WorkspaceEntityKind.computers),
  );
}

/// Opening Computers from the phone's server tab sees every current attention
/// pair (the Fleet page has no rack to do it on mount).
void markComputerAttentionSeenFor(WorkspaceController w) {
  final directory = w.services.entityDirectory;
  markComputerAttentionSeen(
    userId: w.client.user?.id,
    serverId: w.server?.id,
    guest: w.server?.string('role') == 'guest',
    loaded:
        directory.state(WorkspaceEntityKind.computers).loaded &&
        directory.settled(WorkspaceEntityKind.computers),
    machines: directory.rows(WorkspaceEntityKind.computers),
  );
}

/// How many of the server's computers are in an attention state, and how many
/// there are (the dot's name: "{count} of {total} needs attention").
({int count, int total}) computerAttentionCounts(WorkspaceController w) {
  final machines = w.services.entityDirectory
      .rows(WorkspaceEntityKind.computers)
      .toList();
  final ids = {
    for (final pair in computerAttentionPairs(machines))
      pair.split(_pairSeparator).first,
  };
  return (count: ids.length, total: machines.length);
}
