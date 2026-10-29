// Mounted workspace content, without historical shell masks. The observational
// crop follows the real rail and sidebar render boxes rather than guessed sizes.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/sidebar_conversation_finder.dart';

import '../parity_harness.dart';
import 'ext_shell.dart';

class _Framework extends StatefulWidget {
  const _Framework(this.ctx);
  final ParityContext ctx;

  @override
  State<_Framework> createState() => _FrameworkState();
}

class _FrameworkState extends State<_Framework> {
  Rect? navigation;

  @override
  void initState() {
    super.initState();
    final previousFinder = SidebarFinderLayer.hiddenForParity;
    SidebarFinderLayer.hiddenForParity = widget.ctx.props['shell'] != 'desktop';
    widget.ctx.onDispose(
      () => SidebarFinderLayer.hiddenForParity = previousFinder,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => measureNavigation());
  }

  void measureNavigation() {
    if (!mounted || widget.ctx.props['region'] != 'navigation') return;
    Element? rail;
    Element? sidebar;
    void visit(Element element) {
      if (element.widget is RaftWorkspaceRail) rail = element;
      if (element.widget.key == const Key('workspace-sidebar-panel')) {
        sidebar = element;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    Rect bounds(Element element) {
      final box = element.findRenderObject()! as RenderBox;
      final root = context.findRenderObject()! as RenderBox;
      return box.localToGlobal(Offset.zero, ancestor: root) & box.size;
    }

    if (rail == null || sidebar == null) {
      throw StateError('Mounted framework rail/sidebar not found');
    }
    // Capture the actual outer rail slot, including its border. The inner
    // RaftWorkspaceRail render box excludes its surrounding decoration.
    rail!.visitAncestorElements((element) {
      if (element.widget is SizedBox && element.widget.key is GlobalKey) {
        rail = element;
        return false;
      }
      return true;
    });
    setState(
      () => navigation = bounds(rail!).expandToInclude(bounds(sidebar!)),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey('framework-frame'),
    children: [
      Positioned.fill(child: shellWorkspaceView(widget.ctx)),
      if (navigation case final rect?)
        Positioned.fromRect(
          rect: rect,
          child: const IgnorePointer(
            child: SizedBox.expand(key: ValueKey('framework-navigation')),
          ),
        ),
    ],
  );
}

final _frameworkCase = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_ui:RaftAdaptiveWorkspace',
  ],
  notes:
      'Actual workspace content. Desktop uses the source desktop-shell guard; '
      'mobile and tablet use browser chrome. No native OS window capture.',
  settle: const Duration(milliseconds: 900),
  build: (ctx) => _Framework(ctx),
);

final Map<String, ParityCase> extFrameworkCases = {
  for (final platform in const ['desktop', 'mobile', 'phone-short', 'tablet'])
    for (final mode in const ['light', 'dark'])
      for (final region
          in ['mobile', 'phone-short'].contains(platform)
              ? const ['frame']
              : const ['frame', 'navigation'])
        'components.framework.$platform.$region.default.raft-$mode':
            _frameworkCase,
};
