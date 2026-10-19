import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../message_presentation_test.dart' show MessageAdapter;
import '../workspace_source_location_contract_test.dart' show pageFixture;
import 'app_services_fixture.dart';

/// The three widths every closable surface is checked at: phone, foldable
/// (inner display of a fold, a wide layout) and desktop.
const closeSizes = <(String, Size)>[
  ('phone', Size(390, 844)),
  ('foldable', Size(816, 900)),
  ('desktop', Size(1280, 800)),
];

Future<void> frames(WidgetTester t, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> chatRow(String id, int seq, Map<String, dynamic> extra) =>
    {
      'id': id,
      'channelId': 'c1',
      'seq': '$seq',
      'messageType': 'chat',
      'content': 'Hello $id',
      'createdAt': '2026-06-22T02:30:00.000Z',
      ...extra,
    };

List<Map<String, dynamic>> closeRows() => [
  chatRow('mh', 1, {
    'senderId': 'bob',
    'senderType': 'user',
    'senderName': 'Bob',
    'content': 'human row',
  }),
  chatRow('mt', 2, {
    'senderId': 'u2',
    'senderType': 'user',
    'senderName': 'Dana',
    'content': 'thread parent',
    'replyCount': 1,
  }),
];

/// A full [WorkspaceView] at [size] over a fixture server with one channel
/// (`c1`), a human (`bob`), an agent (`a1`) and a thread (`t1`).
Future<(WorkspaceController, MessageAdapter)> mountWorkspace(
  WidgetTester t,
  Size size, {
  String section = 'chat',
  RaftFamily family = RaftFamily.elegant,
  TargetPlatform? platform,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final (w, api) = await pageFixture(t, section: section);
  api.routes['GET /messages/channel/c1'] = (_) => {'messages': closeRows()};
  api.routes['GET /channels/c1/available-mentions'] = (_) => {
    'humans': [],
    'agents': [],
  };
  const agent = {
    'id': 'a1',
    'name': 'cindy',
    'displayName': 'Cindy',
    'status': 'active',
    'runtime': 'claude',
    'model': 'sonnet',
  };
  api.routes['GET /agents'] = (_) => [agent];
  api.routes['GET /agents/a1'] = (_) => agent;
  api.routes['GET /agents/a1/skills'] = (_) => {'global': [], 'workspace': []};
  api.routes['GET /servers/s1/machines'] = (_) => {'machines': []};
  api.routes['GET /servers/s1/members'] = (_) => [
    {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob', 'role': 'member'},
    {'userId': 'u2', 'name': 'dana', 'displayName': 'Dana', 'role': 'member'},
  ];
  api.routes['GET /servers/s1/members/bob/profile'] = (_) => {
    'userId': 'bob',
    'displayName': 'Bob',
  };
  api.routes['GET /channels/c1/threads/mt'] = (_) => {'threadChannelId': 't1'};
  api.routes['GET /messages/channel/t1'] = (_) => {
    'messages': [
      chatRow('mt', 1, {
        'channelId': 't1',
        'senderId': 'u2',
        'senderType': 'user',
        'senderName': 'Dana',
        'content': 'thread parent',
      }),
    ],
  };
  api.routes['GET /channels/threads/followers'] = (_) => {'threads': []};
  await t.runAsync(() => w.entityDirectory.preload());
  w.messageDomain.ledger.ingest(
    closeRows(),
    expectedGeneration: w.messageDomain.ledger.generation,
  );
  w.messageDomain.visibleIds['c1'] = {
    for (final r in closeRows()) r['id'] as String,
  };
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family).copyWith(platform: platform),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(light: family),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await frames(t, 30);
  return (w, api);
}

Future<void> pressEscape(WidgetTester t) async {
  await t.sendKeyEvent(LogicalKeyboardKey.escape);
  await frames(t, 20);
}

/// The Android system back gesture / hardware Back.
Future<void> systemBack(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await frames(t, 20);
}

/// Taps the first match of [finder] and lets the route / layout settle.
Future<void> tapAndSettle(WidgetTester t, Finder finder) async {
  await t.tap(finder.first);
  await frames(t, 20);
}
