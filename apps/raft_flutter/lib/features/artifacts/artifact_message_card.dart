// The cards under a message for the Artifacts its text links to.
//
// Source: packages/web/src/apps/artifacts/{ArtifactMessageRefs,
// ArtifactMessageCard,ArtifactCardExcerpt}.tsx at v1.24.0-source.1: one
// card per Artifact reference in the text, in order; while any is loading,
// one skeleton in the card's shape; `ok` is its card, `deleted` the gray
// card (title, who deleted it and when; nothing opens); unavailable or a
// failed read adds nothing (the link in the text is all a reader who can't
// see it gets). Behind workspace_artifacts_v0. Covers drawn from publish
// check screenshots and publisher images are not drawn (docs/parity.md).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../icu_message.dart';
import 'artifact_models.dart';
import 'artifact_text.dart';

/// Web MessageEmbed size `item`: at most 400 px wide off a phone.
const artifactCardMaxWidth = 400.0;

/// Web FilePreview (`size-8`) and the excerpt's frame height before it fades.
const _tileSize = 32.0;
const _excerptMaxHeight = 120.0;

/// Web `px-3 py-2.5` / `gap-2.5`.
const _inset = EdgeInsets.fromLTRB(
  RaftSpace.x3,
  RaftSpace.x2 + RaftSpace.half,
  RaftSpace.x3,
  RaftSpace.x2 + RaftSpace.half,
);
const _gap = RaftSpace.x2 + RaftSpace.half;

class _CardBox extends StatelessWidget {
  const _CardBox({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.dimmed = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    // Web MessageEmbed size `item`: the card surface, hairline, container
    // radius; pressing it opens the Artifact.
    Widget box = onTap == null
        ? RaftCard(padding: EdgeInsets.zero, clip: true, child: child)
        : Semantics(
            label: semanticLabel,
            child: RaftCard.item(
              padding: EdgeInsets.zero,
              onTap: onTap,
              child: child,
            ),
          );
    if (dimmed) box = Opacity(opacity: .6, child: box);
    return Padding(
      padding: const EdgeInsets.only(top: RaftSpace.x2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: RaftAdaptiveWorkspace.compactOf(context)
                ? double.infinity
                : artifactCardMaxWidth,
          ),
          child: box,
        ),
      ),
    );
  }
}

