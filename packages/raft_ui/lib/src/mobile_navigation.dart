import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'primitive_tokens.dart';
import 'recipe_surface.dart';
import 'tokens/tokens.dart';
import 'theme.dart';

@immutable
class RaftMobileNavItem {
  const RaftMobileNavItem({
    required this.id,
    required this.label,
    required this.glyph,
    this.enabled = true,
    this.attention = false,
    this.key,
  });
  final String id, label;
  final RaftGlyph glyph;
  final bool enabled, attention;
  final Key? key;
}

/// MobileNav recipe5794; MainLayout's Brutal-only short-viewport adaptation.
@immutable
class RaftMobileNavRecipe {
  const RaftMobileNavRecipe(this.tokens, {required this.viewportHeight});
  final RaftTokens tokens;
  final double viewportHeight;
  bool get showGlyph => !tokens.brutal || viewportHeight > 600;
  double get glyphSize => 18;
  double get capsuleInset => 4;
  double get itemGap => 8;
  double capsuleWidth(int count) =>
      capsuleInset * 2 + count * 44 + (count - 1) * itemGap;
  double get capsuleHeight => capsuleInset * 2 + 44;
  double get itemHeight => tokens.brutal
      ? showGlyph
            ? 51
            : 31
      : 44;
  double bottomSpace(double inset) =>
      tokens.brutal ? math.min(inset, 34) : math.max(8, inset);
  Color get background => tokens.panel;
  List<BoxShadow> get rootShadows => tokens.brutal
      ? const []
      : tokens.dark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: .55),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            offset: const Offset(0, 4),
            blurRadius: 8,
            spreadRadius: -3,
          ),
        ]
      : [
          BoxShadow(
            color: tokens.ink.withValues(alpha: .1),
            offset: const Offset(0, 1),
            blurRadius: 1,
          ),
          BoxShadow(color: tokens.ink.withValues(alpha: .04), spreadRadius: 1),
          BoxShadow(
            color: tokens.ink.withValues(alpha: .16),
            offset: const Offset(0, 2),
            blurRadius: 12,
            spreadRadius: -4,
          ),
        ];
}

