import 'message_row_recipe.dart';
import 'message_content_tokens.dart';
import 'mounted_reaction_recipe.dart';
import 'composer_recipe.dart';
import 'composer_suggestions.dart';
import 'collapsible.dart';

import 'package:flutter/material.dart';

import 'localization.dart';

import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'theme.dart';
import 'mounted_avatar_recipe.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'tokens/tokens.dart';

class RaftPanel extends StatelessWidget {
  const RaftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.shadow = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.line, width: t.border),
        borderRadius: BorderRadius.circular(t.radius),
        boxShadow: shadow ? t.shadows : null,
      ),
      child: Material(color: t.panel, child: child),
    );
  }
}

class RaftButton extends StatelessWidget {
  const RaftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.secondary = false,
    this.destructive = false,
    this.variant,
    this.visualHeight = RaftMetrics.buttonMd,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy, secondary, destructive;
  final RaftControlVariant? variant;
  final double visualHeight;
  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          RaftSymbol(icon!, size: visualHeight <= 28 ? 14 : 16),
          const SizedBox(width: 5.5),
        ],
        Flexible(
          child: Text(raftText(context, label), textAlign: TextAlign.center),
        ),
      ],
    );
    return MergeSemantics(
      child: Semantics(
        label: null,
        child: RaftControl(
          onPressed: onPressed,
          busy: busy,
          semanticLabel: busy ? raftText(context, label) : null,
          variant:
              variant ??
              (destructive
                  ? RaftControlVariant.danger
                  : secondary
                  ? RaftControlVariant.outline
                  : RaftControlVariant.accent),
          visualHeight: visualHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: busy ? 0 : 1, child: content),
              if (busy) const RaftSpinner(),
            ],
          ),
        ),
      ),
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
enum RaftConversationNavKind { channel, directMessage }

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
  Color get foreground => tokens.brutal || selected
      ? tokens.colors['foreground-strong']!
      : tokens.colors['foreground-muted']!;
  @override
  Color foregroundFor({bool hovered = false}) =>
      hovered || pointerPressed || selected
      ? tokens.colors['foreground-strong']!
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
      kind == RaftConversationNavKind.channel &&
          channelGlyphVariant == RaftChannelGlyphVariant.mountedProduct
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
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    final recipe = RaftConversationNavigationRecipe(
      RaftTokens.of(context),
      kind: kind,
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
    this.role = RaftNavItemRole.generic,
    this.viewportHeight,
    this.count,
    this.conversationKind,
    this.channelGlyphVariant = RaftChannelGlyphVariant.mountedProduct,
  }) : assert(icon != null || glyph != null),
       assert(conversationKind == null || role == RaftNavItemRole.generic);
  final String label;
  final IconData? icon;
  final RaftGlyph? glyph;
  final double? glyphSize;
  final VoidCallback onTap;
  final bool selected;
  final int unread;
  final Widget? trailing;
  final RaftNavItemRole role;
  final double? viewportHeight;

  /// Saved total is metadata, independent of an unread/activity badge.
  final int? count;

  /// Opt in only for mounted conversation rows; existing roles/defaults stay
  /// unchanged. DM avatars must be supplied by the product, not inferred here.
  final RaftConversationNavKind? conversationKind;
  final RaftChannelGlyphVariant channelGlyphVariant;
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
    final leading = glyph != null
        ? RaftIcon(
            glyph!,
            size: glyphSize ?? conversation?.glyphSize ?? (t.brutal ? 12 : 18),
            strokeWidth: conversation?.glyphStrokeWidth ?? 2,
            color: t.brutal ? t.strong : t.colors['foreground-icon'],
          )
        : RaftSymbol(
            icon!,
            size: conversation?.glyphSize ?? (t.brutal ? 12 : 18),
            color: t.brutal ? t.strong : t.colors['foreground-icon'],
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
      kind: RaftControlKind.sidebar,
      visualHeight: conversationKind == RaftConversationNavKind.channel
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
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (conversation?.titleStyle(loudUnread: unread > 0) ??
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
                        .copyWith(
                          color: conversationKind == null
                              ? t.strong
                              : DefaultTextStyle.of(context).style.color,
                        ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (unread > 0 && conversationKind != null)
              RaftConversationUnreadCount(
                count: unread,
                kind: conversationKind!,
              )
            else if (unread > 0)
              Container(
                height: 16,
                constraints: const BoxConstraints(minWidth: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: t.accentFill,
                  border: Border.all(
                    color: t.brutal ? t.strong : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: RaftTypography.body(
                    t,
                    size: 10,
                    line: 14,
                    weight: FontWeight.w700,
                    color: t.brutal ? t.strong : t.colors['accent-950'],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      selected: selected,
      onTap: onTap,
      button: true,
      label: unread > 0
          ? raftFormat(context, '{label}, {count} unread', {
              'label': label,
              'count': unread,
            })
          : label,
      excludeSemantics: true,
      child: conversationKind == null
          ? row(false)
          : _MountedNavigationPointerSurface(builder: row),
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
              minimumTargetSize:
                  RaftDensityScope.of(context) == RaftDensity.touch
                  ? RaftMetrics.touchTarget
                  : 0,
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
    this.onLink,
    this.threadLabel,
    this.threadPreview,
    this.taskReference,
    this.threadRepliesBadge,
    this.badge,
    this.modelLabel,
    this.subtitle,
    this.avatar,
    this.attachments = const [],
    this.onAttachment,
    this.attachmentBuilder,
    this.attachmentGallery,
    this.reactions = const [],
    this.reactedEmojis = const {},
    this.failedReactionEmojis = const {},
    this.onReaction,
    this.onReact,
    this.onReactionAdd,
    this.collapseLongMessages = true,
    this.bodyFontSize = 14,
    this.body,
    this.hoverToolbar,
    this.onAuthor,
    this.onTap,
    this.rowContext = RaftMessageRowContext.main,
    this.continuation = false,
    this.nextContinuation = false,
    this.coarsePointer = false,
    this.popupOpen = false,
    this.highlighted = false,
  });
  final String author, content, timestamp;
  final RaftMessageRowContext rowContext;
  final String? threadLabel, badge;

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
  final VoidCallback? onThread, onActions, onReact;
  final void Function(String href)? onLink;
  final List<Map<String, dynamic>> attachments, reactions;
  final Set<String> reactedEmojis, failedReactionEmojis;
  final void Function(Map<String, dynamic>)? onAttachment;
  final Widget Function(Map<String, dynamic>)? attachmentBuilder;
  final Widget? attachmentGallery;
  final void Function(String)? onReaction;
  final void Function(BuildContext anchor)? onReactionAdd;

  /// Exact source action strip, supplied only with authorized callbacks.
  final Widget? hoverToolbar;
  final VoidCallback? onAuthor, onTap;
  final bool continuation,
      nextContinuation,
      coarsePointer,
      popupOpen,
      highlighted;
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
      avatar: avatar ?? RaftAvatar(name: author, size: 36),
      onAuthor: onAuthor,
      onActions: onActions,
      onTap: onTap,
      rowContext: rowContext,
      continuation: continuation,
      nextContinuation: nextContinuation,
      coarsePointer: coarsePointer,
      popupOpen: popupOpen,
      highlighted: highlighted,
      toolbar: hoverToolbar,
      subtitle: subtitle,
      metadata: modelLabel == null && badge == null
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
                        style: recipe.time.copyWith(fontSize: 11),
                      ),
                    ),
                  ),
                if (badge != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      badge!,
                      maxLines: 1,
                      style: recipe.time.copyWith(fontSize: 10),
                    ),
                  ),
              ],
            ),
      content: RaftCollapsible(
        enabled: collapseLongMessages,
        child:
            body ??
            SelectionArea(
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
            ),
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
                          .map(
                            (r) => RaftMountedReaction(
                              key: ValueKey('reaction-${r['emoji']}'),
                              label: '${r['emoji']}: ${r['count']}',
                              glyph: RaftReactionGlyph(r['emoji']),
                              count: r['count'],
                              reacted: reactedEmojis.contains(r['emoji']),
                              failure: failedReactionEmojis.contains(
                                r['emoji'],
                              ),
                              onPressed: onReaction == null
                                  ? null
                                  : () => onReaction!(r['emoji']),
                            ),
                          )
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
  final RaftComposerVariant variant;
  final String hint;

  /// Initial controlled focus; the caller admits current identity and scope.
  final bool autofocus;
  final bool Function()? canAutofocus;
  final bool enabled, canSend;
  final String? pendingLabel;
  final String initialDraft;
  final ValueChanged<String>? onDraftChanged;
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
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
        updateSuggestionPortal();
      }
    }
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
        offset: Offset(0, -recipe.suggestionBottomGap),
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

  @override
  Widget build(BuildContext context) {
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
                                    },
                                    child: TextField(
                                      controller: controller,
                                      focusNode: focus,
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
            constraints: BoxConstraints(
              minHeight: RaftDensityScope.of(context) == RaftDensity.touch
                  ? 48
                  : 0,
            ),
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
                opacity: !s.inChannel && s.isMention ? .6 : 1,
                child: Row(
                  children: [
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
                    Flexible(
                      child: Text(
                        '${s.type == 'channel' ? '#' : '@'}${s.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: title,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          raftText(context, switch (s.type) {
                            'agent' => 'Agent',
                            'user' => 'Human',
                            'channel' => 'Channel',
                            'computer' => 'Computer',
                            _ => 'App',
                          }),
                          if (s.title != null && s.title != s.name) s.title!,
                          if (!s.inChannel && s.isMention)
                            raftText(context, 'Not in this conversation'),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: recipe.suggestionMeta,
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

class RaftEmptyState extends StatelessWidget {
  const RaftEmptyState({
    super.key,
    required this.title,
    required this.detail,
    this.icon = Icons.forum_outlined,
    this.action,
  });
  final String title, detail;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
