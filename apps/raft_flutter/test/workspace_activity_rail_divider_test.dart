import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';

import 'desktop_footer_sidebar_page_test.dart' show shellFonts;
import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

// Actual Source MainLayout:2280 passes isActivityRoute to LeftRail:563.
// DOM observations: Brutal Activity footer x11.5/w40; other Brutal routes
// x11/w40. Elegant keeps its independent x8/w40 geometry in both routes.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark actual Activity caller supplies its thin rail divider',
      (t) async {
        final (w, _) = await pageFixture(t, section: 'activity');
        w.navigation.navigate(RaftLocation.parse('/s/demo/activity'));
        await shellFonts(t);
        await mountShell(t, w, family, dark);
        final help = find.byKey(const Key('rail-help'));
        final expectedActivity = family == RaftFamily.brutal ? 31.5 : 28.0;
        final expectedChat = family == RaftFamily.brutal ? 31.0 : 28.0;
        expect(t.getRect(help).width, 40);
        expect(t.getCenter(help).dx, expectedActivity);
        await t.tap(find.byKey(const Key('rail-chat')));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(w.location.route, RaftRoute.channel);
        expect(w.location.entityId, 'c1');
        expect(t.getCenter(help).dx, expectedChat);
        await t.tap(find.byKey(const Key('rail-activity')));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(w.location.route, RaftRoute.activity);
        expect(t.getCenter(help).dx, expectedActivity);
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
  }
}
