import 'dart:async';
import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import 'user_error.dart';

/// Channel row I/O and request ordering for one workspace receiver.
///
/// Borrowed presentations keep their own single-row reads. The controller's
/// public entrypoints retain their existing source delegation and overrides;
/// this owner does not subscribe to events or own the shared client.
class ChannelRepository {
  ChannelRepository(
    this.client, {
    required this._channels,
    required this._dms,
    required this._generation,
    required this._identity,
    required this._isDisposed,
    required this._revokedChannels,
    required this._acceptLists,
    required this._reloadLists,
    required this._reloadRow,
    required this._revokeChannel,
    required this._closeDeniedThread,
    required this._changed,
    required this._setError,
    required this._quietFailure,
    this._saveDirectory,
    this._acceptSelection,
    this._patchSelected,
  });

  final RaftClient client;
  final List<RaftChannel> Function() _channels, _dms;
  final int Function() _generation;
  final String Function() _identity;
  final bool Function() _isDisposed;
  final Set<String> Function() _revokedChannels;
  final void Function(
    List<RaftChannel>,
    List<RaftChannel>, {
    required Set<String> readmit,
  })
  _acceptLists;
  final Future<void> Function() _reloadLists;
  final Future<void> Function(String) _reloadRow;
  final void Function(String) _revokeChannel, _closeDeniedThread, _setError;
  final void Function() _changed;
  final bool Function(Object) _quietFailure;

  // Production receiver projections read these same owned lists through the
  // existing read ports. The ports also preserve explicit external bindings.
  List<RaftChannel> channels = [], dms = [];
  final void Function(Map<String, dynamic>)? _saveDirectory;
  final void Function(Set<String>)? _acceptSelection;
  final void Function(RaftChannel Function(RaftChannel))? _patchSelected;

  /// Selection has always reset only row authority, leaving reads in flight.
  void resetRowAuthority() => _channelRowSeq.clear();

  /// A local row takes its authority before its existing projection changes.
  void recordRowWrite(String id) => _channelRowSeq[id] = ++_channelReadSeq;

  void putRow(RaftChannel row) => _putChannelRow(row);

  /// Read order of channel-row authority. Every list read, single-row read
  /// and realtime row patch takes the next value when it starts; a row keeps
  /// the value of whatever last wrote it. An older response therefore never
  /// overwrites a newer row, and never revokes a row added after it started.
  int _channelReadSeq = 0, _channelListSeq = 0;

  final Map<String, int> _channelRowSeq = {};

  final Map<String, Future<void>> _channelReads = {};

  final Set<String> _channelRereads = {};

  /// Full channel and DM list reload (Source `loadChannels` +
  /// `loadDMChannels`): server selection, `rooms:joined`, a role change, or a
  /// channel event without an id. Unchanged rows keep their objects.
  Future<void> refreshChannels() async {
    final generation = _generation();
    final read = ++_channelReadSeq;
    try {
      final lists = await Future.wait([
        client.channels(),
        client.channels(dm: true),
      ]);
      if (generation != _generation() || _isDisposed()) return;
      // A list read that started later has already been applied.
      if (read < _channelListSeq) return;
      _channelListSeq = read;
      // Rows written after this read started keep their current state.
      final newer = {
        for (final entry in _channelRowSeq.entries)
          if (entry.value > read) entry.key,
      };
      _channelRowSeq.removeWhere((_, seq) => seq <= read);
      List<RaftChannel> merge(
        List<RaftChannel> fetched,
        List<RaftChannel> current,
      ) {
        final held = {for (final c in current) c.id: c};
        final fetchedIds = {for (final c in fetched) c.id};
        final next = [
          for (final c in fetched)
            if (!newer.contains(c.id))
              _reuseChannelRow(held[c.id], c)
            else if (held[c.id] != null)
              held[c.id]!,
        ];
        // A row added after this read started keeps its held position.
        for (var i = 0; i < current.length; i++) {
          final c = current[i];
          if (newer.contains(c.id) && !fetchedIds.contains(c.id)) {
            next.insert(i < next.length ? i : next.length, c);
          }
        }
        return next;
      }

      _acceptLists(
        merge(lists[0], _channels()),
        merge(lists[1], _dms()),
        readmit: {
          for (final c in [...lists[0], ...lists[1]])
            if (!newer.contains(c.id)) c.id,
        },
      );
    } catch (e) {
      // A rate-limited background refresh is not an error to show: the held
      // lists stay, and the next refresh (after Retry-After) catches up.
      if (generation == _generation() && !_isDisposed() && !_quietFailure(e)) {
        _setError(userErrorText(e, where: 'refresh channels'));
      }
    }
  }

  /// A refreshed row equal to the held one keeps the held object, so sidebar
  /// rows and the open channel do not rebuild for an unchanged read.
  static RaftChannel _reuseChannelRow(RaftChannel? held, RaftChannel fresh) {
    if (held == null) return fresh;
    try {
      return jsonEncode(held.json) == jsonEncode(fresh.json) ? held : fresh;
    } catch (_) {
      return fresh;
    }
  }

