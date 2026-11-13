// Source: packages/web/src/store/notificationSettingsStore.ts and
// notifications/NotificationRuntime.tsx at v1.24.0-source.1 (1d689caf).
//
// The unified notification settings of one signed-in account
// (docs/contracts/notifications.md §2): the account settings (pause, quiet
// hours, preview, sound, phone alerts, followed-thread replies), every
// server's level, and each loaded server's explicit channel / thread levels.
// Written only through the notification API; realtime
// `notification_prefs:updated` frames (type account / server / channel /
// thread) are folded in with stale versions dropped. Account data: it is not
// cleared by a server or channel switch, only when the principal changes.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'notification_levels.dart';
import 'notification_settings_api.dart';

class ServerExplicitLevelState {
  const ServerExplicitLevelState({
    this.channels = const {},
    this.threads = const {},
    this.loaded = false,
  });
  final Map<String, NotificationLevel> channels, threads;
  final bool loaded;

  ServerExplicitLevelState withLevel(
    String scope,
    String id,
    NotificationLevel? level,
  ) {
    final map = Map.of(scope == 'channel' ? channels : threads);
    if (level == null) {
      map.remove(id);
    } else {
      map[id] = level;
    }
    return scope == 'channel'
        ? ServerExplicitLevelState(
            channels: map,
            threads: threads,
            loaded: loaded,
          )
        : ServerExplicitLevelState(
            channels: channels,
            threads: map,
            loaded: loaded,
          );
  }
}

/// A plain [Listenable] (not a ChangeNotifier): one store lives as long as
/// its [RaftClient] and is never disposed by a widget.
class NotificationSettingsStore implements Listenable {
  NotificationSettingsStore(this.client, {NotificationSettingsApi? api})
    : api = api ?? NotificationSettingsApi(client) {
    _principal = client.user?.id;
    _events = client.events.listen(_event);
  }

  static final _stores = Expando<NotificationSettingsStore>(
    'notificationSettings',
  );

  /// The one store of [client]'s account (created on first use).
  static NotificationSettingsStore of(RaftClient client) =>
      _stores[client] ??= NotificationSettingsStore(client);

  /// The store of [client] when one exists, without creating it.
  static NotificationSettingsStore? peek(RaftClient client) => _stores[client];

  @visibleForTesting
  static void install(RaftClient client, NotificationSettingsStore store) =>
      _stores[client] = store;

  final RaftClient client;
  final NotificationSettingsApi api;
  StreamSubscription<RaftEvent>? _events;
  String? _principal;
  bool _disposed = false;

  NotificationAccountSettings? account;
  bool accountLoaded = false;

  /// Server levels (`server_members.server_push_mode`).
  final Map<String, NotificationLevel> serverLevels = {};

  /// Explicit (non-default) channel / thread levels per server.
  final Map<String, ServerExplicitLevelState> explicit = {};

  /// Last version applied per `server:<id>` / `channel:<id>` / `thread:<id>`
  /// (prefsVersion of the level frames) and `account`.
  final Map<String, int> scopeVersions = {};

  int _accountRequest = 0;
  final Map<String, ({int latest, NotificationLevel? confirmed})>
  _levelRequests = {};

  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _changed() {
    if (_disposed) return;
    for (final listener in List.of(_listeners)) {
      if (_listeners.contains(listener)) listener();
    }
  }

  /// Signed out, or another account on this client: nothing of the previous
  /// account's settings stays.
  bool _checkPrincipal() {
    final user = client.user?.id;
    if (user == _principal) return true;
    _principal = user;
    reset();
    return false;
  }

  void _event(RaftEvent event) {
    switch (event.name) {
      case 'notification_prefs:updated':
        _checkPrincipal();
        applyPrefsUpdate(event.payload);
      case 'connected':
        // Another device may have changed them while this one was away
        // (Web NotificationRuntime: on every socket (re)connect).
        _checkPrincipal();
        unawaited(loadAccount());
        final server = client.serverId;
        if (server != null) unawaited(loadServerLevels(server));
      case 'session:ended':
        _principal = null;
        reset();
    }
  }

