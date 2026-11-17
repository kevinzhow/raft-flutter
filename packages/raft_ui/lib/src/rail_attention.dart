import 'package:flutter/widgets.dart';

import 'theme.dart';
import 'raft/css_box.dart' show raftControlBorderPx;

/// Source AppRailItemAttention: an 8px Status indicator.
/// The caller owns whether attention is present and whether the active entry
/// suppresses it. It is independent of the numeric AppRailItemBadge slot.
class RaftRailAttention extends StatelessWidget {
  const RaftRailAttention({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Positioned(
              right: t.size('space.railAttentionOffset', fallback: -4),
              top: t.size('space.railAttentionOffset', fallback: -4),
              child: Container(
                key: const ValueKey('rail-attention-indicator'),
                width: t.size('size.railAttention', fallback: 8),
                height: t.size('size.railAttention', fallback: 8),
                decoration: BoxDecoration(
                  color: t.colors['layer-rail-attention'],
                  borderRadius: BorderRadius.circular(
                    t.size('radius.railAttention', fallback: 2),
                  ),
                  border: Border.all(
                    color: t.colors['line-rail-attention']!,
                    width: raftControlBorderPx(
                      context,
                      t.size('stroke.railAttention', fallback: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
