// Web ChatPanel keeps one notice per preference read
// (activityMuteError, messageDisplayPrefsError): each ends only when that
// read or its own write succeeds.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/channel_roster_invalidations.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

Object _dropped(Object _) => throw const SocketException('Connection reset');

Map<String, dynamic> _row({bool muted = false}) => {
  'id': 'c1',
  'name': 'hedong',
  'type': 'private',
  'joined': true,
  'serverId': 's1',
  'collapseLongMessages': true,
  'activityMuteSupported': true,
  'activityMuted': muted,
  'channelRole': 'admin',
  'channelCapabilities': {
    'editChannelMetadata': true,
    'addChannelMembers': true,
  },
};

void _routes(
  MessageAdapter api, {
  bool display = true,
  bool notification = true,
  bool members = true,
  bool muted = false,
}) {
  api.routes['GET /channels'] = (_) => [_row(muted: muted)];
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/members'] = members
      ? (_) => {
          'humans': [
            {'id': 'u1', 'name': 'kevin', 'displayName': 'Kevin'},
          ],
          'agents': [],
        }
      : _dropped;
  api.routes['GET /channels/c1/message-display-settings'] = display
      ? (_) => {'collapseLongMessages': true}
      : _dropped;
  api.routes['GET /channels/c1/notification-settings'] = notification
      ? (_) => {'activityMuted': muted, 'activityMuteSupported': true}
      : _dropped;
  api.routes['GET /channels/c1/external-invites'] = (_) => {'invites': []};
}

Future<(WorkspaceController, MessageAdapter, RaftChannel)> _setUp(
  WidgetTester t, {
  bool muted = false,
}) async {
  final (w, api) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  final channel = RaftChannel(_row(muted: muted));
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

const _displayMsg = 'Failed to load message display settings.';
const _muteMsg = 'Failed to load Activity mute setting.';

void main() {
  testWidgets(
    'both failed preference reads are named, each in its own notice',
    (t) async {
      final (w, api, channel) = await _setUp(t);
      _routes(api, display: false, notification: false);
      await t.pumpWidget(_details(w, channel));
      await t.pumpAndSettle();
      expect(find.text(_displayMsg), findsOneWidget);
      expect(
        find.text(_muteMsg),
        findsOneWidget,
        reason: 'the failed notification-settings read is not named',
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a read notice ends with its own write and stays gone on other reads',
    (t) async {
      final (w, api, channel) = await _setUp(t);
      _routes(api, display: false);
      await t.pumpWidget(_details(w, channel));
      await t.pumpAndSettle();
      expect(find.text(_displayMsg), findsOneWidget);
      api.routes['PATCH /channels/c1/message-display-settings'] = (o) => {
        ...(o.data as Map),
        'prefsVersion': 1,
      };
      final collapse = find.byKey(
        const ValueKey('channel-settings-collapse-switch'),
      );
      await t.ensureVisible(collapse);
      await t.tap(collapse);
      await t.pumpAndSettle();
      expect(find.text(_displayMsg), findsNothing);
      // A member change re-reads only the roster; that read succeeds.
      ChannelRosterInvalidations.of(w.client).invalidate('c1');
      await t.pumpAndSettle();
      expect(
        find.text(_displayMsg),
        findsNothing,
        reason: 'no read failed since the notice was cleared',
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
