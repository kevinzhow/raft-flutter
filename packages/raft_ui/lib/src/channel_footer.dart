// Web ChatPanel footer recipes (components/message/ChatPanel.tsx, the
// `ConversationPanelFooter` chain): the bordered footer frame shared by the
// archived notice, the read-only banners and the Join CTA, and the joint
// over-limit grace banner above the composer. The app decides which one shows.

import 'package:flutter/material.dart';

import 'banner.dart';
import 'design_primitives.dart';
import 'dialog_card.dart' show RaftRecipeButton;
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeVariant, RaftButtonRecipeSize;
import 'theme.dart';
import 'system_inset.dart';
import 'raft/ui_tokens.dart' show RaftTokensUi;
import 'tokens/tokens.dart';

/// `border-t border-line-muted bg-layer-panel`.
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

// Container used to include the recipe border in its content padding. Keep
// that layout when the bottom-edge owner paints through the system inset.
EdgeInsets _footerPadding(BuildContext context, BoxDecoration decoration) =>
    const EdgeInsets.all(12)
        .add(decoration.padding)
        .resolve(Directionality.of(context));

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
    final decoration = _footerDecoration(t);
    return RaftBottomInsetSurface(
      decoration: decoration,
      padding: _footerPadding(context, decoration),
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

/// `This channel is archived.` + `Unarchive`: the Web's
/// `<Banner status="warning" className="justify-center text-center font-bold">`
/// in a `p-3` host ([RaftChannelBannerFooter]).
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
    return RaftChannelBannerFooter(
      key: const ValueKey('channel-archived-footer'),
      message: message,
      linkLabel: linkLabel,
      onLink: onLink,
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
    final decoration = _footerDecoration(t);
    return RaftBottomInsetSurface(
      key: const ValueKey('channel-join-footer'),
      decoration: decoration,
      padding: _footerPadding(context, decoration),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          RaftRecipeButton(
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.md,
            metricsKey: 'channelJoin',
            glyph: RaftGlyph.logIn,
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

/// `ReadOnlyComposer` (components/message/ReadOnlyComposer.tsx): the composer's
/// stand-in where nobody can write: a disabled field that reads
/// "Chat is unavailable", with no typing, attachments or send. ChatPanel shows
/// it for a Lounge the viewer may read but not post in.
class RaftChannelReadOnlyComposer extends StatelessWidget {
  const RaftChannelReadOnlyComposer({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final decoration = BoxDecoration(
      color: t.colors['layer-canvas'] ?? t.panel,
    );
    final radius = t.size('radius.container', fallback: 10);
    return RaftBottomInsetSurface(
      key: const ValueKey('channel-read-only-composer'),
      decoration: decoration,
      // `px-3 pt-2 pb-3`.
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.forbidden,
        child: Semantics(
          container: true,
          textField: true,
          enabled: false,
          child: ConstrainedBox(
            // `min-h-11`: the box is a minimum and grows with the text size.
            constraints: const BoxConstraints(minHeight: 44),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.colors['fill-muted'],
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: t.colors['line-hairline']!),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    raftText(context, 'Chat is unavailable'),
                    style: t.scale(
                      RaftTypeScale.body,
                      color: t.colors['foreground-disabled'],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
