import 'package:flutter/material.dart';

import 'theme.dart';
import 'status_bar.dart';

/// Mounted ChatPanel and ordinary ThreadPanel surfaces. Read-only thread
/// previews have their own canvas role and do not use this composition.
enum RaftConversationSurfaceRole {
  channelTimeline,
  threadTimeline,
  threadParent,
}

@immutable
class RaftConversationSurfaceRecipe {
  const RaftConversationSurfaceRecipe(this.tokens);
  final RaftTokens tokens;

  /// Every conversation surface sits on `layer-panel`. Web paints the thread
  /// timeline the same as the channel one: raft-ui `ThreadPanelRoot` and
  /// `ThreadPanelContent` are `bg-layer-canvas`, and `ThreadPanel.tsx` adds no
  /// dark card layer (a dark thread timeline sits on the canvas in Web 1.21.23).
  Color background(RaftConversationSurfaceRole role) => tokens.panel;
}

/// Gives transparent header/body slots the mounted panel's inherited surface.
class RaftConversationSurface extends StatelessWidget {
  const RaftConversationSurface({
    super.key,
    required this.role,
    required this.child,
  });
  final RaftConversationSurfaceRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = RaftConversationSurfaceRecipe(RaftTokens.of(context))
        .background(role);
    // The surface is the column's top surface under a transparent header.
    return RaftStatusBarSource(
      color: color,
      child: ColoredBox(color: color, child: child),
    );
  }
}
