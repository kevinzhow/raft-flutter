// Web `components/message/HistoryPaywall.tsx`: what a Free plan's history
// cutoff shows at the start of a conversation. A faded glimpse of the newest
// hidden messages (not interactive, hidden from semantics), then a card that
// says how many the window hides with the one paid action. Presentation only:
// the host supplies every sentence, avatar and the upgrade handler.

import 'package:flutter/material.dart';

import 'card.dart';
import 'card_parts.dart';
import 'chat_composition.dart' show RaftConversationDateHeader;
import 'icons.dart';
import 'inline_thread_surface.dart';
import 'message_row_recipe.dart';
import 'raft/button.dart';
import 'recipe_surface.dart';
import 'recipes/message_list.g.dart' show RaftMessageListRecipe;
import 'theme.dart';

/// One hidden message as the glimpse draws it: sender, time and its cut text.
@immutable
class RaftHiddenMessagePreview {
  const RaftHiddenMessagePreview({
    required this.id,
    required this.author,
    required this.timestamp,
    required this.text,
    this.avatar,
  });

  final String id, author, timestamp;

  /// The cut text (two lines at most) or the "sent an attachment" sentence.
  final String text;
  final Widget? avatar;
}

/// The target message's own thread when it continues inside the window.
@immutable
class RaftHiddenTargetReplies {
  const RaftHiddenTargetReplies({
    required this.summary,
    required this.reply,
    required this.semanticLabel,
    required this.onOpen,
  });

  final String summary, semanticLabel;
  final RaftInlineReply reply;
  final VoidCallback onOpen;
}

/// `HistoryPaywall`: [glimpse] then the card (start mode), or [before], the
/// muted [target], the card and [after] (target mode).
class RaftHistoryPaywall extends StatelessWidget {
  const RaftHistoryPaywall({
    super.key,
    required this.title,
    required this.description,
    required this.upgradeLabel,
    required this.onUpgrade,
    this.glimpse = const [],
    this.target,
    this.before = const [],
    this.after = const [],
    this.targetReplies,
    this.noRecentLabel,
    this.recentDividerLabel,
    this.fill = false,
    this.inset = false,
  });

  final String title, description, upgradeLabel;
  final VoidCallback onUpgrade;
  final List<RaftHiddenMessagePreview> glimpse, before, after;

  /// Target mode: the message a jump pointed at.
  final RaftHiddenMessagePreview? target;
  final RaftHiddenTargetReplies? targetReplies;

  /// Nothing sits in the window: the notice under the card.
  final String? noRecentLabel;

  /// Visible messages follow and no date divider says "last N days".
  final String? recentDividerLabel;

  /// The conversation's empty body: the paywall sits on the composer and
  /// scrolls when tall (Web `ScrollArea` with `mt-auto`).
  final bool fill;

  /// The thread panel's host gutter (`px-3 pt-3`).
  final bool inset;

