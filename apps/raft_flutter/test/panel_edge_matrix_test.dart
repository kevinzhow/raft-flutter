import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_master_detail.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/task_surface_previews.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'support/panel_edge_registry.dart';
import 'workspace_activity_activation_test.dart'
    show channelRow, message, threadRow;
import 'support/app_services_fixture.dart';

/// The attached left edge shows everywhere except on a full-width standalone
/// phone page (`RaftPanelEdge`). Every registered panel surface is mounted at
/// phone (390), foldable (816, 841) and desktop (1280) in each theme, and the
/// painted vertical rule (a decoration's left / right border) is looked up at
/// the surface's left edge. Before the shared rule the Activity / Search
/// detail had no divider at all at 816+ (the master/detail wrapper drew none);
/// this fails there and now passes.
class PaintedRule {
  const PaintedRule(this.x, this.width, this.height, this.color);
  final double x, width, height;
  final Color color;
  @override
  String toString() => 'rule(x=$x w=$width h=$height $color)';
}

List<PaintedRule> paintedRules() {
  final rules = <PaintedRule>[];
  void visit(RenderObject node) {
    if (node is RenderDecoratedBox && node.hasSize) {
      final d = node.decoration;
      if (d is BoxDecoration && d.border is Border) {
        final b = d.border! as Border;
        final o = node.localToGlobal(Offset.zero);
        if (b.left.width > 0 && b.left.style == BorderStyle.solid) {
          rules.add(
            PaintedRule(o.dx, b.left.width, node.size.height, b.left.color),
          );
        }
        if (b.right.width > 0 && b.right.style == BorderStyle.solid) {
          rules.add(
            PaintedRule(
              o.dx + node.size.width - b.right.width,
              b.right.width,
              node.size.height,
              b.right.color,
            ),
          );
        }
      }
    }
    node.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.renderViews.first);
  return rules;
}

typedef _Mount = Future<double?> Function(WidgetTester t, double width);

