part of 'announcement_modal.dart';

class RaftAnnouncementSidebarCard extends StatelessWidget {
  const RaftAnnouncementSidebarCard({
    super.key,
    required this.title,
    required this.body,
    required this.position,
    required this.total,
    required this.onDismiss,
    required this.onNext,
    this.label,
    this.image,
    this.pictureFocus,
    this.onExpand,
    this.ctaLabel,
    this.onCta,
    this.externalCta = false,
    this.onLink,
  });

  final String title, body;
  final int position, total;
  final String? label, ctaLabel;
  final RaftAnnouncementImage? image;
  final FocusNode? pictureFocus;
  final VoidCallback onDismiss, onNext;
  final VoidCallback? onExpand, onCta;
  final bool externalCta;
  final ValueChanged<String>? onLink;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final labels = RaftAnnouncementLabels.of(context);
    final picture = image;
    final behind = (total - position).clamp(0, 2);
    final next = position < total
        ? raftTextZh(context, 'Next', '下一条')
        : labels.gotIt;
    final decoration = BoxDecoration(
      color: tokens.colors['layer-card'] ?? tokens.panel,
      border: Border.all(color: tokens.ui['line-seam']),
      borderRadius: BorderRadius.circular(tokens.radius),
    );
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          key: const Key('announcement-sidebar'),
          children: [
            for (var index = behind; index >= 1; index--)
              Positioned(
                left: index * 8,
                right: index * 8,
                bottom: (behind - index) * 5,
                height: 16,
                child: Opacity(
                  opacity: index == 1 ? 1 : .7,
                  child: DecoratedBox(decoration: decoration),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: behind * 5),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.min(
                    MediaQuery.sizeOf(context).height * .6,
                    576,
                  ),
                ),
                child: RaftCard(
                  semanticLabel: title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _Label(label ?? labels.latestUpdates),
                                ),
                                if (total > 1)
                                  RaftCssText(
                                    '$position / $total',
                                    style: tokens.scale(
                                      RaftTypeScale.caption,
                                      color: tokens.ui.foregroundMuted,
                                    ),
                                  ),
                                RaftIconButton(
                                  glyph: RaftGlyph.x,
                                  glyphSize: 14,
                                  tooltip: labels.dismiss,
                                  onPressed: onDismiss,
                                ),
                              ],
                            ),
                            RaftCardTitle(
                              Text(
                                title,
                                style: const TextStyle(
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (picture != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: RaftButton(
                                    key: const ValueKey(
                                      'announcement-picture-zoom',
                                    ),
                                    uiVariant: RaftButtonVariant.ghost,
                                    padding: EdgeInsets.zero,
                                    autoHeight: true,
                                    focusNode: pictureFocus,
                                    semanticLabel: raftTextZh(
                                      context,
                                      'Open announcement: {title}',
                                      '展开公告：{title}',
                                    ).replaceAll('{title}', title),
                                    onPressed: onExpand,
                                    child: Stack(
                                      children: [
                                        _Picture(picture),
                                        PositionedDirectional(
                                          end: 8,
                                          bottom: 8,
                                          child: ExcludeSemantics(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: tokens.ink.withValues(
                                                  alpha: .42,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: SizedBox.square(
                                                dimension: 24,
                                                child: Center(
                                                  child: RaftIcon(
                                                    RaftGlyph.maximize2,
                                                    size: 14,
                                                    color: tokens
                                                        .ui['foreground-inverse'],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              DefaultTextStyle(
                                style: tokens
                                    .scale(
                                      RaftTypeScale.callout,
                                      color: tokens.ui.foregroundMuted,
                                    )
                                    .copyWith(
                                      fontFamilyFallback: tokens.fontFallback,
                                    ),
                                child: RaftAnnouncementMarkdown(
                                  body,
                                  onLink: onLink,
                                  paragraphSpacing: RaftSpace.x2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (ctaLabel case final cta?) ...[
                              RaftButton(
                                label: cta,
                                trailingGlyph: externalCta
                                    ? RaftGlyph.arrowUpRight
                                    : null,
                                variant: RaftControlVariant.primary,
                                autoHeight: true,
                                onPressed: onCta,
                              ),
                              const SizedBox(height: 8),
                            ],
                            RaftButton(
                              label: next,
                              variant: ctaLabel == null
                                  ? RaftControlVariant.primary
                                  : RaftControlVariant.ghost,
                              onPressed: onNext,
                            ),
                          ],
                        ),
                      ),
                    ],
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