  Future<void> loadAccount() async {
    _checkPrincipal();
    if (client.user == null) return;
    final at = ++_accountRequest;
    AccountNotificationSettingsResponse? result;
    try {
      result = await api.fetchAccount();
    } catch (_) {
      result = null;
    }
    if (_disposed || at != _accountRequest) return;
    if (result == null) {
      accountLoaded = true;
      _changed();
      return;
    }
    for (final row in result.servers) {
      serverLevels[row.serverId] = row.level;
    }
    final held = account;
    account = held != null && held.version > result.settings.version
        ? held
        : result.settings;
    accountLoaded = true;
    _changed();
  }

  Future<void> loadServerLevels(String serverId) async {
    ServerExplicitLevels? result;
    try {
      result = await api.fetchServerLevels(serverId);
    } catch (_) {
      result = null;
    }
    if (_disposed || result == null) return;
    serverLevels[serverId] = result.server;
    explicit[serverId] = ServerExplicitLevelState(
      channels: Map.of(result.channels),
      threads: Map.of(result.threads),
      loaded: true,
    );
    _changed();
  }

  bool levelsLoaded(String serverId) => explicit[serverId]?.loaded == true;

  /// PATCH /me/notification-settings, sending back the held version. A 409
  /// reloads what the other device saved.
  Future<PatchAccountSettingsResult> patchAccount(
    Map<String, dynamic> patch,
  ) async {
    final held = account;
    final body = held != null && !patch.containsKey('version')
        ? {...patch, 'version': held.version}
        : patch;
    final result = await api.patchAccount(body);
    if (_disposed) return result;
    switch (result) {
      case PatchAccountOk(:final settings):
        final current = account;
        if (current == null || settings.version >= current.version) {
          account = settings;
          accountLoaded = true;
          _changed();
        }
      case PatchAccountConflict(:final settings):
        if (settings != null) {
          account = settings;
          _changed();
        } else {
          unawaited(loadAccount());
        }
      case PatchAccountError():
        break;
    }
    return result;
  }

  /// A server's level: the loaded one, else the legacy boolean on the
  /// server row (muted = none), else the default `all`.
  NotificationLevel serverLevel(String serverId, {RaftRecord? row}) {
    final loaded = serverLevels[serverId];
    if (loaded != null) return loaded;
    return row != null && row.flag('serverPushMuted')
        ? NotificationLevel.none
        : NotificationLevel.all;
  }

  /// The explicit level of a channel or thread (null = `default`).
  NotificationLevel? explicitLevel(String serverId, String scope, String id) {
    final server = explicit[serverId];
    return scope == 'channel' ? server?.channels[id] : server?.threads[id];
  }

  NotificationLevel? _read(String scope, String serverId, String id) =>
      scope == 'server'
      ? serverLevels[id] ?? NotificationLevel.all
      : explicitLevel(serverId, scope, id);

  void _write(
    String scope,
    String serverId,
    String id,
    NotificationLevel? level,
    int? version,
  ) {
    final key = '$scope:$id';
    if (version != null) scopeVersions[key] = version;
    if (scope == 'server') {
      if (level != null) serverLevels[id] = level;
    } else {
      explicit[serverId] =
          (explicit[serverId] ?? const ServerExplicitLevelState()).withLevel(
            scope,
            id,
            level,
          );
    }
    _changed();
  }

  /// PUT /notification-levels: optimistic; only the latest request may
  /// settle what is shown, and a failure restores the server's last
  /// confirmed value unless a realtime frame arrived meanwhile.
  Future<bool> setLevel({
    required String scope,
    required String id,
    required String serverId,
    required NotificationLevel? level,
  }) async {
    if (scope == 'server' && level == null) return false;
    final key = '$scope:$id';
    final pending = _levelRequests[key];
    final request = (pending?.latest ?? 0) + 1;
    final confirmed = pending != null
        ? pending.confirmed
        : _read(scope, serverId, id);
    _levelRequests[key] = (latest: request, confirmed: confirmed);
    final versionAtStart = scopeVersions[key];
    _write(scope, serverId, id, level, null);
    bool isLatest() => _levelRequests[key]?.latest == request;
    void settle() {
      if (isLatest()) _levelRequests.remove(key);
    }

    try {
      final result = await api.putLevel(
        scope: scope,
        id: id,
        level: level,
        serverId: serverId,
      );
      if (_disposed) return true;
      final held = scopeVersions[key];
      final stale =
          result.prefsVersion != null &&
          held != null &&
          result.prefsVersion! <= held;
      final entry = _levelRequests[key];
      if (!stale && entry != null) {
        _levelRequests[key] = (latest: entry.latest, confirmed: result.level);
      }
      if (isLatest() && !stale) {
        _write(scope, serverId, id, result.level, result.prefsVersion);
      }
      settle();
      return true;
    } catch (_) {
      if (_disposed) return false;
      final entry = _levelRequests[key];
      if (isLatest() && scopeVersions[key] == versionAtStart && entry != null) {
        _write(scope, serverId, id, entry.confirmed, null);
      }
      settle();
      return false;
    }
  }

