import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'workspace_cache.dart';
import 'history_capacity.dart';
import 'local_error_diagnostics.dart';
import 'workspace_cache_reads.dart';
import 'workspace_entity_directory.dart';

/// Serializes one workspace controller's device-cache operations.
///
/// Accepted writes retain their captured account/server identity. Retirement
/// stops new work and drains the existing queue before the app clears account
/// data. The app owns both [cache] and [client]; this service never closes them.
/// Presentation and authorization facts are supplied by the workspace, and
/// failures are reported back without owning UI notices.
class WorkspaceDeviceStore {
  WorkspaceDeviceStore(
    this.client, {
    this.cache,
    required this._isDisposed,
    required this._isChannelRevoked,
    required this._isServerRevoked,
    required this._historyTicket,
    required this._readFailed,
    required this._writeFailed,
    required this._purgeFailed,
  });

  final RaftClient client;
  final WorkspaceCache? cache;
  final bool Function() _isDisposed;
  final bool Function(Object?) _isChannelRevoked;
  final bool Function(String) _isServerRevoked;
  final Object Function(String) _historyTicket;
  final void Function() _readFailed, _purgeFailed;
  final void Function(String) _writeFailed;
  Future<void> _writes = Future<void>.value();
  bool _retired = false;

  Future<void> get settled => _writes;
  bool get writable => !_retired && !_isDisposed();

  Future<void> retire() {
    _retired = true;
    return _writes;
  }

  /// Device records of the server-scoped entity directory: kind `entities`,
  /// id = [WorkspaceEntityKind.name], under the scope's origin, principal and
  /// server (so logout, account and server revocation clear them with the
  /// rest of the account/server data). The directory checks role and
  /// capabilities before painting one.
  Future<dynamic> readEntities(
    WorkspaceEntityScope scope,
    WorkspaceEntityKind kind,
  ) async {
    final store = cache;
    if (store == null || _isDisposed() || _retired) return null;
    await _writes;
    if (_isDisposed() || _retired) return null;
    return store.read(
      scope.origin,
      scope.principal,
      scope.serverId,
      'entities',
      kind.name,
    );
  }

  void writeEntities(
    WorkspaceEntityScope scope,
    WorkspaceEntityKind kind,
    Map<String, dynamic>? record,
  ) {
    final store = cache;
    if (store == null ||
        _retired ||
        (record != null && _isServerRevoked(scope.serverId))) {
      return;
    }
    _writes = _writes.then((_) async {
      try {
        await store.write(
          scope.origin,
          scope.principal,
          scope.serverId,
          'entities',
          kind.name,
          record,
        );
      } catch (_) {
        // Best effort: the directory is revalidated on every start anyway.
      }
    });
  }

  /// Saved message translations of [serverId] under the current account
  /// (see [MessageTranslationStore.restore]); empty without a device cache.
  Future<List<Map<String, dynamic>>> readDeviceTranslations(
    String serverId,
  ) async {
    final store = cache, principal = client.user?.id;
    if (store == null || principal == null || _isDisposed() || _retired) {
      return const [];
    }
    final origin = client.origin;
    await _writes;
    if (_isDisposed() || _retired) return const [];
    try {
      return await store.readTranslations(origin, principal, serverId);
    } catch (_) {
      // Best effort: missing entries are requested again.
      return const [];
    }
  }

  /// Queues a device write of translation [entries] of [serverId] under the
  /// current account. Nothing is written once the cache is retired, for a
  /// revoked server, or for a channel revoked since the entry was made.
  void writeDeviceTranslations(
    String serverId,
    List<Map<String, dynamic>> entries,
  ) {
    final store = cache, principal = client.user?.id;
    if (store == null ||
        principal == null ||
        _retired ||
        _isServerRevoked(serverId)) {
      return;
    }
    final rows = [
      for (final entry in entries)
        if (client.serverId != serverId ||
            !_isChannelRevoked(entry['channelId']))
          entry,
    ];
    if (rows.isEmpty) return;
    final origin = client.origin;
    _writes = _writes.then((_) async {
      if (_retired) return;
      try {
        await store.writeTranslations(origin, principal, serverId, rows);
      } catch (_) {
        // Best effort: unsaved translations are requested again.
      }
    });
  }

  /// The server translation gate saved for [serverId] (kind
  /// `translation-settings`), or null.
  Future<dynamic> readTranslationGate(String serverId) => _retired
      ? Future.value()
      : read('translation-settings', '', server: serverId);

  /// Saves (or with null deletes) the translation gate of [serverId].
  void saveTranslationGate(String serverId, Map<String, dynamic>? gate) {
    if (gate != null && _isServerRevoked(serverId)) return;
    unawaited(write('translation-settings', '', gate, server: serverId));
  }

  Future<dynamic> read(String kind, String id, {String? server}) async {
    try {
      return await WorkspaceCacheReads.read(
        cache,
        client,
        _writes,
        kind,
        id,
        server: server,
        active: () => writable,
        authority: _historyTicket,
        visible: (id) => !_isChannelRevoked(id),
      );
    } catch (_) {
      _readFailed();
      return null;
    }
  }

  Future<void> write(
    String kind,
    String id,
    dynamic value, {
    String? server,
    bool requiredSuccess = false,
  }) async {
    final user = client.user?.id;
    if (cache == null || user == null || _retired) return;
    if (_isChannelRevoked(id) ||
        value is Map && _isChannelRevoked(value['channelId'])) {
      return;
    }
    final origin = client.origin, serverId = server ?? client.serverId ?? '';
    final windowScope =
        value is Map && const {'window', 'thread-window'}.contains(kind)
        ? '${value['parentChannelId'] ?? id}'
        : null;
    final windowTicket = windowScope == null
        ? null
        : _historyTicket(windowScope);
    final writing = _writes.then((_) async {
      if (windowScope != null &&
          (!writable || windowTicket != _historyTicket(windowScope))) {
        return;
      }
      try {
        await cache!.write(origin, user, serverId, kind, id, value);
      } catch (cause, trace) {
        if (cause is! HistoryCapacityExceeded) {
          _writeFailed(LocalErrorDiagnostics.shared.capture(cause, trace));
        }
        if (requiredSuccess) rethrow;
      }
    });
    _writes = writing.then<void>((_) {}, onError: (Object _) {});
    await writing;
  }

  /// Queues an authoritative server purge after already accepted writes.
  void revokeServer(String origin, String principal, String serverId) {
    _writes = _writes.then((_) async {
      try {
        await cache?.revokeServer(origin, principal, serverId);
      } catch (_) {
        _purgeFailed();
      }
    });
  }

  /// Removes private channel data while retaining the caller's authored drafts.
  void revokeChannel({
    required String origin,
    required String principal,
    required String serverId,
    required String channelId,
    required Set<String> scopes,
    required Map<String, dynamic> keptDrafts,
    required bool keepShared,
  }) {
    _writes = _writes.then((_) async {
      try {
        final sharedDraft = keepShared
            ? await cache?.read(origin, principal, serverId, 'draft', channelId)
            : null;
        for (final scope in scopes) {
          await cache?.revokeChannel(origin, principal, serverId, scope);
        }
        for (final entry in keptDrafts.entries) {
          await cache?.write(
            origin,
            principal,
            serverId,
            'draft',
            entry.key,
            entry.key == channelId && keepShared ? sharedDraft : entry.value,
          );
        }
      } catch (_) {
        _purgeFailed();
      }
    });
  }
}
