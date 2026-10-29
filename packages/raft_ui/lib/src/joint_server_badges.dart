// `JointServerBadges` (ChannelMembers.tsx): one soft `information` Badge per
// server a joint-channel member participates through, in roster order (the
// viewed server first), after the member's name on a roster row.
import 'package:flutter/material.dart';

import 'indicators.dart';
import 'theme.dart';

/// Space the name line keeps between the name and the badges (`gap-1.5`).
const double _nameGap = 6;

/// The badge strip: `flex max-w-1/2 shrink-0 items-center gap-1
/// overflow-hidden`; the name keeps at least half the row.
class RaftJointServerBadges extends StatelessWidget {
  const RaftJointServerBadges({super.key, required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return ClipRect(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          for (final label in labels)
            Flexible(
              child: RaftBadge(
                label: label,
                appearance: RaftBadgeRecipeAppearance.soft,
                variant: RaftBadgeRecipeVariant.information,
                fontFamily: t.monoFont,
                center: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// A roster row's name line: the (truncating) [name] with the server
/// [labels] after it. Without labels it is just [name], so ordinary rows keep
/// their layout.
class RaftMemberNameLine extends StatelessWidget {
  const RaftMemberNameLine({
    super.key,
    required this.name,
    required this.labels,
  });
  final Widget name;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return name;
    return LayoutBuilder(
      builder: (context, box) {
        final badges = RaftJointServerBadges(
          key: const ValueKey('member-server-badges'),
          labels: labels,
        );
        return Row(
          children: [
            Flexible(child: name),
            const SizedBox(width: _nameGap),
            box.hasBoundedWidth
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
                    child: badges,
                  )
                : badges,
          ],
        );
      },
    );
  }
}
