import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_announcement_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'a channel manager retries, sets, replaces and removes an announcement',
    (t) async {
      const id = 'pt_db491d86-6156-4fe1-a742-01890ddbfffe';
      const replacement = 'pt_db491d86-6156-4fe1-a742-01890ddbffff';
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final channel = RaftChannel({
        'id': 'c1',
        'type': 'channel',
        'name': 'work',
        'joined': true,
        'channelCapabilities': {'editChannelMetadata': true},
      });
      w.channel = channel;
      w.channels = [channel];
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'channel_announcement_v0', 'enabled': true},
        ],
      };
      api.routes['GET /channels/c1/announcement'] = (_) => {
        'announcement': null,
      };
      Map<String, dynamic>? announcement;
      api.routes['GET /channels/c1/announcement'] = (_) => {
        'announcement': announcement,
      };
      api.routes['PATCH /channels/c1'] = (request) {
        final artifact = (request.data as Map)['announcement'];
        announcement = artifact == null
            ? null
            : {
                'artifactId': artifact,
                'title': artifact == id ? 'Release rules' : 'New rules',
                'version': 1,
                'seen': false,
                'updatedBy': {'id': 'u1', 'type': 'user', 'name': 'Ana'},
                'updatedAt': '2026-11-01T00:00:00Z',
              };
        return {'announcement': announcement};
      };
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ChannelAnnouncementSettings(controller: w, channel: channel),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Set announcement'));
      await t.pumpAndSettle();
      expect(
        find.text('Couldn’t load this channel’s Artifacts.'),
        findsOneWidget,
      );
      api.routes['GET /artifacts/conversations/c1'] = (_) => {
        'rows': [
          {
            'card': {'id': id, 'title': 'Release rules'},
          },
          {
            'card': {'id': replacement, 'title': 'New rules'},
          },
        ],
      };
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('Try again'), findsNothing);
      await t.tap(find.text('Release rules'));
      await t.pumpAndSettle();
      await t.tap(
        find.byKey(const Key('channel-settings-announcement-picker-confirm')),
      );
      await t.pumpAndSettle();
      expect(find.text('Release rules'), findsOneWidget);
      await t.tap(
        find.byKey(const Key('channel-settings-announcement-actions')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Replace'));
      await t.pumpAndSettle();
      expect(find.text('Try again'), findsNothing);
      await t.tap(find.text('New rules'));
      await t.pumpAndSettle();
      await t.tap(
        find.byKey(const Key('channel-settings-announcement-picker-confirm')),
      );
      await t.pumpAndSettle();
      expect(find.text('Replace announcement?'), findsOneWidget);
      expect(api.calls.where((r) => r.method == 'PATCH'), hasLength(1));
      await t.tap(
        find.byKey(const Key('channel-settings-announcement-replace-confirm')),
      );
      await t.pumpAndSettle();
      expect(find.text('New rules'), findsOneWidget);
      await t.tap(
        find.byKey(const Key('channel-settings-announcement-actions')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(find.text('Remove announcement?'), findsOneWidget);
      await t.tap(
        find.byKey(const Key('channel-settings-announcement-remove-confirm')),
      );
      await t.pumpAndSettle();
      expect(find.text('No announcement'), findsOneWidget);
      expect(api.calls.where((r) => r.method == 'PATCH').map((r) => r.data), [
        {'announcement': id},
        {'announcement': replacement},
        {'announcement': null},
      ]);
    },
  );
}
