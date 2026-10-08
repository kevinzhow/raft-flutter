import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

Map<String, dynamic> payload(
  int? version, {
  bool muted = true,
  bool server = false,
}) => {
  'serverId': 's',
  'scopeId': server ? 's' : 'c',
  'prefs': server
      ? {'serverPushMuted': muted}
      : {'activityMuted': muted, 'muteFromSeq': '42'},
  if (version != null) 'prefsVersion': version,
};
void main() {
  test('source parser preserves optional supported bit and exact preference version', () {
    final update = readNotificationPrefsUpdate(payload(2))!;
    expect(update['state'], {
      'activityMuted': true,
      'muteFromSeq': '42',
      'prefsVersion': 2,
    });
    expect(
      readNotificationPrefsUpdate({
        'serverId': 's',
        'scopeId': 'c',
        'prefs': {},
      }),
      isNull,
    );
  });
  test(
    'sparse preference core drops same-version conflict and regressions',
    () {
      final sync = NotificationPrefsSync();
      expect(
        sync.consume(
          readNotificationPrefsUpdate(payload(2))!,
        )!['state']['activityMuted'],
        true,
      );
      expect(
        sync.consume(readNotificationPrefsUpdate(payload(2, muted: false))!),
        isNull,
      );
      expect(
        sync.consume(readNotificationPrefsUpdate(payload(1, muted: false))!),
        isNull,
      );
      expect(
        sync.consume(
          readNotificationPrefsUpdate(payload(100, muted: false))!,
        )!['state']['activityMuted'],
        false,
      );
      expect(sync.core.pendingRequests(), isEmpty);
    },
  );
  test(
    'legacy versionless updates pass through; scope/reset isolate versions',
    () {
      final sync = NotificationPrefsSync();
      sync.consume(readNotificationPrefsUpdate(payload(100))!);
      expect(
        sync.consume(
          readNotificationPrefsUpdate(payload(null, muted: false))!,
        )!['state']['activityMuted'],
        false,
      );
      expect(
        sync.consume(
          readNotificationPrefsUpdate(payload(1, server: true))!,
        )!['serverPushMuted'],
        true,
      );
      sync.revokeChannel('c');
      expect(sync.consume(readNotificationPrefsUpdate(payload(1))!), isNotNull);
      sync.reset();
      expect(sync.core.state(notificationPrefsDomain, 'channel:c'), isNull);
    },
  );
}
