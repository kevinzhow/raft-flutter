// A sub-page opened inside the channel side pane shows exactly one header.
//
// Kevin, 2026-11-26 (task #377, screenshot k12745): on an unfolded foldable
// the pane drew "← 详情" and, under it, the members page's own "← 成员 3".
// `RaftOverflowBareSheet` is documented as the drawer popup *without* its
// header, "holding a page that brings its own" (channel_overflow_sheet.dart),
// but its `details` branch drew one anyway, so the members page stacked a
// second bar under it. The sheet is mounted only while Members is open, so
// the Details root keeps its own header from the offstage root.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/private_route_guard.dart';

import 'workspace_channel_settings_identity_test.dart'
    show settingsFixture, mountSettingsWorkspace;

void main() {
  // Every screen class that hosts Details in the side pane. Below 768 the
  // phone pushes a route instead, which never had the second bar.
  const sizes = <String, Size>{
    'foldable 884x1104': Size(884, 1104),
    'unfolded 1124x1240': Size(1124, 1240),
    'tablet 1180x820': Size(1180, 820),
    'desktop 1440x900': Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    testWidgets('members inside the Details pane shows one header at '
        '${entry.key}', (t) async {
      final (w, _) = await settingsFixture(t);
      await mountSettingsWorkspace(t, w, false, PrivateRouteGuard());
      t.view.physicalSize = entry.value;
      await t.pumpAndSettle();

      // The Details root owns the only header while its roster is closed.
      expect(find.text('Details'), findsOneWidget);
      expect(find.byKey(const ValueKey('member-page-back')), findsNothing);

      await t.tap(find.byKey(const ValueKey('channel-overflow-members-entry')));
      await t.pumpAndSettle();

      // The members page replaces the Details header; its back returns there.
      expect(find.byKey(const ValueKey('member-page-back')), findsOneWidget);
      expect(find.text('Details'), findsNothing);

      await t.tap(find.byKey(const ValueKey('member-page-back')));
      await t.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      expect(find.byKey(const ValueKey('member-page-back')), findsNothing);

      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });
  }
}
