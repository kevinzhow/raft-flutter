import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_announcement_settings.dart';
import 'package:raft_flutter/features/channel_announcement_store.dart';
import 'package:raft_flutter/features/channel_details_slack.dart';
import 'package:raft_flutter/features/channel_section_select.dart';
import 'package:raft_flutter/features/channel_announcement_strip.dart';
import 'package:raft_flutter/features/slack_channel_pairing.dart';

import 'close_dialogs_test.dart' show anyX;
import 'message_presentation_test.dart' show fixture;
import 'slack_channel_pairing_test.dart' show Bridge;
import 'close_popups_test.dart' show farPoint, mountHost, openWhile;
import 'support/close_registry_channel_announcement.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

void main() {
  registerCloseTests(channelAnnouncementSurfaces, {
    'channel-details-slack': (t, size) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /slack-bridge/provisioning'] = (_) => Bridge().snapshot();
      final pairing = SlackChannelPairing(w, channelId: 'c1');
      addTearDown(pairing.dispose);
      await t.runAsync(() => pairing.load(canManage: true, flagEnabled: true));
      await mountHost(
        t,
        size,
        (_) => ChannelDetailsSlack(
          channel: w.channel!,
          pairing: pairing,
          enabled: true,
        ),
      );
      await t.tap(find.byKey(const Key('channel-settings-slack-open')));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(
          find.byKey(const Key('channel-settings-slack-confirm')),
        ),
        x: anyX,
      );
    },
    for (final id in [
      'channel-announcement-actions',
      'channel-announcement-picker',
      'channel-announcement-confirm',
    ])
      id: (t, size) async {
        final empty = id == 'channel-announcement-picker';
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        final channel = RaftChannel({
          'id': 'c1',
          'type': 'channel',
          'name': 'work',
          'joined': true,
          'channelCapabilities': {'editChannelMetadata': true},
        });
        api.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [
            {'key': 'channel_announcement_v0', 'enabled': true},
          ],
        };
        api.routes['GET /channels/c1/announcement'] = (_) => {
          'announcement': empty
              ? null
              : {
                  'artifactId': 'pt_123',
                  'title': 'Announcement',
                  'version': 1,
                  'updatedAt': '2026-11-01T00:00:00Z',
                  'updatedBy': {'type': 'user', 'id': 'u1', 'name': 'Ana'},
                  'seen': false,
                },
        };
        api.routes['GET /artifacts/conversations/c1'] = (_) => {'rows': []};
        await mountHost(
          t,
          size,
          (_) => ChannelAnnouncementSettings(controller: w, channel: channel),
        );
        await t.pumpAndSettle();
        if (empty) {
          await t.tap(find.text('Set announcement'));
        } else {
          await t.tap(
            find.byKey(const Key('channel-settings-announcement-actions')),
          );
          await frames(t, 15);
          if (id == 'channel-announcement-confirm') {
            await t.tap(find.text('Remove'));
          }
        }
        await frames(t, 15);
        final surface = switch (id) {
          'channel-announcement-actions' => find.byKey(
            const Key('channel-settings-announcement-menu'),
          ),
          'channel-announcement-picker' => find.byKey(
            const Key('channel-settings-announcement-picker-confirm'),
          ),
          _ => find.byKey(
            const Key('channel-settings-announcement-remove-confirm'),
          ),
        };
        return SurfaceProbe(
          isOpen: openWhile(surface),
          x: anyX,
          scrim: farPoint(size),
        );
      },
    'channel-sidebar-section': (t, size) async {
      final (w, _) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final channel = RaftChannel({
        'id': 'c1',
        'type': 'channel',
        'name': 'work',
        'joined': true,
      });
      await mountHost(
        t,
        size,
        (_) => ChannelSectionSelect(controller: w, channel: channel),
      );
      await t.tap(find.byKey(const Key('channel-settings-section-select')));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Create section')),
        scrim: farPoint(size),
      );
    },
    'channel-announcement-menu': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => ChannelAnnouncementStrip(
          announcement: const ChannelAnnouncement(
            artifactId: 'pt_123',
            title: 'Announcement',
            version: 1,
            updatedAt: '2026-11-01T00:00:00Z',
            updatedBy: {'type': 'user', 'id': 'u1', 'name': 'Ana'},
            seen: false,
          ),
          webOrigin: Uri.parse('https://example.invalid'),
          onOpen: () {},
        ),
      );
      await t.tap(find.byKey(const Key('channel-announcement-strip-options')));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(
          find.byKey(const Key('channel-announcement-strip-menu')),
        ),
        scrim: farPoint(size),
      );
    },
  });
}
