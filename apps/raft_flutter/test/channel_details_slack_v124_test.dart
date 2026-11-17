import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;
import 'slack_channel_pairing_test.dart' show Bridge;

void main() {
  testWidgets(
    'Details connects Slack independently and offers cross-visibility choices',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final channel = RaftChannel({
        'id': 'c1',
        'name': 'work',
        'type': 'channel',
        'joined': true,
        'channelCapabilities': {'editChannelMetadata': true},
      });
      w.channel = channel;
      w.channels = [channel];
      final bridge = Bridge();
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'slack_bridge_v0', 'enabled': true},
        ],
      };
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['GET /servers/s1/sidebar-order'] = (_) => <String, dynamic>{};
      api.routes['GET /channels/c1/message-display-settings'] = (_) =>
          <String, dynamic>{};
      api.routes['GET /channels/c1/notification-settings'] = (_) => {
        'activityMuted': false,
      };
      api.routes['GET /slack-bridge/provisioning'] = (_) => bridge.snapshot();
      api.routes['PUT /slack-bridge/provisioning/channel-pairs'] = (request) {
        final pair = (request.data['pairs'] as List).single as Map;
        bridge.pairs.add({
          ...Map<String, dynamic>.from(pair),
          'bindingEpoch': 8,
        });
        return bridge.snapshot();
      };
      api.routes['POST /slack-bridge/provisioning/preflight'] = (_) =>
          bridge.snapshot(preflight: true);
      api.routes['POST /slack-bridge/provisioning/enable'] = (_) =>
          bridge.snapshot(preflight: true);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ChannelSettings(
              controller: w,
              channel: channel,
              isPanel: true,
              details: true,
              onClose: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      Finder key(String value) => find.byKey(ValueKey(value));
      final open = key('channel-settings-slack-open');
      expect(open, findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      await t.ensureVisible(open);
      await t.tap(open);
      await t.pumpAndSettle();
      expect(find.text('Connect #work to Slack'), findsOneWidget);
      final at = api.calls.length;
      await t.tap(key('channel-slack-bridge-select'));
      await t.pumpAndSettle();
      await t.tap(find.text('#secret — private in Slack'));
      await t.pumpAndSettle();
      expect(api.calls, hasLength(at));
      await t.tap(key('channel-settings-slack-confirm'));
      await t.pumpAndSettle();
      expect(api.calls.skip(at).map((r) => [r.method, r.path]), [
        ['GET', '/slack-bridge/provisioning'],
        ['PUT', '/slack-bridge/provisioning/channel-pairs'],
        ['POST', '/slack-bridge/provisioning/preflight'],
        ['POST', '/slack-bridge/provisioning/enable'],
      ]);
      expect(bridge.pairs.single['slackChannelId'], 's-priv');
      expect(find.text('#secret · Synced'), findsOneWidget);
      expect(find.byKey(const Key('channel-settings-name')), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
