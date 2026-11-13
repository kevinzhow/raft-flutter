// Source: packages/web/src/notifications/notificationApi.ts at
// v1.24.0-source.1 (1d689caf). The unified notification HTTP API
// (docs/contracts/notifications.md §2, §6): thin typed wrappers so the wire
// shapes live in one place.
import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'notification_levels.dart';

typedef ServerLevelRow = ({String serverId, NotificationLevel level});

typedef AccountNotificationSettingsResponse = ({
  NotificationAccountSettings settings,
  List<ServerLevelRow> servers,
});

sealed class PatchAccountSettingsResult {
  const PatchAccountSettingsResult();
}

class PatchAccountOk extends PatchAccountSettingsResult {
  const PatchAccountOk(this.settings);
  final NotificationAccountSettings settings;
}

/// 409: another device saved first; [settings] is the server's current value.
class PatchAccountConflict extends PatchAccountSettingsResult {
  const PatchAccountConflict(this.settings);
  final NotificationAccountSettings? settings;
}

class PatchAccountError extends PatchAccountSettingsResult {
  const PatchAccountError();
}

typedef PutLevelResult = ({
  String scope,
  String id,
  String serverId,
  NotificationLevel? level,
  NotificationLevel effective,
  bool muted,
  int? prefsVersion,
});

typedef ServerExplicitLevels = ({
  String serverId,
  NotificationLevel server,
  Map<String, NotificationLevel> channels,
  Map<String, NotificationLevel> threads,
});

/// The test notification outcomes the settings card shows (contract §6).
enum TestNotificationState { shown, notShown, unconfirmed, failed }

typedef TestNotificationOutcome = ({
  TestNotificationState state,
  String? reason,
});

/// The requests, bound to one [RaftClient]. Account routes need no server;
/// a server-scoped call names its server in `X-Server-Id`.
class NotificationSettingsApi {
  const NotificationSettingsApi(this.client);
  final RaftClient client;

  static List<ServerLevelRow> _serverLevels(Object? value) => [
    if (value is List)
      for (final row in value)
        if (row is Map &&
            row['serverId'] is String &&
            NotificationLevel.parse(row['level']) != null)
          (
            serverId: row['serverId'] as String,
            level: NotificationLevel.parse(row['level'])!,
          ),
  ];

  Future<AccountNotificationSettingsResponse?> fetchAccount() async {
    final data = await client.get('/me/notification-settings');
    final settings = NotificationAccountSettings.parse(
      data is Map ? data['settings'] : null,
    );
    if (settings == null) return null;
    return (
      settings: settings,
      servers: _serverLevels(data is Map ? data['servers'] : null),
    );
  }

  Future<PatchAccountSettingsResult> patchAccount(
    Map<String, dynamic> patch,
  ) async {
    try {
      final data = await client.request(
        'PATCH',
        '/me/notification-settings',
        data: patch,
      );
      final settings = NotificationAccountSettings.parse(
        data is Map ? data['settings'] : null,
      );
      return settings == null
          ? const PatchAccountError()
          : PatchAccountOk(settings);
    } on RaftApiException catch (error) {
      // The 409 body's current settings are not among the client's
      // allow-listed error details: the store reloads them instead.
      if (error.status == 409) return const PatchAccountConflict(null);
      return const PatchAccountError();
    } catch (_) {
      return const PatchAccountError();
    }
  }

  Future<PutLevelResult> putLevel({
    required String scope,
    required String id,
    required NotificationLevel? level,
    required String serverId,
  }) async {
    final data = await client.request(
      'PUT',
      '/notification-levels',
      // The id names the scope; the route needs no server header.
      data: {'scope': scope, 'id': id, 'level': levelSettingWire(level)},
    );
    final record = data is Map ? data : const {};
    final stored = isLevelSetting(record['level'])
        ? parseLevelSetting(record['level'])
        : level;
    final version = record['prefsVersion'];
    return (
      scope: scope,
      id: id,
      serverId: record['serverId'] is String
          ? record['serverId'] as String
          : serverId,
      level: stored,
      effective:
          NotificationLevel.parse(record['effective']) ??
          stored ??
          NotificationLevel.all,
      muted: record['muted'] == true,
      prefsVersion: version is int && version >= 0 ? version : null,
    );
  }

