part of 'mobile_navigation.dart';

bool _stickerWorkspace(RaftTokens t) =>
    t.option('mobileWorkspace.surface', or: 'polygon') == 'sticker';

/// Sidebar's phone Home header, whose actions use their natural frame boxes.
class _MobileWorkspaceHeader extends StatelessWidget {
  const _MobileWorkspaceHeader({
    required this.recipe,
    required this.leading,
    required this.actions,
  });
  final RaftMobileRootHeaderRecipe recipe;
  final Widget leading;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => RaftChrome(
    child: RaftTapSlopHost(
      child: RaftStatusBarSource(
        color: recipe.background,
        child: Container(
          height: recipe.height,
          padding: EdgeInsets.only(
            left: 16,
            right: recipe.tokens.size(
              'space.mobileWorkspaceHeaderEnd',
              fallback: 3,
            ),
          ),
          decoration: BoxDecoration(
            color: recipe.background,
            border: Border(
              bottom: BorderSide(
                color: recipe.tokens.colors['line-workspace-rail']!,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: leading),
              ),
              const SizedBox(width: 8),
              ...actions,
            ],
          ),
        ),
      ),
    ),
  );
}

class _StickerWorkspaceSelector extends StatelessWidget {
  const _StickerWorkspaceSelector({
    required this.recipe,
    required this.label,
    required this.onPressed,
    required this.attention,
    this.attentionLabel,
    this.focusNode,
    required this.publicPageLive,
  });
  final RaftMobileServerSelectorRecipe recipe;
  final String label;
  final VoidCallback? onPressed;
  final bool attention, publicPageLive;
  final String? attentionLabel;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final t = recipe.tokens;
    final color = recipe.foreground;
    final control = RaftControl(
      focusNode: focusNode,
      semanticLabel: label,
      onPressed: onPressed,
      minimumTargetSize: 36,
      visualHeight: recipe.controlHeight,
      padding: recipe.contentInset,
      recipe: _StickerWorkspaceSelectorRecipe(t, compact: recipe.compact),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: RaftCssText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: recipe.titleStyle,
              ),
            ),
          ),
          if (publicPageLive) ...[
            const SizedBox(width: 6),
            RaftPublicPageGlobe(live: true, size: 14, color: color),
          ],
          SizedBox(width: t.size('space.mobileWorkspaceGap', fallback: 8)),
          RaftIcon(RaftGlyph.chevronDown, size: 16, color: color),
        ],
      ),
    );
    final selector = Transform.rotate(
      angle: recipe.contentAngle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          control,
          if (attention)
            Positioned(
              top: -4,
              right: -4,
              child: Semantics(
                label: attentionLabel,
                child: const RaftAttentionDot(),
              ),
            ),
        ],
      ),
    );
    // The hit rectangle belongs to the unrotated layout box. The pill and
    // its badge rotate inside it; mouse input keeps the actual visual bounds.
    return RaftDensityScope.of(context) == RaftDensity.touch
        ? RaftTapSlopAnchor(
            minSize: const Size.square(RaftMetrics.touchTarget),
            child: selector,
          )
        : selector;
  }
}

class _StickerWorkspaceSelectorRecipe extends _SelectorRecipe {
  const _StickerWorkspaceSelectorRecipe(super.tokens, {required this.compact});
  final bool compact;
  @override
  Color get background =>
      compact ? Colors.transparent : tokens.colors['layer-mobile-workspace']!;
  @override
  Color backgroundFor({bool hovered = false}) => !compact && hovered
      ? Color.alphaBlend(
          tokens.colors['layer-mobile-workspace-veil']!.withValues(
            alpha: tokens.size('opacity.mobileWorkspaceVeil', fallback: .15),
          ),
          background,
        )
      : background;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered || pressed);
  @override
  BorderRadius get radius =>
      BorderRadius.circular(tokens.size('radius.control', fallback: 8));
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [
    if (!compact)
      BoxShadow(
        color: tokens.colors['line-mobile-workspace-ring']!,
        spreadRadius: 1.5,
      ),
    if (focused)
      BoxShadow(color: tokens.colors['line-strong']!, spreadRadius: 2),
  ];
}

/// NotificationTrigger's mobile-navbar frame treatment; generic SDK defaults
/// retain their original 32/16 geometry and muted foreground.
class _MobileHeaderBellRecipe extends _MobileNotificationRecipe {
  const _MobileHeaderBellRecipe(
    super.tokens, {
    super.selected,
    required this.borderWidth,
  });
  final double borderWidth;
  @override
  Color get foreground =>
      tokens.colors[selected
          ? 'foreground-workspace-rail-action-selected'
          : 'foreground-workspace-rail-action']!;
  @override
  Color get background => selected
      ? tokens.colors['layer-workspace-rail-selected']!
      : Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => selected
      ? background
      : hovered
      ? tokens.colors['layer-workspace-rail-hover']!
      : background;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered || pressed);
  @override
  BorderRadius get radius =>
      BorderRadius.circular(tokens.size('radius.control', fallback: 8));
  @override
  BorderSide side({bool hovered = false}) => BorderSide(
    width: borderWidth,
    color: selected
        ? tokens.colors['line-workspace-rail-selected']!
        : Colors.transparent,
  );
}
