// The unified notification rules (Web v1.24 shared/src/notifications.ts,
// notifications/pause.ts) and the account's settings store
// (store/notificationSettingsStore.ts): levels and their inheritance, the
// badge rule, quiet hours, realtime `notification_prefs:updated` frames and
// optimistic level writes.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/activity_attention.dart';
import 'package:raft_flutter/data/notification_levels.dart';
import 'package:raft_flutter/data/notification_settings_api.dart';
import 'package:raft_flutter/data/notification_settings_store.dart';
import 'package:raft_flutter/platform/background_inbox.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.example',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Api extends NotificationSettingsApi {
  _Api(super.client);
  final puts = <Map<String, Object?>>[];
  Completer<PutLevelResult>? next;
  @override
  Future<PutLevelResult> putLevel({
    required String scope,
    required String id,
    required NotificationLevel? level,
    required String serverId,
  }) {
    puts.add({'scope': scope, 'id': id, 'level': levelSettingWire(level)});
    return (next = Completer<PutLevelResult>()).future;
  }
}

Map<String, dynamic> account({int version = 1, bool sound = true}) => {
  'pausedUntil': null,
  'quietHours': {
    'enabled': true,
    'startMinute': 22 * 60,
    'endMinute': 8 * 60,
    'timeZone': 'UTC',
  },
  'previewMode': 'sender_only',
  'sound': sound,
  'version': version,
};