class _MobileItemRecipe extends RaftControlRecipe {
  const _MobileItemRecipe(super.tokens, {super.selected});
  @override
  bool get transformsOnInteraction => false;
  @override
  double get disabledOpacity => .45;
  @override
  Color foregroundFor({bool hovered = false}) => hovered && !selected
      ? tokens.brutal
            ? Colors.black
            : tokens.muted
      : foreground;
  @override
  Color get background => selected
      ? tokens.brutal
            ? tokens.colors['primary-400']!
            : tokens.dark
            ? tokens.colors['fill-muted']!
            : tokens.panel
      : Colors.transparent;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => pressed && !selected
      ? tokens.colors[tokens.brutal ? 'ink-6' : 'fill-strong']!
      : background;
  @override
  Color get foreground => selected
      ? tokens.brutal
            ? Colors.black
            : tokens.strong
      : tokens.brutal
      ? Colors.black.withValues(alpha: .55)
      : tokens.colors['foreground-placeholder']!;
  @override
  Color get focusRing =>
      tokens.brutal ? Colors.black : tokens.colors['line-strong']!;
  // CSS :focus-visible is an outside outline, separate from selected shadows.
  // Consumed by RaftControl's modality-gated outside-RRect painter.
  @override
  double get focusOutlineWidth => 2;
  @override
  double get focusOutlineOffset => 2;
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 22);
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  EdgeInsets get padding => EdgeInsets.zero;
  @override
  double get insetHighlightAlpha =>
      !tokens.brutal && tokens.dark && selected ? .06 : 0;
  @override
  Gradient? get overlayGradient => selected && !tokens.brutal && !tokens.dark
      ? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .12),
            Colors.black.withValues(alpha: .06),
          ],
        )
      : null;
  @override
  TextStyle get textStyle =>
      RaftTypography.body(
        tokens,
        size: 10,
        line: 15,
        weight: FontWeight.w400,
        color: foreground,
        // `tracking-wider`; CSS line boxes split leading evenly.
      ).copyWith(
        letterSpacing: .5,
        leadingDistribution: TextLeadingDistribution.even,
      );
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [
    if (selected && !tokens.brutal && tokens.dark) ...[
      BoxShadow(color: Colors.black.withValues(alpha: .6), spreadRadius: 1),
      BoxShadow(
        color: Colors.black.withValues(alpha: .5),
        offset: const Offset(0, 24),
        blurRadius: 44,
        spreadRadius: -12,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: .45),
        offset: const Offset(0, 10),
        blurRadius: 16,
        spreadRadius: -6,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: .4),
        offset: const Offset(0, 4),
        blurRadius: 6,
        spreadRadius: -3,
      ),
    ],
    if (selected && !tokens.brutal && !tokens.dark) ...[
      BoxShadow(
        color: RaftPrimitiveColors.black.withValues(alpha: .071),
        offset: const Offset(0, .5),
      ),
      BoxShadow(color: tokens.ink.withValues(alpha: .08), spreadRadius: 1),
      BoxShadow(
        color: RaftPrimitiveColors.black.withValues(alpha: .031),
        offset: const Offset(0, 18),
        blurRadius: 24,
        spreadRadius: -12,
      ),
      BoxShadow(
        color: RaftPrimitiveColors.black.withValues(alpha: .039),
        offset: const Offset(0, 12),
        blurRadius: 12,
        spreadRadius: -6,
      ),
      BoxShadow(
        color: RaftPrimitiveColors.black.withValues(alpha: .039),
        offset: const Offset(0, 4),
        blurRadius: 6,
        spreadRadius: -3,
      ),
      BoxShadow(
        color: tokens.colors['line-muted']!.withValues(alpha: .45),
        spreadRadius: 1,
      ),
    ],
  ];
}

/// Presentation only. The caller owns guest visibility, detail hiding and tab resets.
class RaftMobileNav extends StatelessWidget {
  const RaftMobileNav({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.bottomInset,
    this.viewportHeight,
  });
  final List<RaftMobileNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double? bottomInset, viewportHeight;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final t = RaftTokens.of(context);
    final recipe = RaftMobileNavRecipe(
      t,
      viewportHeight: viewportHeight ?? MediaQuery.sizeOf(context).height,
    );
    final inset = bottomInset ?? MediaQuery.viewPaddingOf(context).bottom;
    final touch = RaftDensityScope.of(context) == RaftDensity.touch;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final itemWidth = availableWidth / items.length;
        Widget item(RaftMobileNavItem i, int index) {
          final selected = i.id == selectedId;
          final height = recipe.itemHeight;
          final control = Semantics(
            selected: selected,
            child: RaftControl(
              key: i.key,
              onPressed: i.enabled ? () => onSelected(i.id) : null,
              tooltip: t.brutal ? null : raftText(context, i.label),
              semanticLabel: t.brutal ? null : raftText(context, i.label),
              visualHeight: height,
              visualWidth: t.brutal
                  ? itemWidth - (index == items.length - 1 ? 0 : 2)
                  : 44,
              minimumTargetSize: touch ? math.max(48, height) : height,
              recipe: _MobileItemRecipe(t, selected: selected),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (t.brutal)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (recipe.showGlyph) ...[
                          RaftIcon(i.glyph, size: 18),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          raftText(context, i.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  else
                    RaftIcon(i.glyph, size: 18),
                  if (i.attention)
                    Positioned(
                      top: t.brutal ? 4 : -4,
                      right: t.brutal ? 8 : -4,
                      child: _AttentionDot(t),
                    ),
                ],
              ),
            ),
          );
          return t.brutal
              ? Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: index == items.length - 1
                          ? null
                          // `border-r-2 border-line-strong` (MobileNavItem).
                          : Border(
                              right: BorderSide(
                                color: t.semantic.lineStrong,
                                width: 2,
                              ),
                            ),
                    ),
                    child: control,
                  ),
                )
              : control;
        }

        final bar = Container(
          key: t.brutal ? null : const ValueKey('mobile-nav-source-capsule'),
          width: t.brutal ? null : recipe.capsuleWidth(items.length),
          height: t.brutal ? null : recipe.capsuleHeight,
          padding: t.brutal
              ? EdgeInsets.only(bottom: recipe.bottomSpace(inset))
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: recipe.background,
            border: t.brutal
                ? const Border(top: BorderSide(color: Colors.black, width: 2))
                : null,
            borderRadius: t.brutal ? null : BorderRadius.circular(1000),
            boxShadow: recipe.rootShadows,
          ),
          child: t.brutal
              ? Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      item(items[index], index),
                  ],
                )
              : Stack(
                  // Expanded touch targets fit INSIDE the source capsule and its
                  // gaps. They never borrow pixels from the neighboring body.
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Positioned(
                        left:
                            recipe.capsuleInset +
                            index * (44 + recipe.itemGap) -
                            (touch ? 2 : 0),
                        top: recipe.capsuleInset - (touch ? 2 : 0),
                        width: touch ? 48 : 44,
                        height: touch ? 48 : 44,
                        child: item(items[index], index),
                      ),
                  ],
                ),
        );
        return t.brutal
            ? bar
            : Padding(
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: recipe.bottomSpace(inset),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: bar,
                ),
              );
      },
    );
  }
}

