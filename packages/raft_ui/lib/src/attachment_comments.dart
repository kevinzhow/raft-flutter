// Web AttachmentCommentsPanel.tsx: header ("Comments · file"), the
// anchored comment cards, and the compact composer area with the pending
// location-anchor chip. The app owns loading, posting and authority; this
// file only renders. Classes are resolved from the TSX.
import 'package:flutter/material.dart';

import 'attachment_preview_shell.dart' show RaftCommentsSheetControls;
import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'empty_state.dart';
import 'icons.dart';
import 'interaction.dart' show RaftInteraction;
import 'localization.dart';
import 'message_body.dart';
import 'panel_layout.dart';
import 'raft/button.dart' show RaftButtonSize;
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/markdown.g.dart';
import 'recipes/message_item.g.dart';
import 'recipes/message_reference.g.dart';
import 'recipes/panel_header.g.dart';
import 'system_inset.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart';

@immutable
class RaftAttachmentCommentView {
  const RaftAttachmentCommentView({
    required this.id,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.avatar,
    this.anchorLabel,
    this.quote,
    this.onJump,
  });
  final String id, senderName, content, timestamp;
  final Widget? avatar;

  /// `anchorLabel(anchor)`; null for unanchored comments.
  final String? anchorLabel;
  final String? quote;
  final VoidCallback? onJump;
}

