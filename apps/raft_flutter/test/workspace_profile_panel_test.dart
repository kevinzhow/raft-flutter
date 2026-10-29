import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/external_identity.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'support/app_services_fixture.dart';

void main() {
  for (final width in [1280.0, 390.0]) {
    testWidgets(
      'the profile slot shows the panel and Back / close return ($width)',
      (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
        api.routes['GET /channels/c1/available-mentions'] = (_) => {
          'humans': [],
          'agents': [],
        };
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(find.byKey(const Key('profile-panel')), findsNothing);
        w.openProfile(
          RaftProfileKind.external,
          'm1',
          channelId: 'c1',
          externalAuthor: const {
            'displayName': 'Ada Lovelace',
            'provider': 'slack',
            'actorKind': 'human',
            'workspaceName': 'Acme Product Studio',
          },
        );
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(find.byKey(const Key('profile-panel')), findsOneWidget);
        expect(find.byType(ExternalIdentityDetailPanel), findsOneWidget);
        expect(find.text('Acme Product Studio'), findsOneWidget);
        if (width > 800) {
          // Desktop: a close control; the channel stays beside the panel.
          await t.tap(find.byTooltip('Close'));
        } else {
          // Phone: a page of the stack; its back chevron pops it.
          await t.tap(find.byKey(const Key('external-mobile-back')));
        }
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(w.location.profile, isNull);
        expect(find.byKey(const Key('profile-panel')), findsNothing);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      },
    );
  }
}