/// Source polygon rotates the rectangle's points, not every icon in the header.
@immutable
class RaftMobileServerSelectorRecipe {
  const RaftMobileServerSelectorRecipe(
    this.tokens, {
    required this.viewportHeight,
  });
  final RaftTokens tokens;
  final double viewportHeight;
  bool get compact => viewportHeight <= 600;
  double get contentAngle => compact ? 0 : -2 * math.pi / 180;
  double get chevronAngle => -contentAngle;
  EdgeInsets get contentInset => compact
      ? EdgeInsets.zero
      : const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
  Color get foreground =>
      tokens.colors[tokens.brutal ? 'color-brutal-yellow' : 'primary-strong']!;
  List<Offset> polygon(Size size, {double shadowOffset = 0}) {
    final center = Offset(size.width / 2, size.height / 2);
    final cosine = math.cos(contentAngle), sine = math.sin(contentAngle);
    return [
      Offset(shadowOffset, shadowOffset),
      Offset(size.width + shadowOffset, shadowOffset),
      Offset(size.width + shadowOffset, size.height + shadowOffset),
      Offset(shadowOffset, size.height + shadowOffset),
    ].map((p) {
      final d = p - center;
      return center +
          Offset(d.dx * cosine - d.dy * sine, d.dx * sine + d.dy * cosine);
    }).toList();
  }
}

