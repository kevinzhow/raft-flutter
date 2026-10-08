import 'dart:convert';

import 'core.dart';

const maxSafeInteger = 9007199254740991;
bool _safe(dynamic value) =>
    value is int && value >= 0 && value <= maxSafeInteger;
BigInt? canonicalUint64(dynamic value) {
  if (value is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value))
    return null;
  final n = BigInt.parse(value);
  return n <= (BigInt.one << 64) - BigInt.one ? n : null;
}

class ReadStateLedger {
  final Map<String, Map<String, dynamic>> _accepted = {};
  int generation = 0;
  final SyncCore core = SyncCore(
    domains: [
      SyncDomain(
        name: 'read_state',
        density: SyncDensity.sparse,
        initialState: () => null,
        fold: (_, event, _, _) => event,
        fromSnapshot: (s) => s.state,
        eventFingerprint: (e) => jsonEncode([
          e['serverId'],
          e['principalId'],
          e['scopeId'],
          e['maxReadSeq'],
          e['readStateVersion'],
        ]),
      ),
    ],
  );
  String key(String server, String principal, String scope) =>
      jsonEncode([server, principal, scope]);
  Map<String, dynamic>? state(String server, String principal, String scope) =>
      _accepted[key(server, principal, scope)];
  String consumeUpdate(
    dynamic payload, {
    required String serverId,
    required String principalId,
  }) {
    if (payload is! Map ||
        payload['serverId'] != serverId ||
        payload['scopeId'] is! String ||
        (payload['scopeId'] as String).isEmpty ||
        !_safe(payload['maxReadSeq']) ||
        !_safe(payload['readStateVersion']))
      return 'corrupt';
    final scope = payload['scopeId'] as String,
        id = key(serverId, principalId, scope);
    final old = _accepted[id];
    final fact = {
      'serverId': serverId,
      'principalId': principalId,
      'scopeId': scope,
      'maxReadSeq': payload['maxReadSeq'],
      'readStateVersion': payload['readStateVersion'],
    };
    core.ingestFrame(
      'read_state',
      SyncFrame(
        scopeId: id,
        seq: BigInt.from(payload['readStateVersion']),
        event: fact,
      ),
    );
    if (old != null && payload['readStateVersion'] <= old['readStateVersion'])
      return 'stale';
    _accepted[id] = {...fact, 'generation': ++generation};
    return 'accepted';
  }

  String consumeSnapshot(
    dynamic frontier, {
    required String serverId,
    required String principalId,
    required String scopeId,
    required int generationAtRequest,
    bool authoritativeAbsence = true,
  }) {
    final id = key(serverId, principalId, scopeId),
        old = _accepted[key(serverId, principalId, scopeId)];
    if (frontier is! Map || frontier['kind'] == 'corrupt') return 'corrupt';
    final superseded =
        old != null && (old['generation'] as int) > generationAtRequest;
    if (frontier['kind'] == 'absent') {
      if (superseded || old != null && !authoritativeAbsence) return 'stale';
      _accepted.remove(id);
      core.revokeScope('read_state', id);
      return 'cleared';
    }
    if (frontier['kind'] != 'present' || !_safe(frontier['readStateVersion']))
      return 'corrupt';
    final seq = canonicalUint64(frontier['maxReadSeq']);
    if (seq == null || seq > BigInt.from(maxSafeInteger)) return 'corrupt';
    if (superseded ||
        old != null && frontier['readStateVersion'] <= old['readStateVersion'])
      return 'stale';
    return consumeUpdate(
      {
        'serverId': serverId,
        'scopeId': scopeId,
        'maxReadSeq': seq.toInt(),
        'readStateVersion': frontier['readStateVersion'],
      },
      serverId: serverId,
      principalId: principalId,
    );
  }

  List<Map<String, dynamic>> exportFor(String server, String principal) => [
    for (final fact in _accepted.values)
      if (fact['serverId'] == server && fact['principalId'] == principal)
        {
          for (final key in [
            'serverId',
            'principalId',
            'scopeId',
            'maxReadSeq',
            'readStateVersion',
          ])
            key: fact[key],
        },
  ];

  void restore(
    dynamic rows, {
    required String serverId,
    required String principalId,
  }) {
    if (rows is! List) return;
    for (final fact in rows) {
      if (fact is Map &&
          fact['serverId'] == serverId &&
          fact['principalId'] == principalId) {
        consumeUpdate(fact, serverId: serverId, principalId: principalId);
      }
    }
  }

  void revoke(String server, String principal, String scope) {
    final id = key(server, principal, scope);
    _accepted.remove(id);
    core.revokeScope('read_state', id);
    generation++;
  }

  void reset() {
    for (final id in _accepted.keys) {
      core.revokeScope('read_state', id);
    }
    _accepted.clear();
    generation++;
  }
}
