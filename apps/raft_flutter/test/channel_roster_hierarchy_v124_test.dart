import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

void main() {
  for (final dark in [false, true]) {
    for (final (size, platform, minimum) in [
      (const Size(856, 944), TargetPlatform.android, 56.0),
      (const Size(944, 856), TargetPlatform.android, 56.0),
      (const Size(390, 844), TargetPlatform.linux, 64.0),
    ]) {
      testWidgets(
        'roster uses member identity hierarchy at $size $platform dark=$dark',
        (t) async {
          final (w, api) = (await t.runAsync(() => fixture()))!;
          addTearDown(w.dispose);
          addTearDown(w.client.dispose);
          final channel = RaftChannel({
            'id': 'c1',
            'name': 'work',
            'type': 'channel',
            'serverId': 's1',
          });
          w.channels = [channel];
          api.routes['GET /channels/c1/members'] = (_) => {
            'humans': [
              {
                'id': 'bob',
                'name': 'Bob',
                'description': 'Maintainer',
                'effectiveChannelRole': 'admin',
              },
              {'id': 'carla', 'name': 'Carla'},
            ],
            'agents': [
              {
                'id': 'a-app',
                'name': 'helper',
                'managedByAppInstallId': 'install-1',
                'managedByApp': {'name': 'Deploy'},
              },
            ],
          };
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark).copyWith(platform: platform),
              home: Scaffold(
                body: ChannelMembers(
                  controller: w,
                  channel: channel,
                  page: true,
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final row = find.byKey(const ValueKey('member-page-row-human-bob'));
          expect(t.getSize(row).height, greaterThanOrEqualTo(minimum));
          expect(
            t.widget<Text>(find.text('Bob')).style!.fontWeight,
            FontWeight.w600,
          );
          final avatar = find.descendant(
            of: row,
            matching: find.byType(RaftMountedAvatarFrame),
          );
          expect(t.getSize(avatar).width, 35);
          expect(
            t
                .widget<RaftBadge>(
                  find.widgetWithText(RaftBadge, 'Channel admin'),
                )
                .appearance,
            RaftBadgeRecipeAppearance.outline,
          );
          expect(find.text('App · Deploy'), findsOneWidget);
          final second = find.byKey(
            const ValueKey('member-page-row-human-carla'),
          );
          final rule = find.byKey(
            const ValueKey('member-page-row-human-carla-rule'),
          );
          expect(t.getTopLeft(rule).dx - t.getTopLeft(second).dx, 63);
          final tokens = RaftTokens.of(t.element(row));
          expect(
            t.widget<ColoredBox>(rule).color,
            tokens.colors['line-hairline'],
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
