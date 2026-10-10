import 'message_semantics.dart';
import 'message_row_recipe.dart';
import 'message_content_tokens.dart';
import 'mounted_reaction_recipe.dart';
import 'composer_recipe.dart';
import 'composer_suggestions.dart';
import 'collapsible.dart';
import 'sidebar_indicators.dart';

import 'package:flutter/material.dart';

import 'localization.dart';

import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'theme.dart';
import 'recipes/badge.g.dart';
import 'recipes/composer_suggestion_list.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'mounted_avatar_recipe.dart';
import 'design_primitives.dart';
import 'css_opacity.dart';
import 'icons.dart';
import 'indicators.dart' show RaftWebPalette;
import 'panel_layout.dart' show RaftCssText, RaftCssLineBox;
import 'tokens/tokens.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';
import 'recipes/recipe_utilities.g.dart';

/// Surface styles of [RaftPanel].
enum RaftPanelStyle {
  /// Flat bordered panel (no shadow).
  panel,

  /// raft-ui `Card` root (`card` recipe, variant default).
  card,

  /// The Web client's `.card-brutal` composition class
  /// (packages/web/src/index.css): elegant `border border-line-muted
  /// bg-layer-panel shadow-raft-md`; brutal `border-2 border-black bg-white
  /// shadow-brutal`.
  legacyCard,
}

class RaftPanel extends StatelessWidget {
  const RaftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.shadow = false,
    this.style,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Shorthand for [RaftPanelStyle.legacyCard] when [style] is null.
  final bool shadow;
  final RaftPanelStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolved =
        style ?? (shadow ? RaftPanelStyle.legacyCard : RaftPanelStyle.panel);
    // Material ancestor for ink/fields, without resetting CSS-inherited text.
    final body = Material(
      type: MaterialType.transparency,
      textStyle: DefaultTextStyle.of(context).style,
      child: child,
    );
    switch (resolved) {
      case RaftPanelStyle.card:
        final rt = t.recipeTokens;
        final s = RaftCardRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(),
          tokens: rt,
        ).root;
        return RaftRecipeBox(
          style: s,
          tokens: rt,
          padding: padding.resolve(Directionality.of(context)),
          clip: true,
          child: body,
        );
      case RaftPanelStyle.legacyCard:
        // Web index.css `.card-brutal` is a product composition, including
        // all dark-theme inset layers of `shadow-raft-md`. Use the shared
        // CSS painter in every theme to retain live child state on switching.
        final rt = t.recipeTokens;
        final s = raftRecipeEngine.resolveSlot(
          [
            for (final name in [
              t.brutal ? 'border-2' : 'border',
              t.brutal ? 'border-black' : 'border-line-muted',
              t.brutal ? 'bg-white' : 'bg-layer-panel',
              'shadow-raft-md',
            ])
              raftRecipeUtilities.indexWhere((u) => u.name == name),
          ],
          t.recipeStates(),
          rt,
        );
        return RaftRecipeBox(
          style: s,
          tokens: rt,
          padding: padding.resolve(Directionality.of(context)),
          applyText: false,
          decorationOverride: t.brutal
              ? (d) => d.copyWith(
                  boxShadow: RaftProductShadows.shadowBrutal.paintOrder,
                )
              : null,
          child: body,
        );
      case RaftPanelStyle.panel:
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: t.panel,
            border: Border.all(color: t.line, width: t.border),
            borderRadius: BorderRadius.circular(t.radius),
          ),
          child: body,
        );
    }
  }
}

/// raft-ui `Button` (`buttonVariants` recipe): root box + `content` span
/// (`inline-flex gap-[inherit]`), the elegant `::before` sheen, and the
/// loading indicator that hides the content (`data-loading=true`).
class RaftButton extends StatelessWidget {
  const RaftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.glyph,
    this.busy = false,
    this.secondary = false,
    this.destructive = false,
    this.variant,
    this.tone,
    this.size,
    this.visualHeight = RaftMetrics.buttonMd,
    this.expand = false,
    this.focusNode,
    this.tooltip,
    this.semanticLabel,
    this.foreground,
    this.iconInlineStart = true,
    this.opacityCompositing = RaftOpacityCompositing.layer,
  });
  final String label;

  /// Whether the icon carries Source `data-icon="inline-start"` (the smaller
  /// `has-data-[icon=inline-start]:pl-*` padding). Call sites that render a
  /// bare `<svg>` (no `data-icon`) keep the size's plain `px-*`.
  final bool iconInlineStart;

  /// Explicit caller text/icon color; null retains the resolved button recipe.
  final Color? foreground;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Lucide glyph; wins over [icon].
  final RaftGlyph? glyph;
  final bool busy, secondary, destructive;

  /// Legacy variant axis; mapped onto the recipe variant.
  final RaftControlVariant? variant;

  /// Recipe variant (wins over [variant]): information, success, muted,
  /// warning, danger-secondary, danger-outline, link, ...
  final RaftButtonRecipeVariant? tone;

  /// Recipe size; when null it follows [visualHeight] (24 xs, 28 sm, 32 md,
  /// larger lg).
  final RaftButtonRecipeSize? size;
  final double visualHeight;

  /// `w-full` (stretch to the parent width; content stays centered).
  final bool expand;
  final FocusNode? focusNode;
  final String? tooltip;

  /// Explicit authored aria-label, independent of transient visual feedback.
  final String? semanticLabel;

  /// Matches the mounted Source component's opacity compositing boundary.
  final RaftOpacityCompositing opacityCompositing;

  RaftButtonRecipeVariant get recipeVariant =>
      tone ??
      switch (variant ??
          (destructive
              ? RaftControlVariant.danger
              : secondary
              ? RaftControlVariant.outline
              : RaftControlVariant.accent)) {
        RaftControlVariant.surface => RaftButtonRecipeVariant.default_,
        RaftControlVariant.primary => RaftButtonRecipeVariant.primary,
        RaftControlVariant.accent => RaftButtonRecipeVariant.accent,
        RaftControlVariant.outline => RaftButtonRecipeVariant.outline,
        RaftControlVariant.ghost => RaftButtonRecipeVariant.ghost,
        RaftControlVariant.danger => RaftButtonRecipeVariant.danger,
      };

  RaftButtonRecipeSize get recipeSize =>
      size ??
      (visualHeight <= 24
          ? RaftButtonRecipeSize.xs
          : visualHeight <= 28
          ? RaftButtonRecipeSize.sm
          : visualHeight <= 32
          ? RaftButtonRecipeSize.md
          : RaftButtonRecipeSize.lg);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final text = raftText(context, label);
    return RaftInteractive(
      onPressed: onPressed,
      busy: busy,
      focusNode: focusNode,
      tooltip: tooltip,
      semanticLabel: semanticLabel ?? (busy ? text : null),
      builder: (context, st) {
        final s = RaftButtonRecipe.resolve(
          theme: t.recipeTheme,
          variant: recipeVariant,
          size: recipeSize,
          states: t.recipeStates(
            hovered: st.hovered,
            pressed: st.pressed,
            focusVisible: st.focusVisible,
            disabled: onPressed == null,
            extra: [
              if (busy) RaftRecipeStates.loading,
              if (iconInlineStart && (icon != null || glyph != null))
                RaftRecipeStates.iconInlineStart,
            ],
          ),
          tokens: rt,
        ).root;
        final svg = s.target("& svg:not([class*='size-'])");
        final gap = s.columnGap ?? 0;
        // Accessibility exception (not in the Web): with platform high
        // contrast, elegant danger uses the in-repo component roles
        // `--button-danger-high-contrast(-foreground)` (WCAG AA text).
        final highContrastDanger =
            !t.brutal &&
            MediaQuery.highContrastOf(context) &&
            recipeVariant == RaftButtonRecipeVariant.danger;
        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              RaftIcon(glyph!, size: svg?.width ?? 16),
              SizedBox(width: gap),
            ] else if (icon != null) ...[
              RaftSymbol(icon!, size: svg?.width ?? 16),
              SizedBox(width: gap),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
        Widget content2 = Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: busy
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Visibility.maintain(visible: false, child: content),
                        const RaftSpinner(),
                      ],
                    )
                  : content,
            ),
          ],
        );
        if (highContrastDanger || foreground != null) {
          content2 = DefaultTextStyle.merge(
            style: TextStyle(
              color: foreground ?? t.components.buttonDangerHighContrastForeground,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                color: foreground ?? t.components.buttonDangerHighContrastForeground,
              ),
              child: content2,
            ),
          );
        }
        return RaftRecipeBox(
          style: s,
          tokens: rt,
          overflowCenter: true,
          opacityCompositing: opacityCompositing,
          width: expand ? double.infinity : null,
          decorationOverride: highContrastDanger
              ? (d) => d.copyWith(color: t.components.buttonDangerHighContrast)
              : null,
          child: semanticLabel == null
              ? content2
              : ExcludeSemantics(child: content2),
        );
      },
    );
  }
}

enum RaftAvatarKind { human, agent, server, app }

