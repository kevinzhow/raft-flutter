import 'dart:async';

import 'package:raft_client/raft_client.dart';

/// Sidebar order I/O, request fencing and serialized section updates.
///
/// The source workspace owns this repository and shares it with borrowed pages.
/// Its existing order projection stays on the controller during migration;
/// callbacks preserve direct field assignments and presentation-local defaults.
/// Reloads use the controller's public entrypoint so overrides still apply.
class SidebarRepository {
  SidebarRepository(
    this.client, {
    required this._order,
    required this._setOrder,
    required this._serverId,
    required this._loadAuthority,
    required this._isDisposed,
    required this._readDevice,
    required this._saveDevice,
    required this._changed,
    required this._reload,
  });

  final RaftClient client;
  final Map<String, dynamic> Function() _order;
  final void Function(Map<String, dynamic>) _setOrder;
  final String? Function() _serverId;
  final String Function() _loadAuthority;
  final bool Function() _isDisposed;
  final Future<dynamic> Function() _readDevice;
  final Future<void> Function(Map<String, dynamic>) _saveDevice;
  final void Function() _changed;
  final Future<void> Function() _reload;

  int _request = 0;
  int _sectionSeq = 0, _sectionsInFlight = 0;
  Future<void> _sectionTail = Future.value();
  num? _confirmedVersion;

  static const _sectionFields = {
    'customSections',
    'sectionOrder',
    'sectionPlacements',
  };

  Future<void> load() async {
    final request = ++_request;
    final generation = client.generation, id = client.serverId;
    final authority = _loadAuthority();
    bool accepts() =>
        !_isDisposed() &&
        request == _request &&
        generation == client.generation &&
        id == client.serverId &&
        authority == _loadAuthority();
    if (id == null) return;
    final cached = await _readDevice();
    if (!accepts()) return;
    if (cached is Map) {
      _setOrder(Map<String, dynamic>.from(cached));
      _changed();
    }
    try {
      final value = await client.get('/servers/$id/sidebar-order');
      if (!accepts()) return;
      _setOrder(Map<String, dynamic>.from(value));
      _saveDevice(_order());
      _changed();
    } catch (_) {
      /* Cached order remains usable while offline. */
    }
  }

  /// Publish optimistically, then serialize versioned section writes.
  /// A failed current write restores its previous projection; conflicts reload.
  Future<void> update(Map<String, dynamic> updates) async {
    final id = _serverId() ?? client.serverId;
    if (id == null || _isDisposed()) return;
    final generation = client.generation;
    final previous = _order();
    final next = {...previous, ...updates};
    final sections = updates.keys.any(_sectionFields.contains);
    _setOrder(next);
    _saveDevice(next);
    _changed();
    bool current() =>
        !_isDisposed() &&
        (_serverId() ?? client.serverId) == id &&
        client.generation == generation;

    Future<void> perform(int sequence, num? version, bool queued) async {
      if (!current()) return;
      try {
        final value = await client.request(
          'PATCH',
          '/servers/$id/sidebar-order',
          data: sections ? {...updates, 'sectionsVersion': ?version} : updates,
        );
        if (!current()) return;
        final reply = value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{};
        if (queued) _confirmedVersion = reply['sectionsVersion'] as num?;
        if (queued && sequence != _sectionSeq) {
          // Keep the newer queued write's optimistic order; adopt versions.
          _setOrder({
            ..._order(),
            if (reply['sectionsVersion'] != null)
              'sectionsVersion': reply['sectionsVersion'],
            if (reply['pinnedVersion'] != null)
              'pinnedVersion': reply['pinnedVersion'],
          });
        } else {
          _setOrder({...next, ...reply});
        }
        _saveDevice(_order());
        _changed();
      } catch (error) {
        if (!current()) return;
        if (!queued || sequence == _sectionSeq) {
          _setOrder(previous);
          _saveDevice(previous);
          _changed();
        }
        if (error is RaftApiException && error.status == 409) {
          unawaited(_reload());
        }
      }
    }

    if (!sections) return perform(0, null, false);
    final sequence = ++_sectionSeq;
    _confirmedVersion ??= previous['sectionsVersion'] as num?;
    // An idle queue sends immediately; followers use its confirmed version.
    final run = _sectionsInFlight == 0
        ? perform(sequence, _confirmedVersion, true)
        : _sectionTail.then((_) => perform(sequence, _confirmedVersion, true));
    _sectionsInFlight++;
    _sectionTail = run;
    return run.whenComplete(() {
      if (--_sectionsInFlight == 0) _confirmedVersion = null;
    });
  }
}
