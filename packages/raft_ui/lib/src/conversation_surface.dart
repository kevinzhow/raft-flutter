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

  /// Web v1.21.23 paints ThreadPanel root/content on the canvas. Its component
  /// role lets legacy packs retain their a57 dark card layer independently.
  Color background(RaftConversationSurfaceRole role) => switch (role) {
    RaftConversationSurfaceRole.threadTimeline =>
      tokens.colors['layer-conversation-content']!,
    _ => tokens.panel,
  };
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