class RaftMobileServerSelector extends StatelessWidget {
  const RaftMobileServerSelector({
    super.key,
    required this.label,
    this.onPressed,
    this.attention = false,
    this.viewportHeight,
    this.attentionLabel,
    this.focusNode,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool attention;
  final String? attentionLabel;
  final double? viewportHeight;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMobileServerSelectorRecipe(
      t,
      viewportHeight: viewportHeight ?? MediaQuery.sizeOf(context).height,
    );
    return _SelectorControl(
      recipe: recipe,
      label: label,
      onPressed: onPressed,
      attention: attention,
      attentionLabel: attentionLabel,
      focusNode: focusNode,
    );
  }
}

class _SelectorControl extends StatelessWidget {
  const _SelectorControl({
    required this.recipe,
    required this.label,
    required this.onPressed,
    required this.attention,
    this.attentionLabel,
    this.focusNode,
  });
  final RaftMobileServerSelectorRecipe recipe;
  final String label;
  final VoidCallback? onPressed;
  final bool attention;
  final String? attentionLabel;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => RaftControl(
    focusNode: focusNode,
    onPressed: onPressed,
    semanticLabel: null,
    visualHeight: recipe.compact ? 24 : 36,
    recipe: _SelectorRecipe(recipe.tokens),
    padding: recipe.contentInset,
    child: CustomPaint(
      painter: recipe.compact ? null : _SelectorPainter(recipe),
      child: Transform.rotate(
        angle: recipe.contentAngle,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RaftTypography.heading(
                        recipe.tokens,
                        size: 16,
                        line: 24,
                        weight: FontWeight.w700,
                      ).copyWith(color: recipe.foreground),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Transform.rotate(
                  angle: recipe.chevronAngle,
                  child: RaftIcon(
                    RaftGlyph.chevronDown,
                    size: 16,
                    color: recipe.foreground,
                  ),
                ),
              ],
            ),
            if (attention)
              Positioned(
                top: -10,
                right: -18,
                child: Semantics(
                  label: attentionLabel,
                  child: _AttentionDot(recipe.tokens),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SelectorRecipe extends RaftControlRecipe {
  const _SelectorRecipe(super.tokens);
  @override
  bool get transformsOnInteraction => false;
  @override
  Color get background => Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => Colors.transparent;
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => focused
      ? [BoxShadow(color: tokens.colors['line-strong']!, spreadRadius: 2)]
      : const [];
}

class _SelectorPainter extends CustomPainter {
  const _SelectorPainter(this.recipe);
  final RaftMobileServerSelectorRecipe recipe;
  @override
  void paint(Canvas canvas, Size size) {
    // SVG extends2px beyond the measured button, scales viewBox by4px extra.
    final inset = recipe.contentInset;
    final buttonSize = Size(
      size.width + inset.horizontal,
      size.height + inset.vertical,
    );
    canvas.save();
    canvas.translate(-inset.left - 2, -inset.top - 2);
    canvas.scale(
      (buttonSize.width + 4) / buttonSize.width,
      (buttonSize.height + 4) / buttonSize.height,
    );
    Path path(double shadow) {
      final points = recipe.polygon(buttonSize, shadowOffset: shadow);
      return Path()..addPolygon(points, true);
    }

    canvas.drawPath(
      path(2),
      Paint()..color = RaftProductColors.brutal.brutalBlack,
    );
    canvas.drawPath(path(0), Paint()..color = Colors.black);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SelectorPainter old) =>
      old.recipe.viewportHeight != recipe.viewportHeight ||
      old.recipe.tokens != recipe.tokens;
}

class _AttentionDot extends StatelessWidget {
  const _AttentionDot(this.tokens);
  final RaftTokens tokens;
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: tokens.brutal
          ? tokens.colors['color-brutal-pink']!
          : tokens.accentFill,
      border: tokens.brutal ? Border.all(color: Colors.black) : null,
    ),
  );
}

/// Sidebar3748 mobile TAB ROOT chrome. Detail panel headers are a different recipe.
@immutable
class RaftMobileRootHeaderRecipe {
  const RaftMobileRootHeaderRecipe(this.tokens, {required this.viewportHeight});
  final RaftTokens tokens;
  final double viewportHeight;
  double get height =>
      RaftLayoutMetrics.shellHeaderHeight(tokens, viewportHeight);
  Color get background => tokens.brutal ? tokens.primaryFill : tokens.panel;
  BorderSide get border => BorderSide(
    color: tokens.brutal ? Colors.black : tokens.colors['line-muted']!,
    width: tokens.brutal ? 2 : 1,
  );
  EdgeInsets get inset => const EdgeInsets.symmetric(horizontal: 16);
  TextStyle get title => RaftTypography.heading(
    tokens,
    size: 16,
    line: 24,
    weight: FontWeight.w700,
  );
}

/// No SafeArea inside: the shell applies the top system inset exactly once.
class RaftMobileRootHeader extends StatelessWidget {
  const RaftMobileRootHeader({
    super.key,
    this.leading,
    this.title,
    this.actions = const [],
    this.viewportHeight,
  });
  final Widget? leading;
  final String? title;
  final List<Widget> actions;
  final double? viewportHeight;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftMobileRootHeaderRecipe(
      RaftTokens.of(context),
      viewportHeight: viewportHeight ?? MediaQuery.sizeOf(context).height,
    );
    return Container(
      height: recipe.height,
      padding: recipe.inset,
      decoration: BoxDecoration(
        color: recipe.background,
        border: Border(bottom: recipe.border),
      ),
      child: Row(
        children: [
          if (leading != null)
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: leading!),
            )
          else if (title != null)
            Expanded(
              child: Text(
                raftText(context, title!),
                style: recipe.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (leading == null && title == null) const Spacer(),
          for (final action in actions) ...[const SizedBox(width: 12), action],
        ],
      ),
    );
  }
}

/// Source NotificationTrigger mobile-navbar visual. The caller owns its center.
class RaftMobileNotificationButton extends StatelessWidget {
  const RaftMobileNotificationButton({
    super.key,
    this.onPressed,
    this.open = false,
    this.semanticLabel = 'Notification center',
    this.visualSize = 32,
    this.glyphSize = 16,
  });
  final VoidCallback? onPressed;
  final bool open;
  final String semanticLabel;

