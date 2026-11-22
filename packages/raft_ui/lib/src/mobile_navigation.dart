import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'mobile_page_header.dart';
import 'status_bar.dart';
import 'space.dart' show RaftSpace;
import 'tap_slop.dart';

import 'design_primitives.dart';
import 'components.dart' show RaftSidebarUnreadCount;
import 'icons.dart';
import 'localization.dart';
import 'primitive_tokens.dart';
import 'public_page_mark.dart';
import 'workspace_button.dart';
import 'workspace_shell.dart' show RaftWorkspaceRailAction;
import 'rail_attention.dart';
import 'recipe_surface.dart';
import 'tokens/tokens.dart';
import 'theme.dart';
import 'text_scaling.dart';
import 'large_content_viewer.dart';
import 'dismiss_scope.dart';
import 'interaction.dart';
import 'popover_surface.dart';
import 'recipes/avatar.g.dart';
import 'recipes/mobile_nav_server.g.dart';
import 'recipes/popover.g.dart';
import 'recipes/recipe_runtime.dart' show RaftRecipeStates, RaftSlotStyle;
import 'raft/avatar.dart' show RaftAvatarBadge, RaftAvatarSize;
import 'raft/blink_snap.dart';
import 'raft/css_box.dart' show RaftCssBox, raftControlBorderPx;
import 'raft/status.dart' show RaftStatus, RaftStatusSize, RaftStatusVariant;
import 'raft/ui_tokens.dart' show RaftTokensUi;
import 'panel_layout.dart' show RaftCssText, RaftCssFocusOutline;

part 'mobile_navigation_docked.dart';
part 'mobile_nav_server.dart';
part 'mobile_nav_server_content.dart';
part 'mobile_workspace_header.dart';

@immutable
class RaftMobileNavItem {
  const RaftMobileNavItem({
    required this.id,
    required this.label,
    required this.glyph,
    this.enabled = true,
    this.attention = false,
    this.attentionKey,
    this.attentionLabel,
    this.badgeCount = 0,
    this.key,
  });
  final String id, label;
  final RaftGlyph glyph;
  final bool enabled, attention;

  /// Web v1.24 Activity tab: the accent pixel at the icon's top-right is a dot,
  /// never a number. [attentionKey] / [attentionLabel] name it for tests and
  /// assistive technology ("Unread activity").
  final Key? attentionKey;
  final String? attentionLabel;

  /// Positive unread total shown as the sidebar count badge on the glyph
  /// (Sidebar.tsx SidebarItemCount accent, capped at 99+). Zero shows none.
  final int badgeCount;
  final Key? key;
}

/// MobileNav recipe5794; MainLayout's Brutal-only short-viewport adaptation.
@immutable
class RaftMobileNavRecipe {
  const RaftMobileNavRecipe(this.tokens, {required this.viewportHeight});
  final RaftTokens tokens;
  final double viewportHeight;
  bool get showGlyph => true;
  double get glyphSize => 18;
  double get capsuleInset => 4;
  double get itemGap => 8;
  double capsuleWidth(int count) =>
      capsuleInset * 2 + count * 44 + (count - 1) * itemGap;
  double get capsuleHeight => capsuleInset * 2 + 44;
  double get itemHeight => 44;
  double bottomSpace(double inset) => math.max(8, inset);
  Color get background => tokens.panel;
  List<BoxShadow> get rootShadows => tokens.dark
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
  Color foregroundFor({bool hovered = false}) =>
      hovered && !selected ? tokens.muted : foreground;
  @override
  Color get background => selected
      ? tokens.dark
            ? tokens.colors['fill-muted']!
            : tokens.panel
      : Colors.transparent;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => pressed && !selected ? tokens.colors['fill-strong']! : background;
  @override
  Color get foreground =>
      selected ? tokens.strong : tokens.colors['foreground-placeholder']!;
  @override
  Color get focusRing => tokens.colors['line-strong']!;
  // CSS :focus-visible is an outside outline, separate from selected shadows.
  // Consumed by RaftControl's modality-gated outside-RRect painter.
  @override
  double get focusOutlineWidth => 2;
  @override
  double get focusOutlineOffset => 2;
  @override
  BorderRadius get radius => BorderRadius.circular(22);
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  EdgeInsets get padding => EdgeInsets.zero;
  @override
  double get insetHighlightAlpha => tokens.dark && selected ? .06 : 0;
  @override
  Gradient? get overlayGradient => selected && !tokens.dark
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
    if (selected && tokens.dark) ...[
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
    if (selected && !tokens.dark) ...[
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
    this.trailing,
  });
  final List<RaftMobileNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double? bottomInset, viewportHeight;

