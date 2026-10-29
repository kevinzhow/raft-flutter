// Web ForwardComposerWarnings.tsx (v1.21.23): the banners above the forwarded
// preview. "Join {targets} before forwarding." with a Join button for public
// channels found by search that the user has not joined, and the exposure
// warning for Joint Channel destinations. The destinations of one forward are
// joined before it is sent; Send stays off until then ("Join selected
// channels first").
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web `joinTargetSummary`: the one label, "{target} and {count} more" for
/// several, "the selected channel" when a row has no label.
String forwardJoinTargetSummary(BuildContext context, List<String> labels) {
  if (labels.length > 1) {
    return raftFormat(context, '{target} and {count} more', {
      'target': labels.first.isEmpty
          ? raftText(context, 'the selected channel')
          : labels.first,
      'count': labels.length - 1,
    });
  }
  return labels.isEmpty || labels.first.isEmpty
      ? raftText(context, 'the selected channel')
      : labels.first;
}

/// Web `joinActionStatus` outcome copy: one toast for the joins that failed.
String forwardJoinFailureMessage(
  BuildContext context, {
  required List<String> labels,
  required int failed,
}) {
  final total = labels.length;
  if (total == 1) {
    return raftFormat(context, "Couldn't join {target}. Try again.", {
      'target': labels.first.isEmpty
          ? raftText(context, 'the selected channel')
          : labels.first,
    });
  }
  if (failed == total) {
    return raftFormat(context, "Couldn't join {count} channels. Try again.", {
      'count': failed,
    });
  }
  return raftFormat(
    context,
    'Joined {joined} of {total} channels. Try the remaining {failed}.',
    {'joined': total - failed, 'total': total, 'failed': failed},
  );
}

/// The banners, in Web order: join, Joint Channel exposure.
List<Widget> forwardWarningBanners(
  BuildContext context, {
  required List<String> joinLabels,
  required bool joining,
  required VoidCallback? onJoin,
  required bool hasJointDestination,
}) => [
  if (joinLabels.isNotEmpty)
    RaftBanner(
      key: const ValueKey('forward-join-banner'),
      status: RaftBannerRecipeStatus.warning,
      size: RaftBannerRecipeSize.sm,
      glyph: RaftGlyph.alertTriangle,
      centerAction: true,
      descriptionBuilder: (style) => RaftTooltip(
        message: raftFormat(context, 'Join {targets} before forwarding.', {
          'targets': joinLabels.join(', '),
        }),
        child: Text(
          raftFormat(context, 'Join {targets} before forwarding.', {
            'targets': forwardJoinTargetSummary(context, joinLabels),
          }),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
      action: RaftButton(
        key: const ValueKey('forward-join-selected-channels'),
        label: 'Join',
        glyph: RaftGlyph.logIn,
        variant: RaftControlVariant.outline,
        size: RaftButtonRecipeSize.sm,
        busy: joining,
        semanticLabel: raftText(context, 'Join selected public channels'),
        onPressed: joining ? null : onJoin,
      ),
    ),
  if (hasJointDestination)
    RaftBanner(
      key: const ValueKey('forward-joint-warning'),
      status: RaftBannerRecipeStatus.warning,
      glyph: RaftGlyph.alertTriangle,
      description: 'Joint channel destinations may expose this forwarded snapshot to people outside this server.',
    ),
];

/// Web `submitDisabledReason`: why Send is off, or null.
String? forwardSubmitDisabledReason(
  BuildContext context, {
  required bool hasSelection,
  required bool joinReady,
}) => !hasSelection
    ? raftText(context, 'Select a target first')
    : !joinReady
    ? raftText(context, 'Join selected channels first')
    : null;