class RaftAvatar extends StatelessWidget {
  const RaftAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.kind = RaftAvatarKind.human,
    this.imageUrl,
    this.content,
    this.mountedContext,
    this.presence,
    this.deactivated = false,
    this.muted = false,
  });
  final String name;
  final double size;
  final RaftAvatarKind kind;
  final String? imageUrl;

  /// Authorized artwork/image content supplied by the host; frame stays shared.
  final Widget? content;

  /// Explicit mounted AvatarSlot role; null preserves generic sizing/paint.
  /// When provided, the role determines the outer extent (36 or20).
  final RaftMountedAvatarContext? mountedContext;
  final RaftAvatarPresence? presence;
  final bool deactivated;

  /// MentionCandidateAvatar's muted mounted frame, for an absent channel member.
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final mountedRole = mountedContext;
    if (mountedRole != null) {
      final identity = switch (kind) {
        RaftAvatarKind.human => RaftMountedAvatarIdentity.human,
        RaftAvatarKind.agent => RaftMountedAvatarIdentity.agent,
        RaftAvatarKind.server => RaftMountedAvatarIdentity.server,
        RaftAvatarKind.app => RaftMountedAvatarIdentity.app,
      };
      final fallback = RaftMountedAvatarFallback(
        avatarContext: mountedRole,
        identity: identity,
        initials: name,
      );
      return RaftMountedAvatarFrame(
        name: name,
        avatarContext: mountedRole,
        identity: identity,
        presence: presence,
        deactivated: deactivated,
        muted: muted,
        child:
            content ??
            (imageUrl == null
                ? fallback
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  )),
      );
    }
    final fallback = Center(
      child: switch (kind) {
        RaftAvatarKind.human => RaftIcon(
          RaftGlyph.user,
          size: size >= 32 ? 18 : 12,
          color: t.brutal
              ? Colors.black
              : t.colors['foreground-placeholder']!.withValues(alpha: .7),
        ),
        RaftAvatarKind.agent => RaftIcon(
          RaftGlyph.bot,
          size: size >= 32 ? 18 : 12,
          color: t.brutal ? Colors.black : t.muted,
        ),
        _ => Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: RaftTypography.body(
            t,
            size: size * .4,
            line: size * .5,
            weight: FontWeight.w700,
          ),
        ),
      },
    );
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Padding(
          padding: EdgeInsets.all(t.brutal ? 0 : 2),
          child: Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: t.brutal
                  ? t.colors[kind == RaftAvatarKind.agent
                        ? 'color-brutal-cyan'
                        : kind == RaftAvatarKind.human
                        ? 'color-brutal-lavender'
                        : 'brutal-cream']
                  : t.colors['fill-muted'],
              border: t.brutal
                  ? Border.all(color: Colors.black, width: size >= 28 ? 2 : 1)
                  : null,
              borderRadius: BorderRadius.circular(t.brutal ? 0 : size / 2),
            ),
            child:
                content ??
                (imageUrl == null
                    ? fallback
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      )),
          ),
        ),
      ),
    );
  }
}

/// Mounted Sidebar.tsx product roles; generic preserves existing SDK callers.
enum RaftNavItemRole { generic, search, activity, saved }

/// Source border/content/padding composition, not a fixed Material row height.
class RaftMountedSidebarNavigationRecipe extends RaftControlRecipe {
  const RaftMountedSidebarNavigationRecipe(
    super.tokens, {
    required this.role,
    required this.viewportWidth,
    required this.viewportHeight,
    super.selected,
    this.pointerPressed = false,
  }) : assert(role != RaftNavItemRole.generic);
  final RaftNavItemRole role;
  final bool pointerPressed;
  final double viewportWidth, viewportHeight;
  bool get compact =>
      viewportHeight <= 600 ||
      (viewportWidth >= 768 &&
          (tokens.brutal || role != RaftNavItemRole.saved));
  bool get active => selected && role != RaftNavItemRole.search;
  double get sourceBorder => tokens.brutal ? 2 : 1;
  double get glyphSize => 14;
  double get gap => 6;
  double get marginBottom => 4;
  double get fontSize =>
      !tokens.brutal && role == RaftNavItemRole.saved ? 13 : 14;
  double get contentHeight =>
      !tokens.brutal && role == RaftNavItemRole.saved ? 19.5 : 20;
  double get verticalInset => compact
      ? 4
      : !tokens.brutal && role == RaftNavItemRole.saved
      ? 6
      : 8;
  double get sourceHeight =>
      contentHeight + verticalInset * 2 + sourceBorder * 2;
  @override
  bool get transformsOnInteraction => false;
  @override
  EdgeInsets get padding => EdgeInsets.symmetric(
    horizontal: tokens.brutal || role != RaftNavItemRole.saved ? 8 : 6,
  );
  @override
  BorderRadius get radius => BorderRadius.circular(
    !tokens.brutal && role == RaftNavItemRole.saved ? 6 : 0,
  );
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  Color get foreground => tokens.brutal
      ? Colors.black
      : role == RaftNavItemRole.saved && !active
      ? tokens.muted
      : tokens.strong;
  @override
  Color foregroundFor({bool hovered = false}) =>
      (hovered || pointerPressed) &&
          !tokens.brutal &&
          role == RaftNavItemRole.saved &&
          !active
      ? tokens.ink
      : foreground;
  @override
  Color get background => !active
      ? Colors.transparent
      : tokens.brutal
      ? tokens.colors['color-brutal-pink']!
      : tokens.colors['fill-muted']!;
  @override
  Color backgroundFor({bool hovered = false}) {
    if (active || (!hovered && !pointerPressed)) {
      return background;
    }
    if (tokens.brutal) {
      return tokens.panel;
    }
    if (role != RaftNavItemRole.saved) {
      return tokens.colors['fill-muted']!;
    }
    return tokens.dark
        ? tokens.colors['ink-6']!
        : tokens.colors['fill-strong']!.withValues(
            alpha: tokens.colors['fill-strong']!.a * .8,
          );
  }

  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered || pressed);
  @override
  BorderSide side({bool hovered = false}) => BorderSide(
    width: sourceBorder,
    color:
        !tokens.brutal && role == RaftNavItemRole.saved ||
            (!active && !hovered && !pointerPressed)
        ? Colors.transparent
        : tokens.brutal
        ? Colors.black
        : tokens.colors['line-strong']!,
  );
  @override
  TextStyle get textStyle => RaftTypography.heading(
    tokens,
    size: fontSize,
    line: contentHeight,
    weight: active && role == RaftNavItemRole.activity
        ? FontWeight.w700
        : FontWeight.w500,
  ).copyWith(color: null);
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) {
    if (focused) {
      return [
        BoxShadow(
          color: tokens.brutal ? Colors.black : tokens.colors['line-strong']!,
          spreadRadius: 2,
        ),
      ];
    }
    if (!active && !hovered && !pressed) {
      return const [];
    }
    if (!tokens.brutal && role == RaftNavItemRole.saved) {
      return const [];
    }
    if (tokens.brutal && (role != RaftNavItemRole.saved || active)) {
      // Product index.css `--shadow-brutal-sm: 2px 2px 0px #141111`.
      return RaftProductShadows.shadowBrutalSm.outer;
    }
    return tokens.shadows;
  }

  TextStyle get savedCount => RaftTypography.mono(
    tokens,
    size: 10,
    line: 15,
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .4)
        : tokens.colors['foreground-placeholder'],
  ).copyWith(fontWeight: FontWeight.w500);
}

/// Mounted ChannelRow and DM unread counts are product variants, independent
/// of the generic SidebarItemChannelIcon slot and management/navigation rows.
enum RaftConversationNavKind { channel, directMessage, directory }

/// ChannelKindIcon is the mounted product default. The generic component slot
/// is retained explicitly for SDK compositions that actually mount that slot.
enum RaftChannelGlyphVariant { mountedProduct, genericComponent }

/// Mounted Sidebar.tsx ChannelRow/DmRow use an unstyled Base UI button.
/// Its selected utility overrides generic SidebarItem accents in both Elegant
/// modes; it never inherits styled Button gradients, inset edges or transforms.
class RaftMountedConversationControlRecipe extends RaftControlRecipe {
  const RaftMountedConversationControlRecipe(
    super.tokens, {
    super.selected,
    this.pointerPressed = false,
  }) : super(kind: RaftControlKind.sidebar);
  final bool pointerPressed;
  @override
  bool get transformsOnInteraction => false;
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  @override
  EdgeInsets get padding => const EdgeInsets.symmetric(horizontal: 8);
  @override
  double get focusOutlineWidth => 2;
  @override
  double get focusOutlineOffset => 2;
  @override
  Color get focusRing =>
      tokens.brutal ? Colors.black : tokens.colors['line-strong']!;
  @override
  Color get foreground => tokens.brutal
      ? Colors.black
      : selected
      ? tokens.colors['foreground-strong']!
      : tokens.colors['foreground-muted']!;
  @override
  Color foregroundFor({bool hovered = false}) =>
      hovered || pointerPressed || selected
      ? (tokens.brutal ? Colors.black : tokens.colors['foreground-strong']!)
      : foreground;
  @override
  Color get background => !selected
      ? Colors.transparent
      : tokens.colors[tokens.brutal ? 'color-brutal-pink' : 'fill-muted']!;
  @override
  Color backgroundFor({bool hovered = false}) {
    if (selected || (!hovered && !pointerPressed)) {
      return background;
    }
    return tokens.brutal
        ? Colors.white
        : tokens.dark
        ? tokens.colors['ink-6']!
        : tokens.colors['fill-strong']!.withValues(alpha: .8);
  }

  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered || pressed);
  @override
  BorderSide side({bool hovered = false}) => BorderSide(
    width: tokens.brutal ? 2 : 1,
    color: tokens.brutal && (selected || hovered || pointerPressed)
        ? Colors.black
        : Colors.transparent,
  );
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [
    if (tokens.brutal && (selected || hovered || pressed || pointerPressed))
      ...RaftProductShadows.shadowBrutalSm.outer,
  ];
}

class RaftConversationNavigationRecipe {
  const RaftConversationNavigationRecipe(
    this.tokens, {
    required this.kind,
    this.channelGlyphVariant = RaftChannelGlyphVariant.mountedProduct,
  });
  final RaftTokens tokens;
  final RaftConversationNavKind kind;
  final RaftChannelGlyphVariant channelGlyphVariant;

  // Sidebar.tsx866: fixed18 slot; channelKindIcon.tsx4: default14, Lucide2.
  // RUI index.mjs3824/3852/3880: separate generic SVG12Br/14El, stroke1.5.
  double? get glyphSize => kind == RaftConversationNavKind.directMessage
      ? null
      : channelGlyphVariant == RaftChannelGlyphVariant.mountedProduct
      ? 14
      : tokens.brutal
      ? 12
      : 14;
  double? get glyphSlotSize =>
      kind == RaftConversationNavKind.channel &&
          channelGlyphVariant == RaftChannelGlyphVariant.mountedProduct
      ? 18
      : null;
  double get glyphStrokeWidth =>
      kind == RaftConversationNavKind.channel &&
          channelGlyphVariant == RaftChannelGlyphVariant.genericComponent
      ? 1.5
      : 2;