  static const double fadeExtent = 48;
  static const double glimpseOpacity = 0.7, neighbourOpacity = 0.4;
  static const double targetOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    final paywall = _build(context);
    if (fill) {
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: box.hasBoundedHeight ? box.maxHeight - 8 : 0,
            ),
            child: Align(alignment: Alignment.bottomCenter, child: paywall),
          ),
        ),
      );
    }
    return inset
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: paywall,
          )
        : paywall;
  }

  Widget _build(BuildContext context) {
    final t = RaftTokens.of(context);
    final targetMode = target != null;
    return Semantics(
      container: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (targetMode) ...[
              _Glimpse(
                key: const ValueKey('history-paywall-before'),
                rows: before,
                opacity: neighbourOpacity,
                fadeUp: true,
              ),
              Opacity(
                key: const ValueKey('history-paywall-target'),
                opacity: targetOpacity,
                child: _Rows(
                  rows: [target!],
                  replies: targetReplies,
                  interactiveReplies: true,
                ),
              ),
            ] else if (glimpse.isNotEmpty)
              _Glimpse(
                key: const ValueKey('history-paywall-preview'),
                rows: glimpse,
                opacity: glimpseOpacity,
                fadeUp: true,
              ),
            if (targetMode || glimpse.isNotEmpty) const SizedBox(height: 8),
            RaftCard(
              key: const ValueKey('history-paywall-card'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RaftCardSectionHeader(
                    aboveContent: true,
                    // History, not a lock: in the Raft DS a lock is a private
                    // channel.
                    leading: RaftCardLeading(
                      ExcludeSemantics(
                        child: RaftIcon(
                          RaftGlyph.history,
                          size: 20,
                          color: t.colors['foreground-muted'],
                        ),
                      ),
                    ),
                    title: RaftCardTitle(Text(title)),
                    description: RaftCardDescription(Text(description)),
                  ),
                  RaftCardContent(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: RaftButton(
                        key: const ValueKey('history-paywall-upgrade'),
                        label: upgradeLabel,
                        uiVariant: RaftButtonVariant.primary,
                        uiSize: RaftButtonSize.md,
                        onPressed: onUpgrade,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (targetMode && after.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Glimpse(
                key: const ValueKey('history-paywall-after'),
                rows: after,
                opacity: neighbourOpacity,
                fadeUp: false,
              ),
            ],
            if (noRecentLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _Notice(noRecentLabel!),
              )
            else if (recentDividerLabel != null)
              KeyedSubtree(
                key: const ValueKey('history-paywall-recent-divider'),
                child: RaftConversationDateHeader(label: recentDividerLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

/// `MessageListNotice tone=muted`.
class _Notice extends StatelessWidget {
  const _Notice(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMessageListRecipe.resolve(
      tokens: t.recipeTokens,
      states: t.recipeStates(responsive: true),
    );
    return Center(
      child: Text(
        label,
        key: const ValueKey('history-paywall-none-recent'),
        textAlign: TextAlign.center,
        style: recipe.notice.text(
          t.recipeTokens,
          base: DefaultTextStyle.of(context).style,
        ),
      ),
    );
  }
}

/// Hidden messages as a glimpse, not a read: not interactive, absent from
/// semantics, faded over [RaftHistoryPaywall.fadeExtent] toward the top (the
/// newest hidden, above the card) or the bottom (after a jump's target).
class _Glimpse extends StatelessWidget {
  const _Glimpse({
    super.key,
    required this.rows,
    required this.opacity,
    required this.fadeUp,
  });

  final List<RaftHiddenMessagePreview> rows;
  final double opacity;
  final bool fadeUp;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final veil = RaftTokens.of(context).colors['layer-canvas']!;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final stop = bounds.height <= 0
                  ? 1.0
                  : (RaftHistoryPaywall.fadeExtent / bounds.height).clamp(
                      0.0,
                      1.0,
                    );
              return LinearGradient(
                begin: fadeUp ? Alignment.topCenter : Alignment.bottomCenter,
                end: fadeUp ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [veil.withValues(alpha: 0), veil],
                stops: [0, stop],
              ).createShader(bounds);
            },
            child: _Rows(rows: rows),
          ),
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({
    required this.rows,
    this.replies,
    this.interactiveReplies = false,
  });

  final List<RaftHiddenMessagePreview> rows;
  final RaftHiddenTargetReplies? replies;
  final bool interactiveReplies;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final row in rows)
        // The preview rows are drawn like messages but never act like them.
        IgnorePointer(
          ignoring: !(interactiveReplies && replies != null),
          child: RaftMessageRow(
            key: ValueKey('history-paywall-row-${row.id}'),
            author: row.author,
            timestamp: row.timestamp,
            avatar: row.avatar,
            content: Text(
              row.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            inlineReplies: replies == null
                ? null
                : RaftInlineThreadSurface(
                    key: const ValueKey('history-paywall-target-replies'),
                    replyCount: 1,
                    replies: [replies!.reply],
                    summary: Text(replies!.summary),
                    semanticLabel: replies!.semanticLabel,
                    onOpen: replies!.onOpen,
                  ),
          ),
        ),
    ],
  );
}

/// Web `OlderMessageNotice`: one message, quoted or listed away from its
/// conversation, that is older than the window. This line takes the place of
/// its text, with Upgrade to Pro. For where the line is not itself a button.
class RaftOlderMessageNotice extends StatelessWidget {
  const RaftOlderMessageNotice({
    super.key,
    required this.label,
    required this.upgradeLabel,
    required this.onUpgrade,
    this.withIcon = true,
  });

  final String label, upgradeLabel;
  final VoidCallback onUpgrade;

  /// False where the row already leads with its own icon.
  final bool withIcon;

  @override
  Widget build(BuildContext context) {
    final muted = RaftTokens.of(context).colors['foreground-muted']!;
    return Wrap(
      key: const ValueKey('history-older-message'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        if (withIcon)
          ExcludeSemantics(
            child: RaftIcon(RaftGlyph.history, size: 14, color: muted),
          ),
        Text(label, style: TextStyle(color: muted)),
        RaftButton(
          key: const ValueKey('history-older-message-upgrade'),
          label: upgradeLabel,
          uiVariant: RaftButtonVariant.link,
          uiSize: RaftButtonSize.inline,
          onPressed: onUpgrade,
        ),
      ],
    );
  }
}
