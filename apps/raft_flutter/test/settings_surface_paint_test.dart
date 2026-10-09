import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'desktop_footer_sidebar_page_test.dart' show shellFonts;
import 'workspace_shell_contract_test.dart' show retire;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, frames, LocalNotifications;

// Source SettingsPanel.tsx:7911–7940 keeps the transparent Elegant header on
// the Panel's canvas-muted surface and the content on a separate panel surface.
// Exact Chromium samples are retained in the desktop-region-audit receipt.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final (tab, width) in [
      ('language-region', 1280.0),
      ('notifications', 1280.0),
      ('billing', 1280.0),
      ('administration', 1280.0),
      ('applications', 1280.0),
      ('language-region', 390.0),
    ]) {
      testWidgets(
        '$family/$dark $tab width$width actual Settings header inherits its own surface',
        (t) async {
          final (w, api) = await pageFixture(t, section: 'settings');
          api.routes['GET /servers/s1/notification-settings'] = (_) => {
            'serverPushMuted': false,
            'prefsVersion': 1,
          };
          final notifications = LocalNotifications();
          addTearDown(notifications.dispose);
          w.navigation.navigate(RaftLocation.parse('/s/demo/settings/$tab'));
          await shellFonts(t);
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final key = GlobalKey();
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: RepaintBoundary(
                key: key,
                child: WorkspaceView(
                  controller: w,
                  appearance: RaftAppearance(light: family),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                  notifications: notifications,
                ),
              ),
            ),
          );
          await frames(t, () {});
          await t.pumpAndSettle();
          final header = find.byType(RaftSettingsPanelHeader);
          expect(header, findsOneWidget);
          expect(t.widget<RaftSettingsPanelHeader>(header).title, switch (tab) {
            'language-region' => 'Language & Region',
            'notifications' => 'Notifications',
            'billing' => 'Plan & Billing',
            'administration' => 'Administration',
            _ => 'Applications',
          });
          expect(t.getRect(header).top, 0);
          expect(find.byType(RaftPageHeader), findsNothing);
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await t.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              List<int> rgb(int y) => [
                for (var c = 0; c < 3; c++)
                  data.getUint8((y * image.width + image.width - 8) * 4 + c),
              ];
              expect(
                rgb(28),
                family == RaftFamily.brutal
                    ? [255, 255, 255]
                    : dark
                    ? [13, 13, 11]
                    : [248, 248, 247],
                reason: 'Source transparent header inherits canvas-muted',
              );
              expect(
                rgb(780),
                dark ? [36, 36, 34] : [255, 255, 255],
                reason: 'Source content independently owns layer-panel',
              );
            } finally {
              image.dispose();
            }
          });
          await retire(t);
        },
        variant: TargetPlatformVariant({TargetPlatform.linux}),
      );
    }
  }
}
