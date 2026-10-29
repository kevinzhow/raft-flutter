// The phone channel Members page reaches the screen's bottom edge (edge to
// edge), so its bottom controls pad themselves by the system gesture-bar
// inset instead of sitting under the gesture pill.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/private_route_guard.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'task_surface_test.dart' show flush;
import 'workspace_channel_settings_identity_test.dart' show settingsFixture;
import 'support/app_services_fixture.dart';

const _dpr = 2.625;
const _gesturePx = 48.0;

void main() {
  for (final (dark) in [(false), (true)]) {
    testWidgets(
      'members page clears the gesture bar ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(1081, 2402);
        t.view.devicePixelRatio = _dpr;
        t.view.viewPadding = const FakeViewPadding(
          top: 100,
          bottom: _gesturePx,
        );
        t.view.padding = const FakeViewPadding(top: 100, bottom: _gesturePx);
        addTearDown(() {
          t.view.reset();
          t.view.resetPadding();
          t.view.resetViewPadding();
        });
        final (w, api) = await settingsFixture(t);
        w.channel = RaftChannel({
          ...w.channel!.json,
          'channelCapabilities': {
            ...w.channel!.json['channelCapabilities'] as Map,
            'addChannelMembers': true,
          },
        });
        w.channels = [w.channel!];
        api.routes['GET /channels'] = (_) => [w.channel!.json];
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [
          {'userId': 'alice', 'name': 'Alice'},
          {'userId': 'bob', 'name': 'Bob'},
        ];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            navigatorObservers: [PrivateRouteGuard()],
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
        await t.tap(find.byTooltip('Channel Details and Settings'));
        await flush(t);
        await t.pumpAndSettle();
        await t.tap(
          find.byKey(const ValueKey('channel-overflow-members-entry')),
        );
        await flush(t);
        await t.pumpAndSettle();
        expect(find.byType(ChannelMembers), findsOneWidget);

        final screenH = t.view.physicalSize.height / _dpr;
        final inset = _gesturePx / _dpr;
        // p-3 footer around the button: the button must end `12 + inset` above
        // the screen bottom, i.e. fully above the gesture pill.
        double bottomGap(String key) =>
            screenH - t.getRect(find.byKey(ValueKey(key))).bottom;
        expect(
          bottomGap('add-member-open'),
          greaterThanOrEqualTo(12 + inset - .5),
          reason: 'Add member button sits under the gesture bar',
        );
        // The footer's own background and rule still reach the screen edge.
        final footer = find.ancestor(
          of: find.byKey(const ValueKey('add-member-open')),
          matching: find.byType(Container),
        );
        expect(
          t.getRect(footer.first).bottom,
          closeTo(screenH, .5),
          reason: 'footer must paint to the screen bottom',
        );

        await t.tap(find.byKey(const ValueKey('add-member-open')));
        await t.pumpAndSettle();
        expect(
          bottomGap('add-member-confirm'),
          greaterThanOrEqualTo(12 + inset - .5),
          reason: 'Add selected button sits under the gesture bar',
        );
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }
}