  /// A `notification_prefs:updated` frame with a `type` of account / server
  /// / channel / thread, or the legacy server frame (boolean
  /// `prefs.serverPushMuted` only). True when applied.
  bool applyPrefsUpdate(Object? payload) {
    if (payload is! Map) return false;
    final type = payload['type'];
    if (type == 'account') {
      final settings = NotificationAccountSettings.parse(payload['settings']);
      if (settings == null) return false;
      final held = [
        account?.version ?? -1,
        scopeVersions['account'] ?? -1,
      ].reduce((a, b) => a > b ? a : b);
      if (settings.version <= held) return false;
      account = settings;
      accountLoaded = true;
      scopeVersions['account'] = settings.version;
      _changed();
      return true;
    }
    final serverId = payload['serverId'], scopeId = payload['scopeId'];
    if (serverId is! String || scopeId is! String) return false;
    if (type != 'server' && type != 'channel' && type != 'thread') {
      // The untyped frame: a legacy server mute, or the Activity mute.
      final prefs = payload['prefs'];
      if (type == null && prefs is Map && prefs['serverPushMuted'] is bool) {
        noteLegacyServerMuted(serverId, prefs['serverPushMuted'] as bool);
        return true;
      }
      return false;
    }
    final raw = payload['level'];
    final valid = type == 'server'
        ? NotificationLevel.parse(raw) != null
        : isLevelSetting(raw);
    if (!valid) return false;
    final level = parseLevelSetting(raw);
    final version =
        payload['prefsVersion'] is int && payload['prefsVersion'] >= 0
        ? payload['prefsVersion'] as int
        : null;
    final key = '$type:$scopeId';
    final held = scopeVersions[key];
    if (version != null && held != null && version <= held) return false;
    _write(type as String, serverId, scopeId, level, version);
    final inFlight = _levelRequests[key];
    if (inFlight != null) {
      _levelRequests[key] = (latest: inFlight.latest, confirmed: level);
    }
    return true;
  }

  /// muted = none; unmuted moves a held `none` back to `all` and keeps
  /// `mentions`.
  void noteLegacyServerMuted(String serverId, bool muted) {
    final held = serverLevels[serverId];
    final next = muted
        ? NotificationLevel.none
        : held == NotificationLevel.none
        ? NotificationLevel.all
        : held;
    if (next == null || next == held) return;
    serverLevels[serverId] = next;
    _changed();
  }

  /// `notificationLevel` read off channel / thread payloads. Unversioned, so
  /// a scope a realtime frame already set is left alone.
  void seedLevelsFromPayloads(
    String serverId,
    String scope,
    Iterable<({String id, Object? notificationLevel})> rows,
  ) {
    var changed = false;
    for (final row in rows) {
      // null = no explicit level; absent (an older server) is skipped.
      if (row.notificationLevel != null &&
          !isLevelSetting(row.notificationLevel)) {
        continue;
      }
      if (scopeVersions.containsKey('$scope:${row.id}')) continue;
      final level = parseLevelSetting(row.notificationLevel);
      if (explicitLevel(serverId, scope, row.id) == level) continue;
      explicit[serverId] =
          (explicit[serverId] ?? const ServerExplicitLevelState()).withLevel(
            scope,
            row.id,
            level,
          );
      changed = true;
    }
    if (changed) _changed();
  }

  /// Seeds a server's channel levels from channel rows (their v1.24
  /// `notificationLevel`); rows of an older server carry none.
  void seedChannels(String serverId, Iterable<RaftRecord> channels) =>
      seedLevelsFromPayloads(serverId, 'channel', [
        for (final c in channels)
          if (c.json.containsKey('notificationLevel'))
            (id: c.id, notificationLevel: c.json['notificationLevel']),
      ]);

  void reset() {
    _accountRequest++;
    _levelRequests.clear();
    account = null;
    accountLoaded = false;
    serverLevels.clear();
    explicit.clear();
    scopeVersions.clear();
    _changed();
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
    unawaited(_events?.cancel());
  }
}
