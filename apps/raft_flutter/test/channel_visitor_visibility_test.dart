import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

// The channel / DM settings drawer as Web mounts it (ChannelOverflowMenu ->
// OverflowSheet + EditChannelDialog presentation="panel").

const _ownerCaps = {
  'editChannelMetadata': true,
  'archiveChannels': true,
  'deleteChannels': true,
  'changeChannelVisibility': true,
  'manageVisitorAccess': true,
  'federateChannels': false,
  'addChannelMembers': true,
  'removeChannelMembers': true,
  'changeChannelMemberRoles': true,
};

Map<String, dynamic> _row({
  String id = 'c1',
  String name = 'work',
  String type = 'channel',
  String description = 'Release gates',
  Map<String, dynamic>? caps = _ownerCaps,
  Map<String, dynamic> extra = const {},
}) => {
  'id': id,
  'name': name,
  'type': type,
  'description': description,
  'joined': true,
  'activityMuteSupported': true,
  'channelCapabilities': ?caps,
  ...extra,
};

void _routes(MessageAdapter api, {List<Map<String, dynamic>>? channels}) {
  api.routes['GET /channels/c1/members'] = (_) => {
    'humans': [
      {'id': 'u1', 'userId': 'u1', 'name': 'ana', 'displayName': 'Ana'},
      {'id': 'u2', 'userId': 'u2', 'name': 'bo', 'displayName': 'Bo'},
    ],
    'agents': [
      {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy', 'status': 'active'},
    ],
  };
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {
    'collapseLongMessages': true,
  };
  api.routes['GET /channels/c1/notification-settings'] = (_) => {
    'activityMuted': false,
  };
  api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'server_guest_v0', 'enabled': true},
    ],
  };
  api.routes['GET /channels'] = (_) => channels ?? [_row()];
  api.routes['GET /channels/dm'] = (_) => [];
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
}

/// Opens the drawer through its real route, from a host page.
Future<(WorkspaceController, MessageAdapter)> _open(
  WidgetTester t, {
  String role = 'owner',
  Map<String, dynamic>? row,
  String? dmName,
  Size size = const Size(1280, 1800),
  bool dark = false,
  Locale locale = const Locale('en'),
  RaftThemePack? pack,
  TargetPlatform? platform,
}) async {
  final (w, api) = (await t.runAsync(() => fixture(role)))!;
  addTearDown(w.dispose);
  final data = row ?? _row();
  _routes(api, channels: [data]);
  final channel = RaftChannel(data);
  if (channel.type == 'dm') {
    w
      ..channels = []
      ..dms = [channel];
  } else {
    w.channels = [channel];
  }
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(
        dark: dark,
        pack: pack,
        locale: locale,
      ).copyWith(platform: platform),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('host-open'),
              onPressed: () => ChannelSettings.show(
                context,
                controller: w,
                channel: channel,
                dmName: dmName,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const ValueKey('host-open')));
  await t.pumpAndSettle();
  return (w, api);
}

Finder _id(String id) => find.byKey(ValueKey(id));
List<RequestOptions> _writes(MessageAdapter api) => api.calls
    .where(
      (c) =>
          c.method != 'GET' &&
          !c.path.startsWith('/auth/') &&
          !c.path.startsWith('/feature-flags/'),
    )
    .toList();

void main() {
  testWidgets('visitor visibility uses the v1.24 capability and payload', (
    t,
  ) async {
    final (_, api) = await _open(
      t,
      row: _row(extra: {'visitorVisible': false}),
    );
    final visitor = _id('channel-settings-visitor-visible-switch');
    expect(visitor, findsOneWidget);
    expect(_id('channel-settings-guest-joinable-switch'), findsNothing);
    api.routes['PATCH /channels/c1'] = (_) =>
        _row(extra: {'visitorVisible': true});
    await t.ensureVisible(visitor);
    await t.tap(visitor);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(_writes(api).last.data, {'visitorVisible': true});
  });

  for (final scenario in <(String, Map<String, dynamic>)>[
    ('private', _row(type: 'private')),
    ('all', _row(name: 'all')),
    ('external relation', _row(extra: {'hasExternalRelation': true})),
    ('archived', _row(extra: {'archivedAt': '2026-01-01T00:00:00Z'})),
    (
      'without permission',
      _row(caps: {..._ownerCaps, 'manageVisitorAccess': false}),
    ),
  ]) {
    testWidgets('visitor switch hidden for ${scenario.$1}', (t) async {
      await _open(t, row: scenario.$2);
      expect(_id('channel-settings-visitor-visible-switch'), findsNothing);
    });
  }

  testWidgets('legacy guestVisible is readable and can be turned off', (
    t,
  ) async {
    final (_, api) = await _open(
      t,
      row: _row(type: 'private', extra: {'guestVisible': true}),
    );
    final visitor = _id('channel-settings-visitor-visible-switch');
    expect(visitor, findsOneWidget);
    api.routes['PATCH /channels/c1'] = (_) =>
        _row(type: 'private', extra: {'visitorVisible': false});
    await t.ensureVisible(visitor);
    await t.tap(visitor);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(_writes(api).last.data, {'visitorVisible': false});
    expect(visitor, findsOneWidget);
  });

  for (final scenario in <(String, Size, TargetPlatform)>[
    ('foldable portrait', const Size(856, 944), TargetPlatform.android),
    ('foldable landscape', const Size(944, 856), TargetPlatform.android),
    ('narrow desktop', const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('visitor visibility works on ${scenario.$1}', (t) async {
      final (_, api) = await _open(
        t,
        size: scenario.$2,
        platform: scenario.$3,
        locale: const Locale('zh'),
      );
      final visitor = _id('channel-settings-visitor-visible-switch');
      expect(find.text('游客可见'), findsOneWidget);
      api.routes['PATCH /channels/c1'] = (_) =>
          _row(extra: {'visitorVisible': true});
      await t.ensureVisible(visitor);
      await t.tap(visitor);
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      expect(_writes(api).single.data, {'visitorVisible': true});
    });
  }

  testWidgets('a failed visitor update can be retried', (t) async {
    final (_, api) = await _open(t);
    final visitor = _id('channel-settings-visitor-visible-switch');
    api.routes['PATCH /channels/c1'] = (_) => throw StateError('offline');
    await t.ensureVisible(visitor);
    await t.tap(visitor);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      find.text("Couldn't change whether visitors can see this channel."),
      findsOneWidget,
    );
    api.routes['PATCH /channels/c1'] = (_) =>
        _row(extra: {'visitorVisible': true});
    await t.tap(visitor);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      find.text("Couldn't change whether visitors can see this channel."),
      findsNothing,
    );
    expect(_writes(api).length, 2);
  });
}
