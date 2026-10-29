import 'package:flutter/material.dart';

import 'theme.dart';

/// Platform refresh feedback using Raft colors. The owner supplies the read
/// and an always-scrollable vertical list, including its empty state.
class RaftPullToRefresh extends StatelessWidget {
  const RaftPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.enabled = true,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final t = RaftTokens.of(context);
    return RefreshIndicator.adaptive(
      color: t.accent,
      backgroundColor: t.panel,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
