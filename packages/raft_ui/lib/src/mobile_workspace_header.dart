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
            // The workspace button hangs 11px outward (`-ml-[11px]`), so its
            // avatar sits on the band's 20px content edge.
            left: 20 - RaftWorkspaceButton.hang,
            // Web v1.24 measured: the bell's 44px box ends 9px from the edge (the
            // band's 20 less the same 11).
            right: 20 - RaftWorkspaceButton.hang,
          ),
          decoration: BoxDecoration(
            color: recipe.background,
            border: Border(bottom: recipe.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: leading),
              ),
              // TabRootBar puts a flexible spacer between the workspace and
              // the actions, with one gap on each side of that spacer.
              const SizedBox(width: RaftSpace.x2 * 2),
              ...actions,
            ],
          ),
        ),
      ),
    ),
  );
}

/// NotificationTrigger's frame button in the phone navbar and desktop top bar.
class _FrameBellRecipe extends _MobileNotificationRecipe {
  const _FrameBellRecipe(
    super.tokens, {
    super.selected,
    required this.borderWidth,
  });
  final double borderWidth;
  @override
  Color get foreground =>
      tokens.colors[selected
          ? 'foreground-on-frame-active'
          : 'foreground-on-frame']!;
  @override
  Color get background =>
      selected ? tokens.colors['layer-frame-active']! : Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => selected
      ? background
      : hovered
      ? tokens.colors['fill-frame-medium']!
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
    color: selected ? tokens.colors['line-frame-active']! : Colors.transparent,
  );

  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [
    if (focused)
      for (final layer in tokens.shadowLayers('shadow.focusRing').reversed)
        if (!layer.inset) layer.toBoxShadow(),
  ];
}
