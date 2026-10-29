part of 'mobile_navigation.dart';

/// Shared in-flow grid. Arrangement, selection, type and paint rules are
/// independent contract data; the floating capsule keeps its original path.
class _DockedMobileNav extends StatelessWidget {
  const _DockedMobileNav({
    required this.items,
    required this.selectedId,
    required this.onSelected,
    required this.bottomInset,
    required this.viewportHeight,
  });
  final List<RaftMobileNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double bottomInset, viewportHeight;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final g = _DockedNavGeometry(context, viewportHeight, bottomInset);
    return Container(
      key: const ValueKey('mobile-nav-source-docked'),
      height: g.rootHeight,
      decoration: BoxDecoration(
        color: t.colors['layer-mobile-nav'],
        border: Border(
          top: BorderSide(
            color: t.colors['line-mobile-nav']!,
            width: g.lineTop,
          ),
          bottom: g.lineBottom == 0
              ? BorderSide.none
              : BorderSide(
                  color: t.colors['line-mobile-nav']!,
                  width: g.lineBottom,
                ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: g.n('space.mobileNavInline', 8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth / items.length;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < items.length; index++)
                  Positioned(
                    left: index * width,
                    top: g.targetTop,
                    width: width,
                    height: g.targetHeight,
                    child: _DockedNavItem(
                      item: items[index],
                      selected: items[index].id == selectedId,
                      onSelected: onSelected,
                      geometry: g,
                      width: width,
                      last: index == items.length - 1,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DockedNavGeometry {
  _DockedNavGeometry(BuildContext context, double viewportHeight, double inset)
    : t = RaftTokens.of(context),
      scaler = MediaQuery.textScalerOf(context),
      touch = RaftDensityScope.of(context) == RaftDensity.touch,
      viewportHeight = viewportHeight,
      inset = inset;
  final RaftTokens t;
  final TextScaler scaler;
  final bool touch;
  final double viewportHeight, inset;
  double n(String name, double value) => t.size(name, fallback: value);
  bool get labels =>
      t.option('mobileNav.labels', or: 'withLabels') == 'withLabels';
  bool get glyphs => viewportHeight > n('size.mobileNavGlyphHideHeight', 0);
  bool get iconSticker =>
      t.option('mobileNav.selection', or: 'iconSticker') == 'iconSticker';
  double get top => n('space.mobileNavTop', 6);
  double get lineTop => n('stroke.mobileNavTop', 1);
  double get lineBottom => n('stroke.mobileNavBottom', 0);
  double get safe => math.min(inset, n('size.mobileNavSafeMax', 34));
  double get height {
    final size = n('type.mobileNavLabel.size', 10);
    final content =
        n('space.mobileNavItemTop', 4) +
        (glyphs ? n('size.mobileNavGlyph', 22) : 0) +
        (glyphs && labels ? n('space.mobileNavGlyphLabel', 7) : 0) +
        (labels
            ? n('type.mobileNavLabel.line', 12) * scaler.scale(size) / size
            : 0);
    return math.max(
      n(glyphs ? 'size.mobileNavItem' : 'size.mobileNavItemCompact', 45),
      content,
    );
  }

  double get rootHeight => lineTop + top + height + lineBottom + safe;
  double get targetHeight => touch ? math.max(48, height) : height;
  // The full hit box stays inside chrome; the visual retains its source top.
  double get targetTop => math.max(
    0,
    math.min(
      top - (targetHeight - height) / 2,
      top + height + safe - targetHeight,
    ),
  );
  Widget box(Widget child) =>
      t.option('mobileNav.boxLayout', or: 'css') == 'css'
      ? RaftBlinkSnap(child: child)
      : child;
  TextStyle labelStyle(bool selected) =>
      RaftTypography.body(
        t,
        size: n('type.mobileNavLabel.size', 10),
        line: n('type.mobileNavLabel.line', 12),
        weight: raftFontWeight(
          n(
            selected
                ? 'type.mobileNavLabelSelected.weight'
                : 'type.mobileNavLabel.weight',
            selected ? 700 : 600,
          ),
        ),
        color:
            t.colors[selected
                ? 'foreground-mobile-nav-selected'
                : 'foreground-mobile-nav'],
      ).copyWith(
        decoration: TextDecoration.none,
        letterSpacing: n('type.mobileNavLabel.tracking', 0),
        leadingDistribution: TextLeadingDistribution.even,
      );
}

class _DockedNavItem extends StatelessWidget {
  const _DockedNavItem({
    required this.item,
    required this.selected,
    required this.onSelected,
    required this.geometry,
    required this.width,
    required this.last,
  });
  final RaftMobileNavItem item;
  final bool selected, last;
  final ValueChanged<String> onSelected;
  final _DockedNavGeometry geometry;
  final double width;
  RaftTokens get t => geometry.t;
  double n(String name, double value) => geometry.n(name, value);

  @override
  Widget build(BuildContext context) => RaftLargeContentViewer(
    label: raftText(context, item.label),
    enabled: item.enabled,
    onActivate: () => onSelected(item.id),
    iconBuilder: (context, size) => RaftIcon(item.glyph, size: size),
    child: RaftInteractive(
      key: item.key,
      semanticLabel: raftText(context, item.label),
      selected: selected,
      tooltip: geometry.labels ? null : raftText(context, item.label),
      onPressed: item.enabled ? () => onSelected(item.id) : null,
      builder: (context, state) => SizedBox(
        width: width,
        height: geometry.targetHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: geometry.top - geometry.targetTop,
              left: 0,
              width: width,
              height: geometry.height,
              child: Opacity(
                opacity: item.enabled ? 1 : .45,
                child: CustomPaint(
                  foregroundPainter: RaftCssFocusOutline(
                    enabled: state.focusVisible,
                    color: t.colors['line-strong']!,
                    radius: BorderRadius.circular(
                      n('radius.mobileNavSticker', 8),
                    ),
                  ),
                  child: Container(
                    decoration: last || n('stroke.mobileNavDivider', 0) == 0
                        ? null
                        : BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: t.colors['line-mobile-nav-divider']!,
                                width: n('stroke.mobileNavDivider', 0),
                              ),
                            ),
                          ),
                    child: ColoredBox(
                      color: !geometry.iconSticker
                          ? (state.pressed
                                ? t.colors['layer-mobile-nav-pressed']!
                                : selected
                                ? t.colors['layer-mobile-nav-selected']!
                                : Colors.transparent)
                          : Colors.transparent,
                      child: _content(context, state),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _content(BuildContext context, RaftInteractionState state) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: [
      if (geometry.iconSticker) geometry.box(_sticker(context, state)),
      Padding(
        padding: EdgeInsets.only(top: n('space.mobileNavItemTop', 4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (geometry.glyphs) _glyph(context),
            if (geometry.glyphs && geometry.labels)
              SizedBox(height: n('space.mobileNavGlyphLabel', 7)),
            if (geometry.labels) _label(context),
          ],
        ),
      ),
      if (item.attention) Positioned(top: 4, right: 8, child: _AttentionDot(t)),
    ],
  );

  Widget _sticker(BuildContext context, RaftInteractionState state) {
    final fill = selected
        ? t.colors['layer-mobile-nav-selected']!
        : Colors.transparent;
    return Container(
      key: ValueKey('mobile-nav-sticker-${item.id}'),
      width: n('size.mobileNavStickerWidth', 56),
      height: n('size.mobileNavStickerHeight', 30),
      decoration: BoxDecoration(
        color: state.pressed
            ? (selected
                  ? Color.alphaBlend(t.colors['sticker-pressed']!, fill)
                  : t.colors['layer-mobile-nav-pressed'])
            : fill,
        borderRadius: BorderRadius.circular(n('radius.mobileNavSticker', 8)),
        border: Border.all(
          color: selected
              ? t.colors['line-mobile-nav-selected']!
              : Colors.transparent,
          width: raftControlBorderPx(
            context,
            n('stroke.mobileNavSticker', 1.5),
          ),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: t.colors['line-mobile-nav-selected-ring']!,
                  spreadRadius: n('stroke.mobileNavStickerRing', 1.5),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _glyph(BuildContext context) {
    Widget glyph = geometry.box(
      RaftIcon(
        item.glyph,
        size: n('size.mobileNavGlyph', 22),
        color:
            t.colors[selected
                ? 'foreground-mobile-nav-glyph-selected'
                : 'foreground-mobile-nav'],
      ),
    );
    if (item.badgeCount > 0)
      glyph = Stack(
        clipBehavior: Clip.none,
        children: [
          glyph,
          Positioned(
            top: geometry.iconSticker ? -8 : -3,
            left: 11,
            child: Semantics(
              key: ValueKey('mobile-nav-badge-${item.id}'),
              label: raftFormat(context, '{count} unread', {
                'count': item.badgeCount > 99 ? '99+' : item.badgeCount,
              }),
              child: ExcludeSemantics(
                child: RaftSidebarUnreadCount(count: item.badgeCount),
              ),
            ),
          ),
        ],
      );
    return glyph;
  }

  Widget _label(BuildContext context) {
    final label = raftText(context, item.label),
        style = geometry.labelStyle(selected);
    return ExcludeSemantics(
      child: t.option('mobileNav.textLayout', or: 'css') == 'css'
          ? RaftCssText(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}
