import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_announcement_session.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final enabled in [false, true]) {
    testWidgets('announcement flag $enabled controls the request', (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.channel = RaftChannel({'id': 'c1', 'type': 'channel', 'joined': true});
      w.channels = [w.channel!];
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'channel_announcement_v0', 'enabled': enabled},
        ],
      };
      api.routes['GET /channels/c1/announcement'] = (_) => {
        'announcement': null,
      };
      await t.runAsync(() async {
        final session = ChannelAnnouncementSession.of(w);
        await session.ready;
        await session.load('c1');
      });
      expect(
        api.calls.where((c) => c.path == '/channels/c1/announcement').length,
        enabled ? 1 : 0,
      );
    });
  }

  testWidgets(
    'setting an announcement sends one patch and accepts its response',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'channel_announcement_v0', 'enabled': true},
        ],
      };
      api.routes['PATCH /channels/c1'] = (_) => {
        'id': 'c1',
        'announcement': {
          'artifactId': 'pt_123',
          'title': 'Notice',
          'version': 1,
          'updatedAt': '2026-11-01T00:00:00Z',
          'updatedBy': {'type': 'user', 'id': 'u1', 'name': 'Ana'},
          'seen': false,
        },
      };
      await t.runAsync(() async {
        final session = ChannelAnnouncementSession.of(w);
        await session.ready;
        await session.setAnnouncement('c1', 'pt_123');
        expect(session.store.forChannel('c1')?.title, 'Notice');
      });
      final writes = api.calls.where((c) => c.method == 'PATCH').toList();
      expect(writes, hasLength(1));
      expect(writes.single.data, {'announcement': 'pt_123'});
    },
  );
}