  /// One more equal-width cell after [items]: the server tab
  /// ([RaftMobileNavServerTab]). It is never selected and owns its own press.
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    // The whole bar is what the server popover anchors to.
    return _MobileNavBarAnchor(child: _bar0(context));
  }

  Widget _bar0(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMobileNavRecipe(
      t,
      viewportHeight: viewportHeight ?? MediaQuery.sizeOf(context).height,
    );
    final inset = bottomInset ?? MediaQuery.viewPaddingOf(context).bottom;
    if (t.option('mobileNav.style', or: 'docked') == 'docked') {
      return RaftChrome(
        child: RaftLargeContentScope(
          child: _DockedMobileNav(
            items: items,
            trailing: trailing,
            selectedId: selectedId,
            onSelected: onSelected,
            bottomInset: inset,
            viewportHeight: recipe.viewportHeight,
          ),
        ),
      );
    }
    final touch = RaftDensityScope.of(context) == RaftDensity.touch;
    // Fixed chrome: label text is bounded (RaftChrome) and, once that hides
    // growth, a long press shows the item large (Large Content Viewer).
    return RaftChrome(
      child: RaftLargeContentScope(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _bar(context, constraints, t, recipe, inset, touch),
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    BoxConstraints constraints,
    RaftTokens t,
    RaftMobileNavRecipe recipe,
    double inset,
    bool touch,
  ) {
    // The count sits on the glyph's upper right corner and may overhang
    // the cell: the capsule gap (Elegant) and the neighbour's rule
    // (Brutal) leave room for "99+".
    Widget badged(RaftMobileNavItem i, Widget glyph) => i.badgeCount <= 0
        ? glyph
        : Stack(
            clipBehavior: Clip.none,
            children: [
              glyph,
              Positioned(
                top: -8,
                left: 11,
                child: Semantics(
                  key: ValueKey('mobile-nav-badge-${i.id}'),
                  label: raftFormat(context, '{count} unread', {
                    'count': i.badgeCount > 99 ? '99+' : i.badgeCount,
                  }),
                  child: ExcludeSemantics(
                    child: RaftSidebarUnreadCount(count: i.badgeCount),
                  ),
                ),
              ),
            ],
          );
    Widget item(RaftMobileNavItem i, int index) {
      final selected = i.id == selectedId;
      final height = recipe.itemHeight;
      Widget control = Semantics(
        selected: selected,
        child: RaftControl(
          key: i.key,
          onPressed: i.enabled ? () => onSelected(i.id) : null,
          tooltip: raftText(context, i.label),
          semanticLabel: raftText(context, i.label),
          visualHeight: height,
          visualWidth: 44,
          minimumTargetSize: touch ? math.max(48, height) : height,
          recipe: _MobileItemRecipe(t, selected: selected),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              badged(i, RaftIcon(i.glyph, size: 18)),
              if (i.attention)
                Positioned(
                  top: -4,
                  right: -4,
                  child: _AttentionDot(
                    t,
                    key: i.attentionKey,
                    label: i.attentionLabel,
                  ),
                ),
            ],
          ),
        ),
      );
      control = RaftLargeContentViewer(
        label: raftText(context, i.label),
        enabled: i.enabled,
        onActivate: () => onSelected(i.id),
        iconBuilder: (context, size) => RaftIcon(i.glyph, size: size),
        child: control,
      );
      return control;
    }

    final cells = items.length + (trailing == null ? 0 : 1);
    final bar = Container(
      key: const ValueKey('mobile-nav-source-capsule'),
      width: recipe.capsuleWidth(cells),
      height: recipe.capsuleHeight,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: recipe.background,
        borderRadius: BorderRadius.circular(1000),
        boxShadow: recipe.rootShadows,
      ),
      child: Stack(
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
          if (trailing != null)
            Positioned(
              left:
                  recipe.capsuleInset +
                  items.length * (44 + recipe.itemGap) -
                  (touch ? 2 : 0),
              top: recipe.capsuleInset - (touch ? 2 : 0),
              width: touch ? 48 : 44,
              height: touch ? 48 : 44,
              child: trailing!,
            ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: recipe.bottomSpace(inset)),
      child: Align(
        alignment: Alignment.bottomCenter,
        widthFactor: 1,
        heightFactor: 1,
        child: bar,
      ),
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
  double get chevronAngle => _stickerWorkspace(tokens) ? 0 : -contentAngle;
  double get controlHeight =>
      compact ? tokens.size('size.mobileWorkspaceCompact', fallback: 24) : 36;
  EdgeInsets get contentInset => compact
      ? EdgeInsets.zero
      : EdgeInsets.fromLTRB(
          tokens.size('space.mobileWorkspaceStart', fallback: 14),
          tokens.size('space.mobileWorkspaceBlock', fallback: 6),
          tokens.size('space.mobileWorkspaceEnd', fallback: 14),
          tokens.size('space.mobileWorkspaceBlock', fallback: 6),
        );
  Color get foreground =>
      tokens.colors[compact
          ? 'foreground-mobile-workspace-compact'
          : 'foreground-mobile-workspace'] ??
      tokens.colors['primary-strong']!;
  TextStyle get titleStyle =>
      RaftTypography.heading(
        tokens,
        size: tokens.size('type.mobileWorkspaceTitle.size', fallback: 16),
        line: tokens.size('type.mobileWorkspaceTitle.line', fallback: 24),
        weight: FontWeight.w700,
      ).copyWith(
        color: foreground,
        fontFamily: tokens.fontFamily('font.mobileWorkspaceTitle'),
      );
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
    this.publicPageLive = false,
    this.avatarUrl,
    this.open = false,
  });
  final String label;
  final VoidCallback? onPressed;

  /// The server's avatar (Raft look: [RaftWorkspaceButton]).
  final String? avatarUrl;
  final bool attention;
  final String? attentionLabel;
  final double? viewportHeight;
  final FocusNode? focusNode;

  /// The server's public page is live: a globe after the name (Web
  /// `PublicPageGlobe`).
  final bool publicPageLive;

  /// The server menu is open (the WorkspaceButton's pressed fill).
  final bool open;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMobileServerSelectorRecipe(
      t,
      viewportHeight: viewportHeight ?? MediaQuery.sizeOf(context).height,
    );
    if (_stickerWorkspace(t)) {
      return RaftWorkspaceButton(
        name: label,
        avatarUrl: avatarUrl,
        onPressed: onPressed,
        attention: attention,
        attentionLabel: attentionLabel,
        focusNode: focusNode,
        publicPageLive: publicPageLive,
        open: open,
      );
    }
    return _SelectorControl(
      recipe: recipe,
      label: label,
      onPressed: onPressed,
      attention: attention,
      attentionLabel: attentionLabel,
      focusNode: focusNode,
      publicPageLive: publicPageLive,
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
    this.publicPageLive = false,
  });
  final RaftMobileServerSelectorRecipe recipe;
  final String label;
  final VoidCallback? onPressed;
  final bool attention;
  final String? attentionLabel;
  final FocusNode? focusNode;
  final bool publicPageLive;
  @override
  Widget build(BuildContext context) => RaftControl(
    focusNode: focusNode,
    onPressed: onPressed,
    semanticLabel: null,
    visualHeight: recipe.controlHeight,
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
                      style: recipe.titleStyle,
                    ),
                  ),
                ),
                if (publicPageLive) ...[
                  const SizedBox(width: 6),
                  RaftPublicPageGlobe(
                    live: true,
                    size: 14,
                    color: recipe.foreground,
                  ),
                ],
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
                // `-right-1 -top-1` of the padding-box anchor: 4px beyond it,
                // that is 12 / 4px past the content box.
                top: -8,
                right: -16,
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
    // `.mobile-server-selector-vector-surface { inset: -2px }` is measured
    // from the button's padding box (the button has a 2px transparent
    // border), so the SVG covers exactly the button's border box and its
    // viewBox maps 1:1.
    final inset = recipe.contentInset;
    final buttonSize = Size(
      size.width + inset.horizontal,
      size.height + inset.vertical,
    );
    canvas.save();
    canvas.translate(-inset.left, -inset.top);
    Path path(double shadow) {
      final points = recipe.polygon(buttonSize, shadowOffset: shadow);
      return Path()..addPolygon(points, true);
    }

    canvas.drawPath(
      path(2),
      Paint()..color = RaftTokenSet.light.product.brutalBlack,
    );
    canvas.drawPath(path(0), Paint()..color = Colors.black);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SelectorPainter old) =>
      old.recipe.viewportHeight != recipe.viewportHeight ||
      old.recipe.tokens != recipe.tokens;
}

