import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/feature_flag_client_facts.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/joint_channel_link_intent.dart';
import 'package:raft_flutter/features/management_support.dart';

import 'announcement_cta_test.dart' as cta;
import 'announcement_host_test.dart' as host;
import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  test('consuming the only dialog parameter leaves a clean URL', () {
    final location = Uri.parse('/s/alpha?dialog=create-joint-channel#anchor');
    expect(
      withoutJointChannelLinkIntent(location),
      Uri.parse('/s/alpha#anchor'),
    );
  });

  for (final external in [true, false]) {
    testWidgets(
      'a joint-channel CTA uses the resolved External flag $external',
      (tester) async {
        final (fixture, externalLinks) = await cta.mount(
          tester,
          cta.row(
            cta: {'label': 'Create', 'href': '?dialog=create-joint-channel'},
          ),
        );
        rememberServerFlag(
          fixture.w,
          RaftFeatureFlags.externalChannels,
          external,
          pageIdentity(fixture.w),
        );
        await tester.tap(find.byKey(const ValueKey('announcement-ok')));
        await host.settle(tester);
        final current = find.byType(CreateChannelDialog);
        final legacy = find.byType(CreateJointChannelDialog);
        final externalPrefill = tester
            .widgetList<CreateChannelDialog>(current)
            .map((w) => w.prefilledVisibility)
            .toList();
        final legacyCount = legacy.evaluate().length;
        await tester.pumpWidget(const SizedBox.shrink());
        expect(externalLinks, isEmpty);
        expect(externalPrefill, external ? ['external'] : isEmpty);
        expect(legacyCount, external ? 0 : 1);
      },
    );
  }

  for (final role in ['owner', 'member']) {
    testWidgets('a direct joint intent is consumed for a $role', (
      tester,
    ) async {
      final flag = Completer<Map<String, dynamic>>();
      final fixture = RootFixture();
      fixture.servers.first['role'] = role;
      fixture.overrides['POST /feature-flags/evaluate'] = (_) => flag.future;
      fixture.overrides['GET /channels/external-availability'] = (_) => {
        'freeLimitReached': false,
      };
      final route = Uri.parse('/s/alpha/channel/ca?pin=a&pin=b#source');
      final incoming = route.replace(
        query: '${route.query}&dialog=create-joint-channel',
      );
      try {
        await fixture.mount(tester, 'light', 1280, uri: incoming);
        expect(fixture.router(tester).currentConfiguration, route);
        expect(find.byType(CreateJointChannelDialog), findsNothing);
        expect(find.byType(CreateChannelDialog), findsNothing);
        flag.complete({
          'evaluations': [
            {'key': 'external_channels_v1', 'enabled': true},
          ],
        });
        await fixture.flush(tester);
        final opened = find.byType(CreateChannelDialog);
        if (role == 'owner') {
          expect(
            tester.widget<CreateChannelDialog>(opened).prefilledVisibility,
            'external',
          );
          fixture.router(tester).navigatorKey.currentState!.pop();
          await fixture.flush(tester);
        }
        expect(opened, findsNothing);
        expect(find.byType(CreateJointChannelDialog), findsNothing);
        expect(fixture.router(tester).currentConfiguration, route);
        await fixture.pushUri(tester, route.toString());
        expect(opened, findsNothing);
      } finally {
        if (!flag.isCompleted) flag.complete({'evaluations': []});
        await fixture.close(tester);
      }
    });
  }
}
