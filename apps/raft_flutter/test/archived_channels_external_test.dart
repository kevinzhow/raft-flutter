import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/archived_channels_section.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

/// Web v1.24 ArchivedChannelsSection `channelTypeMessageId`: a channel with a
/// Guest or an open external invite reads as a joint (external) channel.
Map<String, dynamic> _row(String id, String type, {bool? external}) => {
  'id': id,
  'name': id,
  'type': type,
  'serverId': 's',
  'joined': true,
  'archivedAt': '2026-06-10T09:00:00.000Z',
  'hasExternalRelation': ?external,
};

void main() {
  testWidgets('external channels are labelled Joint channel, others by type', (
    t,
  ) async {
    final client = ScreenFixtureClient(
      (method, path, query) => <String, dynamic>{},
      user: {'id': 'alice', 'preferredTimezone': 'UTC'},
      server: 's',
    );
    final w = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 's',
        'name': 'S',
        'slug': 's',
        'role': 'owner',
      });
    w.channels = [
      for (final r in [
        _row('pub', 'channel'),
        _row('ext-pub', 'channel', external: true),
        _row('ext-priv', 'private', external: true),
        _row('priv', 'private', external: false),
      ])
        RaftChannel(r),
    ];
    addTearDown(w.dispose);
    t.view.physicalSize = const Size(1000, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: ArchivedChannelsSection(controller: w)),
      ),
    );
    await t.pump();
    expect(find.textContaining('Public channel · Archived'), findsOneWidget);
    expect(find.textContaining('Private channel · Archived'), findsOneWidget);
    expect(find.textContaining('Joint channel · Archived'), findsNWidgets(2));
  });
}
