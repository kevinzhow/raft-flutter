import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_announcement_host.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final enabled in [false, true]) {
    testWidgets(
      'channel announcement ${enabled ? 'shows' : 'stays hidden'} with its flag',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.client.user = RaftRecord({'id': 'alice', 'displayName': 'Ana'});
        w.channel = RaftChannel({
          'id': 'c1',
          'type': 'channel',
          'joined': true,
        });
        w.channels = [w.channel!];
        api.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [
            {'key': 'channel_announcement_v0', 'enabled': enabled},
          ],
        };
        api.routes['GET /channels/c1/announcement'] = (_) => {
          'announcement': {
            'artifactId': 'pt_123',
            'title': 'Read this',
            'version': 1,
            'updatedAt': '2026-11-01T00:00:00Z',
            'updatedBy': {'type': 'user', 'id': 'alice'},
            'seen': false,
          },
        };
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: ChannelAnnouncementHost(controller: w, channel: w.channel!),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Read this'), enabled ? findsOneWidget : findsNothing);
        expect(
          find.text('Ana updated it'),
          enabled ? findsOneWidget : findsNothing,
        );
        expect(
          api.calls.where((c) => c.path == '/channels/c1/announcement').length,
          enabled ? 1 : 0,
        );
      },
    );
  }
}
