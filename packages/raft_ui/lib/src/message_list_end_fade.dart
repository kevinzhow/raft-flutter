import 'package:flutter/widgets.dart';

import 'theme.dart';

/// raft-ui `MessageListEndFade`: the 24px (`h-timeline-section`) veil at the
/// bottom of a message list, `layer-canvas` fading to transparent upwards, so
/// rows slide under the composer without a hard edge. Place it as the last
/// child of the timeline `Stack`; it never takes pointer events.
class RaftMessageListEndFade extends StatelessWidget {
  const RaftMessageListEndFade({
    super.key,
    this.aboveComposer = false,
    this.solidTail = 0,
  });

  /// `--spacing-timeline-section`.
  static const double height = 24;

  /// The composer owns the final 8px of the section.
  final bool aboveComposer;

  /// The typing line has solid canvas below the gradient.
  final double solidTail;

  @override
  Widget build(BuildContext context) {
    final canvas = RaftTokens.of(context).colors['layer-canvas']!;
    final extent = height - (aboveComposer ? 8 : 0) + solidTail;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: extent,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [canvas, canvas.withValues(alpha: 0)],
              stops: [solidTail / extent, 1],
            ),
          ),
        ),
      ),
    );
  }
}
