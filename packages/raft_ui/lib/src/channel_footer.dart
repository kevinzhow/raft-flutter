// Web ChatPanel footer recipes (components/message/ChatPanel.tsx, the
// `ConversationPanelFooter` chain): the bordered footer frame shared by the
// archived notice, the read-only banners and the Join CTA, and the joint
// over-limit grace banner above the composer. The app decides which one shows.
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'raft_underline.dart';
import 'banner.dart';
import 'design_primitives.dart';
import 'dialog_card.dart' show RaftRecipeButton;
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeVariant, RaftButtonRecipeSize;
import 'theme.dart';

/// `border-t border-line-muted bg-layer-panel` / brutal `border-t-2 border-black bg-white`.
BoxDecoration _footerDecoration(RaftTokens t, {Color? color}) => BoxDecoration(
  color: color ?? t.panel,
  border: t.size('stroke.channelFooter', fallback: 1) > 0
      ? Border(
          top: BorderSide(
            color: t.colors['line-muted']!,
            width: t.size('stroke.channelFooter', fallback: 1),
          ),
        )
      : null,
);

/// The joint over-limit grace banner (`px-3 pt-3` host) above the footer.
class RaftChannelGraceBanner extends StatelessWidget {
  const RaftChannelGraceBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      key: const ValueKey('joint-over-limit-grace-banner'),
      decoration: _footerDecoration(t),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: RaftBanner(textAlign: TextAlign.center, description: message),
    );
  }
}

/// A warning Banner footer with an optional underlined action link
/// (`justify-center text-center font-bold`).
class RaftChannelBannerFooter extends StatelessWidget {
  const RaftChannelBannerFooter({
    super.key,
    required this.message,
    this.linkLabel,
    this.onLink,
  });
  final String message;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      decoration: _footerDecoration(t),
      padding: const EdgeInsets.all(12),
      child: RaftBanner(
        textAlign: TextAlign.center,
        description: message,
        descriptionTailWeight: FontWeight.w700,
        descriptionTail: linkLabel == null
            ? null
            : (label: linkLabel!, onPressed: onLink ?? () {}),
      ),
    );
  }
}

/// `This channel is archived.` + `Unarchive` on `bg-warning-soft` /
/// brutal `bg-brutal-orange/20`.
class RaftChannelArchivedFooter extends StatelessWidget {
  const RaftChannelArchivedFooter({
    super.key,
    required this.message,
    this.linkLabel,
    this.onLink,
  });
  final String message;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = t.colors['warning-strong'];
    final text = RaftTypography.heading(t, size: 14, line: 20, color: color);
    return Container(
      key: const ValueKey('channel-archived-footer'),
      decoration: _footerDecoration(t, color: t.colors['warning-soft']),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          Flexible(child: Text(raftText(context, message), style: text)),
          if (linkLabel != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLink,
              child: RaftHoverRegion(
                cursor: SystemMouseCursors.click,
                child: RaftUnderlinedText(
                  raftText(context, linkLabel!),
                  style: text.copyWith(color: t.strong),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `Join #name` accent button (+ the guest explanation line).
class RaftChannelJoinFooter extends StatelessWidget {
  const RaftChannelJoinFooter({
    super.key,
    required this.channelName,
    required this.onJoin,
    this.explanation,
    this.label,
  });

  /// Full button copy (thread panel: "Join channel to reply"); null = `Join #name`.
  final String? label;
  final String channelName;
  final VoidCallback onJoin;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      key: const ValueKey('channel-join-footer'),
      decoration: _footerDecoration(t),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          RaftRecipeButton(
            variant: RaftButtonRecipeVariant.accent,
            size: t.option('channelFooter.joinSize', or: 'md') == 'lg'
                ? RaftButtonRecipeSize.lg
                : RaftButtonRecipeSize.md,
            glyph: RaftGlyph.logIn,
            glyphSize: 14,
            gap: t.option('channelFooter.joinSize', or: 'md') == 'lg'
                ? null
                : 6,
            expand: true,
            fontWeight: FontWeight.w700,
            label:
                label ??
                raftFormat(context, 'Join #{channel}', {
                  'channel': channelName,
                }),
            onPressed: onJoin,
          ),
          if (explanation != null)
            Text(
              raftText(context, explanation!),
              textAlign: TextAlign.center,
              style: RaftTypography.heading(
                t,
                size: 12,
                line: 16,
                weight: FontWeight.w500,
                color: t.colors['foreground-channel-footer-note'] ?? t.muted,
              ),
            ),
        ],
      ),
    );
  }
}