void main() {
  group('rules', () {
    test('the most specific explicit level wins; a mute caps at mentions', () {
      const all = NotificationLevel.all, none = NotificationLevel.none;
      const mentions = NotificationLevel.mentions;
      expect(resolveEffectiveLevel(server: none, channel: all), all);
      expect(resolveEffectiveLevel(server: all, channel: none), none);
      expect(resolveEffectiveLevel(server: none), none);
      expect(
        resolveEffectiveLevel(server: none, channel: mentions, thread: all),
        all,
      );
      expect(resolveEffectiveLevel(server: all, muted: true), mentions);
      expect(resolveEffectiveLevel(server: none, muted: true), none);
    });

    test('the badge skips servers at Nothing (and their unknown counts)', () {
      expect(
        notificationBadgeCount([
          (level: NotificationLevel.all, activityUnreadCount: 3),
          (level: NotificationLevel.mentions, activityUnreadCount: 2),
          (level: NotificationLevel.none, activityUnreadCount: 9),
        ]),
        5,
      );
      expect(
        knownActivityBadgeTotal(
          currentServerId: 's1',
          currentTotal: 4,
          memberServerIds: ['s1', 's2', 's3'],
          summary: {'s1': 1, 's2': 6, 's3': null},
          silencedServerIds: {'s3'},
        ),
        10,
      );
      expect(
        knownActivityBadgeTotal(
          currentServerId: 's1',
          currentTotal: 4,
          memberServerIds: ['s1', 's2'],
          summary: {'s1': 1, 's2': 6},
          silencedServerIds: {'s2'},
        ),
        4,
      );
    });

    test('account settings parse closed, with the v1.1 / v1.2 defaults', () {
      final parsed = NotificationAccountSettings.parse(account())!;
      expect(parsed.mobileDelay, NotificationMobileDelay.inactive);
      expect(parsed.followedThreadReplies, isTrue);
      expect(parsed.previewMode, NotificationPreviewMode.senderOnly);
      expect(
        NotificationAccountSettings.parse({
          ...account(),
          'quietHours': {'enabled': true},
        }),
        isNull,
      );
      expect(
        NotificationAccountSettings.parse({...account(), 'version': -1}),
        isNull,
      );
    });

    test('quiet hours span midnight; a pause holds until its time', () {
      final quiet = NotificationAccountSettings.parse(account())!;
      expect(quiet.quietAt(DateTime.utc(2026, 11, 14, 23)), isTrue);
      expect(quiet.quietAt(DateTime.utc(2026, 11, 14, 7, 59)), isTrue);
      expect(quiet.quietAt(DateTime.utc(2026, 11, 14, 8)), isFalse);
      final now = DateTime(2026, 11, 14, 7);
      expect(nextMorningNine(now), DateTime(2026, 11, 15, 9));
      expect(
        pausedUntilForPreset(PausePreset.h2, now),
        now.add(const Duration(hours: 2)),
      );
      expect(isPausedNow(now.add(const Duration(minutes: 1)), now), isTrue);
      expect(timeToMinutes('9:05'), 545);
      expect(timeToMinutes('24:00'), isNull);
      expect(minutesToTime(545), '09:05');
    });

    test('a background poll applies the channel level over the server; a thread follows its channel', () {
      const policy = BackgroundNotificationPolicy(
        server: NotificationLevel.none,
        channels: {
          'c1': NotificationLevel.all,
          'c2': NotificationLevel.mentions,
        },
        account: null,
      );
      expect(
        policy.levelOf({'kind': 'channel', 'channelId': 'c1'}),
        NotificationLevel.all,
      );
      expect(
        policy.levelOf({'kind': 'thread', 'parentChannelId': 'c2'}),
        NotificationLevel.mentions,
      );
      expect(
        policy.levelOf({'kind': 'dm', 'channelId': 'd1'}),
        NotificationLevel.none,
      );
      expect(policy.anyAll, isTrue);
    });
  });

  group('store', () {
    late _Client client;
    late _Api api;
    late NotificationSettingsStore store;
    setUp(() {
      client = _Client();
      api = _Api(client);
      store = NotificationSettingsStore(client, api: api);
    });
    tearDown(() async {
      store.dispose();
      await client.stream.close();
    });

    test('typed frames fold in by version; the legacy server frame maps to Nothing / back', () {
      client.stream.add(
        RaftEvent('notification_prefs:updated', {
          'type': 'account',
          'settings': account(version: 4, sound: false),
        }),
      );
      expect(store.account!.sound, isFalse);
      client.stream.add(
        RaftEvent('notification_prefs:updated', {
          'type': 'account',
          'settings': account(version: 3),
        }),
      );
      expect(store.account!.sound, isFalse, reason: 'stale version dropped');
      expect(
        store.applyPrefsUpdate({
          'type': 'channel',
          'serverId': 's1',
          'scopeId': 'c1',
          'level': 'mentions',
          'prefsVersion': 2,
        }),
        isTrue,
      );
      expect(
        store.explicitLevel('s1', 'channel', 'c1'),
        NotificationLevel.mentions,
      );
      expect(
        store.applyPrefsUpdate({
          'type': 'channel',
          'serverId': 's1',
          'scopeId': 'c1',
          'level': 'default',
          'prefsVersion': 3,
        }),
        isTrue,
      );
      expect(store.explicitLevel('s1', 'channel', 'c1'), isNull);
      // The untyped server frame (older route): muted = Nothing.
      store.applyPrefsUpdate({
        'serverId': 's2',
        'scopeId': 's2',
        'prefs': {'serverPushMuted': true},
      });
      expect(store.serverLevel('s2'), NotificationLevel.none);
      store.applyPrefsUpdate({
        'serverId': 's2',
        'scopeId': 's2',
        'prefs': {'serverPushMuted': false},
      });
      expect(store.serverLevel('s2'), NotificationLevel.all);
      // An Activity-mute frame is not a level.
      expect(
        store.applyPrefsUpdate({
          'serverId': 's1',
          'scopeId': 'c1',
          'prefs': {'activityMuted': true},
          'prefsVersion': 9,
        }),
        isFalse,
      );
    });

    test('a level write is optimistic; a failure restores the confirmed value unless a frame came first', () async {
      store.applyPrefsUpdate({
        'type': 'channel',
        'serverId': 's1',
        'scopeId': 'c1',
        'level': 'all',
        'prefsVersion': 1,
      });
      final failing = store.setLevel(
        scope: 'channel',
        id: 'c1',
        serverId: 's1',
        level: NotificationLevel.none,
      );
      expect(
        store.explicitLevel('s1', 'channel', 'c1'),
        NotificationLevel.none,
      );
      api.next!.completeError(const RaftApiException('Failed'));
      expect(await failing, isFalse);
      expect(store.explicitLevel('s1', 'channel', 'c1'), NotificationLevel.all);
      final second = store.setLevel(
        scope: 'channel',
        id: 'c1',
        serverId: 's1',
        level: NotificationLevel.mentions,
      );
      store.applyPrefsUpdate({
        'type': 'channel',
        'serverId': 's1',
        'scopeId': 'c1',
        'level': 'none',
        'prefsVersion': 5,
      });
      api.next!.completeError(const RaftApiException('Failed'));
      expect(await second, isFalse);
      expect(
        store.explicitLevel('s1', 'channel', 'c1'),
        NotificationLevel.none,
        reason: 'the realtime frame is the server\'s word',
      );
    });

    test('a response older than a frame does not overwrite it; channel payloads seed unversioned levels', () async {
      final write = store.setLevel(
        scope: 'server',
        id: 's1',
        serverId: 's1',
        level: NotificationLevel.mentions,
      );
      store.applyPrefsUpdate({
        'type': 'server',
        'serverId': 's1',
        'scopeId': 's1',
        'level': 'none',
        'prefsVersion': 8,
      });
      api.next!.complete((
        scope: 'server',
        id: 's1',
        serverId: 's1',
        level: NotificationLevel.mentions,
        effective: NotificationLevel.mentions,
        muted: false,
        prefsVersion: 7,
      ));
      expect(await write, isTrue);
      expect(store.serverLevel('s1'), NotificationLevel.none);
      store.seedChannels('s1', [
        RaftRecord({'id': 'c2', 'notificationLevel': 'mentions'}),
        RaftRecord({'id': 'c3'}),
      ]);
      expect(
        store.explicitLevel('s1', 'channel', 'c2'),
        NotificationLevel.mentions,
      );
      expect(store.explicitLevel('s1', 'channel', 'c3'), isNull);
    });

    test('another account on the client clears everything', () {
      store.applyPrefsUpdate({
        'type': 'account',
        'settings': account(version: 2),
      });
      client.user = RaftRecord({'id': 'bob'});
      client.stream.add(
        const RaftEvent('notification_prefs:updated', {'type': 'noop'}),
      );
      expect(store.account, isNull);
    });
  });
}
