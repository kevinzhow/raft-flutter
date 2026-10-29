import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'desktop_footer_sidebar_page_test.dart' show shellFonts;
import 'workspace_shell_contract_test.dart' show retire;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, frames, LocalNotifications;
import 'support/app_services_fixture.dart';

// Current Raft uses its approved panel-header surface; content independently
// owns layer-panel. Keep actual raster samples at both viewport widths.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final (tab, width) in [
      ('language-region', 1280.0),
      ('notifications', 1280.0),
      ('billing', 1280.0),
      ('administration', 1280.0),
      ('applications', 1280.0),
      ('language-region', 390.0),
    ]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} $tab width$width actual Settings header inherits its own surface',
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
              theme: raftTheme(dark: dark),
              home: RepaintBoundary(
                key: key,
                child: withAppServices(
                  WorkspaceView(
                    controller: w,
                    appearance: RaftAppearance(),
                    onAppearance: (_) async {},
                    onLogout: () async {},
                    notifications: notifications,
                  ),
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
          final headerTop = width >= 768 ? 48.0 : 0.0;
          expect(t.getRect(header).top, headerTop);
          expect(
            find.byType(RaftWorkspaceTopBar),
            width >= 768 ? findsOneWidget : findsNothing,
          );
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
              final colors =
                  (dark ? RaftTokenSet.dark : RaftTokenSet.light).colors;
              List<int> bytes(Color c) => [
                (c.r * 255).round(),
                (c.g * 255).round(),
                (c.b * 255).round(),
              ];
              expect(
                rgb(headerTop.toInt() + 28),
                bytes(
                  RaftTokens.theme(dark: dark).colors['layer-panel-header']!,
                ),
                reason: 'Raft header owns layer-panel-header',
              );
              expect(
                rgb(780),
                bytes(colors.layerPanel),
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
