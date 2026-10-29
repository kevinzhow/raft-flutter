import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'workspace_channel_settings_identity_test.dart' show settingsFixture;
import 'task_surface_test.dart' show flush;
import 'support/app_services_fixture.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Mobile DM settings push a page with no metadata editor ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (w, api) = await settingsFixture(t);
        final dm = RaftChannel({
          ...w.channel!.json,
          'type': 'dm',
          'peerName': 'alice',
          'peerDisplayName': 'Alice',
        });
        w.channel = dm;
        w.channels = [];
        w.dms = [dm];
        w.navigation.navigate(
          RaftLocation.at(
            serverSlug: w.location.serverSlug,
            route: RaftRoute.dm,
            entityId: dm.id,
          ),
        );
        api.routes['GET /channels/dm'] = (_) => [dm.json];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
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
        await flush(t);
        await t.pumpAndSettle();
        final base = w.location;
        final pages = mobilePageEntries(w.navigation).length;
        final rosterReads = api.calls
            .where((r) => r.path == '/channels/c1/members')
            .length;
        await t.tap(find.byTooltip('Channel Details and Settings'));
        await t.pump();
        expect(
          ModalRoute.of(t.element(find.byType(ChannelSettings)))
              ?.animation
              ?.value,
          lessThan(1),
        );
        await flush(t);
        await t.pumpAndSettle();
        expect(w.location.channelPage?.kind, RaftChannelPage.settings);
        expect(mobilePageEntries(w.navigation), hasLength(pages + 1));
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Direct message'), findsOneWidget);
        expect(find.byType(RaftOverflowSheet), findsOneWidget);
        expect(find.byType(RaftChannelSettingsSheet), findsNothing);
        expect(find.byType(RaftChannelInfoForm), findsNothing);
        expect(find.byType(RaftMembersStrip), findsNothing);
        // Web's Drawer Back: px-4 + half of the `icon-sm` button (raft-ui 0.7.0
        // `iconMd`, `size-8`: 32px in the Raft look); no left edge line on the
        // phone (owner decision 2026-10-12).
        expect(
          t.getCenter(find.byKey(const ValueKey('channel-overflow-back'))).dx,
          16 + 16,
        );
        expect(
          api.calls.where((r) => r.path == '/channels/c1/members'),
          hasLength(rosterReads),
        );
        expect(
          find.byKey(const ValueKey('channel-settings-edit')),
          findsNothing,
        );
        expect(find.byType(TextField), findsNothing);
        expect(t.testTextInput.isVisible, isFalse);
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(w.location, base);
        expect(find.byType(ChannelSettings), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