  // Mounted ChannelRow title inherits Sidebar's heading face. Selection does
  // not make it bold: only the loud unread marker applies font-bold.
  TextStyle? titleStyle({required bool loudUnread}) =>
      (kind == RaftConversationNavKind.directMessage ||
          channelGlyphVariant == RaftChannelGlyphVariant.mountedProduct)
      ? RaftTypography.heading(
          tokens,
          size: 14,
          line: 20,
          weight: loudUnread ? FontWeight.w700 : FontWeight.w500,
        )
      : null;

  // Resolved mounted ChannelRow cascade (including original md:py-1.5
  // Elegant precedence): desktop Br32/El34, short Br32/El30,
  // tall mobile Br40/El34. Direct-message AvatarSlot is a separate contract.
  double rowHeight({
    required double viewportWidth,
    required double viewportHeight,
  }) => tokens.brutal
      ? viewportWidth >= RaftLayoutMetrics.desktopBreakpoint ||
                viewportHeight <= 600
            ? 32
            : 40
      : viewportHeight <= 600
      ? 30
      : 34;

  // SidebarItemCount solid/accent merges Sidebar count and Badge recipes.
  double get countHeight => 16;
  double get countMinimumWidth => tokens.brutal ? 0 : 16;
  EdgeInsets get countPadding => EdgeInsets.symmetric(
    horizontal: tokens.brutal ? 6 : 4,
    vertical: tokens.brutal ? 2 : 0,
  );
  Color get countBackground => tokens.brutal
      ? tokens.colors['color-brutal-pink']!
      : tokens.colors['accent-soft']!;
  Color get countForeground =>
      tokens.brutal ? Colors.white : tokens.colors['accent-strong']!;
  BoxDecoration get countDecoration => BoxDecoration(
    color: countBackground,
    border: Border.all(
      color: tokens.brutal ? Colors.black : Colors.transparent,
    ),
    borderRadius: BorderRadius.circular(4),
  );
  // Elegant inherits the mounted Sidebar Inter face; Brutal font-sans resolves
  // Hanken. Generic navigation and DM label typography stay unchanged.
  TextStyle get countTextStyle =>
      RaftTypography.body(
        tokens,
        size: 10,
        line: 10,
        weight: tokens.brutal ? FontWeight.w700 : FontWeight.w400,
      ).copyWith(
        color: countForeground,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Only the loud positive unread badge. Quiet/muted/draft indicators and DM
/// avatars are separate product contracts; this widget invents none of them.
class RaftSidebarUnreadCount extends StatelessWidget {
  const RaftSidebarUnreadCount({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    // Source AgentRow/DMRow/ChannelRow all mount SidebarItemCount accent.
    final recipe = RaftConversationNavigationRecipe(
      RaftTokens.of(context),
      kind: RaftConversationNavKind.directMessage,
    );
    return Container(
      height: recipe.countHeight,
      constraints: BoxConstraints(minWidth: recipe.countMinimumWidth),
      padding: recipe.countPadding,
      decoration: recipe.countDecoration,
      alignment: Alignment.center,
      child: Text(count > 99 ? '99+' : '$count', style: recipe.countTextStyle),
    );
  }
}

class RaftConversationUnreadCount extends StatelessWidget {
  const RaftConversationUnreadCount({
    super.key,
    required this.count,
    required this.kind,
  });
  final int count;
  final RaftConversationNavKind kind;
  @override
  Widget build(BuildContext context) {
    return RaftSidebarUnreadCount(count: count);
  }
}

class RaftNavItem extends StatelessWidget {
  const RaftNavItem({
    super.key,
    required this.label,
    this.icon,
    this.glyph,
    this.glyphSize,
    required this.onTap,
    this.selected = false,
    this.unread = 0,
    this.trailing,
    this.leading,
    this.description,
    this.labelSuffix,
    this.role = RaftNavItemRole.generic,
    this.viewportHeight,
    this.count,
    this.conversationKind,
    this.channelGlyphVariant = RaftChannelGlyphVariant.mountedProduct,
    this.joined = true,
    this.activityMuted = false,
    this.hasDraft = false,
  }) : assert(icon != null || glyph != null || leading != null),
       assert(conversationKind == null || role == RaftNavItemRole.generic);
  final String label;
  final IconData? icon;
  final RaftGlyph? glyph;
  final double? glyphSize;
  final VoidCallback onTap;
  final bool selected;
  final int unread;
  final Widget? trailing, leading;
  final String? description, labelSuffix;
  final RaftNavItemRole role;
  final double? viewportHeight;

  /// Saved total is metadata, independent of an unread/activity badge.
  final int? count;

  /// Opt in for mounted conversation/directory rows; existing roles/defaults stay
  /// unchanged. DM avatars must be supplied by the product, not inferred here.
  final RaftConversationNavKind? conversationKind;
  final RaftChannelGlyphVariant channelGlyphVariant;

  /// Mounted channel membership and accepted notification preference. They
  /// change emphasis and count appearance; they never disable navigation.
  final bool joined, activityMuted, hasDraft;
  bool get _channel => conversationKind == RaftConversationNavKind.channel;
  bool get _mutedIcon => _channel && joined && activityMuted;
  bool get _loudUnread => unread > 0 && (!_channel || joined && !_mutedIcon);
  bool get _dimmed => _channel && !selected && !joined;
  Color? _titleColor(BuildContext context, RaftTokens t) => _dimmed
      ? t.brutal
            ? Colors.black.withValues(alpha: .4)
            : t.colors['foreground-placeholder']
      : _channel && activityMuted
      ? t.brutal
            ? Colors.black.withValues(alpha: .7)
            : t.colors['foreground-muted']
      : conversationKind == null
      ? t.strong
      : conversationKind == RaftConversationNavKind.directMessage && t.brutal
      ? Colors.black
      : DefaultTextStyle.of(context).style.color;
  Widget _title(RaftTokens t, TextStyle style) => labelSuffix == null
      ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)
      : Text.rich(
          TextSpan(
            text: label,
            children: [
              TextSpan(
                text: ' $labelSuffix',
                style: style.copyWith(
                  color: t.brutal
                      ? Colors.black.withValues(alpha: .4)
                      : t.colors['foreground-placeholder'],
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (role != RaftNavItemRole.generic) {
      return _mounted(context, t);
    }
    final conversation = conversationKind == null
        ? null
        : RaftConversationNavigationRecipe(
            t,
            kind: conversationKind!,
            channelGlyphVariant: channelGlyphVariant,
          );
    final leading =
        this.leading ??
        (glyph != null
            ? RaftIcon(
                glyph!,
                size:
                    glyphSize ??
                    conversation?.glyphSize ??
                    (t.brutal ? 12 : 18),
                strokeWidth: conversation?.glyphStrokeWidth ?? 2,
                color: _dimmed
                    ? t.brutal
                          ? Colors.black.withValues(alpha: .4)
                          : t.colors['foreground-placeholder']
                    : t.brutal
                    ? t.strong
                    : t.colors['foreground-icon'],
              )
            : RaftSymbol(
                icon!,
                size: conversation?.glyphSize ?? (t.brutal ? 12 : 18),
                color: _dimmed
                    ? t.brutal
                          ? Colors.black.withValues(alpha: .4)
                          : t.colors['foreground-placeholder']
                    : t.brutal
                    ? t.strong
                    : t.colors['foreground-icon'],
              ));
    Widget titleContent(BuildContext context) => description == null
        ? _title(
            t,
            (conversation?.titleStyle(loudUnread: _loudUnread) ??
                    RaftTypography.body(
                      t,
                      size: t.brutal ? 14 : 13,
                      line: 20,
                      weight: selected || unread > 0
                          ? FontWeight.w700
                          : t.brutal
                          ? FontWeight.w400
                          : FontWeight.w500,
                    ))
                .copyWith(color: _titleColor(context, t)),
          )
        : LayoutBuilder(
            builder: (context, box) => Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * .7),
                  child: _title(
                    t,
                    RaftTypography.heading(
                      t,
                      size: 14,
                      line: 20,
                      weight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                    ).copyWith(
                      color: t.brutal
                          ? Colors.black
                          : DefaultTextStyle.of(context).style.color,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        RaftTypography.heading(
                          t,
                          size: 12,
                          line: 16,
                          weight: FontWeight.w500,
                        ).copyWith(
                          color: t.brutal
                              ? Colors.black.withValues(alpha: .4)
                              : t.colors['foreground-muted'],
                        ),
                  ),
                ),
              ],
            ),
          );
    Widget row(bool pointerPressed) => RaftControl(
      recipe: conversationKind == null
          ? null
          : RaftMountedConversationControlRecipe(
              t,
              selected: selected,
              pointerPressed: pointerPressed,
            ),
      onPressed: onTap,
      selected: selected,
      // Mounted directory rows share Source's box; expand their touch area
      // without inserting 48px of layout between the section's entities.
      minimumTargetSize: conversationKind == RaftConversationNavKind.directory
          ? conversation!.rowHeight(
              viewportWidth: MediaQuery.sizeOf(context).width,
              viewportHeight:
                  viewportHeight ?? MediaQuery.sizeOf(context).height,
            )
          : null,
      kind: RaftControlKind.sidebar,
      visualHeight: conversationKind != null
          ? conversation!.rowHeight(
              viewportWidth: MediaQuery.sizeOf(context).width,
              viewportHeight:
                  viewportHeight ?? MediaQuery.sizeOf(context).height,
            )
          : 32,
      variant: selected
          ? t.brutal
                ? RaftControlVariant.accent
                : RaftControlVariant.surface
          : RaftControlVariant.ghost,
      child: Builder(
        builder: (context) => Row(
          children: [
            if (conversation?.glyphSlotSize case final double slot)
              SizedBox.square(
                dimension: slot,
                child: Center(child: leading),
              )
            else
              leading,
            const SizedBox(width: 6),
            Expanded(
              child: _mutedIcon
                  ? Row(
                      children: [
                        Flexible(child: titleContent(context)),
                        RaftSidebarMutedIcon(
                          label: raftText(context, 'Activity muted'),
                        ),
                      ],
                    )
                  : titleContent(context),
            ),
            if (_mutedIcon && (unread > 0 || hasDraft))
              const SizedBox(width: 4),
            if (trailing != null)
              trailing!
            else if (unread > 0 && _channel && !_loudUnread)
              RaftSidebarQuietUnreadCount(count: unread)
            else if (unread > 0 && conversationKind != null)
              RaftConversationUnreadCount(
                count: unread,
                kind: conversationKind!,
              )
            else if (unread > 0)
              RaftSidebarUnreadCount(count: unread)
            else if (hasDraft && conversationKind != null)
              const RaftSidebarDraftIcon(),
          ],
        ),
      ),
    );
    final semanticLabel = description == null ? label : '$label $description';
    final stateLabel = [
      unread > 0
          ? raftFormat(context, '{label}, {count} unread', {
              'label': semanticLabel,
              'count': unread,
            })
          : semanticLabel,
      if (_mutedIcon) raftText(context, 'Activity muted'),
      if (_channel && !joined) raftText(context, 'Not joined'),
      if (hasDraft && unread <= 0 && conversationKind != null)
        raftText(context, 'Draft'),
    ].join(', ');
    return Semantics(
      selected: selected,
      onTap: onTap,
      button: true,
      label: stateLabel,
      excludeSemantics: true,
      child: conversationKind == null
          ? row(false)
          : Padding(
              padding: EdgeInsets.only(bottom: t.brutal ? 4 : 2),
              child: _MountedNavigationPointerSurface(
                builder: (pressed) =>
                    conversationKind == RaftConversationNavKind.directory &&
                        RaftDensityScope.of(context) == RaftDensity.touch
                    ? RaftTouchTarget(child: row(pressed))
                    : row(pressed),
              ),
            ),
    );
  }

  Widget _mounted(BuildContext context, RaftTokens t) {
    return _MountedNavigationPointerSurface(
      builder: (pointerPressed) {
        final size = MediaQuery.sizeOf(context);
        final recipe = RaftMountedSidebarNavigationRecipe(
          t,
          role: role,
          viewportWidth: size.width,
          viewportHeight: viewportHeight ?? size.height,
          selected: selected,
          pointerPressed: pointerPressed,
        );
        final saved =
            role == RaftNavItemRole.saved && count != null && count! > 0;
        final savedLabel = saved
            ? Localizations.localeOf(context).languageCode == 'zh'
                  ? '$count 项'
                  : '$count'
            : '';
        return Padding(
          padding: EdgeInsets.only(bottom: recipe.marginBottom),
          child: Semantics(
            selected: selected,
            button: true,
            onTap: onTap,
            excludeSemantics: true,
            label: saved
                ? '$label, $savedLabel'
                : unread > 0
                ? raftFormat(context, '{label}, {count} unread', {
                    'label': label,
                    'count': unread,
                  })
                : label,
            child: RaftControl(
              kind: RaftControlKind.sidebar,
              selected: selected,
              visualHeight: recipe.sourceHeight,
              // Same box as the Web mobile sidebar row (no 48dp inflation).
              minimumTargetSize: recipe.sourceHeight,
              recipe: recipe,
              onPressed: onTap,
              child: Row(
                children: [
                  if (glyph != null)
                    RaftIcon(glyph!, size: recipe.glyphSize)
                  else
                    RaftSymbol(icon!, size: recipe.glyphSize),
                  SizedBox(width: recipe.gap),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (saved)
                    Text(savedLabel, style: recipe.savedCount)
                  else if (role == RaftNavItemRole.activity && unread > 0)
                    Container(
                      height: 16,
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: EdgeInsets.symmetric(
                        horizontal: t.brutal ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: t.brutal
                            ? t.colors['color-brutal-pink']
                            : t.colors['accent-soft'],
                        border: t.brutal
                            ? Border.all(color: Colors.black)
                            : null,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style:
                            RaftTypography.heading(
                              t,
                              size: 10,
                              line: 10,
                              weight: t.brutal
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ).copyWith(
                              color: t.brutal
                                  ? Colors.white
                                  : t.colors['accent-strong'],
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// RaftControl owns activation/focus/hover. This projects source :active into
// border/foreground recipes, whose shared side() API currently receives hover only.
class _MountedNavigationPointerSurface extends StatefulWidget {
  const _MountedNavigationPointerSurface({required this.builder});
  final Widget Function(bool pressed) builder;
  @override
  State<_MountedNavigationPointerSurface> createState() =>
      _MountedNavigationPointerSurfaceState();
}

class _MountedNavigationPointerSurfaceState
    extends State<_MountedNavigationPointerSurface> {
  int? pointer;
  void release(int id) {
    if (mounted && id == pointer) {
      setState(() => pointer = null);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (pointer == null && (event.buttons & 1) == 1) {
        setState(() => pointer = event.pointer);
      }
    },
    onPointerUp: (event) => release(event.pointer),
    onPointerCancel: (event) => release(event.pointer),
    child: widget.builder(pointer != null),
  );
}

class RaftMessageTile extends StatelessWidget {
  const RaftMessageTile({
    super.key,
    required this.author,
    required this.content,
    required this.timestamp,
    this.onThread,
    this.onActions,
    this.onActionsAt,
    this.onLink,
    this.threadLabel,
    this.threadPreview,
    this.taskReference,
    this.threadRepliesBadge,
    this.badge,
    this.departureLabel,
    this.modelLabel,
    this.subtitle,
    this.avatar,
    this.attachments = const [],
    this.translation,
    this.onAttachment,
    this.attachmentBuilder,
    this.attachmentGallery,
    this.reactions = const [],
    this.reactedEmojis = const {},
    this.failedReactionEmojis = const {},
    this.reactionViewerId,
    this.onReaction,
    this.onReact,
    this.onReactionAdd,
    this.collapseLongMessages = true,
    this.bodyFontSize = 14,
    this.body,
    this.hoverToolbar,
    this.selectionLeading,
    this.onAuthor,
    this.onTap,
    this.rowContext = RaftMessageRowContext.main,
    this.continuation = false,
    this.nextContinuation = false,
    this.coarsePointer = false,
    this.popupOpen = false,
    this.highlighted = false,
    this.compactSemantics = false,
    this.semanticsContent,
    this.semanticsActions = const [],
  });
  final String author, content, timestamp;
  final RaftMessageRowContext rowContext;
  final String? threadLabel, badge;

  /// Timeline rows: one semantics node labelled with author, status, time and
  /// the plain [content]; prose nodes are dropped (links, code blocks and
  /// controls stay reachable). [semanticsActions] become its custom actions.
  final bool compactSemantics;

  /// Markdown the compact label announces instead of [content]; empty when a
  /// custom [body] (an action card, a forwarded bundle) keeps its own nodes.
  final String? semanticsContent;
  final List<RaftMessageSemanticsAction> semanticsActions;

  /// Authorized left/removed/deleted sender status, separate from custom badges.
  final String? departureLabel;

  /// Permitted adapter-projected label; this component performs no model lookup.
  final String? modelLabel, subtitle;
  final Widget? avatar;
  final bool collapseLongMessages;
  final double bodyFontSize;

  /// Business adapters may supply a richer body without replacing message
  /// actions, thread controls, attachments, or reactions.
  final Widget? body, threadPreview, taskReference;

  /// Web MessageItem footer `ThreadRepliesBadge`, after the task badge and
  /// before reactions (hidden when the inline reply surface replaces it).
  final Widget? threadRepliesBadge;

  /// Message translation status line, between attachments and footer.
  final Widget? translation;
  final VoidCallback? onThread, onActions, onReact;
  final ValueChanged<Offset>? onActionsAt;
  final void Function(String href)? onLink;
  final List<Map<String, dynamic>> attachments, reactions;
  final Set<String> reactedEmojis, failedReactionEmojis;

  /// The viewer, listed as "You" first in a reaction's reactor names.
  final String? reactionViewerId;
  final void Function(Map<String, dynamic>)? onAttachment;
  final Widget Function(Map<String, dynamic>)? attachmentBuilder;
  final Widget? attachmentGallery;
  final void Function(String)? onReaction;
  final void Function(BuildContext anchor)? onReactionAdd;

  /// Exact source action strip, supplied only with authorized callbacks.
  final Widget? hoverToolbar;

  /// Multi-select checkbox shown while the app is in select mode.
  final Widget? selectionLeading;
  final VoidCallback? onAuthor, onTap;
  final bool continuation,
      nextContinuation,
      coarsePointer,
      popupOpen,
      highlighted;
  /// The default Markdown body in a compact row contributes only its links.
  Widget compactProse(Widget prose) => compactSemantics
      ? RaftMessageProseSemantics(
          links: raftMessageSemanticsLinks(content),
          onLink: onLink,
          child: prose,
        )
      : prose;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMessageRowRecipe(
      t,
      viewportWidth: MediaQuery.sizeOf(context).width,
      rowContext: rowContext,
    );
    return RaftMessageRow(
      author: author,
      timestamp: timestamp,
      semanticsLabel: compactSemantics
          ? [
              author,
              ?departureLabel,
              if (badge != null && badge!.trim().isNotEmpty) badge!,
              if (timestamp.isNotEmpty) timestamp,
            ].join(', ')
          : null,
      semanticsText: compactSemantics
          ? raftMessageSemanticsText(context, semanticsContent ?? content)
          : '',
      semanticsActions: semanticsActions,
      avatar: avatar ?? RaftAvatar(name: author, size: 36),
      onAuthor: onAuthor,
      onActions: onActions,
      onActionsAt: onActionsAt,
      onTap: onTap,
      rowContext: rowContext,
      continuation: continuation,
      nextContinuation: nextContinuation,
      coarsePointer: coarsePointer,
      popupOpen: popupOpen,
      highlighted: highlighted,
      toolbar: hoverToolbar,
      selectionLeading: selectionLeading,
      subtitle: subtitle,
      metadata: modelLabel == null && badge == null && departureLabel == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (modelLabel != null && modelLabel!.trim().isNotEmpty)
                  Flexible(
                    child: Tooltip(
                      message: modelLabel!,
                      child: Text(
                        modelLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // `text-[11px]` replaces the meta slot's `text-xs`
                        // (tailwind-merge), so brutal inherits the body's
                        // 20/14 line height; elegant keeps `leading-none`.
                        style: recipe.time.copyWith(
                          fontSize: 11,
                          height: t.brutal ? 20 / 14 : 1,
                        ),
                      ),
                    ),
                  ),
                if (badge != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(badge!, maxLines: 1,
                      style: recipe.time.copyWith(fontSize: 10)),
                  ),
                if (departureLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: t.brutal
                          ? RaftWebPalette.gray300
                          : t.colors['fill-muted'],
                      border: Border.all(
                        color: t.brutal
                            ? Colors.black
                            : t.colors['line-muted']!,
                      ),
                    ),
                    child: RaftCssText(
                      departureLabel!.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      style: recipe.body.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: t.brutal
                            ? Colors.black.withValues(alpha: .6)
                            : t.muted,
                      ),
                    ),
                  ),
              ],
            ),
      content: RaftCollapsible(
        enabled: collapseLongMessages,
        child:
            body ??
            compactProse(SelectionArea(
              child: MarkdownBody(
                data: content,
                onTapLink: (_, href, _) {
                  if (href != null) onLink?.call(href);
                },
                styleSheet:
                    MessageContentRecipe(
                          t,
                          fontSize: bodyFontSize,
                          mountedMessage: true,
                        )
                        .stylesheet(context)
                        .copyWith(
                          code: TextStyle(
                            fontFamily: t.monoFont,
                            fontSize: 12,
                            color: t.ink,
                            backgroundColor: t.sidebar,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: t.sidebar,
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                        ),
              ),
            )),
      ),
      attachments: attachments.isEmpty
          ? null
          : attachmentGallery ??
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: attachments
                      .map(
                        (a) =>
                            attachmentBuilder?.call(a) ??
                            OutlinedButton.icon(
                              onPressed: () => onAttachment?.call(a),
                              icon: const Icon(Icons.attach_file, size: 16),
                              label: Text(
                                '${a['filename'] ?? a['name'] ?? 'Attachment'}',
                              ),
                            ),
                      )
                      .toList(),
                ),
      translation: translation,
      inlineReplies: threadPreview,
      footer:
          taskReference == null &&
              threadRepliesBadge == null &&
              reactions.isEmpty &&
              (threadPreview != null ||
                  onThread == null ||
                  hoverToolbar != null)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (taskReference != null ||
                    threadRepliesBadge != null ||
                    reactions.isNotEmpty)
                  // `mt-1.5 flex flex-wrap items-center gap-1.5`.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ?taskReference,
                      ?threadRepliesBadge,
                      ...reactions
                          .where(
                            (r) =>
                                r['emoji'] is String &&
                                r['count'] is int &&
                                r['count'] > 0,
                          )
                          .map((r) {
                            final reacted = reactedEmojis.contains(r['emoji']);
                            final reactors = raftReactionReactors(
                              context,
                              r,
                              viewerId: reactionViewerId,
                              reacted: reacted,
                            );
                            return RaftReactionReactorsHover(
                              key: ValueKey('reaction-reactors-${r['emoji']}'),
                              emoji: r['emoji'],
                              names: reactors.names,
                              hiddenCount: reactors.hidden,
                              child: RaftMountedReaction(
                                key: ValueKey('reaction-${r['emoji']}'),
                                label: '${r['emoji']}: ${r['count']}',
                                glyph: RaftReactionGlyph(r['emoji']),
                                count: r['count'],
                                reacted: reacted,
                                failure: failedReactionEmojis.contains(
                                  r['emoji'],
                                ),
                                onPressed: onReaction == null
                                    ? null
                                    : () => onReaction!(r['emoji']),
                              ),
                            );
                          })
                          .toList(),
                      if (MediaQuery.sizeOf(context).width < 768 &&
                          reactions.any(
                            (r) =>
                                r['emoji'] is String &&
                                r['count'] is int &&
                                r['count'] > 0,
                          ) &&
                          (onReactionAdd != null || onReact != null))
                        Builder(
                          builder: (anchor) => RaftMountedReactionAdd(
                            key: const ValueKey('message-reaction-add'),
                            label: raftText(context, 'Add reaction'),
                            onPressed: () {
                              if (onReactionAdd != null) {
                                onReactionAdd!(anchor);
                              } else {
                                onReact!();
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                if (hoverToolbar == null &&
                    threadPreview == null &&
                    threadRepliesBadge == null &&
                    onThread != null)
                  TextButton.icon(
                    onPressed: onThread,
                    icon: const Icon(Icons.forum_outlined, size: 15),
                    label: Text(
                      threadLabel ?? raftText(context, 'Reply in thread'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RaftForceTaskSendIntent extends Intent {
  const _RaftForceTaskSendIntent();
}

/// TextField's default context menu (system menu where supported).
Widget _defaultEditorMenu(BuildContext context, EditableTextState state) =>
    SystemContextMenu.isSupportedByField(state)
    ? SystemContextMenu.editableText(editableTextState: state)
    : AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

/// Overrides the editor's [PasteTextIntent] (EditableText actions are
/// overridable from ancestors). The host is asked for clipboard attachments
/// first; only when it takes none does the editor's own text paste run.
class _RaftPasteAction extends Action<PasteTextIntent> {
  _RaftPasteAction(this.handler);
  final Future<bool> Function()? Function() handler;

  @override
  bool isEnabled(PasteTextIntent intent) =>
      callingAction?.isEnabled(intent) ?? true;

  @override
  Object? invoke(PasteTextIntent intent) {
    final fallback = callingAction;
    final take = handler();
    if (take == null) return fallback?.invoke(intent);
    take().then(
      (taken) {
        if (!taken && (fallback?.isEnabled(intent) ?? false)) {
          fallback!.invoke(intent);
        }
      },
      onError: (Object _) {
        if (fallback?.isEnabled(intent) ?? false) fallback!.invoke(intent);
      },
    );
    return null;
  }
}

/// Controlled editor action seam; identity/authority belongs to the caller.
/// Only the current mounted editor can accept an insertion, and offstage,
/// disabled, IME-composing and busy editors reject it without moving focus.
class RaftComposerHandle {
  Object? _owner;
  bool Function(RaftComposerSuggestion)? _insert;
  bool insertMention(RaftComposerSuggestion suggestion) =>
      suggestion.isMention && (_insert?.call(suggestion) ?? false);
  void _bind(Object owner, bool Function(RaftComposerSuggestion) insert) {
    _owner = owner;
    _insert = insert;
  }

  void _release(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _insert = null;
  }
}

class RaftComposer extends StatefulWidget {
  const RaftComposer({
    super.key,
    required this.onSend,
    this.onAttach,
    this.onImagePick,
    this.taskAction,
    this.accessoryRow,
    this.suggestionOverlay,
    this.bottomSafeInset = 0,
    this.submitBusy = false,
    this.clearOnSubmit = false,
    this.variant = RaftComposerVariant.normal,
    this.hint = 'Message',
    this.autofocus = false,
    this.canAutofocus,
    this.enabled = true,
    this.canSend = true,
    this.pendingLabel,
    this.initialDraft = '',
    this.onDraftChanged,
    this.suggestions = const [],
    this.onSendWithMentions,
    this.onForceTaskSendWithMentions,
    this.onSuggestionsRequested,
    this.handle,
    this.onPasteAttachments,
    this.onContentInserted,
    this.frame,
  }) : assert(bottomSafeInset >= 0);
  final List<RaftComposerSuggestion> suggestions;
  final Future<bool> Function(String, List<Map<String, dynamic>>)?
  onSendWithMentions;
  final Future<bool> Function(String, List<Map<String, dynamic>>)?
  onForceTaskSendWithMentions;
  final ValueChanged<String>? onSuggestionsRequested;
  final RaftComposerHandle? handle;
  final Future<bool> Function(String) onSend;
  final VoidCallback? onAttach, onImagePick;
  final Widget? taskAction, accessoryRow, suggestionOverlay;
  final double bottomSafeInset;
  final bool submitBusy;

  /// Web MessageInput submit: the editor clears as the message is handed off
  /// (the host presents it optimistically) and stays usable for the next one.
  /// A rejected send merges its text back ahead of anything typed since.
  final bool clearOnSubmit;
  final RaftComposerVariant variant;
  final String hint;

  /// Initial controlled focus; the caller admits current identity and scope.
  final bool autofocus;
  final bool Function()? canAutofocus;
  final bool enabled, canSend;
  final String? pendingLabel;
  final String initialDraft;
  final ValueChanged<String>? onDraftChanged;

  /// Web MessageInput `handlePaste`: a keyboard paste (Ctrl/Cmd+V) first asks
  /// the host whether the clipboard carries files or an image. It resolves
  /// true when it took them as attachments; the text paste is then skipped.
  /// Otherwise the ordinary text paste runs unchanged.
  final Future<bool> Function()? onPasteAttachments;

  /// Rich content committed by a software keyboard (Android IME image,
  /// GIF and sticker insertion). Null leaves the editor text-only.
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;

  /// Host wrapper around the composer root (Web `ComposerRoot`), for
  /// example a platform file drop target with its overlay. [enabled] is
  /// false while the composer is disabled or not presented. Keep it set for
  /// the composer's lifetime: adding or removing it remounts the editor.
  final Widget Function(BuildContext context, Widget composer, bool enabled)?
  frame;
  @override
  State<RaftComposer> createState() => _RaftComposerState();
}

class _RaftComposerState extends State<RaftComposer> {
  late final TextEditingController controller;
  final focus = FocusNode();
  final suggestionScroll = ScrollController();
  final suggestionPortal = OverlayPortalController();
  final suggestionLink = LayerLink();
  final suggestionKeys = <String, GlobalKey>{};
  bool suggestionUpdateScheduled = false;
  bool presentationActive = true;
  bool initialFocusHandled = false, initialFocusQueued = false;

  void queueInitialFocus() {
    if (initialFocusHandled || initialFocusQueued || !widget.autofocus) return;
    initialFocusQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialFocusQueued = false;
      if (!mounted ||
          !presentationActive ||
          !widget.enabled ||
          !widget.autofocus ||
          widget.canAutofocus?.call() == false)
        return;
      initialFocusHandled = true;
      focus.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    presentationActive = Visibility.of(context);
    queueInitialFocus();
    updateSuggestionPortal(defer: true);
  }

  bool sending = false;
  bool composerFocused = false;
  bool restoringDraft = false;
  RaftComposerTrigger? trigger;
  int suggestionIndex = 0;
  String? dismissedValue;
  final mentions = <String, Map<String, dynamic>>{};
  bool get composing =>
      controller.value.composing.isValid &&
      !controller.value.composing.isCollapsed;
  List<RaftComposerSuggestion> get matches {
    if (!presentationActive ||
        trigger == null ||
        composing ||
        sending ||
        widget.submitBusy ||
        !widget.enabled)
      return [];
    final q = trigger!.query.toLowerCase();
    final result = widget.suggestions
        .where(
          (s) =>
              (trigger!.prefix == '#'
                  ? s.type == 'channel'
                  : s.type != 'channel') &&
              ('${s.name} ${s.title ?? ''} ${s.detail ?? ''}')
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    result.sort((a, b) {
      final group = suggestionGroup(a).compareTo(suggestionGroup(b));
      if (group != 0) return group;
      final ap = a.name.toLowerCase().startsWith(q),
          bp = b.name.toLowerCase().startsWith(q);
      return ap != bp
          ? ap
                ? -1
                : 1
          : 0;
    });
    return result.take(10).toList();
  }

  int suggestionGroup(RaftComposerSuggestion s) => s.type == 'channel'
      ? 0
      : s.type == 'computer'
      ? 2
      : s.type == 'app'
      ? 3
      : s.inChannel
      ? 0
      : 1;

  void changed() {
    if (dismissedValue != null && dismissedValue != controller.text)
      dismissedValue = null;
    if (!restoringDraft) widget.onDraftChanged?.call(controller.text);
    mentions.removeWhere(
      (name, _) => !raftStructuredMentionAppears(controller.text, name),
    );
    final next = composing || dismissedValue == controller.text
        ? null
        : raftComposerTrigger(controller.text, controller.selection.baseOffset);
    if (next?.query != trigger?.query || next?.prefix != trigger?.prefix)
      suggestionIndex = 0;
    trigger = next;
    if (presentationActive && next != null)
      widget.onSuggestionsRequested?.call(next.prefix);
    if (mounted) {
      setState(() {});
      updateSuggestionPortal();
    }
  }

  void insert(RaftComposerSuggestion suggestion) {
    final range = trigger;
    if (!presentationActive ||
        range == null ||
        composing ||
        sending ||
        widget.submitBusy ||
        !widget.enabled)
      return;
    final next = controller.text.replaceRange(
      range.start,
      range.end,
      '${suggestion.insertion} ',
    );
    if (suggestion.isMention) mentions[suggestion.name] = suggestion.mention;
    dismissedValue = next;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: range.start + suggestion.insertion.length + 1,
      ),
    );
    focus.requestFocus();
  }

  bool insertSender(RaftComposerSuggestion suggestion) {
    if (!presentationActive ||
        composing ||
        sending ||
        widget.submitBusy ||
        !widget.enabled ||
        !suggestion.isMention)
      return false;
    final cursor = controller.selection.baseOffset < 0
        ? controller.text.length
        : controller.selection.baseOffset.clamp(0, controller.text.length);
    final before = controller.text.substring(0, cursor);
    final after = controller.text.substring(cursor);
    final leading = before.isNotEmpty && !RegExp(r'\s$').hasMatch(before);
    final trailing = after.isEmpty || !RegExp(r'^\s').hasMatch(after);
    final insertion =
        '${leading ? ' ' : ''}@${suggestion.name}${trailing ? ' ' : ''}';
    mentions[suggestion.name] = suggestion.mention;
    final next = '$before$insertion$after';
    dismissedValue = next;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: before.length + insertion.length,
      ),
    );
    focus.requestFocus();
    return true;
  }

  KeyEventResult suggestionKey(FocusNode node, KeyEvent event) {
    final options = matches;
    if (event is! KeyDownEvent ||
        composing ||
        options.isEmpty ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => suggestionIndex =
            (suggestionIndex + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
            options.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || matches.isEmpty) return;
        final selected = matches[suggestionIndex.clamp(0, matches.length - 1)];
        final target =
            suggestionKeys['${selected.type}:${selected.id}']?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target, alignment: .5);
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab ||
        (key == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed)) {
      insert(options[suggestionIndex.clamp(0, options.length - 1)]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        dismissedValue = controller.text;
        trigger = null;
      });
      updateSuggestionPortal();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialDraft);
    controller.addListener(changed);
    widget.handle?._bind(this, insertSender);
    updateSuggestionPortal(defer: true);
  }

  @override
  void didUpdateWidget(covariant RaftComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    queueInitialFocus();
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?._release(this);
      widget.handle?._bind(this, insertSender);
    }
    updateSuggestionPortal(defer: true);
    if (oldWidget.initialDraft != widget.initialDraft &&
        controller.text.isEmpty &&
        !focus.hasFocus &&
        !sending) {
      restoringDraft = true;
      controller.text = widget.initialDraft;
      restoringDraft = false;
    }
  }

  Future<void> send({bool forceTask = false}) async {
    final draft = controller.text;
    final text = draft.trim();
    if (!presentationActive ||
        sending ||
        widget.submitBusy ||
        composing ||
        !widget.enabled ||
        !widget.canSend ||
        (text.isEmpty && widget.pendingLabel == null))
      return;
    if (widget.clearOnSubmit) return handOff(draft, text, forceTask);
    setState(() => sending = true);
    updateSuggestionPortal();
    try {
      final selected = mentions.values
          .where((m) => raftStructuredMentionAppears(text, m['name'] as String))
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final submit = forceTask
          ? widget.onForceTaskSendWithMentions ?? widget.onSendWithMentions
          : widget.onSendWithMentions;
      final succeeded = submit == null
          ? await widget.onSend(text)
          : await submit(text, selected);
      if (succeeded && mounted && controller.text == draft) {
        mentions.clear();
        controller.clear();
        // Programmatic clearing does not invoke TextField.onChanged. Release
        // the old draft's insertion handle so its overlay cannot cover the
        // toolbar while the empty editor stays focused for the next draft.
        focus.context
            ?.findAncestorStateOfType<EditableTextState>()
            ?.hideToolbar();
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
        updateSuggestionPortal();
      }
    }
  }

  Future<void> handOff(String draft, String text, bool forceTask) async {
    final submitted = Map.of(mentions);
    final selected = submitted.values
        .where((m) => raftStructuredMentionAppears(text, m['name'] as String))
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final submit = forceTask
        ? widget.onForceTaskSendWithMentions ?? widget.onSendWithMentions
        : widget.onSendWithMentions;
    mentions.clear();
    controller.clear();
    // Release the sent draft's insertion handle (see [send]).
    focus.context?.findAncestorStateOfType<EditableTextState>()?.hideToolbar();
    final succeeded = submit == null
        ? await widget.onSend(text)
        : await submit(text, selected);
    if (succeeded || !mounted) return;
    // Web `mergeFailedSendIntoDraft`.
    final current = controller.text;
    final restored = current.isEmpty
        ? draft
        : draft.isEmpty
        ? current
        : '$draft${draft.endsWith('\n') || current.startsWith('\n') ? '' : '\n'}$current';
    for (final entry in submitted.entries) {
      mentions.putIfAbsent(entry.key, () => entry.value);
    }
    controller.value = TextEditingValue(
      text: restored,
      selection: TextSelection.collapsed(offset: restored.length),
    );
  }

  @override
  void dispose() {
    widget.handle?._release(this);
    controller.dispose();
    focus.dispose();
    suggestionScroll.dispose();
    super.dispose();
  }

  void updateSuggestionPortal({bool defer = false}) {
    if (!defer) {
      applySuggestionPortal();
      return;
    }
    if (suggestionUpdateScheduled) return;
    suggestionUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      suggestionUpdateScheduled = false;
      if (mounted) applySuggestionPortal();
    });
  }

  void applySuggestionPortal() {
    final show =
        presentationActive &&
        widget.enabled &&
        !sending &&
        !widget.submitBusy &&
        (widget.suggestionOverlay != null || matches.isNotEmpty);
    if (show && !suggestionPortal.isShowing) {
      suggestionPortal.show();
    } else if (!show && suggestionPortal.isShowing) {
      suggestionPortal.hide();
    }
  }

  String groupLabelCase(String label, bool uppercase) =>
      uppercase ? label.toUpperCase() : label;

  Widget suggestionPopup(RaftComposerRecipe recipe, double width) {
    final options = matches;
    if (widget.suggestionOverlay == null && options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 0,
      top: 0,
      width: width,
      child: CompositedTransformFollower(
        link: suggestionLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        // `bottom-full mb-2` resolves against the form's padding box, i.e.
        // inside its top border.
        offset: Offset(
          0,
          -recipe.suggestionBottomGap +
              ((recipe.hostDecoration.border as Border?)?.top.width ?? 0),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            key: const ValueKey('composer-suggestions-slot'),
            width: width,
            child:
                widget.suggestionOverlay ??
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: recipe.suggestionMaximum,
                  ),
                  child: DecoratedBox(
                    decoration: recipe.suggestionDecoration,
                    child: Padding(
                      padding: recipe.suggestionInset,
                      child: ListView.builder(
                        controller: suggestionScroll,
                        primary: false,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final s = options[index];
                          final group = suggestionGroup(s);
                          final startGroup =
                              index == 0 ||
                              suggestionGroup(options[index - 1]) != group;
                          final label = group == 1
                              ? 'Not in this channel'
                              : group == 2
                              ? 'Computers'
                              : group == 3
                              ? 'Apps'
                              : options.any(
                                  (item) => suggestionGroup(item) == 1,
                                )
                              ? 'In this channel'
                              : null;
                          final row = _RaftComposerSuggestionRow(
                            key: ValueKey(
                              'composer-suggestion-${s.type}-${s.id}',
                            ),
                            anchorKey: suggestionKeys.putIfAbsent(
                              '${s.type}:${s.id}',
                              () => GlobalKey(),
                            ),
                            suggestion: s,
                            highlighted: index == suggestionIndex,
                            recipe: recipe,
                            onPressed: () => insert(s),
                          );
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // `ComposerSuggestionGroup separated`:
                              // `mt-1 pt-1`, brutal `border-t-2 border-black`.
                              if (startGroup && index > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  height: 4 + (recipe.tokens.brutal ? 2 : 1),
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    height: recipe.tokens.brutal ? 2 : 1,
                                    color: recipe.tokens.brutal
                                        ? Colors.black
                                        : recipe.tokens.colors['line-hairline'],
                                  ),
                                ),
                              if (startGroup && label != null)
                                Padding(
                                  padding: recipe.suggestionGroupInset,
                                  child: Text(
                                    groupLabelCase(
                                      raftText(context, label),
                                      recipe.tokens.brutal,
                                    ),
                                    style: recipe.suggestionGroupLabel,
                                  ),
                                ),
                              row,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }

  // CSS places line-height leading evenly above and below the glyphs.
  @override
  Widget build(BuildContext context) {
    final composer = DefaultTextHeightBehavior(
      textHeightBehavior: raftCssTextHeightBehavior,
      child: Builder(builder: buildContent),
    );
    return widget.frame?.call(
          context,
          composer,
          presentationActive && widget.enabled,
        ) ??
        composer;
  }

  /// The selection toolbar's Paste follows the same host-first order as
  /// the keyboard shortcut (Web: every paste fires the paste event).
  Widget pasteAwareMenu(BuildContext context, EditableTextState state) =>
      SystemContextMenu.isSupportedByField(state)
      ? _defaultEditorMenu(context, state)
      : AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            for (final item in state.contextMenuButtonItems)
              item.type == ContextMenuButtonType.paste
                  ? item.copyWith(
                      onPressed: () {
                        state.hideToolbar();
                        final take = widget.onPasteAttachments;
                        if (take == null) {
                          state.pasteText(SelectionChangedCause.toolbar);
                          return;
                        }
                        take().then(
                          (taken) {
                            if (!taken && state.mounted) {
                              state.pasteText(SelectionChangedCause.toolbar);
                            }
                          },
                          onError: (Object _) {
                            if (state.mounted) {
                              state.pasteText(SelectionChangedCause.toolbar);
                            }
                          },
                        );
                      },
                    )
                  : item,
          ],
        );

  Widget buildContent(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftComposerRecipe(
      t,
      desktop:
          MediaQuery.sizeOf(context).width >=
          RaftLayoutMetrics.desktopBreakpoint,
      variant: widget.variant,
      bottomSafeInset: widget.bottomSafeInset,
    );
    final busy = sending || widget.submitBusy;
    final submitEnabled =
        widget.enabled &&
        widget.canSend &&
        !busy &&
        !composing &&
        (controller.text.trim().isNotEmpty || widget.pendingLabel != null);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return OverlayPortal(
          controller: suggestionPortal,
          overlayChildBuilder: (_) => suggestionPopup(recipe, width),
          child: CompositedTransformTarget(
            link: suggestionLink,
            child: Container(
              key: const ValueKey('composer-host-slot'),
              decoration: recipe.hostDecoration,
              padding: recipe.hostInset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.pendingLabel != null) ...[
                    Text(
                      widget.pendingLabel!,
                      style: TextStyle(color: t.accent),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.accessoryRow != null) ...[
                    KeyedSubtree(
                      key: const ValueKey('composer-accessory-slot'),
                      child: widget.accessoryRow!,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Focus(
                    onFocusChange: (value) {
                      if (composerFocused != value) {
                        setState(() => composerFocused = value);
                      }
                    },
                    child: Container(
                      key: const ValueKey('composer-shell-slot'),
                      decoration: recipe.shellDecoration(
                        focused: composerFocused,
                      ),
                      padding: recipe.shellInset,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            key: const ValueKey('composer-editor-slot'),
                            constraints: BoxConstraints(
                              minHeight: recipe.editorMinimum,
                              maxHeight: recipe.editorMaximum,
                            ),
                            child: Padding(
                              padding: recipe.editorInset,
                              child: Focus(
                                onKeyEvent: suggestionKey,
                                child: Shortcuts(
                                  shortcuts: const {
                                    SingleActivator(
                                      LogicalKeyboardKey.enter,
                                      control: true,
                                      shift: true,
                                    ): _RaftForceTaskSendIntent(),
                                    SingleActivator(
                                      LogicalKeyboardKey.enter,
                                      meta: true,
                                      shift: true,
                                    ): _RaftForceTaskSendIntent(),
                                    SingleActivator(
                                      LogicalKeyboardKey.enter,
                                      control: true,
                                    ): ActivateIntent(),
                                    SingleActivator(
                                      LogicalKeyboardKey.enter,
                                      meta: true,
                                    ): ActivateIntent(),
                                  },
                                  child: Actions(
                                    actions: {
                                      _RaftForceTaskSendIntent:
                                          CallbackAction<
                                            _RaftForceTaskSendIntent
                                          >(
                                            onInvoke: (_) {
                                              if (!composing)
                                                send(forceTask: true);
                                              return null;
                                            },
                                          ),
                                      ActivateIntent:
                                          CallbackAction<ActivateIntent>(
                                            onInvoke: (_) {
                                              if (!composing) send();
                                              return null;
                                            },
                                          ),
                                      if (widget.onPasteAttachments != null)
                                        PasteTextIntent: _RaftPasteAction(
                                          () => widget.onPasteAttachments,
                                        ),
                                    },
                                    child: RaftCssLineBox(
                                      style: recipe.editorText,
                                      textScaler: MediaQuery.textScalerOf(
                                        context,
                                      ),
                                      child: TextField(
                                        autofillHints: null,
                                        controller: controller,
                                        focusNode: focus,
                                        onChanged: (_) {
                                          // A typed collapsed caret replaces the
                                          // previous insertion handle. Merely
                                          // fading it leaves its overlay hit box
                                          // above the Source composer toolbar.
                                          if (controller
                                              .selection
                                              .isCollapsed) {
                                            focus.context
                                                ?.findAncestorStateOfType<
                                                  EditableTextState
                                                >()
                                                ?.hideToolbar();
                                          }
                                        },
                                        enabled: widget.enabled,
                                        minLines: 1,
                                        maxLines: 6,
                                        style: recipe.editorText,
                                        decoration: InputDecoration(
                                          hintText: widget.hint,
                                          hintStyle: recipe.placeholder,
                                          filled: false,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                        ),
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        contextMenuBuilder:
                                            widget.onPasteAttachments == null
                                            ? _defaultEditorMenu
                                            : pasteAwareMenu,
                                        contentInsertionConfiguration:
                                            widget.onContentInserted == null
                                            ? null
                                            : ContentInsertionConfiguration(
                                                onContentInserted: (content) {
                                                  if (presentationActive &&
                                                      widget.enabled) {
                                                    widget.onContentInserted
                                                        ?.call(content);
                                                  }
                                                },
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: recipe.shellGap),
                          Transform.translate(
                            offset: recipe.toolbarPaintOffset,
                            child: Padding(
                              key: const ValueKey('composer-toolbar-slot'),
                              padding: recipe.toolbarInset,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!recipe.compact &&
                                          widget.onImagePick != null)
                                        RaftComposerAction(
                                          glyph: RaftGlyph.imagePlus,
                                          tooltip: 'Attach image',
                                          onPressed: busy || !widget.enabled
                                              ? null
                                              : widget.onImagePick,
                                        ),
                                      if (!recipe.compact &&
                                          widget.onImagePick != null &&
                                          widget.onAttach != null)
                                        SizedBox(width: recipe.actionGap),
                                      if (!recipe.compact &&
                                          widget.onAttach != null)
                                        RaftComposerAction(
                                          glyph: RaftGlyph.paperclip,
                                          tooltip: 'Attach file',
                                          onPressed: busy || !widget.enabled
                                              ? null
                                              : widget.onAttach,
                                        ),
                                    ],
                                  ),
                                  SizedBox(width: recipe.toolbarGap),
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (widget.taskAction != null) ...[
                                          Flexible(
                                            child: KeyedSubtree(
                                              key: const ValueKey(
                                                'composer-task-action-slot',
                                              ),
                                              child: widget.taskAction!,
                                            ),
                                          ),
                                          SizedBox(width: recipe.metaGap),
                                        ],
                                        RaftComposerAction(
                                          glyph: RaftGlyph.send,
                                          tooltip: 'Send message (Ctrl+Enter)',
                                          submit: true,
                                          busy: busy,
                                          onPressed: submitEnabled
                                              ? () {
                                                  send();
                                                  focus.requestFocus();
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RaftComposerSuggestionRow extends StatefulWidget {
  const _RaftComposerSuggestionRow({
    super.key,
    required this.anchorKey,
    required this.suggestion,
    required this.highlighted,
    required this.recipe,
    required this.onPressed,
  });
  final GlobalKey anchorKey;
  final RaftComposerSuggestion suggestion;
  final bool highlighted;
  final RaftComposerRecipe recipe;
  final VoidCallback onPressed;
  @override
  State<_RaftComposerSuggestionRow> createState() =>
      _RaftComposerSuggestionRowState();
}

class _RaftComposerSuggestionRowState
    extends State<_RaftComposerSuggestionRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final recipe = widget.recipe;
    final t = recipe.tokens;
    final title = recipe.suggestionTitle(
      highlighted: widget.highlighted,
      hovered: hovered,
    );
    return Semantics(
      key: widget.anchorKey,
      button: true,
      selected: widget.highlighted,
      onTap: widget.onPressed,
      child: MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onPressed,
          child: ConstrainedBox(
            // Web options are `py-2` rows on touch as well (no 48px floor).
            constraints: const BoxConstraints(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: recipe.suggestionBackground(
                  highlighted: widget.highlighted,
                  hovered: hovered,
                ),
                borderRadius: BorderRadius.circular(t.brutal ? 0 : 2),
              ),
              child: Opacity(
                // Not-in-channel options carry `opacity-60`.
                opacity: !s.inChannel && s.isMention ? .6 : 1,
                child: Row(
                  children: [
                    if (s.isMention && s.avatar != null) ...[
                      SizedBox.square(
                        dimension: 20,
                        child: s.inChannel
                            ? s.avatar
                            : (s.mutedAvatar ?? s.avatar),
                      ),
                      if (!s.inChannel) ...[
                        // `ComposerSuggestionIcon variant="auxiliary"`:
                        // UserX 12, `-ml-1 text-black/40`.
                        const SizedBox(width: 4),
                        RaftIcon(
                          RaftGlyph.userX,
                          size: 12,
                          color: recipe.suggestionAuxiliary,
                        ),
                      ],
                    ] else if (s.type == 'channel')
                      const _FramedSuggestionIcon(glyph: RaftGlyph.hash)
                    else
                      RaftIcon(
                        switch (s.type) {
                          'channel' => RaftGlyph.hash,
                          'computer' => RaftGlyph.monitor,
                          'app' => RaftGlyph.globe,
                          'agent' => RaftGlyph.bot,
                          _ => RaftGlyph.user,
                        },
                        size: 14,
                        color: title.color,
                      ),
                    SizedBox(width: t.brutal ? 8 : 10),
                    Expanded(
                      child: s.isMention
                          ? _MentionSuggestionBody(
                              suggestion: s,
                              recipe: recipe,
                              title: title,
                              highlighted: widget.highlighted,
                            )
                          : _ChannelSuggestionBody(
                              name: s.type == 'channel'
                                  ? s.name
                                  : (s.title ?? s.name),
                              detail: s.detail,
                              title: title,
                              meta: recipe.suggestionMetaFor(
                                highlighted: widget.highlighted,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Source ComposerSuggestionTitle has flex-basis:auto, while Meta is
/// flex:1 1 0. Reserve only the title's natural width (not half the row).
class _ChannelSuggestionBody extends StatelessWidget {
  const _ChannelSuggestionBody({
    required this.name,
    required this.detail,
    required this.title,
    required this.meta,
  });
  final String name;
  final String? detail;
  final TextStyle title, meta;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final hasMeta = detail?.trim().isNotEmpty == true;
      final painter = TextPainter(
        text: TextSpan(text: name, style: title),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final available = (bounds.maxWidth - (hasMeta ? 6 : 0)).clamp(
        0.0,
        double.infinity,
      );
      final width = painter.width.clamp(0.0, available);
      painter.dispose();
      return Row(
        children: [
          SizedBox(
            width: width,
            child: Text(
              name,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: title,
            ),
          ),
          if (hasMeta) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                detail!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: meta,
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// `ComposerSuggestionIcon variant="framed"` (channel rows), from the
/// raft-ui composerSuggestionList recipe: brutal 20px `bg-primary` box with
/// a black border and a 12px glyph; elegant bare 14px icon (`-mr-1`).
class _FramedSuggestionIcon extends StatelessWidget {
  const _FramedSuggestionIcon({required this.glyph});
  final RaftGlyph glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final s = RaftComposerSuggestionListRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      iconVariant: RaftComposerSuggestionListRecipeIconVariant.framed,
      tokens: resolver,
    ).icon;
    // CSS negative right margin reduces the flow width while the icon
    // retains its own painted bounds; Flutter Padding cannot be negative.
    final width = s.width ?? 14, height = s.height ?? 14;
    return SizedBox(
      width: (width + s.margin.right).clamp(0.0, double.infinity),
      height: height,
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: width,
        maxWidth: width,
        minHeight: height,
        maxHeight: height,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: s.decoration(resolver),
          child: RaftIcon(
            glyph,
            size: t.brutal ? 12 : width,
            color: s.color?.resolve(resolver),
          ),
        ),
      ),
    );
  }
}

/// Web `MentionCandidateBody`: title (`max-w-[12rem] flex-[0_1_auto]`), the
/// uppercase soft/muted actor Badge, the description meta (`flex-1 basis-0
/// truncate`) and the `@handle` code meta in the aside (`ml-auto
/// max-w-[33%]`, `max-w-[7rem] truncate`).
class _MentionSuggestionBody extends StatelessWidget {
  const _MentionSuggestionBody({
    required this.suggestion,
    required this.recipe,
    required this.title,
    required this.highlighted,
  });
  final RaftComposerSuggestion suggestion;
  final RaftComposerRecipe recipe;
  final TextStyle title;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final description = s.detail?.trim().replaceAll(RegExp(r'\s+'), ' ');
    final badge = RaftActorTypeBadge(
      label: raftText(context, s.type == 'agent' ? 'Agent' : 'Human'),
    );
    final handle = Text(
      '@${s.name}',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: recipe.suggestionCode(highlighted: highlighted),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final handlePainter = TextPainter(
          text: TextSpan(
            text: '@${s.name}',
            style: recipe.suggestionCode(highlighted: highlighted),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        // Source aside is shrink-0 with max-w-[33%], rather than one third.
        final handleWidth = handlePainter.width.clamp(
          0.0,
          (constraints.maxWidth * .33).clamp(0.0, 112.0),
        );
        handlePainter.dispose();
        final hasDescription = description != null && description.isNotEmpty;
        final titleMaximum =
            (constraints.maxWidth -
                    badge.naturalWidth(context) -
                    handleWidth -
                    (hasDescription ? 18 : 12))
                .clamp(0.0, 192.0);
        return Row(
          children: [
            // `max-w-[12rem] flex-[0_1_auto]`: natural width, shrink-only.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: titleMaximum),
              child: Text(
                s.title?.isNotEmpty == true ? s.title! : s.name,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: title,
              ),
            ),
            const SizedBox(width: 6),
            badge,
            if (hasDescription) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  description,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.suggestionMetaFor(highlighted: highlighted),
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: 6),
            SizedBox(width: handleWidth, child: handle),
          ],
        );
      },
    );
  }
}

/// raft-ui `Badge appearance="soft" variant="muted" uppercase` with the
/// mention option overrides `px-1 py-px text-[10px] leading-none`.
class RaftActorTypeBadge extends StatelessWidget {
  const RaftActorTypeBadge({super.key, required this.label});
  final String label;
  ({BoxDecoration decoration, TextStyle text, double? height, String label})
  _resolved(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final s = RaftBadgeRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      appearance: RaftBadgeRecipeAppearance.soft,
      variant: RaftBadgeRecipeVariant.muted,
      uppercase: true,
      tokens: resolver,
    ).root;
    final text = s
        .textStyle(resolver)
        .copyWith(
          fontFamily: t.headingFont,
          fontSize: 10,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        );
    return (
      decoration: s.decoration(resolver),
      text: text,
      height: s.height,
      label: s.textTransform == 'uppercase' ? label.toUpperCase() : label,
    );
  }

  double naturalWidth(BuildContext context) {
    final style = _resolved(context);
    final painter = TextPainter(
      text: TextSpan(text: style.label, style: style.text),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + 8 + style.decoration.padding.horizontal;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolved(context);
    return Container(
      height: style.height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: style.decoration,
      alignment: Alignment.center,
      child: Text(style.label, style: style.text),
    );
  }
}

class RaftEmptyState extends StatelessWidget {
  const RaftEmptyState({
    super.key,
    required this.title,
    required this.detail,
    this.icon = Icons.forum_outlined,
    this.glyph,
    this.action,
  });
  final String title, detail;
  final IconData icon;

  /// Lucide glyph; wins over [icon].
  final RaftGlyph? glyph;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null)
            RaftIcon(glyph!, size: 40)
          else
            Icon(icon, size: 40),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 18), child: action),
        ],
      ),
    ),
  );
}

class RaftUploadChip extends StatelessWidget {
  const RaftUploadChip({
    super.key,
    required this.name,
    required this.onRemove,
    this.progress = 0,
    this.ready = false,
    this.error,
    this.onRetry,
  });
  final String name;
  final VoidCallback onRemove;
  final double progress;
  final bool ready;
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => RaftPanel(
    padding: const EdgeInsets.only(left: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null)
          const Icon(Icons.error_outline, size: 18)
        else if (ready)
          const Icon(Icons.attach_file, size: 18)
        else
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 2,
              semanticsLabel: 'Uploading $name',
            ),
          ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            error == null ? name : '$name · Upload failed',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (error != null && onRetry != null)
          IconButton(
            tooltip: raftText(context, 'Retry upload'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        IconButton(
          tooltip: ready || error != null
              ? raftText(context, 'Remove attachment')
              : raftText(context, 'Cancel upload'),
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}