/// The tab's attention pixel (Web v1.24 `ActivityTabUnreadDot`): a 10px status
/// pixel (the `lg` status size's radius and edge, the ink border) in the accent.
class _AttentionDot extends StatelessWidget {
  const _AttentionDot(this.tokens, {super.key, this.label});
  final RaftTokens tokens;
  final String? label;
  @override
  Widget build(BuildContext context) {
    const size = RaftStatusSize.lg;
    final dot = RaftCssBox(
      radius: size.radius,
      fill: tokens.ui[RaftStatusVariant.accent.token],
      borderWidth: raftControlBorderPx(context, size.border),
      borderColor: tokens.ui.stickerInk,
      width: 10,
      height: 10,
    );
    return label == null
        ? ExcludeSemantics(child: dot)
        : Semantics(label: raftText(context, label!), image: true, child: dot);
  }
}

/// Web TabRootBar's PanelSectionHeader frame, used by phone page headers.
@immutable
class RaftMobileRootHeaderRecipe {
  const RaftMobileRootHeaderRecipe(
    this.tokens, {
    required this.viewportHeight,
    this.inset = 16,
  });
  final RaftTokens tokens;
  final double viewportHeight;

  /// Horizontal text inset (`px-4` 16, TasksPanel `px-5` 20).
  final double inset;
  double get height =>
      RaftLayoutMetrics.shellHeaderHeight(tokens, viewportHeight);
  // Web PanelSectionHeader; old theme packs preserve a57's root fill.
  Color get background => tokens.colors['layer-section-header-mobile']!;
  BorderSide get border => RaftMobilePageHeader.defaultBorder(tokens);
  // Web TabRootBar's `PanelTitle` is `text-headline` (17/22 on a phone); the
  // old looks keep the 16/24 heading.
  TextStyle get title =>
      tokens.option('listGroup.frame', or: 'framed') == 'plain'
      ? tokens.scale(
          RaftTypeScale.headline,
          color: tokens.colors['foreground-on-frame'],
        )
      : RaftTypography.heading(
          tokens,
          size: 16,
          line: 24,
          weight: FontWeight.w700,
          color: tokens.strong,
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
    this.inset = 16,
    this.workspace = false,
    this.onBack,
    this.backKey,
    this.subtitle,
    this.content,
  });

  /// Web TabRootBar `content`: replaces the name and subtitle in the band
  /// (Search's field). [title] then stays as the screen-reader-only heading,
  /// and the content gets the band's [inset] on both sides.
  final Widget? content;

  /// The phone Home workspace header has natural-width frame actions.
  final bool workspace;

  /// A pushed server page (Members, Settings) shows Back before the title;
  /// tab roots have none.
  final VoidCallback? onBack;
  final Key? backKey;
  final Widget? leading;
  final String? title;

  /// Web TabRootBar's one line under the name (Activity's counts), already
  /// localised; styled like the Tasks root's count line.
  final String? subtitle;
  final List<Widget> actions;
  final double? viewportHeight;
  final double inset;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftMobileRootHeaderRecipe(
      RaftTokens.of(context),
      viewportHeight: viewportHeight ?? MediaQuery.sizeOf(context).height,
      inset: inset,
    );
    if (workspace && _stickerWorkspace(recipe.tokens) && leading != null) {
      return _MobileWorkspaceHeader(
        recipe: recipe,
        leading: leading!,
        actions: actions,
      );
    }
    if (content != null) {
      return RaftStatusBarSource(
        color: recipe.background,
        child: Container(
          height: RaftScaled.grows(context) ? null : recipe.height,
          constraints: RaftScaled.grows(context)
              ? BoxConstraints(minHeight: recipe.height)
              : null,
          padding: EdgeInsets.symmetric(horizontal: recipe.inset),
          decoration: BoxDecoration(
            color: recipe.background,
            border: Border(bottom: recipe.border),
          ),
          child: Row(
            children: [
              // `<h1 class="sr-only">`: the page's heading for assistive tech.
              Semantics(
                header: true,
                label: raftText(context, title ?? ''),
                child: const SizedBox.shrink(),
              ),
              Expanded(child: content!),
            ],
          ),
        ),
      );
    }
    final t = recipe.tokens;
    final caption = subtitle;
    final countHeader =
        caption != null && t.option('listGroup.frame', or: 'framed') == 'plain';
    final lines = RaftScaled.grows(context) ? null : 1;
    final name = countHeader
        ? RaftCssText(
            raftText(context, title ?? ''),
            style: recipe.title,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
          )
        : Text(
            raftText(context, title ?? ''),
            style: recipe.title,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
          );
    final titleBlock = caption == null || caption.isEmpty
        ? name
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              name,
              if (countHeader)
                RaftCssText.rich(
                  _countCaption(caption, t),
                  style: t.scale(
                    RaftTypeScale.caption,
                    color: t.colors['foreground-on-frame-muted'],
                  ),
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  caption,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.mono(t, color: t.muted),
                ),
            ],
          );
    return RaftMobilePageHeader(
      background: recipe.background,
      border: recipe.border,
      headerHeight: recipe.height,
      inset: recipe.inset,
      onBack: onBack,
      backKey: backKey,
      title: Align(
        alignment: AlignmentDirectional.centerStart,
        child: leading ?? titleBlock,
      ),
      actions: actions,
    );
  }

  // Web's localized Activity and Tasks captions wrap each count in font-mono.
  // Keep the translated word order and expose the whole subtitle as one line.
  TextSpan _countCaption(String caption, RaftTokens t) {
    final number = TextStyle(fontFamily: t.monoFont);
    final runs = <TextSpan>[];
    var start = 0;
    for (final match in RegExp(r'\d+').allMatches(caption)) {
      if (match.start > start) {
        runs.add(TextSpan(text: caption.substring(start, match.start)));
      }
      runs.add(TextSpan(text: match[0], style: number));
      start = match.end;
    }
    if (start < caption.length) {
      runs.add(TextSpan(text: caption.substring(start)));
    }
    return TextSpan(children: runs);
  }
}

