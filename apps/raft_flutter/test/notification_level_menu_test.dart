// The notification level picker (Web v1.24 NotificationLevelMenu.tsx): a
// server's level, and a channel's (All new messages / Only what involves me
// / Mute, Mute being the Activity mute) in its ⋯ sheet and the sidebar
// menu's "Notifications ▸".
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/notification_levels.dart';
import 'package:raft_flutter/data/notification_settings_api.dart';
import 'package:raft_flutter/data/notification_settings_store.dart';
import 'package:raft_flutter/features/notification_level_menu.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.example',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Api extends NotificationSettingsApi {
  _Api(super.client);
  final puts = <String>[];
  bool fail = false;
  @override
  Future<PutLevelResult> putLevel({
    required String scope,
    required String id,
    required NotificationLevel? level,
    required String serverId,
  }) async {
    puts.add('$scope:$id:${levelSettingWire(level)}');
    if (fail) throw const RaftApiException('Failed');
    return (
      scope: scope,
      id: id,
      serverId: serverId,
      level: level,
      effective: level ?? NotificationLevel.all,
      muted: false,
      prefsVersion: null,
    );
  }
}

void main() {
  late _Client client;
  late _Api api;
  late NotificationSettingsStore store;
  setUp(() {
    client = _Client();
    api = _Api(client);
    store = NotificationSettingsStore(client, api: api);
    NotificationSettingsStore.install(client, store);
    store.serverLevels['s1'] = NotificationLevel.mentions;
  });
  tearDown(() async {
    store.dispose();
    await client.stream.close();
  });

  NotificationMuteControl mute(bool muted, List<bool> calls) =>
      NotificationMuteControl(
        muted: muted,
        setMuted: (next) async {
          calls.add(next);
          return true;
        },
      );

  test('a channel inherits the server\'s level; choosing it again goes back to default', () async {
    final model = NotificationLevelModel(
      store: store,
      serverId: 's1',
      channelId: 'c1',
      mute: mute(false, []),
    );
    expect(model.value, NotificationLevelChoice.mentions);
    expect(model.options, [
      NotificationLevelChoice.all,
      NotificationLevelChoice.mentions,
      NotificationLevelChoice.mute,
    ]);
    expect(await model.set(NotificationLevelChoice.all), isTrue);
    expect(store.explicitLevel('s1', 'channel', 'c1'), NotificationLevel.all);
    final again = NotificationLevelModel(
      store: store,
      serverId: 's1',
      channelId: 'c1',
    );
    expect(again.value, NotificationLevelChoice.all);
    expect(await again.set(NotificationLevelChoice.mentions), isTrue);
    expect(api.puts, ['channel:c1:all', 'channel:c1:default']);
  });

  test('Mute is the Activity mute; leaving it unmutes first; a channel at Nothing keeps that option', () async {
    final calls = <bool>[];
    final muted = NotificationLevelModel(
      store: store,
      serverId: 's1',
      channelId: 'c1',
      mute: mute(true, calls),
    );
    expect(muted.value, NotificationLevelChoice.mute);
    expect(muted.effective, NotificationLevel.none);
    expect(await muted.set(NotificationLevelChoice.all), isTrue);
    expect(calls, [false]);
    expect(api.puts, ['channel:c1:all']);
    store.explicit['s1'] = const ServerExplicitLevelState(
      channels: {'c2': NotificationLevel.none},
    );
    final nothing = NotificationLevelModel(
      store: store,
      serverId: 's1',
      channelId: 'c2',
      mute: mute(false, calls),
    );
    expect(nothing.options, contains(NotificationLevelChoice.none));
    expect(await nothing.set(NotificationLevelChoice.mute), isTrue);
    expect(calls, [false, true]);
  });

  test('a server row offers All / Only what involves me / Nothing; a failed write restores it', () async {
    final server = NotificationLevelModel(store: store, serverId: 's1');
    expect(server.options, [
      NotificationLevelChoice.all,
      NotificationLevelChoice.mentions,
      NotificationLevelChoice.none,
    ]);
    api.fail = true;
    expect(await server.set(NotificationLevelChoice.none), isFalse);
    expect(store.serverLevel('s1'), NotificationLevel.mentions);
    // An older server: the server row's legacy mute is Nothing.
    final legacy = NotificationLevelModel(
      store: store,
      serverId: 's9',
      serverRow: RaftRecord({'id': 's9', 'serverPushMuted': true}),
    );
    expect(legacy.value, NotificationLevelChoice.none);
  });

  testWidgets(
    'the sidebar "Notifications ▸" opens its own submenu with the levels and the Mute note',
    (t) async {
      final calls = <bool>[];
      var closed = 0;
      late NotificationLevelModel model;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                model = NotificationLevelModel(
                  store: store,
                  serverId: 's1',
                  channelId: 'c1',
                  mute: mute(true, calls),
                );
                return RaftSidebarContextMenu.sidebar(
                  entries: [
                    const RaftSidebarMenuItem(
                      label: 'Pin',
                      glyph: RaftGlyph.pin,
                    ),
                    notificationLevelSubmenuItem(
                      context: context,
                      model: model,
                      close: () => closed++,
                      onFailed: (_) {},
                    ),
                  ],
                  legacyWidth: 192,
                );
              },
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('sidebar-ctx-notification-level')));
      await t.pumpAndSettle();
      for (final choice in ['all', 'mentions', 'mute']) {
        expect(
          find.byKey(ValueKey('sidebar-ctx-notification-level-$choice')),
          findsOneWidget,
          reason: choice,
        );
      }
      expect(find.text(levelMuteNote), findsOneWidget);
      // The level row sits level with its trigger, not with the first row.
      expect(
        t
            .getTopLeft(
              find.byKey(const ValueKey('sidebar-ctx-notification-level-all')),
            )
            .dy,
        greaterThan(t.getTopLeft(find.text('Pin')).dy),
      );
      await t.tap(
        find.byKey(const ValueKey('sidebar-ctx-notification-level-mentions')),
      );
      await t.pumpAndSettle();
      expect(closed, 1);
      expect(calls, [false], reason: 'leaving Mute unmutes');
      expect(
        api.puts,
        isEmpty,
        reason: 'mentions is the server level: default',
      );
    },
  );
}
