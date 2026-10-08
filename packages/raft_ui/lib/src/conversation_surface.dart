import 'package:flutter/material.dart';

import 'theme.dart';

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

  Color background(RaftConversationSurfaceRole role) {
    if (tokens.brutal) return Colors.white;
    return switch (role) {
      RaftConversationSurfaceRole.threadTimeline when tokens.dark =>
        tokens.card,
      _ => tokens.panel,
    };
  }
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
  Widget build(BuildContext context) => ColoredBox(
    color: RaftConversationSurfaceRecipe(RaftTokens.of(context))
        .background(role),
    child: child,
  );
}
