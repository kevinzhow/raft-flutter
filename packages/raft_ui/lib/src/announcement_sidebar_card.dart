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
    final pictureRadius = raftRoundedBorder(
      tokens.size('radius.control', fallback: 8),
    );
    final behind = (total - position).clamp(0, 2);
    final next = position < total
        ? raftTextZh(context, 'Next', '下一条')
        : labels.gotIt;
    final decoration = BoxDecoration(
      color: tokens.colors['layer-card'] ?? tokens.panel,
      border: Border.all(color: tokens.ui['line-seam']),
      borderRadius: BorderRadius.circular(tokens.radius),
    );
    final scrollCard = RaftScaled.grows(context);
    final bodyContent = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (picture != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RaftInteractive(
                key: const ValueKey('announcement-picture-zoom'),
                expandTouchTarget: false,
                focusNode: pictureFocus,
                semanticLabel: raftTextZh(
                  context,
                  'Open announcement: {title}',
                  '展开公告：{title}',
                ).replaceAll('{title}', title),
                onPressed: onExpand,
                builder: (context, state) => CustomPaint(
                  foregroundPainter: RaftCssFocusOutline(
                    enabled: state.focusVisible,
                    color: tokens.ui['foreground'],
                    radius: pictureRadius,
                  ),
                  child: Stack(
                    children: [
                      _Picture(picture, radius: pictureRadius),
                      if (state.hovered)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: RaftPrimitiveColors.black.withValues(
                                alpha: .1,
                              ),
                              borderRadius: pictureRadius,
                            ),
                          ),
                        ),
                      PositionedDirectional(
                        end: RaftSpace.x2,
                        bottom: RaftSpace.x2,
                        child: ExcludeSemantics(
                          child: Opacity(
                            opacity: state.hovered || state.focusVisible
                                ? 1
                                : .7,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: tokens.ui['foreground'].withValues(
                                  alpha: .6,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox.square(
                                dimension: RaftSpace.x6,
                                child: Center(
                                  child: RaftIcon(
                                    RaftGlyph.maximize2,
                                    size: 14,
                                    color: tokens.ui['foreground-inverse'],
                                  ),
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
            ),
          DefaultTextStyle(
            style: tokens
                .scale(RaftTypeScale.callout, color: tokens.ui.foregroundMuted)
                .copyWith(fontFamilyFallback: tokens.fontFallback),
            child: RaftAnnouncementMarkdown(
              body,
              onLink: onLink,
              paragraphSpacing: RaftSpace.x2,
            ),
          ),
        ],
      ),
    );
    final content = Column(
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
                  Expanded(child: _Label(label ?? labels.latestUpdates)),
                  if (total > 1)
                    RaftCssText(
                      '$position / $total',
                      style: tokens.scale(
                        RaftTypeScale.caption,
                        color: tokens.ui.foregroundMuted,
                      ),
                    ),
                  RaftChrome(
                    child: RaftLargeContentViewer(
                      label: labels.dismiss,
                      enabled: true,
                      onActivate: onDismiss,
                      iconBuilder: (_, size) =>
                          RaftIcon(RaftGlyph.x, size: size),
                      child: RaftButton(
                        glyph: RaftGlyph.x,
                        uiSize: RaftButtonSize.iconMd,
                        uiVariant: RaftButtonVariant.ghost,
                        tooltip: labels.dismiss,
                        onPressed: onDismiss,
                        layoutTouchTarget: true,
                        expandTouchTarget: false,
                        semanticContainer: false,
                      ),
                    ),
                  ),
                ],
              ),
              RaftCardTitle(
                Text(
                  title,
                  style: const TextStyle(decoration: TextDecoration.none),
                ),
              ),
            ],
          ),
        ),
        if (scrollCard)
          bodyContent
        else
          Flexible(child: SingleChildScrollView(child: bodyContent)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ctaLabel case final cta?) ...[
                RaftButton(
                  label: cta,
                  trailingGlyph: externalCta ? RaftGlyph.arrowUpRight : null,
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
                  child: scrollCard
                      ? SingleChildScrollView(child: content)
                      : content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
