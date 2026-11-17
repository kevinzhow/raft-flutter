// The inbox's one notice line (AboutFeedbackDialog.tsx `inboxNotice`,
// FeedbackAgentHint.tsx): between the toolbar and the list, and at most one
// banner in one place. The list being degraded outranks the agent hint.
import 'package:flutter/material.dart';

import 'banner.dart';
import 'icons.dart';
import 'localization.dart';

class RaftFeedbackInboxNotice extends StatelessWidget {
  const RaftFeedbackInboxNotice({
    super.key,
    required this.degraded,
    this.showAgentHint = true,
  });

  /// The first page is waiting out a degraded answer (Hands briefly
  /// unavailable) and is being retried: a polite status warning. The list
  /// stays loading meanwhile, so it never reads as "no feedback".
  final bool degraded;

  /// The agent hint (`settings.about.feedbackAgentHint`): off once this person
  /// sent an agent's draft. Part of the page rather than news, so it is not
  /// announced as live.
  final bool showAgentHint;

  /// Whether [RaftFeedbackInboxNotice] draws anything, so a slot can skip its
  /// inset instead of leaving it empty.
  static bool shows({required bool degraded, required bool showAgentHint}) =>
      degraded || showAgentHint;

  @override
  Widget build(BuildContext context) {
    if (degraded) {
      return RaftBanner(
        key: const ValueKey('settings-feedback-list-degraded'),
        status: RaftBannerRecipeStatus.warning,
        size: RaftBannerRecipeSize.sm,
        description: raftText(
          context,
          "Feedback can't load right now. Retrying…",
        ),
      );
    }
    if (!showAgentHint) return const SizedBox.shrink();
    return RaftBanner(
      key: const ValueKey('settings-feedback-agent-hint'),
      status: RaftBannerRecipeStatus.info,
      size: RaftBannerRecipeSize.sm,
      glyph: RaftGlyph.info,
      live: false,
      descriptionBuilder: (style) => Text.rich(
        TextSpan(
          children: raftRichText(
            context,
            '<strong>Did you know?</strong> Any agent can draft your feedback. Just ask, and you’ll review it before it’s sent.',
            {
              'strong': (inner) => TextSpan(
                text: inner,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            },
          ),
        ),
        style: style,
      ),
    );
  }
}
