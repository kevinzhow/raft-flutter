import 'package:flutter/widgets.dart';

import 'panel_edge.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';

/// Where a side-panel column participates in its owner's layout.
enum RaftSidePanelPlacement { docked, floating, overlay }

/// The canonical frame for thread, channel-side, detail, and task columns.
///
/// A docked column has only the seam on its left. A floating column adds its
/// bottom seam and elevation. An overlay has no outer seam or elevation.
class RaftSidePanelFrame extends StatelessWidget {
  const RaftSidePanelFrame({
    super.key,
    required this.placement,
    required this.child,
  });

  final RaftSidePanelPlacement placement;
  final Widget child;

  /// The divider under a side-panel header at its actual laid-out height.
  static Border headerRule(RaftTokens tokens) => Border(
    bottom: RaftPanelEdge.side(tokens, RaftPanelEdgeStyle.attachedPanel)!,
  );

  static Border _edge(RaftTokens tokens, RaftSidePanelPlacement placement) {
    final seam = RaftPanelEdge.side(tokens, RaftPanelEdgeStyle.attachedPanel)!;
    return switch (placement) {
      RaftSidePanelPlacement.docked => Border(left: seam),
      RaftSidePanelPlacement.floating => Border(left: seam, bottom: seam),
      RaftSidePanelPlacement.overlay => const Border(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.ui.layerCanvas,
        boxShadow: placement == RaftSidePanelPlacement.floating
            ? [
                for (final layer in t.shadowLayers('shadow.float').reversed)
                  if (!layer.inset) layer.toBoxShadow(),
              ]
            : null,
        borderRadius: BorderRadius.zero,
      ),
      // The real seam stays above opaque children; elevation stays behind.
      foregroundDecoration: BoxDecoration(
        border: _edge(t, placement),
        borderRadius: BorderRadius.zero,
      ),
      child: child,
    );
  }
}