void main() {
  const widths = <double>[390, 816, 841, 1280];

  Future<void> pumpUi(
    WidgetTester t,
    double width,
    RaftFamily family,
    bool dark,
    Widget home,
  ) async {
    t.view.physicalSize = Size(width, width < 768 ? 844 : 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: Scaffold(body: home),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> pumpWorkspace(
    WidgetTester t,
    double width,
    RaftFamily family,
    bool dark, {
    required bool openThread,
  }) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = Size(width, width < 768 ? 844 : 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.loading = false;
    w.messageDomain.ledger.switchServer('s1');
    w.section = 'activity';
    api.routes['GET /channels/inbox'] = (_) => {
      'items': [threadRow, channelRow],
    };
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [message('parent', 'c1')],
    };
    api.routes['GET /messages/context/reply'] = (_) => {
      'messages': [message('reply', 'thread-1')],
    };
    api.routes['GET /channels/c1/threads/parent'] = (_) => {
      'threadChannelId': 'thread-1',
    };
    api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    api.routes['POST /channels/thread-1/read'] = (_) => {};
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    await t.pumpWidget(
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
    await t.pumpAndSettle();
    if (!openThread) return;
    await t.tap(find.byKey(const ValueKey('activity-thread-thread-1')));
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
  }

  double leftOf(WidgetTester t, Finder f) => t.getTopLeft(f.first).dx;

  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ], full: true)) {
    final mounts = <String, _Mount>{
      'settings-panel': (t, width) async {
        await pumpUi(
          t,
          width,
          family,
          dark,
          const RaftSettingsPanelFrame(
            header: SizedBox(height: 56),
            child: SizedBox.expand(),
          ),
        );
        return leftOf(t, find.byType(RaftSettingsPanelFrame));
      },
      'channel-drawer': (t, width) async {
        await pumpUi(
          t,
          width,
          family,
          dark,
          RaftOverflowSheet(
            title: '#general',
            onClose: () {},
            page: width < 768,
            children: const [SizedBox(height: 40)],
          ),
        );
        return leftOf(t, find.byKey(const ValueKey('channel-overflow-sheet')));
      },
      'members-page': (t, width) async {
        await pumpUi(
          t,
          width,
          family,
          dark,
          RaftOverflowBareSheet(
            page: width < 768,
            child: const SizedBox.expand(),
          ),
        );
        return leftOf(t, find.byKey(const ValueKey('channel-overflow-sheet')));
      },
      'channel-settings-sheet': (t, width) async {
        await pumpUi(
          t,
          width,
          family,
          dark,
          RaftChannelSettingsSheet(
            page: width < 768,
            channelName: 'general',
            onClose: () {},
          ),
        );
        return leftOf(
          t,
          find.descendant(
            of: find.byType(RaftChannelSettingsSheet),
            matching: find.byType(SizedBox),
          ),
        );
      },
      'task-thread-panel': (t, width) async {
        await pumpUi(t, width, family, dark, taskModalPreview());
        // The modal frame has its own all-round border; the thread panel's
        // edge starts one border width inside it.
        final frame = find.byKey(const ValueKey('task-thread-modal'));
        if (width < 768 || frame.evaluate().isEmpty) return 0;
        return leftOf(t, frame) + (family == RaftFamily.brutal ? 2 : 1);
      },
      'workspace-thread-panel': (t, width) async {
        await pumpUi(
          t,
          width,
          family,
          dark,
          RaftAdaptiveWorkspace(
            rail: const SizedBox.shrink(),
            sidebar: const SizedBox.expand(),
            content: const SizedBox.expand(),
            thread: const SizedBox.expand(key: ValueKey('probe')),
          ),
        );
        final panel = find.byKey(const Key('workspace-thread-panel'));
        return leftOf(
          t,
          panel.evaluate().isNotEmpty
              ? panel
              : find.byKey(const ValueKey('probe')),
        );
      },
      'workspace-profile-panel': (t, width) async {
        await pumpUi(
          t,
          width,
          family,
          dark,
          RaftAdaptiveWorkspace(
            rail: const SizedBox.shrink(),
            sidebar: const SizedBox.expand(),
            content: const SizedBox.expand(),
            profile: const SizedBox.expand(key: ValueKey('probe')),
          ),
        );
        final panel = find.byKey(const Key('workspace-profile-panel'));
        return leftOf(
          t,
          panel.evaluate().isNotEmpty
              ? panel
              : find.byKey(const ValueKey('probe')),
        );
      },
      'activity-inbox': (t, width) async {
        await pumpWorkspace(t, width, family, dark, openThread: false);
        return leftOf(t, find.byKey(const Key('desktop-master-panel')));
      },
      'activity-thread-detail': (t, width) async {
        // A phone tap opens the conversation as a page (no detail beside the
        // list): nothing to look for.
        if (width < 768) return null;
        await pumpWorkspace(t, width, family, dark, openThread: true);
        expect(find.byKey(const Key('desktop-content-detail')), findsOneWidget);
        return leftOf(t, find.byKey(const Key('desktop-content-detail')));
      },
      'search-detail': (t, width) async {
        await pumpUi(
          t,
          width,
          family,
          dark,
          const DesktopMasterDetail(
            master: SizedBox.expand(),
            detail: SizedBox.expand(),
            masterEdge: true,
          ),
        );
        return leftOf(t, find.byKey(const Key('desktop-content-detail')));
      },
    };
    for (final surface in panelEdgeSurfaces) {
      for (final width in widths) {
        testWidgets(
          '[edge] ${surface.id} $family/${dark ? 'dark' : 'light'} @$width: '
          '${width < 768 ? 'phone page draws no left edge' : 'left edge is painted'}',
          (t) async {
            final mount = mounts[surface.id];
            expect(mount, isNotNull, reason: '${surface.id} has no mount');
            final edgeX = await mount!(t, width);
            if (edgeX == null) return;
            final drawn =
                width >= 768 &&
                (family == RaftFamily.brutal || surface.elegantDraws);
            final lineWidth = family == RaftFamily.brutal
                ? surface.brutalWidth
                : 1.0;
            final rules = paintedRules().where((r) => r.height >= 200);
            // The line is the surface's own border (starts at its left edge)
            // or a neighbour's border that ends there (sidebar / master).
            final matching = rules
                .where(
                  (r) =>
                      (r.x - edgeX).abs() <= .6 ||
                      (r.x + r.width - edgeX).abs() <= .6,
                )
                .where((r) => (r.width - lineWidth).abs() <= .1)
                .where((r) => r.color.a > 0)
                .toList();
            // The task modal's frame border also ends at its inside edge;
            // only the thread panel's own rule starts there.
            final own = surface.id == 'task-thread-panel'
                ? matching.where((r) => (r.x - edgeX).abs() <= .6).toList()
                : matching;
            if (drawn) {
              expect(
                own,
                isNotEmpty,
                reason:
                    '${surface.id} paints no ${lineWidth}px left edge at '
                    'x=$edgeX (width $width, $family). Rules: ${rules.toList()}',
              );
            } else {
              expect(
                own,
                isEmpty,
                reason:
                    '${surface.id} paints a left edge on the phone page at '
                    'x=$edgeX (width $width, $family): $own',
              );
            }
          },
        );
      }
    }
  }
}