  static Map<String, NotificationLevel> _explicit(Object? value) => {
    if (value is List)
      for (final row in value)
        if (row is Map &&
            row['id'] is String &&
            NotificationLevel.parse(row['level']) != null)
          row['id'] as String: NotificationLevel.parse(row['level'])!,
  };

  Future<ServerExplicitLevels?> fetchServerLevels(String serverId) async {
    final data = await client.getForServer(serverId, '/notification-levels');
    if (data is! Map || NotificationLevel.parse(data['server']) == null) {
      return null;
    }
    return (
      serverId: serverId,
      server: NotificationLevel.parse(data['server'])!,
      channels: _explicit(data['channels']),
      threads: _explicit(data['threads']),
    );
  }

  // -------------------------------------------------------------------------
  // Test notifications (§6)
  // -------------------------------------------------------------------------

  static const testWait = Duration(seconds: 15);
  static const testPoll = Duration(seconds: 1);

  /// `{sent, testId, reason}` of POST /notifications/test for this desktop
  /// socket. Never throws.
  Future<({bool sent, String? testId, String reason})> startDesktopTest(
    String socketId,
  ) async {
    try {
      final data = await client.request(
        'POST',
        '/notifications/test',
        data: {
          'device': {'kind': 'desktop', 'socketId': socketId},
        },
      );
      final record = data is Map ? data : const {};
      final testId = record['testId'] is String
          ? record['testId'] as String
          : null;
      if (record['sent'] == true && testId != null) {
        return (sent: true, testId: testId, reason: '');
      }
      return (
        sent: false,
        testId: testId,
        reason: record['reason'] is String
            ? record['reason'] as String
            : 'error',
      );
    } on RaftApiException catch (error) {
      // The server's machine-readable reason (no_device, ...); never text.
      return (sent: false, testId: null, reason: error.code ?? 'error');
    } catch (_) {
      return (sent: false, testId: null, reason: 'error');
    }
  }

  /// The client displayed (or failed to display) a test notification.
  Future<void> ackTest(String testId, bool shown) async {
    try {
      await client.request(
        'POST',
        '/notifications/test/${Uri.encodeComponent(testId)}/ack',
        data: {'shown': shown},
      );
    } catch (_) {
      // The settings card times out to "not shown" on its own.
    }
  }

  Future<({String status, String? reason})?> testStatus(String testId) async {
    try {
      final data = await client.get(
        '/notifications/test/${Uri.encodeComponent(testId)}',
      );
      if (data is! Map) return null;
      final status = data['status'];
      if (status is! String ||
          !const {'pending', 'shown', 'not_shown', 'failed'}.contains(status)) {
        return null;
      }
      return (
        status: status,
        reason: data['reason'] is String ? data['reason'] as String : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// `runTestNotification` for this desktop: sends, then waits up to 15 s
  /// for this device's ack. `no_socket` without a live connection.
  Future<TestNotificationOutcome> runDesktopTest({
    bool Function(String testId)? isUnconfirmed,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
  }) async {
    final socketId = client.socketId;
    if (socketId == null) {
      return (state: TestNotificationState.failed, reason: 'no_socket');
    }
    final started = await startDesktopTest(socketId);
    if (!started.sent || started.testId == null) {
      return (state: TestNotificationState.failed, reason: started.reason);
    }
    final testId = started.testId!;
    final wait = sleep ?? (d) => Future<void>.delayed(d);
    final clock = now ?? DateTime.now;
    final unconfirmed = isUnconfirmed ?? (_) => false;
    TestNotificationOutcome notShown() => unconfirmed(testId)
        ? (state: TestNotificationState.unconfirmed, reason: null)
        : (state: TestNotificationState.notShown, reason: null);
    final deadline = clock().add(testWait);
    while (clock().isBefore(deadline)) {
      await wait(testPoll);
      if (unconfirmed(testId)) {
        return (state: TestNotificationState.unconfirmed, reason: null);
      }
      final result = await testStatus(testId);
      if (result == null || result.status == 'pending') continue;
      if (result.status == 'shown') {
        return (state: TestNotificationState.shown, reason: null);
      }
      if (result.status == 'failed') {
        return (
          state: TestNotificationState.failed,
          reason: result.reason ?? 'error',
        );
      }
      return notShown();
    }
    return notShown();
  }
}
