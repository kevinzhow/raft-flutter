import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'desktop_footer_sidebar_page_test.dart' show shellFonts;
import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

// Activity retains its thin divider, but navigation slots keep the regular
// border-box geometry on every route (Kevin bd97261a).
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} Activity divider does not move actual navigation slots',
      (t) async {
        final (w, _) = await pageFixture(t, section: 'activity');
        w.navigation.navigate(RaftLocation.parse('/s/demo/activity'));
        await shellFonts(t);
        await mountShell(t, w, dark);
        final help = find.byKey(const Key('rail-help'));
        final expectedCenter = 28.0;
        void checkGeometry() {
          expect(t.getRect(help).width, 40);
          expect(t.getCenter(help).dx, expectedCenter);
          final rail = find.byType(RaftWorkspaceRail);
          final border = find.descendant(
            of: rail,
            matching: find.byWidgetPredicate((widget) {
              if (widget is! DecoratedBox ||
                  widget.decoration is! BoxDecoration) {
                return false;
              }
              final decoration = widget.decoration as BoxDecoration;
              return widget.position == DecorationPosition.foreground &&
                  decoration.border is Border;
            }),
          );
          expect(border, findsOneWidget);
          final edge =
              (t.widget<DecoratedBox>(border).decoration as BoxDecoration)
                      .border!
                  as Border;
          expect(edge.right.width, 1);
          expect(t.getRect(rail).width, 57);
        }

        expect(t.getRect(help).width, 40);
        checkGeometry();
        await t.tap(find.byKey(const Key('rail-chat')));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(w.location.route, RaftRoute.channel);
        expect(w.location.entityId, 'c1');
        checkGeometry();
        await t.tap(find.byKey(const Key('rail-activity')));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(w.location.route, RaftRoute.activity);
        checkGeometry();
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
  }
}
