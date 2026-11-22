// The Members page's widths on desktop, as Web v1.24 lays them out: the page
// is the row's main column beside the rail (MainLayout `thread-main-column`
// flex-1, no sidebar on Members: shellRouteLayout.ts hideSidebar), and a person
// or agent opens in the profile column beside it. The seam between them trades
// width (rowSeams.ts startSeamDrag, seamCascade.ts cascadeSeam): the profile
// grows until the list is at the row's 160 (SEAM_COLUMN_MIN_WIDTH), not up to
// a fixed 600 that leaves the list as wide as the window allows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_flutter/features/panel_width_store.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';
import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  tearDown(DevicePreferences.reset);

  for (final window in const [Size(1920, 1080), Size(1280, 720)]) {
    testWidgets('Members at ${window.width.toInt()}: the list fills the page; '
        'with a profile open the seam takes it down to 160', (t) async {
      t.view.physicalSize = window;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final (w, api) = await pageFixture(t, section: 'members');
      // Runs before the fixture's own teardown (w.dispose): last added, first run.
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
      final prefs = await t.runAsync(SharedPreferences.getInstance);
      DevicePreferences.adopt(prefs!);
      api.routes['GET /agents'] = (_) => [];
      api.routes['GET /servers/s1/members'] = (_) => [
        {'userId': 'h1', 'name': 'Public human', 'role': 'member'},
      ];
      api.routes['GET /servers/s1/members/h1/profile'] = (_) => {
        'userId': 'h1',
        'name': 'Public human',
      };
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
      final list = find.byKey(const Key('desktop-master-panel'));
      // Nothing open: the list is the whole page right of the rail.
      final page = t.getRect(list);
      expect(page.right, window.width);
      expect(page.width, greaterThan(window.width - 120));

      await t.tap(find.text('Public human').first);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(MemberProfileView), findsOneWidget);
      // The profile column at its default width; the list keeps the rest.
      expect(t.getRect(list).left, page.left);
      expect(t.getSize(list).width, page.width - 380);

      // Drag the seam all the way left: the list gives way down to 160.
      final handle = find.byKey(const Key('profile-resize-handle'));
      final drag = await t.startGesture(t.getCenter(handle));
      await drag.moveBy(const Offset(-40, 0));
      await drag.moveBy(Offset(-window.width, 0));
      await drag.up();
      await t.pump();
      expect(t.getSize(list).width, 160);
      // What shows is what is saved, and the next open has it.
      expect(profilePanelWidth.value, page.width - 160);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }
}