  /// Whether the server's channel lists carry [row] for this viewer: private
  /// and joint channels only for members (`requiresExplicitMembership`).
  static bool _listsChannel(RaftChannel row) =>
      !const {'private', 'joint'}.contains(row.type) || row.joined;

  /// Replaces [next]'s row in place, or adds it (a new DM goes first, as the
  /// server's recency-ordered DM list would place it).
  void _putChannelRow(RaftChannel next) {
    final held = [..._channels(), ..._dms()].where((c) => c.id == next.id);
    if (held.length == 1 && identical(held.single, next)) return;
    final dm = next.type == 'dm';
    List<RaftChannel> put(List<RaftChannel> list, bool owns) {
      final index = list.indexWhere((c) => c.id == next.id);
      if (!owns) return index < 0 ? list : ([...list]..removeAt(index));
      if (index >= 0) return [...list]..[index] = next;
      return dm ? [next, ...list] : [...list, next];
    }

    _acceptLists(put(_channels(), !dm), put(_dms(), dm), readmit: {next.id});
  }

  static String? _payloadChannelId(dynamic payload) {
    if (payload is! Map) return null;
    final id = payload['channelId'] ?? payload['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Source `readApiChannel`: `{channel: row}` or a bare row with a name.
  static Map<String, dynamic>? _payloadChannelRow(dynamic payload) {
    if (payload is! Map) return null;
    final candidate = payload.containsKey('channel')
        ? payload['channel']
        : payload;
    if (candidate is! Map ||
        candidate['id'] is! String ||
        candidate['name'] is! String) {
      return null;
    }
    return Map<String, dynamic>.from(candidate);
  }

  /// Source channelRealtimeSync: a channel event changes one row. A carried
  /// row is patched in place; an id re-reads that one channel; only an event
  /// without an id reloads both lists.
  void consumeRealtime(String name, dynamic payload) {
    if (name == 'channel:updated') {
      final row = _payloadChannelRow(payload);
      if (row != null) {
        // A user-room event can carry another server's joint-channel row.
        final serverId = row['serverId'];
        if (serverId is String &&
            client.serverId != null &&
            serverId != client.serverId) {
          return;
        }
        _patchChannelRow(row);
        return;
      }
    }
    final id = _payloadChannelId(payload);
    if (id == null) {
      if (name != 'dm:new') unawaited(_reloadLists());
      return;
    }
    if (name == 'dm:new') {
      client.joinChannel(id);
      // Source addOrRefreshDM: a held DM moves first without a read.
      final index = _dms().indexWhere((c) => c.id == id);
      if (index >= 0 && !_revokedChannels().contains(id)) {
        if (index > 0) {
          _acceptLists(_channels(), [
            _dms()[index],
            for (var i = 0; i < _dms().length; i++)
              if (i != index) _dms()[i],
          ], readmit: const {});
        }
        return;
      }
    }
    unawaited(_reloadRow(id));
  }

  /// Web `patchChannel` `hiddenAllChannel`: an admin hiding `#all` turns it
  /// into a private channel named `all`, which leaves the list.
  static bool isHiddenAllChannelRow(Map<String, dynamic> row) =>
      row['name'] == 'all' && row['type'] == 'private';

  void _patchChannelRow(Map<String, dynamic> patch) {
    final id = patch['id'] as String;
    final held = [
      ..._channels(),
      ..._dms(),
    ].where((c) => c.id == id).firstOrNull;
    if (isHiddenAllChannelRow({...?held?.json, ...patch})) {
      _channelRowSeq[id] = ++_channelReadSeq;
      if (held != null) {
        _acceptLists(
          _channels().where((c) => c.id != id).toList(),
          _dms().where((c) => c.id != id).toList(),
          readmit: const {},
        );
      }
      return;
    }
    // A projection lacks viewer fields (membership, capabilities): an unknown
    // or revoked row is read once instead of trusted.
    if (held == null || _revokedChannels().contains(id)) {
      unawaited(_reloadRow(id));
      return;
    }
    final next = _reuseChannelRow(held, RaftChannel({...held.json, ...patch}));
    if (!_listsChannel(next) || next.type == 'thread') {
      unawaited(_reloadRow(id));
      return;
    }
    _channelRowSeq[id] = ++_channelReadSeq;
    _putChannelRow(next);
  }

  /// Source `ensureChannel(id, {refresh: true})`: reads one channel and
  /// upserts its row. Lost access (403/404, or a private row the lists would
  /// not carry) revokes that channel through the list revocation path.
  Future<void> refreshChannel(String id) {
    final pending = _channelReads[id];
    if (pending != null) {
      // The read in flight may predate this change: read once more after it.
      _channelRereads.add(id);
      return pending;
    }
    final read = _readChannel(id).whenComplete(() {
      _channelReads.remove(id);
      if (_channelRereads.remove(id) && !_isDisposed()) {
        unawaited(_reloadRow(id));
      }
    });
    return _channelReads[id] = read;
  }

  Future<void> _readChannel(String id) async {
    final generation = _generation(), identity = _identity();
    final read = ++_channelReadSeq;
    bool current() =>
        !_isDisposed() &&
        generation == _generation() &&
        identity == _identity() &&
        read > _channelListSeq &&
        read > (_channelRowSeq[id] ?? 0);
    RaftChannel? fresh;
    var lostAccess = false;
    try {
      final data = await client.get('/channels/$id');
      if (!current() || data is! Map || data['id'] != id) return;
      fresh = RaftChannel(Map<String, dynamic>.from(data));
      if (fresh.type == 'thread') return;
      final serverId = fresh.json['serverId'];
      if (serverId is String && serverId != client.serverId) fresh = null;
    } on RaftApiException catch (e) {
      if (!current() || (e.status != 403 && e.status != 404)) return;
      lostAccess = true;
    } catch (_) {
      // Transient failure: the held row stays until a later read.
      return;
    }
    _channelRowSeq[id] = read;
    final held = [
      ..._channels(),
      ..._dms(),
    ].where((c) => c.id == id).firstOrNull;
    if (fresh != null && _listsChannel(fresh)) {
      _putChannelRow(_reuseChannelRow(held, fresh));
    } else if (held != null) {
      _acceptLists(
        _channels().where((c) => c.id != id).toList(),
        _dms().where((c) => c.id != id).toList(),
        readmit: const {},
      );
    }
    // The server never emits `channel:removed`: this 403/404 is the way a lost
    // channel is noticed, so it runs that event's cleanup. A held row was
    // already revoked by the list update above.
    if (lostAccess) {
      if (held == null) _revokeChannel(id);
      _closeDeniedThread(id);
      if (held == null) _changed();
    }
  }

  /// Revoke missing rows before publishing; selection remains the UI's job.
  void acceptLists(
    List<RaftChannel> nextChannels,
    List<RaftChannel> nextDms, {
    required Set<String> readmit,
  }) {
    final accessible = {
      for (final c in [...nextChannels, ...nextDms]) c.id,
    };
    for (final old in [..._channels(), ..._dms()]) {
      if (!accessible.contains(old.id)) _revokeChannel(old.id);
    }
    _revokedChannels().removeAll(readmit);
    channels = nextChannels;
    dms = nextDms;
    _saveDirectory?.call({
      'channels': channels.map((c) => c.json).toList(),
      'dms': dms.map((c) => c.json).toList(),
    });
    _acceptSelection?.call(accessible);
    _changed();
  }

  /// The controller has already accepted this channel preference update.
  bool applyNotificationPrefs(Map<String, dynamic> accepted) {
    final state = accepted['state'] as Map;
    final id = accepted['channelId'];
    if (_revokedChannels().contains(id)) return false;
    RaftChannel patch(RaftChannel value) {
      if (value.id != id) return value;
      final old = value.json['prefsVersion'], incoming = state['prefsVersion'];
      if (old is int && incoming is int && incoming < old) return value;
      return RaftChannel({...value.json, ...state});
    }

    channels = channels.map(patch).toList();
    dms = dms.map(patch).toList();
    _patchSelected?.call(patch);
    return true;
  }

  /// Patch activity mute without changing its existing notification boundary.
  void setActivityMuteState(String id, Map<String, dynamic> state) {
    RaftChannel patch(RaftChannel value) =>
        value.id == id ? RaftChannel({...value.json, ...state}) : value;
    channels = channels.map(patch).toList();
    dms = dms.map(patch).toList();
    _patchSelected?.call(patch);
    _changed();
  }

  static ({String serverId, String channelId, bool collapse, int? version})?
  readMessageDisplayPrefsUpdate(dynamic payload) {
    if (payload is! Map) return null;
    final serverId = payload['serverId'], scopeId = payload['scopeId'];
    final prefs = payload['prefs'];
    if (serverId is! String || scopeId is! String || prefs is! Map) return null;
    final collapse = prefs['collapseLongMessages'];
    if (collapse is! bool) return null;
    final version = payload['prefsVersion'];
    return (
      serverId: serverId,
      channelId: scopeId,
      collapse: collapse,
      version: version is num ? version.toInt() : null,
    );
  }

  static RaftChannel applyMessageDisplayPrefsToChannel(
    RaftChannel value, {
    required bool collapse,
    int? version,
  }) {
    final prior = value.json['displayPrefsVersion'];
    if (prior is num && version != null && version < prior) return value;
    return RaftChannel({
      ...value.json,
      'collapseLongMessages': collapse,
      'displayPrefsVersion': ?version,
    });
  }

  void consumeMessageDisplayPrefs(dynamic payload) {
    final update = readMessageDisplayPrefsUpdate(payload);
    if (update == null ||
        (client.serverId != null && update.serverId != client.serverId) ||
        _revokedChannels().contains(update.channelId)) {
      return;
    }
    RaftChannel patch(RaftChannel value) => value.id != update.channelId
        ? value
        : applyMessageDisplayPrefsToChannel(
            value,
            collapse: update.collapse,
            version: update.version,
          );
    channels = channels.map(patch).toList();
    dms = dms.map(patch).toList();
    _patchSelected?.call(patch);
  }
}
