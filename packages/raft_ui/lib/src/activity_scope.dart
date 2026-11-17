import 'package:flutter/material.dart';

import 'localization.dart';
import 'indicators.dart';
import 'theme.dart';

/// ConversationCardSkeleton's six real loading cards; no synthetic result rows.
class RaftActivityLoadingList extends StatelessWidget {
  const RaftActivityLoadingList({super.key});
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      label: raftText(context, 'Loading Activity'),
      child: ListView.separated(
        // v1.21.23: the cards sit in the `py-1` scroller edge to edge; the
        // pre-theme looks inset them 16. Both are component geometry data.
        padding: EdgeInsets.symmetric(
          horizontal: t.size('space.activityLoadingInline', fallback: 0),
          vertical: t.size('space.activityLoadingBlock', fallback: 4),
        ),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.panel,
            borderRadius: BorderRadius.circular(
              t.size('radius.activityLoadingCard', fallback: 10),
            ),
            // The rule colour varies independently of padding and corners;
            // this list retains its existing 1px rule in every mode.
            border: Border.all(color: t.colors['line-loading-card']!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              const Row(
                spacing: 10,
                children: [
                  RaftSkeleton(
                    variant: RaftSkeletonVariant.line,
                    width: 80,
                    themed: true,
                  ),
                  RaftSkeleton(
                    variant: RaftSkeletonVariant.line,
                    width: 64,
                    themed: true,
                  ),
                  RaftSkeleton(
                    variant: RaftSkeletonVariant.line,
                    width: 40,
                    themed: true,
                  ),
                ],
              ),
              const RaftSkeleton(
                variant: RaftSkeletonVariant.line,
                themed: true,
              ),
              const FractionallySizedBox(
                widthFactor: .6,
                alignment: Alignment.centerLeft,
                child: RaftSkeleton(
                  variant: RaftSkeletonVariant.line,
                  themed: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