/// The kind's file tile (Web `KindGlyph`: FilePreview with its badge).
class ArtifactKindTile extends StatelessWidget {
  const ArtifactKindTile({super.key, required this.kind});
  final ArtifactKind kind;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final badge = artifactKindBadge(kind);
    return SizedBox.square(
      dimension: _tileSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.ui.fillMuted,
          borderRadius: RaftShapes.attachment(t),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            RaftIcon(
              artifactKindGlyph(kind),
              size: 16,
              color: t.ui.foregroundMuted,
            ),
            if (badge != null)
              Positioned(
                bottom: 1,
                child: Text(
                  badge,
                  style: RaftTypography.mono(
                    t,
                    size: 7,
                    line: 8,
                  ).copyWith(color: t.ui.foregroundMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small outline badge ("v3", "Updated").
class ArtifactBadge extends StatelessWidget {
  const ArtifactBadge(this.text, {super.key, this.accent = false});
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? t.colors['info-soft'] : null,
        borderRadius: RaftShapes.attachment(t),
        border: accent ? null : Border.all(color: ui.lineHairline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RaftSpace.x1_5,
          vertical: RaftSpace.half,
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RaftTypography.body(
            t,
            size: 11,
            line: 16,
            weight: FontWeight.w500,
            color: accent ? t.colors['info-strong'] : ui.foregroundMuted,
          ),
        ),
      ),
    );
  }
}

/// One Artifact's card (Web `OkCard`).
class ArtifactMessageCard extends StatelessWidget {
  const ArtifactMessageCard({
    super.key,
    required this.card,
    required this.onOpen,
    this.onOpenInBrowser,
    this.serverName,
  });

  final ArtifactCard card;
  final VoidCallback onOpen;
  final VoidCallback? onOpenInBrowser;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final facts = artifactFactsLine(context, card);
    final unseen = card.unseen;
    final newer = unseen != null && unseen.newerVersion && !card.pinned;
    final newComments = unseen == null || card.commentCount <= 0
        ? 0
        : unseen.newComments.clamp(0, card.commentCount);
    final marks = [
      if (newer) raftText(context, 'Updated'),
      if (newComments > 0)
        icuText(
          context,
          '{count, plural, one {# new comment} other {# new comments}}',
          {'count': newComments},
        ),
    ];
    final marksLabel = [
      if (newer) raftText(context, 'New version since you last looked'),
      if (newComments > 0)
        icuText(
          context,
          '{count, plural, one {# new comment since you last looked} other {# new comments since you last looked}}',
          {'count': newComments},
        ),
    ].join('; ');
    final excerpt = card.preview.kind == 'excerpt' ? card.preview.text : null;
    final meta = artifactUpdatedLine(context, card);
    final hint = RaftTypography.mono(
      t,
      size: 11,
      line: 16,
    ).copyWith(color: ui.foregroundHint);
    final openLabel = raftText(context, 'Open in browser');
    return _CardBox(
      key: ValueKey(
        'artifact-card-${card.id}@${card.pinned ? card.version : 'latest'}',
      ),
      onTap: onOpen,
      semanticLabel: card.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (excerpt != null && excerpt.trim().isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ui.lineHairline)),
              ),
              child: Padding(
                padding: _inset,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: _excerptMaxHeight,
                  ),
                  child: ClipRect(
                    child: Text(
                      excerpt,
                      key: const ValueKey('artifact-card-excerpt'),
                      maxLines: 6,
                      overflow: TextOverflow.fade,
                      style: RaftTypography.body(
                        t,
                        size: 13,
                        line: 18,
                      ).copyWith(color: ui.foregroundMuted),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RaftSpace.x3,
              _gap,
              RaftSpace.x1_5,
              RaftSpace.x1_5,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: _gap,
              children: [
                ArtifactKindTile(kind: card.kind),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftSpace.half,
                    children: [
                      Wrap(
                        spacing: RaftSpace.x1_5,
                        runSpacing: RaftSpace.x1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            card.title,
                            key: const ValueKey('artifact-card-title'),
                            style: RaftTypography.body(
                              t,
                              size: 14,
                              line: 20,
                              weight: FontWeight.w600,
                              color: ui.foreground,
                            ),
                          ),
                          ArtifactBadge(
                            artifactVersionLabel(
                              context,
                              card.version,
                              card.pinned ? card.latestVersion : null,
                            ),
                          ),
                          if (marks.isNotEmpty)
                            Semantics(
                              label: marksLabel,
                              child: ExcludeSemantics(
                                child: ArtifactBadge(
                                  marks.join(' · '),
                                  key: const ValueKey('artifact-card-new'),
                                  accent: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (facts != null)
                        Text(
                          facts,
                          key: const ValueKey('artifact-card-facts'),
                          style: hint,
                        ),
                      if (card.description case final String description
                          when description.isNotEmpty)
                        Text(
                          description,
                          maxLines: facts == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: RaftTypography.body(
                            t,
                            size: 13,
                            line: 18,
                          ).copyWith(color: ui.foregroundMuted),
                        ),
                    ],
                  ),
                ),
                if (onOpenInBrowser != null)
                  RaftButton(
                    key: const ValueKey('artifact-card-open-browser'),
                    glyph: RaftGlyph.arrowUpRight,
                    tooltip: openLabel,
                    semanticLabel: openLabel,
                    tone: RaftButtonRecipeVariant.ghost,
                    size: RaftButtonRecipeSize.iconSm,
                    onPressed: onOpenInBrowser,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: RaftSpace.x3,
              right: RaftSpace.x3,
              bottom: _gap,
            ),
            child: Wrap(
              spacing: _gap,
              runSpacing: RaftSpace.x1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: RaftSpace.x1,
                  children: [
                    RaftIcon(
                      artifactScopeGlyph(card.home),
                      size: 12,
                      color: ui.foregroundMuted,
                    ),
                    Text(
                      artifactScopeLabel(
                        context,
                        card.home,
                        fromAnotherServer: card.fromAnotherServer,
                        serverName: serverName,
                      ),
                      key: const ValueKey('artifact-card-scope'),
                      style: RaftTypography.body(
                        t,
                        size: 12,
                        line: 16,
                      ).copyWith(color: ui.foregroundMuted),
                    ),
                  ],
                ),
                Text(
                  meta,
                  key: const ValueKey('artifact-card-meta'),
                  style: hint,
                ),
                if (card.commentCount > 0)
                  Semantics(
                    label: icuText(
                      context,
                      '{count, plural, one {# comment} other {# comments}}',
                      {'count': card.commentCount},
                    ),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: RaftSpace.x1,
                        children: [
                          RaftIcon(
                            RaftGlyph.messageSquare,
                            size: 12,
                            color: ui.foregroundMuted,
                          ),
                          Text(
                            '${card.commentCount}',
                            key: const ValueKey('artifact-card-comments'),
                            style: hint,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The gray card of a deleted Artifact (Web `ArtifactDeletedCard`).
class ArtifactDeletedCard extends StatelessWidget {
  const ArtifactDeletedCard({super.key, required this.deleted});
  final ArtifactDeleted deleted;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return _CardBox(
      key: const ValueKey('artifact-card-deleted'),
      dimmed: true,
      child: Padding(
        padding: _inset,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: _gap,
          children: [
            const ArtifactKindTile(kind: ArtifactKind.other),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: RaftSpace.half,
                children: [
                  Text(
                    deleted.title,
                    style: RaftTypography.body(
                      t,
                      size: 14,
                      line: 20,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    artifactDeletedLine(context, deleted),
                    style: RaftTypography.mono(
                      t,
                      size: 11,
                      line: 16,
                    ).copyWith(color: t.ui.foregroundHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One skeleton in the card's shape while any card of the message loads
/// (Web `ArtifactMessageCardLoading`).
class ArtifactMessageCardLoading extends StatelessWidget {
  const ArtifactMessageCardLoading({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: raftText(context, 'Loading Artifact'),
    child: const _CardBox(
      key: ValueKey('artifact-card-loading'),
      child: Padding(padding: _inset, child: RaftSkeletonRow()),
    ),
  );
}

/// The cards for a message's Artifact links (Web `ArtifactMessageRefs`).
class ArtifactMessageRefs extends StatelessWidget {
  const ArtifactMessageRefs({
    super.key,
    required this.links,
    required this.onOpen,
    this.onOpenInBrowser,
    this.serverName,
  });

  final List<ArtifactLinkState> links;
  final void Function(ArtifactLinkTarget target, ArtifactCard card) onOpen;
  final void Function(ArtifactCard card)? onOpenInBrowser;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    if (links.any((link) => link is ArtifactLinkLoading)) {
      return const ArtifactMessageCardLoading();
    }
    final drawn = <Widget?>[
      for (final (index, link) in links.indexed)
        switch (link) {
          ArtifactLinkOk(:final card) => KeyedSubtree(
            key: ValueKey('artifact-ref-${link.target}#$index'),
            child: ArtifactMessageCard(
              card: card,
              serverName: serverName,
              onOpen: () => onOpen(link.target, card),
              onOpenInBrowser: onOpenInBrowser == null
                  ? null
                  : () => onOpenInBrowser!(card),
            ),
          ),
          ArtifactLinkDeleted(:final deleted) => KeyedSubtree(
            key: ValueKey('artifact-ref-${link.target}#$index'),
            child: ArtifactDeletedCard(deleted: deleted),
          ),
          _ => null,
        },
    ].nonNulls.toList();
    if (drawn.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('artifact-message-refs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: drawn,
    );
  }
}