/// Source NotificationTrigger mobile-navbar visual. The caller owns its center.
class RaftMobileNotificationButton extends StatelessWidget {
  const RaftMobileNotificationButton({
    super.key,
    this.onPressed,
    this.open = false,
    this.semanticLabel = 'Notification Center',
    this.visualSize = 32,
    this.glyphSize = 16,
    this.rail = false,
    this.onFrame = false,
    this.mobileHeader = false,
    this.attention = false,
  });
  final VoidCallback? onPressed;
  final bool open;
  final String semanticLabel;

  /// Original mobile32/16 and LeftRail40/18 share one trigger state recipe.
  final double visualSize, glyphSize;

  /// NotificationTrigger `rail-bottom`: the bell reads like every other rail
  /// item's icon (the AppRailItem glyph size and `foreground-icon`, brightening
  /// to `foreground-strong` on hover; Brutal `foreground-strong`) instead of
  /// the fixed [glyphSize] and muted colour, and [attention] rides the same
  /// AppRailItemAttention composite the other rail items use. [glyphSize] is
  /// ignored then.
  final bool rail, attention;
  final bool onFrame, mobileHeader;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (onFrame || (mobileHeader && _stickerWorkspace(t))) {
      final frameExtent = t.size('css.frame-item-height', fallback: 36);
      final extent = onFrame
          ? (t.desktop ? RaftLayoutMetrics.desktopControl : frameExtent)
          : t.size('size.mobileHeaderAction', fallback: 44);
      final icon = RaftIcon(
        RaftGlyph.bell,
        size: onFrame
            ? RaftRailRecipe(
                t,
                viewportHeight: MediaQuery.sizeOf(context).height,
              ).glyphSize
            : t.size('size.mobileHeaderActionGlyph', fallback: 22),
      );
      final control = Semantics(
        expanded: open,
        child: RaftBlinkSnap(
          child: RaftControl(
            onPressed: onPressed,
            semanticLabel: raftText(context, semanticLabel),
            tooltip: onFrame ? raftText(context, semanticLabel) : null,
            minimumTargetSize: extent,
            visualHeight: extent,
            visualWidth: extent,
            recipe: _FrameBellRecipe(
              t,
              selected: open,
              borderWidth: raftControlBorderPx(context, 1.5),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                icon,
                if (attention)
                  Positioned.fill(child: RaftRailAttention(child: icon)),
              ],
            ),
          ),
        ),
      );
      final touch = RaftDensityScope.of(context) == RaftDensity.touch;
      return RaftTapSlopAnchor(
        minSize: Size.square(touch ? RaftMetrics.touchTarget : frameExtent),
        includePointerRelease: onFrame && !touch,
        child: control,
      );
    }
    if (rail) {
      return RaftWorkspaceRailAction(
        label: raftText(context, semanticLabel),
        glyph: RaftGlyph.bell,
        selected: open,
        attention: attention,
        onPressed: onPressed,
      );
    }
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
            EdgeInsets.all(t.border),
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
  Color get background =>
      selected ? tokens.colors['fill-muted']! : Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) =>
      selected || !hovered ? background : tokens.colors['fill-muted']!;
  @override
  Color get foreground => tokens.muted;
  @override
  BorderRadius get radius => BorderRadius.circular(6);
  @override
  BorderSide side({bool hovered = false}) =>
      BorderSide(color: Colors.transparent, width: 1);
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
