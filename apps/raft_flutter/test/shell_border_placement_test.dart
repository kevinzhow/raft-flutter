import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';

/// Vertical borders of the desktop shell, per page, as Web draws them:
/// - rail: Brutal `border-r-2` (1px on the Activity page: LeftRail
///   `thinDivider`), Elegant none;
/// - Chat: the Sidebar column owns the divider on its right edge, nothing sits
///   between the rail and the sidebar;
/// - Activity: the sidebar column is hidden and the inbox panel (raft-ui Panel
///   `edge="attached"`, `theme-brutal:!border-l`) owns the line at its LEFT
///   edge, beside the rail. Owner decision 2026-10-11 (overrides the Web
///   measurement of a line at x = 0): the mobile Activity page draws no
///   vertical border.
/// The desktop expectations are the measured Web DOM
/// (components.shell.*.activity.frame).
void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    for (final (page, mobile) in [
      ('chat', false),
      ('activity', false),
      ('activity', true),
    ]) {
      testWidgets(
        '[WP1] $family/$dark ${mobile ? 'mobile ' : ''}$page vertical borders',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = mobile
              ? const Size(390, 844)
              : const Size(1440, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.loading = false;
          w.messageDomain.ledger.switchServer('s1');
          w.section = page;
          api.routes['GET /channels/inbox'] = (_) => {'items': []};
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          api.routes['POST /feature-flags/evaluate'] = (_) => {
            'evaluations': [],
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: withAppServices(
                WorkspaceView(
                  controller: w,
                  appearance: RaftAppearance(light: family),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final railWidth = family == RaftFamily.brutal ? 64.0 : 56.0;
          final found = <String>[];
          void visit(RenderObject node) {
            if (node is RenderDecoratedBox && node.hasSize) {
              final d = node.decoration;
              if (d is BoxDecoration && d.border is Border) {
                final b = d.border! as Border;
                final o = node.localToGlobal(Offset.zero);
                if (b.left.width > 0 &&
                    b.left.style == BorderStyle.solid &&
                    node.size.height > 600) {
                  found.add('L@${o.dx}:${b.left.width}');
                }
                if (b.right.width > 0 &&
                    b.right.style == BorderStyle.solid &&
                    node.size.height > 600) {
                  found.add('R@${o.dx + node.size.width}:${b.right.width}');
                }
              }
            }
            node.visitChildren(visit);
          }

          visit(tester.binding.renderViews.first);
          final brutal = family == RaftFamily.brutal;
          final expected = mobile
              ? <String>[]
              : page == 'chat'
              ? (brutal ? ['R@64.0:2.0', 'R@304.0:2.0'] : ['R@296.0:1.0'])
              : (brutal
                    ? ['R@64.0:1.0', 'L@64.0:1.0']
                    : ['L@${railWidth.toStringAsFixed(1)}:1.0']);
          expect(found..sort(), expected..sort());
        },
      );
    }
  }
}
