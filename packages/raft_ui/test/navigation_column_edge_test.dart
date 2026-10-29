import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/task_surface_previews.dart';

/// A painted vertical border stroke, in global coordinates.
class _Rule {
  const _Rule(this.x, this.width, this.height);
  final double x, width, height;
  @override
  String toString() => 'rule(x=$x w=$width h=$height)';
}

List<_Rule> _rules() {
  final rules = <_Rule>[];
  void visit(RenderObject node) {
    if (node is RenderDecoratedBox && node.hasSize) {
      final decoration = node.decoration;
      if (decoration is BoxDecoration && decoration.border is Border) {
        final border = decoration.border! as Border;
        final origin = node.localToGlobal(Offset.zero);
        if (border.left.width > 0 && border.left.style == BorderStyle.solid) {
          rules.add(_Rule(origin.dx, border.left.width, node.size.height));
        }
        if (border.right.width > 0 && border.right.style == BorderStyle.solid) {
          rules.add(
            _Rule(
              origin.dx + node.size.width - border.right.width,
              border.right.width,
              node.size.height,
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

void main() {
  const width = 900.0;
  const height = 900.0;
  const navWidth = 57.0;

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    for (final side in [RaftRailSide.start, RaftRailSide.end]) {
      final onRight = RaftRailSideScope.onRight(side, direction);
      testWidgets('${direction.name} rail ${side.name} '
          'keeps the divider on the content side', (t) async {
        t.view.physicalSize = const Size(width, height);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: false),
            home: Scaffold(
              body: Directionality(
                textDirection: direction,
                child: RaftNavigationColumnScope(
                  onRight: onRight,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      if (!onRight) _nav(onRight),
                      const Expanded(child: _ActivityEdge()),
                      if (onRight) _nav(onRight),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();

        final content = t.getRect(find.byKey(const Key('content-panel')));
        final rules = _rules().where((r) => r.height >= 200).toList();
        // Raft's real rail owns the single seam. The Activity inset must
        // not add a second stroke, regardless of reading direction/rail side.
        expect(rules, hasLength(1), reason: 'Rules: $rules');
        final rule = rules.single;
        expect(rule.width, 1);
        final seam = onRight ? content.right : content.left;
        final paintedEdge = onRight ? rule.x : rule.x + rule.width;
        expect(paintedEdge, closeTo(seam, .6));
        expect(content.left, onRight ? 0 : navWidth);
        expect(content.right, onRight ? width - navWidth : width);
      });
    }
  }

  _otherSurfaces();
}

/// Isolates the unrelated settings/modal/drawer edge tests below. The
/// Activity seam matrix above mounts the real RaftWorkspaceRail.
class _Nav extends StatelessWidget {
  const _Nav(this.onRight);
  final bool onRight;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final line = BorderSide(color: t.colors['line-muted']!);
    final border = onRight ? Border(left: line) : null;
    return Container(
      key: const Key('nav-column'),
      width: 56,
      decoration: BoxDecoration(border: border),
    );
  }
}

Widget _nav(bool onRight) => RaftRailEdgeScope(
  onRight: onRight,
  child: RaftWorkspaceRail(
    destinations: const [],
    selected: 'activity',
    onSelected: (_) {},
    workspaceName: 'Demo',
    onWorkspace: () {},
    workspaceHeader: const SizedBox(height: 56),
    topBar: true,
    thinDivider: true,
  ),
);

class _ActivityEdge extends StatelessWidget {
  const _ActivityEdge();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('content-panel'),
    decoration: BoxDecoration(
      border: RaftPanelEdge.besideNavigation(
        context,
        RaftPanelEdgeStyle.activityInbox,
      ),
    ),
  );
}

/// Settings, the task thread and the two channel drawers keep [RaftPanelEdge.left].
/// With the navigation column on the physical right, none of those lines is
/// the window's far edge: settings divides its own nav from its page, the
/// task line is inside the centered modal, and a drawer line is the drawer's
/// leading edge.
void _otherSurfaces() {
  const window = Size(900, 900);

  Future<void> pump(WidgetTester t, Widget body) async {
    t.view.physicalSize = window;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false),
        home: Scaffold(
          body: RaftNavigationColumnScope(onRight: true, child: body),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Widget shell(Widget content) => Row(
    textDirection: TextDirection.ltr,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: content),
      const _Nav(true),
    ],
  );

  /// Drawers and the task modal cover the window. They are not the content
  /// column, so the navigation column stays on the right underneath them.
  Widget overWindow(Widget child) => Stack(
    fit: StackFit.expand,
    children: [shell(const SizedBox.expand()), child],
  );

  List<_Rule> atWindow() =>
      _rules().where((r) => r.x.abs() <= .6 && r.height >= 200).toList();

  testWidgets('settings line stays beside the settings nav', (t) async {
    await pump(
      t,
      shell(
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              width: RaftSettingsLayoutRecipe.navigationWidth,
              child: RaftMountedSidebarFrame(
                trailingEdge: true,
                header: SizedBox(height: 56),
                body: SizedBox.expand(),
              ),
            ),
            const Expanded(
              child: RaftSettingsPanelFrame(
                header: SizedBox(height: 56),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
    expect(atWindow(), isEmpty);
    final panel = t.getTopLeft(find.byType(RaftSettingsPanelFrame));
    expect(panel.dx, RaftSettingsLayoutRecipe.navigationWidth);
    final besideNav = _rules().where(
      (r) =>
          (r.x - RaftSettingsLayoutRecipe.navigationWidth).abs() <= .6 &&
          r.height >= 200,
    );
    expect(besideNav, isNotEmpty);
  });

  testWidgets('task line stays inside the modal', (t) async {
    await pump(t, overWindow(taskModalPreview()));
    expect(atWindow(), isEmpty);
    final frame = t.getTopLeft(find.byKey(const ValueKey('task-thread-modal')));
    expect(frame.dx, greaterThan(8));
  });

  testWidgets('channel drawer line stays on the drawer', (t) async {
    await pump(
      t,
      overWindow(
        RaftOverflowSheet(
          title: '#general',
          onClose: () {},
          children: const [SizedBox(height: 40)],
        ),
      ),
    );
    expect(atWindow(), isEmpty);
    final sheet = t.getTopLeft(
      find.byKey(const ValueKey('channel-overflow-sheet')),
    );
    expect(sheet.dx, greaterThan(100));
  });

  testWidgets('channel settings line stays on the drawer', (t) async {
    await pump(
      t,
      overWindow(
        RaftChannelSettingsSheet(channelName: 'general', onClose: () {}),
      ),
    );
    expect(atWindow(), isEmpty);
    final sheet = t.getRect(
      find.descendant(
        of: find.byType(RaftChannelSettingsSheet),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 544,
        ),
      ),
    );
    expect(sheet.left, greaterThan(100));
  });
}
