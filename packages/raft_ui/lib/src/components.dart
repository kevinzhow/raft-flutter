import 'composer_suggestions.dart';
import 'collapsible.dart';

import 'package:flutter/material.dart';

import 'localization.dart';

import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'theme.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'primitive_tokens.dart';

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
  });
  final String name;
  final double size;
  final RaftAvatarKind kind;
  final String? imageUrl;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
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
            child: imageUrl == null
                ? fallback
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  ),
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
      return const [
        BoxShadow(color: RaftPrimitives.rgbaff141111, offset: Offset(2, 2)),
      ];
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
    borderRadius: BorderRadius.circular(2),
  );
  // Elegant inherits the mounted Sidebar Inter face; Brutal font-sans resolves
  // Hanken. Generic navigation and DM label typography stay unchanged.
  TextStyle get countTextStyle =>
      RaftTypography.heading(
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
      child: RaftControl(
        onPressed: onTap,
        selected: selected,
        kind: RaftControlKind.sidebar,
        visualHeight: 32,
        variant: selected
            ? t.brutal
                  ? RaftControlVariant.accent
                  : RaftControlVariant.surface
            : RaftControlVariant.ghost,
        child: Row(
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
                    conversation?.titleStyle(loudUnread: unread > 0) ??
                    RaftTypography.body(
                      t,
                      size: t.brutal ? 14 : 13,
                      line: 20,
                      weight: selected || unread > 0
                          ? FontWeight.w700
                          : t.brutal
                          ? FontWeight.w400
                          : FontWeight.w500,
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
    this.badge,
    this.modelLabel,
    this.attachments = const [],
    this.onAttachment,
    this.attachmentBuilder,
    this.attachmentGallery,
    this.reactions = const [],
    this.reactedEmojis = const {},
    this.onReaction,
    this.onReact,
    this.collapseLongMessages = true,
    this.bodyFontSize = 14,
    this.body,
  });
  final String author, content, timestamp;
  final String? threadLabel, badge;

  /// Permitted adapter-projected label; this component performs no model lookup.
  final String? modelLabel;
  final bool collapseLongMessages;
  final double bodyFontSize;

  /// Business adapters may supply a richer body without replacing message
  /// actions, thread controls, attachments, or reactions.
  final Widget? body, threadPreview;
  final VoidCallback? onThread, onActions, onReact;
  final void Function(String href)? onLink;
  final List<Map<String, dynamic>> attachments, reactions;
  final Set<String> reactedEmojis;
  final void Function(Map<String, dynamic>)? onAttachment;
  final Widget Function(Map<String, dynamic>)? attachmentBuilder;
  final Widget? attachmentGallery;
  final void Function(String)? onReaction;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return GestureDetector(
      onLongPress: onActions,
      onSecondaryTap: onActions,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RaftAvatar(name: author),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (modelLabel != null && modelLabel!.trim().isNotEmpty)
                        Tooltip(
                          message: modelLabel!,
                          child: Text(
                            modelLabel!,
                            style: RaftTypography.body(
                              t,
                              size: 11,
                              line: 16.5,
                              color: t.muted,
                            ),
                          ),
                        ),
                      Text(
                        timestamp,
                        style: TextStyle(color: t.muted, fontSize: 11),
                      ),
                      if (badge != null)
                        Text(
                          badge!,
                          style: TextStyle(
                            color: t.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  RaftCollapsible(
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
                                MarkdownStyleSheet.fromTheme(
                                  Theme.of(context),
                                ).copyWith(
                                  p: TextStyle(
                                    fontSize: bodyFontSize,
                                    height: 1.5,
                                    color: t.ink,
                                  ),
                                  code: TextStyle(
                                    fontFamily: 'packages/raft_ui/GeistMono',
                                    fontSize: 12,
                                    color: t.ink,
                                    backgroundColor: t.sidebar,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: t.sidebar,
                                    borderRadius: BorderRadius.circular(
                                      t.radius,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                  ),
                  if (attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child:
                          attachmentGallery ??
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: attachments
                                .map(
                                  (a) =>
                                      attachmentBuilder?.call(a) ??
                                      OutlinedButton.icon(
                                        onPressed: () => onAttachment?.call(a),
                                        icon: const Icon(
                                          Icons.attach_file,
                                          size: 16,
                                        ),
                                        label: Text(
                                          '${a['filename'] ?? a['name'] ?? 'Attachment'}',
                                        ),
                                      ),
                                )
                                .toList(),
                          ),
                    ),
                  if (reactions.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: reactions
                          .map(
                            (r) => FilterChip(
                              selected: reactedEmojis.contains(r['emoji']),
                              showCheckmark: false,
                              label: Text('${r['emoji']} ${r['count'] ?? 1}'),
                              onSelected: onReaction == null
                                  ? null
                                  : (_) => onReaction?.call('${r['emoji']}'),
                            ),
                          )
                          .toList(),
                    ),
                  if (threadPreview != null)
                    threadPreview!
                  else if (onThread != null)
                    TextButton.icon(
                      onPressed: onThread,
                      icon: const Icon(Icons.forum_outlined, size: 15),
                      label: Text(
                        threadLabel ?? raftText(context, 'Reply in thread'),
                      ),
                    ),
                ],
              ),
            ),
            if (onActions != null)
              IconButton(
                tooltip: raftText(context, 'Message actions'),
                onPressed: onActions,
                icon: const Icon(Icons.more_horiz, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class RaftComposer extends StatefulWidget {
  const RaftComposer({
    super.key,
    required this.onSend,
    this.onAttach,
    this.hint = 'Message',
    this.enabled = true,
    this.canSend = true,
    this.pendingLabel,
    this.initialDraft = '',
    this.onDraftChanged,
    this.suggestions = const [],
    this.onSendWithMentions,
    this.onSuggestionsRequested,
  });
  final List<RaftComposerSuggestion> suggestions;
  final Future<bool> Function(String, List<Map<String, dynamic>>)?
  onSendWithMentions;
  final ValueChanged<String>? onSuggestionsRequested;
  final Future<bool> Function(String) onSend;
  final VoidCallback? onAttach;
  final String hint;
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
    if (trigger == null || composing || sending || !widget.enabled) return [];
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
      if (a.inChannel != b.inChannel) return a.inChannel ? -1 : 1;
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
    if (next != null) widget.onSuggestionsRequested?.call(next.prefix);
    if (mounted) setState(() {});
  }

  void insert(RaftComposerSuggestion suggestion) {
    final range = trigger;
    if (range == null || composing || sending) return;
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
        if (mounted && suggestionScroll.hasClients)
          suggestionScroll.jumpTo(
            (suggestionIndex * 56.0).clamp(
              0.0,
              suggestionScroll.position.maxScrollExtent,
            ),
          );
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
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialDraft);
    controller.addListener(changed);
  }

  @override
  void didUpdateWidget(covariant RaftComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDraft != widget.initialDraft &&
        controller.text.isEmpty &&
        !focus.hasFocus &&
        !sending) {
      restoringDraft = true;
      controller.text = widget.initialDraft;
      restoringDraft = false;
    }
  }

  Future<void> send() async {
    final draft = controller.text;
    final text = draft.trim();
    if (sending ||
        composing ||
        !widget.enabled ||
        !widget.canSend ||
        (text.isEmpty && widget.pendingLabel == null))
      return;
    setState(() => sending = true);
    try {
      final selected = mentions.values
          .where((m) => raftStructuredMentionAppears(text, m['name'] as String))
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final succeeded = widget.onSendWithMentions == null
          ? await widget.onSend(text)
          : await widget.onSendWithMentions!(text, selected);
      if (succeeded && mounted && controller.text == draft) {
        mentions.clear();
        controller.clear();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    suggestionScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final options = matches;
    final desktop =
        MediaQuery.sizeOf(context).width >= RaftLayoutMetrics.desktopBreakpoint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Focus(
        onFocusChange: (value) => setState(() => composerFocused = value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.panel,
            borderRadius: RaftShapes.panel(t),
            border: Border.all(
              color: t.brutal
                  ? Colors.black
                  : t.dark
                  ? composerFocused
                        ? t.accentFill.withValues(alpha: .7)
                        : Colors.transparent
                  : Colors.black.withValues(alpha: .06),
              width: t.brutal
                  ? 2
                  : t.dark
                  ? .5
                  : 1,
            ),
            boxShadow: t.brutal
                ? composerFocused
                      ? t.focusShadows
                      : t.shadows
                : t.dark
                ? null
                : t.shadows,
          ),
          child: Padding(
            padding: t.brutal ? const EdgeInsets.all(8) : EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (options.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      controller: suggestionScroll,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final s = options[index];
                        return Semantics(
                          selected: index == suggestionIndex,
                          child: Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              key: ValueKey(
                                'composer-suggestion-${s.type}-${s.id}',
                              ),
                              selected: index == suggestionIndex,
                              tileColor: t.panel,
                              dense: true,
                              minTileHeight: 48,
                              leading: RaftSymbol(
                                s.type == 'channel'
                                    ? Icons.tag
                                    : s.type == 'agent'
                                    ? Icons.smart_toy_outlined
                                    : s.type == 'computer'
                                    ? Icons.computer
                                    : s.type == 'app'
                                    ? Icons.extension_outlined
                                    : Icons.person_outline,
                              ),
                              title: Text(
                                '${s.type == 'channel' ? '#' : '@'}${s.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                [
                                  raftText(context, switch (s.type) {
                                    'agent' => 'Agent',
                                    'user' => 'Human',
                                    'channel' => 'Channel',
                                    'computer' => 'Computer',
                                    _ => 'App',
                                  }),
                                  if (s.title != null && s.title != s.name)
                                    s.title!,
                                  if (!s.inChannel && s.isMention)
                                    raftText(
                                      context,
                                      'Not in this conversation',
                                    ),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => insert(s),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (widget.pendingLabel != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      widget.pendingLabel!,
                      style: TextStyle(color: t.accent),
                    ),
                  ),

                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: desktop ? 40 : 20,
                    maxHeight: RaftMetrics.composerInputMax,
                  ),
                  child: Padding(
                    padding: t.brutal
                        ? EdgeInsets.zero
                        : const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Focus(
                      onKeyEvent: suggestionKey,
                      child: Shortcuts(
                        shortcuts: const {
                          SingleActivator(
                            LogicalKeyboardKey.enter,
                            control: true,
                          ): ActivateIntent(),
                          SingleActivator(LogicalKeyboardKey.enter, meta: true):
                              ActivateIntent(),
                        },
                        child: Actions(
                          actions: {
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) {
                                if (controller.value.composing.isValid &&
                                    !controller.value.composing.isCollapsed)
                                  return null;
                                send();
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
                            style: RaftTypography.heading(
                              t,
                              size: desktop ? 14 : 16,
                              line: 20,
                              weight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.hint,
                              hintStyle: TextStyle(
                                color: t.brutal
                                    ? Colors.black.withValues(alpha: .35)
                                    : t.colors['foreground-placeholder'],
                              ),
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RaftMetrics.composerGap),
                Padding(
                  padding: t.brutal
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.onAttach != null)
                        RaftIconButton(
                          glyph: RaftGlyph.paperclip,
                          visualSize: t.brutal ? 26 : 28,
                          glyphSize: 14,
                          variant: t.brutal
                              ? RaftControlVariant.outline
                              : RaftControlVariant.ghost,
                          tooltip: 'Attach file',
                          onPressed: sending || !widget.enabled
                              ? null
                              : widget.onAttach,
                        )
                      else
                        const SizedBox.shrink(),
                      RaftIconButton(
                        glyph: RaftGlyph.send,
                        visualSize: 28,
                        glyphSize: 14,
                        variant: RaftControlVariant.accent,
                        tooltip: 'Send message (Ctrl+Enter)',
                        busy: sending,
                        onPressed: widget.enabled && widget.canSend && !sending
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