  /// Original mobile32/16 and LeftRail40/18 share one trigger state recipe.
  final double visualSize, glyphSize;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = _MobileNotificationRecipe(t, selected: open);
    return RaftInteractive(
      onPressed: onPressed,
      semanticLabel: raftText(context, semanticLabel),
      tooltip: raftText(context, semanticLabel),
      builder: (context, state) => CustomPaint(
        painter: RaftOuterShadowPainter(
          recipe.shadows(focused: state.focusVisible),
          recipe.radius,
        ),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : RaftPrimitives.controlDuration,
          width: visualSize,
          height: visualSize,
          alignment: Alignment.center,
          decoration: RaftLayeredDecoration(
            BoxDecoration(
              color: recipe.backgroundFor(hovered: state.hovered),
              border: Border.fromBorderSide(
                recipe.side(hovered: state.hovered),
              ),
              borderRadius: recipe.radius,
            ),
            open ? t.themeShadows.sm.inset : const [],
            recipe.radius,
            null,
            EdgeInsets.all(t.brutal ? 2 : 1),
          ),
          child: RaftIcon(
            RaftGlyph.bell,
            size: glyphSize,
            color: recipe.foreground,
          ),
        ),
      ),
    );
  }
}

class _MobileNotificationRecipe extends RaftControlRecipe {
  const _MobileNotificationRecipe(super.tokens, {super.selected});
  @override
  bool get transformsOnInteraction => false;
  @override
  Color get background => selected
      ? tokens.brutal
            ? tokens.panel
            : tokens.colors['fill-muted']!
      : Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => selected || !hovered
      ? background
      : tokens.brutal
      ? tokens.panel
      : tokens.colors['fill-muted']!;
  @override
  Color get foreground => tokens.brutal ? Colors.black : tokens.muted;
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  @override
  BorderSide side({bool hovered = false}) => BorderSide(
    color: tokens.brutal && (selected || hovered)
        ? Colors.black
        : Colors.transparent,
    width: tokens.brutal ? 2 : 1,
  );
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [
    // NotificationTrigger.tsx explicitly uses shadow-raft-sm in every mode.
    // Keep CSS order and blur conversion, including Elegant dark's sm layers.
    if (selected)
      for (final layer in tokens.themeShadows.sm.layers.reversed)
        if (!layer.inset)
          BoxShadow(
            color: layer.color,
            offset: layer.offset,
            spreadRadius: layer.spread,
            blurRadius: raftCssBlurRadius(layer.blur),
          ),
    if (focused)
      BoxShadow(color: tokens.colors['line-strong']!, spreadRadius: 2),
  ];
}