/// Web `ReferenceChip variant="muted"` used for attachment comment anchors.
class RaftCommentAnchorChip extends StatelessWidget {
  const RaftCommentAnchorChip({
    super.key,
    required this.label,
    this.glyph = RaftGlyph.mapPin,
    this.onRemove,
    this.removeLabel,
  });
  final String label;
  final RaftGlyph glyph;
  final VoidCallback? onRemove;
  final String? removeLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final s = RaftMessageReferenceRecipe.resolve(
      variant: RaftMessageReferenceRecipeVariant.muted,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    final ink = s.foreground(rt) ?? t.strong;
    final rawStyle = s.text(
      rt,
      base: TextStyle(
        fontFamily: t.headingFont,
        fontFamilyFallback: t.fontFallback,
        locale: t.textLocale,
      ),
    );
    final labelSize = onRemove == null ? 12.25 : 14.0;
    final labelStyle = rawStyle.copyWith(
      color: ink,
      fontSize: labelSize,
      height: 20.0 / labelSize,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final grows = RaftScaled.grows(context);
    return Container(
      constraints: grows ? null : const BoxConstraints(maxHeight: 20),
      padding: EdgeInsets.symmetric(horizontal: s.padding.horizontal / 2),
      decoration: s.decoration(rt),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftIcon(glyph, size: 12, color: ink),
          const SizedBox(width: 4),
          Flexible(
            child: RaftCssText(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            RaftInteractive(
              onPressed: onRemove,
              expandTouchTarget: false,
              semanticLabel: removeLabel ?? raftText(context, 'Remove Anchor'),
              tooltip: removeLabel ?? raftText(context, 'Remove Anchor'),
              builder: (_, state) => RaftIcon(
                RaftGlyph.x,
                size: 12,
                color: state.hovered || state.focusVisible
                    ? t.strong
                    : t.ui.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RaftAttachmentCommentsPanel extends StatelessWidget {
  const RaftAttachmentCommentsPanel({
    super.key,
    required this.filename,
    required this.comments,
    required this.composer,
    this.loading = false,
    this.error,
    this.blockedMessage,
    this.sheet,
    this.collapsedBody = false,
  });
  final String filename;

  /// Mobile bottom sheet: the header row carries the expand / collapse
  /// chevron (Web `sheetControls`).
  final RaftCommentsSheetControls? sheet;

  /// Hides the list and composer while the sheet is collapsed to its header.
  final bool collapsedBody;

  /// Sorted cards; null while loading.
  final List<RaftAttachmentCommentView>? comments;

  /// The compact MessageInput (with the pending anchor in its accessory).
  final Widget composer;
  final bool loading;
  final String? error, blockedMessage;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final rule = BorderSide(color: t.ui.lineSeam);
    final hideBottomRule = collapsedBody && raftBottomInset(context) > 0;
    final list = comments;
    final headerRecipe = RaftPanelHeaderRecipe.resolve(
      tokens: rt,
      states: t.recipeStates(
        responsive: true,
        pointerCoarse: RaftInteraction.of(context).touch,
      ),
    );
    final grows = RaftScaled.grows(context);
    final headerHeight = RaftLayoutMetrics.shellHeaderHeight(
      t,
      MediaQuery.sizeOf(context).height,
    );
    final sheetAction = sheet == null
        ? null
        : RaftPanelAction(
            key: const ValueKey('attachment-comments-sheet-toggle'),
            glyph: sheet!.expanded
                ? RaftGlyph.chevronDown
                : RaftGlyph.chevronUp,
            ghostSize: RaftButtonSize.iconMd,
            tooltip: raftText(
              context,
              sheet!.expanded ? 'Collapse Comments' : 'Expand Comments',
            ),
            onPressed: sheet!.onToggle,
          );
    final Widget header = sheet != null
        ? Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            decoration: BoxDecoration(
              color: t.canvas,
              border: hideBottomRule ? null : Border(bottom: rule),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: raftText(context, 'Comments'),
                          style: t.scale(
                            RaftTypeScale.subhead,
                            weight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '  $filename',
                          style: t.scale(
                            RaftTypeScale.caption,
                            color: t.ui.foregroundHint,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                sheetAction!,
              ],
            ),
          )
        : Container(
            height: grows ? null : headerHeight,
            constraints: BoxConstraints(
              minHeight: headerRecipe.header.minHeight ?? headerHeight,
            ),
            alignment: Alignment.centerLeft,
            padding: headerRecipe.header.padding.copyWith(top: 0, bottom: 0),
            decoration: BoxDecoration(
              color: t.canvas,
              border: hideBottomRule ? null : Border(bottom: rule),
            ),
            child: RaftTooltip(
              message: raftFormat(context, 'Comments · {filename}', {
                'filename': filename,
              }),
              child: RaftPanelHeaderContent(
                style: headerRecipe.headerContent,
                inline: !grows && t.desktop,
                heading: Semantics(
                  header: true,
                  child: RaftCssText(
                    raftText(context, 'Comments'),
                    maxLines: grows ? null : 1,
                    overflow: grows
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    softWrap: grows,
                    style: t.scale(
                      RaftTypeScale.headline,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                meta: RaftCssText(
                  filename,
                  maxLines: grows ? null : 1,
                  overflow: grows
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  softWrap: grows,
                  style: t.scale(
                    RaftTypeScale.caption,
                    color: t.ui.foregroundHint,
                  ),
                ),
              ),
            ),
          );
    return DefaultTextHeightBehavior(
      textHeightBehavior: raftCssTextHeightBehavior,
      child: ColoredBox(
        color: t.canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (!collapsedBody)
              Expanded(
                child: list == null || loading
                    ? Center(
                        child: error != null
                            ? Text(
                                error!,
                                style: t.scale(
                                  RaftTypeScale.callout,
                                  color: t.colors['danger-strong'],
                                ),
                              )
                            : Semantics(
                                label: raftText(context, 'Loading'),
                                child: const RaftSpinner(),
                              ),
                      )
                    : list.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: RaftEmptyState(
                            glyph: RaftGlyph.messageSquare,
                            title: raftText(context, 'No comments yet'),
                            detail: raftFormat(
                              context,
                              'Comments here are pinned to {filename}. For general discussion, reply in the thread.',
                              {'filename': filename},
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, index) =>
                            _CommentRow(comment: list[index]),
                      ),
              ),
            if (!collapsedBody)
              Container(
                // `COMPOSER_DOCK_CLASS`: `shrink-0 border-t border-line-seam p-3`.
                padding: const EdgeInsets.all(12)
                    .copyWith(bottom: 12 + raftBottomInset(context)),
                decoration: BoxDecoration(border: Border(top: rule)),
                child: blockedMessage != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          blockedMessage!,
                          style: t.scale(
                            RaftTypeScale.footnote,
                            color: t.ui.foregroundHint,
                          ),
                        ),
                      )
                    : composer,
              ),
          ],
        ),
      ),
    );
  }
}

/// Web `MessageItem` row inside `AttachmentCommentsPanel`.
class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});
  final RaftAttachmentCommentView comment;

  Widget _buildRow(BuildContext context, {bool hovered = false}) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final c = comment;
    final s = RaftMessageItemRecipe.resolve(
      states: t.recipeStates(responsive: true, hovered: hovered),
      tokens: rt,
    );
    final base = TextStyle(
      locale: t.textLocale,
      fontFamily: t.bodyFont,
      fontFamilyFallback: t.fontFallback,
    );
    final quoteStyle = RaftMarkdownRecipe.resolve(tokens: rt).blockquote;
    final bodyStyle = t.scale(RaftTypeScale.body);
    return RaftRecipeBox(
      style: s.root,
      tokens: rt,
      applyText: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: s.root.columnGap ?? 12,
        children: [
          SizedBox(
            width: s.gutter.width ?? 35,
            child: Align(
              alignment: Alignment.topCenter,
              child: c.avatar ?? const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: s.header.padding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: s.header.columnGap ?? 6,
                    children: [
                      Flexible(
                        child: RaftCssText(
                          c.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: s.sender.text(rt, base: base),
                        ),
                      ),
                      RaftCssText(
                        c.timestamp,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: s.time
                            .text(
                              rt,
                              base: TextStyle(
                                locale: t.textLocale,
                                fontFamily: t.monoFont,
                                fontFamilyFallback: t.fontFallback,
                              ),
                            )
                            .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
                if (c.anchorLabel != null) ...[
                  const SizedBox(height: 2),
                  RaftCommentAnchorChip(
                    label: c.anchorLabel!,
                    glyph: RaftGlyph.mapPin,
                  ),
                ],
                if (c.quote != null && c.quote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RaftRecipeBox(
                    style: quoteStyle,
                    tokens: rt,
                    applyText: false,
                    child: Text(
                      c.quote!,
                      style: quoteStyle.text(rt, base: base),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                RaftMessageBody(
                  content: c.content,
                  enableProseSelection: c.onJump == null,
                  fontSize: bodyStyle.fontSize,
                  lineHeight:
                      bodyStyle.fontSize != null && bodyStyle.height != null
                      ? bodyStyle.fontSize! * bodyStyle.height!
                      : null,
                  foregroundColor: t.strong,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = comment;
    if (c.onJump == null) return _buildRow(context);
    return RaftInteractive(
      onPressed: c.onJump,
      tooltip: c.quote?.isNotEmpty == true
          ? c.quote
          : raftText(context, 'Jump to Location'),
      builder: (_, state) => _buildRow(context, hovered: state.hovered),
    );
  }
}

/// Full-height host for the comments panel opened from an attachment
/// preview on touch layouts (Material ancestor for the composer field).
///
/// The page background reaches the screen bottom; the composer inside pads
/// itself by the system inset.
class RaftAttachmentCommentsPage extends StatelessWidget {
  const RaftAttachmentCommentsPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final color = RaftTokens.of(context).canvas;
    return RaftNavigationBarStyle(
      background: color,
      child: Material(
        color: color,
        child: SafeArea(bottom: false, child: child),
      ),
    );
  }
}
