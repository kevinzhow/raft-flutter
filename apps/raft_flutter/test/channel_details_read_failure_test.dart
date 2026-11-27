import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/notification_level_menu.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

// A private channel the viewer administers, with a pending external invite,
// whose per-channel reads get no answer from the server (a dropped
// connection). Web keeps every preference control usable, says which read
// failed, and shows nothing for a failed roster read.

Object _dropped(Object _) => throw const SocketException('Connection reset');

void _routes(MessageAdapter api, {required bool fail}) {
  final row = {
    'id': 'c1',
    'name': 'hedong',
    'type': 'private',
    'joined': true,
    'serverId': 's1',
    'hasExternalRelation': true,
    'collapseLongMessages': true,
    'activityMuteSupported': true,
    'channelRole': 'admin',
    'channelCapabilities': {
      'editChannelMetadata': true,
      'addChannelMembers': true,
    },
  };
  api.routes['GET /channels'] = (_) => [row];
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/members'] = fail
      ? _dropped
      : (_) => {
          'humans': [
            {'id': 'u1', 'name': 'kevin', 'displayName': 'Kevin'},
          ],
          'agents': [],
        };
  api.routes['GET /channels/c1/message-display-settings'] = fail
      ? _dropped
      : (_) => {'collapseLongMessages': true};
  api.routes['GET /channels/c1/notification-settings'] = fail
      ? _dropped
      : (_) => {'activityMuted': false, 'activityMuteSupported': true};
  api.routes['GET /channels/c1/external-invites'] = (_) => {'invites': []};
}

Future<(WorkspaceController, MessageAdapter, RaftChannel)> _setUp(
  WidgetTester t,
) async {
  final (w, api) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  _routes(api, fail: true);
  final channel = RaftChannel({
    'id': 'c1',
    'name': 'hedong',
    'type': 'private',
    'joined': true,
    'serverId': 's1',
    'hasExternalRelation': true,
    'collapseLongMessages': true,
    'activityMuteSupported': true,
  });
  w.channels = [channel];
  t.view.physicalSize = const Size(412, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  return (w, api, channel);
}

Widget _details(WorkspaceController w, RaftChannel channel) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: ChannelSettings(
      controller: w,
      channel: channel,
      isPanel: true,
      page: true,
      details: true,
      onClose: () {},
      onMembers: () {},
    ),
  ),
);

bool _stored(WorkspaceController w, String key) =>
    w.channels.singleWhere((c) => c.id == 'c1').json[key] == true;

void main() {
  // The preference read failed, so the page knows only the channel row's
  // value. A failed write must put that value back, on screen and in the
  // channel list.
  testWidgets(
    'details: a failed collapse write after a failed read keeps the old value',
    (t) async {
      final (w, api, channel) = await _setUp(t);
      api.routes['PATCH /channels/c1/message-display-settings'] = _dropped;
      await t.pumpWidget(_details(w, channel));
      await t.pumpAndSettle();

      final collapse = find.byKey(
        const ValueKey('channel-settings-collapse-switch'),
      );
      await t.ensureVisible(collapse);
      expect(t.widget<RaftSwitch>(collapse).value, isTrue);
      await t.tap(collapse);
      await t.pumpAndSettle();

      expect(
        api.calls.where(
          (c) =>
              c.method == 'PATCH' &&
              c.path == '/channels/c1/message-display-settings',
        ),
        hasLength(1),
      );
      expect(t.widget<RaftSwitch>(collapse).value, isTrue);
      expect(_stored(w, 'collapseLongMessages'), isTrue);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'details: a failed mute write after a failed read keeps the old value',
    (t) async {
      final (w, api, _) = await _setUp(t);
      final channel = RaftChannel({
        ...w.channels.single.json,
        'activityMuted': false,
      });
      w.channels = [channel];
      api.routes['PATCH /channels/c1/notification-settings'] = _dropped;
      await t.pumpWidget(_details(w, channel));
      await t.pumpAndSettle();

      RaftSettingsSelect<NotificationLevelChoice> select() =>
          t.widget<RaftSettingsSelect<NotificationLevelChoice>>(
            find.byKey(
              const ValueKey('channel-settings-notification-level-select'),
            ),
          );
      expect(select().value, isNot(NotificationLevelChoice.mute));
      select().onChanged!(NotificationLevelChoice.mute);
      await t.pumpAndSettle();

      expect(
        api.calls.where(
          (c) =>
              c.method == 'PATCH' &&
              c.path == '/channels/c1/notification-settings',
        ),
        hasLength(1),
      );
      expect(select().value, isNot(NotificationLevelChoice.mute));
      expect(_stored(w, 'activityMuted'), isFalse);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'details: failed preference reads keep their controls and name the read',
    (t) async {
      final (w, api, channel) = await _setUp(t);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ChannelSettings(
              controller: w,
              channel: channel,
              isPanel: true,
              page: true,
              details: true,
              onClose: () {},
              onMembers: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      final collapse = find.byKey(
        const ValueKey('channel-settings-collapse-switch'),
      );
      await t.ensureVisible(collapse);
      expect(
        collapse.hitTestable(),
        findsOneWidget,
        reason: 'a failed read must not leave the row without its switch',
      );
      expect(t.widget<RaftSwitch>(collapse).onChanged, isNotNull);
      expect(find.text(raftGenericErrorText), findsNothing);
      expect(
        find.text('Failed to load message display settings.'),
        findsOneWidget,
      );

      // The switch works: it writes the preference like a loaded one.
      api.routes['PATCH /channels/c1/message-display-settings'] = (o) => {
        ...(o.data as Map),
        'prefsVersion': 1,
      };
      await t.tap(collapse);
      await t.pumpAndSettle();
      expect(
        api.calls.where(
          (c) =>
              c.method == 'PATCH' &&
              c.path == '/channels/c1/message-display-settings',
        ),
        hasLength(1),
      );

      // The next read that succeeds clears the notice.
      _routes(api, fail: false);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ChannelSettings(
              controller: w,
              channel: channel,
              isPanel: true,
              page: true,
              details: true,
              onClose: () {},
              onMembers: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Failed to load message display settings.'),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('members page: a failed roster read shows no generic error', (
    t,
  ) async {
    final (w, _, channel) = await _setUp(t);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ChannelMembers(
            controller: w,
            channel: channel,
            page: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(raftGenericErrorText), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
