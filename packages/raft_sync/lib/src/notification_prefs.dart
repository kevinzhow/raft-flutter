/// Mounted notificationPrefsSyncDomain.ts compatibility adapter. The preference
/// version is sparse; legacy updates without a version retain the source path.
library;

import 'core.dart';
import 'read_state.dart';

const notificationPrefsFlag = 'sync_core_notification_prefs_v0';
const notificationPrefsDomain = 'notification_prefs';

Map<String, dynamic>? readNotificationPrefsUpdate(dynamic payload) {
  if (payload is! Map ||
      payload['serverId'] is! String ||
      payload['scopeId'] is! String ||
      payload['prefs'] is! Map)
    return null;
  final prefs = payload['prefs'] as Map;
  final raw = payload['prefsVersion'];
  final version = raw is int && raw >= 0 && raw <= maxSafeInteger ? raw : null;
  if (prefs['serverPushMuted'] is bool) {
    return {
      'type': 'server',
      'serverId': payload['serverId'],
      'serverPushMuted': prefs['serverPushMuted'],
      if (version != null) 'prefsVersion': version,
    };
  }
  if (prefs['activityMuted'] is! bool) return null;
  return {
    'type': 'channel',
    'serverId': payload['serverId'],
    'channelId': payload['scopeId'],
    'state': {
      'activityMuted': prefs['activityMuted'],
      'muteFromSeq':
          prefs['muteFromSeq'] is String || prefs['muteFromSeq'] is num
          ? prefs['muteFromSeq']
          : null,
      if (prefs.containsKey('activityMuteSupported'))
        'activityMuteSupported': prefs['activityMuteSupported'] == true,
      if (version != null) 'prefsVersion': version,
    },
  };
}

class NotificationPrefsSync {
  NotificationPrefsSync() : core = _create();
  SyncCore core;
  static SyncCore _create() => SyncCore(
    domains: [
      SyncDomain(
        name: notificationPrefsDomain,
        density: SyncDensity.sparse,
        initialState: () => null,
        fold: (_, event, _, _) =>
            Map<String, dynamic>.unmodifiable(event as Map),
        fromSnapshot: (snapshot) => snapshot.state,
      ),
    ],
  );
  void reset() => core = _create();
  void revokeChannel(String channel) =>
      core.revokeScope(notificationPrefsDomain, 'channel:$channel');

  /// Null means invalid or duplicate. Reading and server/principal authority
  /// remain the controller's responsibility; this reducer performs no I/O.
  Map<String, dynamic>? consume(Map<String, dynamic> update) {
    final channel = update['type'] == 'channel';
    final state = channel ? update['state'] as Map : update;
    final version = state['prefsVersion'];
    if (version == null) return update;
    final scope = channel
        ? 'channel:${update['channelId']}'
        : 'server:${update['serverId']}';
    final outcome = core.ingestFrame(
      notificationPrefsDomain,
      SyncFrame(
        scopeId: scope,
        seq: BigInt.from(version as int),
        event: update,
      ),
    );
    if (outcome['kind'] != 'applied' && outcome['kind'] != 'max_advanced') {
      return null;
    }
    return Map<String, dynamic>.from(
      core.state(notificationPrefsDomain, scope),
    );
  }
}
