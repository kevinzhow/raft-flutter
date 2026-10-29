import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';

/// Current Web shell seams: the 57px rail owns its right border; Chat adds
/// the sidebar's right border at297. Activity is an inset panel, so it does
/// not add a second line beside the rail. The full-width phone page keeps
/// the owner's intentional no-border rule.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final (page, mobile) in [
      ('chat', false),
      ('activity', false),
      ('activity', true),
    ]) {
      testWidgets(
        '[WP1] ${dark ? 'dark' : 'light'} ${mobile ? 'mobile ' : ''}$page vertical borders',
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
          await tester.pumpAndSettle();
          final railWidth = 57.0;
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
          final expected = mobile
              ? <String>[]
              : page == 'chat'
              ? ['R@297.0:1.0', 'R@57.0:1.0']
              : ['R@${railWidth.toStringAsFixed(1)}:1.0'];
          expect(found..sort(), expected..sort());
        },
      );
    }
  }
}
