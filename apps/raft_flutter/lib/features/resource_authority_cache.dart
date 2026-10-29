import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

/// The principal, server, role and page owning an accepted projection.
typedef ResourceAuthorityIdentity = ({
  String origin,
  int generation,
  String? principal,
  String? clientServer,
  String? server,
  String? role,
  String section,
  String? channel,
});

/// Memoizes an accepted page's directory facts.
///
/// Workspace notifications check record identity once; building each visible
/// row only reads the cached token.
class ResourceAuthorityCache {
  static const _accessKeys = [
    'isPrivate',
    'visibility',
    'accessLevel',
    'membership',
    'capabilities',
    'channelCapabilities',
    'guestAccessEnabled',
    'readOnlyReason',
    'parentChannelId',
    'serverId',
    'role',
  ];

  List<RaftChannel>? _channelSource, _dmSource;
  List<RaftChannel> _records = [];
  Map<String, List<RaftChannel>> _recordsById = {};
  List<({String wire, Map<String, dynamic> value})> _factsByRecord = [];
  Map<String, Map<String, dynamic>> _access = const {};
  List<Map<String, dynamic>> _orderedFacts = const [];

  /// The accepted access facts, isolated from mutable wire maps.
  Map<String, Map<String, dynamic>> get access => _access;
  String? _directory, _value;
  ResourceAuthorityIdentity? _identity;
  int? _revision;

  /// Mute is a current display preference, not part of the permission token.
  /// Reuse the directory index, while reading the record's current preference.
  bool activityMuted(
    Map<String, dynamic> row, {
    required List<RaftChannel> channels,
    required List<RaftChannel> dms,
  }) {
    if (!identical(channels, _channelSource) || !identical(dms, _dmSource)) {
      synchronize(channels, dms);
    }
    final id = row['kind'] == 'thread'
        ? row['parentChannelId']
        : row['channelId'];
    return _recordsById[id]?.any((c) => c.json['activityMuted'] == true) ??
        false;
  }

  static Map<String, dynamic> _facts(RaftChannel channel) => {
    'id': channel.id,
    'type': channel.type,
    'joined': channel.joined,
    'archived': channel.archived,
    for (final key in _accessKeys)
      if (channel.json.containsKey(key)) key: channel.json[key],
  };

  /// Checks workspace directory changes, including in-place list changes.
  ///
  /// An authoritative permission event forces fresh facts even when an adapter
  /// retained a channel record while changing a nested capability map.
  void synchronize(
    List<RaftChannel> channels,
    List<RaftChannel> dms, {
    bool force = false,
  }) {
    _channelSource = channels;
    _dmSource = dms;
    final records = [...channels, ...dms];
    if (_directory != null && !force && listEquals(_records, records)) return;
    _recordsById = {};
    for (final record in records) {
      (_recordsById[record.id] ??= []).add(record);
    }
    final facts = <({String wire, Map<String, dynamic> value})>[];
    var changed = records.length != _records.length;
    for (var i = 0; i < records.length; i++) {
      final previous = i < _factsByRecord.length ? _factsByRecord[i] : null;
      if (!force && i < _records.length && identical(_records[i], records[i])) {
        facts.add(previous!);
        continue;
      }
      final wire = jsonEncode(_facts(records[i]));
      if (previous?.wire == wire) {
        facts.add(previous!);
      } else {
        changed = true;
        facts.add((
          wire: wire,
          value: Map<String, dynamic>.unmodifiable(jsonDecode(wire) as Map),
        ));
      }
    }
    _records = records;
    _factsByRecord = facts;
    // New-message/unread updates replace channel records too. Keep their
    // unchanged access snapshots without cloning or serializing the directory.
    if (_directory != null && !changed) return;
    final owned = [for (final fact in facts) fact.value];
    final ordered = [...owned]
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final directory = jsonEncode(ordered);
    if (_directory == directory) return;
    _directory = directory;
    _orderedFacts = ordered;
    // Preserve the directory's channel-then-DM collision rule independently
    // from the sorted token, and retain the previous facts across revocation.
    _access = Map.unmodifiable({
      for (final row in owned) row['id'] as String: row,
    });
    _value = null;
  }

  /// Returns the complete token for [identity] and the accepted access facts.
  String read({
    required ResourceAuthorityIdentity identity,
    required int revision,
    required List<RaftChannel> channels,
    required List<RaftChannel> dms,
  }) {
    if (_directory == null ||
        !identical(_channelSource, channels) ||
        !identical(_dmSource, dms)) {
      synchronize(channels, dms);
    }
    if (_value == null || _identity != identity || _revision != revision) {
      _identity = identity;
      _revision = revision;
      // Keep the previous token's wire shape: cached projections and pending
      // requests still compare the complete principal, page and access facts.
      _value = jsonEncode([
        identity.origin,
        identity.generation,
        identity.principal,
        identity.clientServer,
        identity.server,
        identity.role,
        identity.section,
        identity.channel,
        revision,
        ..._orderedFacts,
      ]);
    }
    return _value!;
  }
}
