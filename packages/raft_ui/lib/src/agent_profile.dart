// Visual building blocks of the Web member/agent detail panels
// (packages/web/src/components/agent/AgentDetailPanel.tsx, AgentActivityLog,
// AgentRemindersSection, AgentWorkspace, AgentAppAccessTab and
// components/member/HumanDetailPanel.tsx). Data loading stays in the app; the
// widgets here take plain view data and callbacks. Values cite the Tailwind
// classes / raft-ui recipes they come from.
import 'hover_region.dart';
import 'css_pixel_snap.dart';
import 'anchored_popup.dart';
import 'dismiss_scope.dart';
import 'dialog_card.dart' show RaftRecipeButton;
import 'error_presentation.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'raft_selection_area.dart';

import 'package:flutter/services.dart';

import 'system_inset.dart';
import 'avatar_content.dart';
import 'icons.dart';
import 'inline_badge_editor.dart';
import 'localization.dart';
import 'panel_layout.dart';
import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'recipes/avatar.g.dart';
import 'recipes/badge.g.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/recipe_utilities.g.dart';
import 'recipes/spinner.g.dart';
import 'recipes/token_binding.dart';
import 'list_items.dart';
import 'product_empty_state.dart';
import 'recipe_surface.dart'
    show RaftCssBoxDecoration, RaftCssOverflowY, RaftRecipeBox, raftCssText;
import 'theme.dart';
import 'tooltip.dart';
import 'status_bar.dart';

/// Tailwind `bg-gray-400` (oklch(70.7% 0.022 261.325)), StatusDot default.
const raftGray400 = Color(0xFF99A1AF);

/// Tailwind `bg-blue-300` (oklch(80.9% 0.105 251.813)), slock_action dot.
const raftBlue300 = Color(0xFF8EC5FF);

/// utils/activity.ts getActivityDotClass.
Color raftActivityDotColor(RaftTokens t, String? activity) =>
    switch (activity) {
      'online' => t.product.brutalLime,
      'thinking' || 'working' => t.product.statusBusy,
      'error' => t.product.brutalOrange,
      _ => raftGray400,
    };

/// Panel body text at 16/24 in the page's inherited family (the theme's
/// heading family).
///
/// [sans] is Web v1.21.12's `font-sans` on the profile panels' root
/// (`ProfilePanelBody className="... font-sans"` in AgentDetailPanel,
/// HumanDetailPanel and ExternalIdentityDetailPanel): text that names no
/// family of its own switches from Inter to Geist in elegant (brutal's
/// heading and sans families are both Hanken Grotesk).
class RaftPanelTextScope extends StatelessWidget {
  const RaftPanelTextScope({super.key, required this.child, this.sans = false});
  final Widget child;
  final bool sans;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInheritedFontScope(
      child: DefaultTextStyle(
        style: raftCssText.merge(
          (sans
                  ? RaftTypography.body(t, weight: FontWeight.w400)
                  : RaftTypography.heading(t, weight: FontWeight.w400))
              .copyWith(color: t.ink),
        ),
        // The panel body is the column's surface under a transparent header.
        child: RaftStatusBarSource(
          color: t.colors['layer-panel']!,
          child: ColoredBox(color: t.colors['layer-panel']!, child: child),
        ),
      ),
    );
  }
}

/// StatusDot.tsx: `inline-block shrink-0 rounded-full border
/// border-line-strong theme-brutal:border-black`, size md 10 / sm 8.
class RaftActivityDot extends StatelessWidget {
  const RaftActivityDot({super.key, required this.color, this.small = false});
  final Color color;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = small ? 8.0 : 10.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-strong']!,
        ),
      ),
    );
  }
}

/// raft-ui Badge (`badge` recipe); [background] is a Web className override.
class RaftRecipeBadge extends StatelessWidget {
  const RaftRecipeBadge(
    this.label, {
    super.key,
    this.appearance = RaftBadgeRecipeAppearance.soft,
    this.variant,
    this.uppercase = false,
    this.background,
    this.foreground,
    this.trailing,
    this.mono = false,
  });
  final String label;

  /// Web `font-mono` className override.
  final bool mono;

  /// Web className text colour override (`text-warning-strong`).
  final Color? foreground;
  final RaftBadgeRecipeAppearance appearance;
  final RaftBadgeRecipeVariant? variant;
  final bool uppercase;
  final Color? background;

  /// Inline content after the label (a runtime usage health Status).
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftBadgeRecipe.resolve(
      theme: raftRecipeTheme(t),
      appearance: appearance,
      variant: variant,
      uppercase: uppercase,
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
      }, MediaQuery.sizeOf(context).width),
      tokens: rt,
    ).root;
    final decoration = s.decoration(rt);
    // The recipe's `uppercase` axis only transforms Brutal (`text-transform`).
    final upper =
        uppercase && '${s.properties['text-transform']}' == 'uppercase';
    final text = RaftCssText(
      upper ? label.toUpperCase() : label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      controlLabel: true,
      style: raftCssText.merge(
        RaftTypography.body(t, size: 10, line: 10)
            .merge(s.textStyle(rt))
            .copyWith(
              // Inside a panel the label inherits the page face (Inter).
              fontFamily: mono
                  ? t.monoFont
                  : RaftInheritedFontScope.active(context)
                  ? t.headingFont
                  : null,
              color: foreground,
            ),
      ),
    );
    // The recipe height is a minimum: a label whose line box is taller than the
    // box (Android Chinese control profile 1.3, or any text scale above 1) grows
    // the capsule instead of being squeezed into it, which clipped descenders
    // and, with the line box overflowing downwards, dropped the text low.
    // RaftCssOverflowY keeps a label that still meets a tighter parent centred.
    return Container(
      constraints: BoxConstraints(minHeight: s.height ?? 0),
      padding: s.padding,
      decoration: background == null
          ? decoration
          : decoration.copyWith(color: background),
      child: Center(
        widthFactor: 1,
        child: RaftCssOverflowY(
          child: trailing == null
              ? text
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [text, trailing!],
                ),
        ),
      ),
    );
  }
}

/// A Badge inline in a text line: `text-sm` (14/20) by default, or the body
/// 16/24 line when [bodyLine].
class RaftInlineBadge extends StatelessWidget {
  const RaftInlineBadge({
    super.key,
    required this.badge,
    this.bodyLine = false,
  });
  final Widget badge;
  final bool bodyLine;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = RaftBadgeRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
      }, MediaQuery.sizeOf(context).width),
    ).root;
    return RaftCssInlineBox(
      lineText: bodyLine
          ? raftCssText.merge(
              RaftTypography.heading(t, weight: FontWeight.w400),
            )
          : RaftInfoRow.valueStyle(t),
      childText: RaftTypography.heading(
        t,
        size: s.fontSize ?? 10,
        line: (s.lineHeight ?? 1) * (s.fontSize ?? 10),
        weight: FontWeight.w700,
      ),
      // Elegant badges size to their content (`py-0.5` + 1px border).
      height:
          s.height ??
          (s.lineHeight ?? 1) * (s.fontSize ?? 10) + s.padding.vertical + 2,
      // The badge height is a minimum: a taller capsule grows its line.
      minHeight: true,
      child: Align(alignment: Alignment.centerLeft, child: badge),
    );
  }
}

/// Web AvatarSlot contexts (components/ui/AvatarSlot.tsx RAFT_AVATAR_SPEC).
enum RaftAvatarSlotContext {
  profileTile(64, 2),
  // AvatarSlot `mention-card`: `!size-12 !border-2` (hover cards).
  mentionCard(48, 2),
  panelHeader(36, 2),
  surfaceList(32, 2),
  // AvatarSlot `compact-list`: `!size-5 !border` (SelectionPopover rows).
  compactList(20, 1),
  creatorLink(22, 1),
  previewMini(14, 1);

  const RaftAvatarSlotContext(this.size, this.border);
  final double size, border;
}

/// raft-ui Avatar sized for an AvatarSlot context; agents render their
/// `pixel:` artwork, humans the user glyph fallback.
class RaftAvatarSlot extends StatelessWidget {
  const RaftAvatarSlot({
    super.key,
    required this.name,
    required this.slot,
    this.agent = true,
    this.avatarUrl,
    this.content,
    this.sizeOverride,
    this.server = false,
  });

  /// AvatarSlot `type="server"`: Brutal adds `bg-soft-signal text-black`.
  final bool server;
  final double? sizeOverride;
  final Widget? content;
  final String name;
  final RaftAvatarSlotContext slot;
  final bool agent;
  final String? avatarUrl;

  static String? pixelKey(String? url) =>
      url != null && url.startsWith('pixel:') ? url.substring(6) : null;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftAvatarRecipe.resolve(
      theme: raftRecipeTheme(t),
      type_: agent ? RaftAvatarRecipeType.agent : RaftAvatarRecipeType.human,
      size: RaftAvatarRecipeSize.xl,
      tokens: rt,
    );
    // Avatar fallback `& > svg`: 24 at xl/lg, 18 at md, 12 at xs.
    final icon = slot == RaftAvatarSlotContext.previewMini
        ? 10.0
        : slot.size >= 48
        ? 24.0
        : slot.size >= 36
        ? 18.0
        : 12.0;
    final key = pixelKey(avatarUrl);
    final base = s.root.decoration(rt);
    final radius = t.brutal
        ? base.borderRadius
        : BorderRadius.circular((sizeOverride ?? slot.size) / 2);
    // Elegant `border-2 border-transparent bg-clip-padding`: the fill stops
    // at the padding box, so the transparent border shows the surface behind
    // (a BoxDecoration colour would also paint under the border).
    final clipPadding =
        s.root.properties['background-clip']?.toString() == 'padding-box';
    Widget child =
        content ??
        RaftAvatarContent(
          name: name,
          kind: agent
              ? RaftAvatarContentKind.agent
              : RaftAvatarContentKind.human,
          pixelKey: key,
          uploadedUrl: key == null ? avatarUrl : null,
          fallback: Center(
            child: RaftIcon(
              agent ? RaftGlyph.bot : RaftGlyph.user,
              size: icon,
              color: s.fallback.color?.resolve(rt),
            ),
          ),
        );
    // `rounded-full bg-clip-padding border-2 border-transparent`: the circle
    // the artwork is clipped to is the padding box, `border` smaller than the
    // slot on each side (not the outer box, which would show the artwork's
    // corners cut by a circle wider than the padding box).
    final BorderRadius? inner = t.brutal
        ? null
        : BorderRadius.circular(
            math.max(0, (sizeOverride ?? slot.size) / 2 - slot.border),
          );
    if (clipPadding && base.color != null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: base.color,
          borderRadius: inner ?? radius,
        ),
        child: child,
      );
    }
    if (inner != null) {
      child = ClipRRect(borderRadius: inner, child: child);
    }
    return Container(
      width: sizeOverride ?? slot.size,
      height: sizeOverride ?? slot.size,
      clipBehavior: Clip.antiAlias,
      decoration: base.copyWith(
        color: server && t.brutal
            ? t.product.softSignal
            : clipPadding
            ? Colors.transparent
            : null,
        // `rounded-full` in Elegant at every AvatarSlot size.
        borderRadius: radius,
        border: Border.all(
          color: s.root.borderColor?.resolve(rt) ?? Colors.black,
          width: slot.border,
        ),
      ),
      child: child,
    );
  }
}

/// Web className text-size overrides on a Button: `text-[11px]`, `text-sm`.
enum RaftButtonText { recipe, px11, sm }

/// Recipe-resolved Button (`buttonVariants`) with a label and optional icon.
class RaftRecipeTextButton extends StatefulWidget {
  const RaftRecipeTextButton({
    super.key,
    required this.label,
    this.glyph,
    this.onPressed,
    this.variant = RaftButtonRecipeVariant.outline,
    this.size = RaftButtonRecipeSize.sm,
    this.text = RaftButtonText.recipe,
    this.bold = false,
    this.expand = false,
    this.horizontalPadding,
  });
  final String label;
  final RaftGlyph? glyph;
  final VoidCallback? onPressed;

  /// null = the recipe default variant.
  final RaftButtonRecipeVariant? variant;
  final RaftButtonRecipeSize size;

  /// className text-size override.
  final RaftButtonText text;
  final bool bold, expand;
  final double? horizontalPadding;
  @override
  State<RaftRecipeTextButton> createState() => _RaftRecipeTextButtonState();
}

class _RaftRecipeTextButtonState extends State<RaftRecipeTextButton> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftButtonRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: widget.variant,
      size: widget.size,
      states: RaftRecipeStates({
        if (hovered) RaftRecipeStates.hover,
        if (pressed) RaftRecipeStates.active,
        if (widget.onPressed == null) RaftRecipeStates.disabled,
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: rt,
    ).root;
    final size = switch (widget.text) {
      RaftButtonText.px11 => 11.0,
      RaftButtonText.sm => 14.0,
      RaftButtonText.recipe => s.fontSize ?? 14,
    };
    var text = RaftTypography.body(
      t,
      size: size,
      line: size * 1.4286,
    ).merge(s.textStyle(rt).copyWith(fontSize: size));
    if (widget.bold) text = text.copyWith(fontWeight: FontWeight.w700);
    text = raftCssText.merge(text);
    final pad = widget.horizontalPadding;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: RaftHoverRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: widget.onPressed,
          child: Opacity(
            opacity: s.opacity ?? 1,
            child: Transform.translate(
              offset: s.translate ?? Offset.zero,
              // The recipe box paints the `::before` sheen and inset shadows
              // (Elegant solid buttons carry a vertical gradient).
              child: RaftRecipeBox(
                style: s,
                tokens: rt,
                height: s.height,
                padding: EdgeInsets.symmetric(
                  horizontal: pad ?? s.padding.left,
                ),
                applyText: false,
                applyOpacity: false,
                applyTransform: false,
                child: Row(
                  mainAxisSize: widget.expand
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.glyph != null) ...[
                      RaftIcon(widget.glyph!, size: 14, color: text.color),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: RaftCssText(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text,
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

/// A bordered section of a detail panel: `px-5 py-4 border-t
/// border-line-muted theme-brutal:border-black/10`.
class RaftPanelSection extends StatelessWidget {
  const RaftPanelSection({
    super.key,
    required this.children,
    this.topBorder = true,
    this.vertical = 16,
    this.gap = 12,
  });
  final List<Widget> children;
  final bool topBorder;
  final double vertical, gap;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final content = Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: vertical + (topBorder ? 1 : 0),
        bottom: vertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );
    if (!topBorder) return content;
    return RaftCssTopBorder(color: raftPanelRuleColor(t), child: content);
  }
}

/// Panel section rule: `border-line-muted theme-brutal:border-black/10`.
/// The product JSX's border-black/10 literal uses the generated CSS composite
/// colour; do not replace it with a separately rounded alpha.
Color raftPanelRuleColor(RaftTokens t) {
  if (!t.brutal) return t.colors['line-muted']!;
  final rt = RaftRecipeTokens(t);
  final compiled = raftRecipeEngine.resolveSlot(
    [raftRecipeUtilities.indexWhere((u) => u.name == 'border-black/10')],
    RaftRecipeStates.none,
    rt,
  );
  return compiled.borderColor!.resolve(rt);
}

/// Eyebrow followed by optional inline edit pencil (`flex items-center
/// gap-2`).
class RaftEditableEyebrow extends StatelessWidget {
  const RaftEditableEyebrow(
    this.label, {
    super.key,
    this.onEdit,
    this.editLabel,
    this.editKey,
  });
  final String label;
  final VoidCallback? onEdit;
  final String? editLabel;
  final Key? editKey;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      RaftSectionEyebrow(label),
      if (onEdit != null) ...[
        const SizedBox(width: 8),
        RaftInlineIconButton(
          key: editKey,
          glyph: RaftGlyph.pencil,
          tooltip: editLabel ?? label,
          onPressed: onEdit,
        ),
      ],
    ],
  );
}

/// Text styles shared by the panels.
abstract final class RaftPanelText {
  static TextStyle value(RaftTokens t) => raftCssText.merge(
    RaftTypography.body(
      t,
      size: 14,
      line: 20,
    ).copyWith(color: t.brutal ? Colors.black : t.strong),
  );

  /// Web v1.21.12 profile value (`InfoRow` dd, `KeyValueRow` value, the
  /// description paragraph): `text-sm text-foreground-muted
  /// theme-brutal:text-black`.
  static TextStyle profileValue(RaftTokens t) => RaftInfoRow.valueStyle(t);

  /// `italic text-foreground-placeholder theme-brutal:text-black/40` in a
  /// profile value (Web v1.21.12 human description).
  static TextStyle profilePlaceholder(RaftTokens t) => profileValue(t).copyWith(
    fontStyle: FontStyle.italic,
    color: raftPanelInk(t, .4, t.colors['foreground-placeholder']!),
  );

  /// [profileValue] in the mono face (`font-mono` inside the profile value).
  static TextStyle profileMono(RaftTokens t) =>
      profileValue(t).copyWith(fontFamily: t.monoFont);

  /// Web v1.21.12 profile term (`InfoRow` dt, `KeyValueRow` label):
  /// `text-[13px] text-foreground-hint theme-brutal:text-black/50`.
  static TextStyle profileLabel(RaftTokens t) => RaftInfoRow.labelStyle(t);
  static TextStyle placeholder(RaftTokens t) => value(t).copyWith(
    fontStyle: FontStyle.italic,
    color: raftPanelInk(t, .4, t.colors['foreground-muted']!),
  );
  static TextStyle muted(RaftTokens t) =>
      value(t)
          .copyWith(color: raftPanelInk(t, .5, t.colors['foreground-muted']!));
  static TextStyle mono(RaftTokens t) =>
      value(t).copyWith(fontFamily: t.monoFont);
  static TextStyle label(RaftTokens t) => raftCssText.merge(
    RaftTypography.body(
      t,
      size: 12,
      line: 16,
    ).copyWith(color: raftPanelInk(t, .5, t.colors['foreground-muted']!)),
  );
  static TextStyle caption(RaftTokens t) => raftCssText.merge(
    RaftTypography.body(
      t,
      size: 12,
      line: 16,
    ).copyWith(color: t.colors['foreground-muted']),
  );
  static TextStyle monoCaption(RaftTokens t) => raftCssText.merge(
    RaftTypography.mono(
      t,
      color: raftPanelInk(t, .5, t.colors['foreground-muted']!),
    ),
  );
}

/// A `<span>` placeholder inside a block whose own text is the 16/24 body
/// (HumanDetailPanel "No created agents"): the line box is 24px and the 14px
/// text sits 4px below its top.
class RaftSpanPlaceholder extends StatelessWidget {
  const RaftSpanPlaceholder(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.topLeft,
        child: RaftCssText(
          text,
          style: RaftPanelText.placeholder(RaftTokens.of(context)),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ identity

/// Profile header of the agent / human panels: `flex items-start gap-4 px-5
/// py-5` (+ `theme-brutal:min-h-[72px]` for agents), avatar tile, name
/// (`text-lg font-bold leading-tight`), mono handle and an optional status
/// line.
class RaftProfileIdentity extends StatelessWidget {
  const RaftProfileIdentity({
    super.key,
    required this.name,
    required this.handle,
    this.avatarUrl,
    this.agent = true,
    this.onEditName,
    this.onAvatar,
    this.avatarButton = false,
    this.statusColor,
    this.statusText,
    this.minHeight = 0,
    this.youLabel,
  });

  /// `(you)` after the handle: `shrink-0 text-sm font-mono text-foreground-muted`.
  final String? youLabel;
  final String name, handle;
  final String? avatarUrl;
  final bool agent, avatarButton;
  final VoidCallback? onEditName, onAvatar;
  final Color? statusColor;
  final String? statusText;
  final double minHeight;

  /// `text-sm PROFILE_HANDLE_SIZE_CLASS font-mono text-foreground-placeholder
  /// theme-brutal:...`: 14/20 mono; elegant raises the size to 15 (the
  /// line box stays `text-sm`'s 20) and uses the placeholder ink.
  static TextStyle _handleStyle(RaftTokens t, {required Color brutal}) =>
      raftCssText.merge(
        RaftTypography.mono(
          t,
          size: t.brutal ? 14 : 15,
          line: 20,
          color: t.brutal ? brutal : t.colors['foreground-placeholder'],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    Widget avatar = RaftAvatarSlot(
      name: name,
      agent: agent,
      avatarUrl: avatarUrl,
      slot: RaftAvatarSlotContext.profileTile,
    );
    if (avatarButton) {
      // `<Button variant="outline" className="size-16 !p-0">` contributes
      // the outline shadow around the tile.
      final button = RaftButtonRecipe.resolve(
        theme: raftRecipeTheme(t),
        variant: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.md,
        tokens: rt,
      ).root;
      avatar = DecoratedBox(
        decoration: RaftCssBoxDecoration(
          boxShadow: button.boxShadow.toBoxShadows(rt),
        ),
        child: avatar,
      );
    }
    if (onAvatar != null) {
      avatar = _ProfileAvatarAction(
        key: const ValueKey('agent-profile-avatar-trigger'),
        onPressed: onAvatar!,
        child: avatar,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Web v1.21.12 `PanelTitle` (the detail-block name follows the
                  // panel-title spec): elegant 17 / semibold / heading family
                  // in `text-foreground-muted`; brutal `text-lg` (18) black.
                  // The recipe's `leading-tight` is a 22.5px (brutal) line
                  // box; Flutter rounds a paragraph's height to whole pixels,
                  // so the line box is sized explicitly.
                  // The row is 22.5px tall in both themes (measured on the Web
                  // render: the handle starts there), the name at its top and
                  // the pencil centred (`flex items-center gap-2`).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: RaftCssText(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: raftPanelTitleStyle(t),
                        ),
                      ),
                      if (onEditName != null) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 22.5,
                          child: Center(
                            child: RaftInlineIconButton(
                              key: const ValueKey('agent-edit-display-name'),
                              glyph: RaftGlyph.pencil,
                              size: 14,
                              tooltip: raftText(context, 'Edit display name'),
                              onPressed: onEditName,
                            ),
                          ),
                        ),
                      ] else
                        // ignore: raft_lints/off_grid_spacing -- measured Web name-row height (leading-tight line box + pencil), not a spacing step
                        const SizedBox(height: 22.5),
                    ],
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: RaftCssText(
                          '@$handle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _handleStyle(
                            t,
                            brutal: agent
                                ? t.colors['foreground-muted']!
                                : raftPanelInk(
                                    t,
                                    .5,
                                    t.colors['foreground-muted']!,
                                  ),
                          ),
                        ),
                      ),
                      if (youLabel != null) ...[
                        const SizedBox(width: 8),
                        RaftCssText(
                          youLabel!,
                          maxLines: 1,
                          style: _handleStyle(
                            t,
                            brutal: raftPanelInk(
                              t,
                              .6,
                              t.colors['foreground-muted']!,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (statusText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          RaftActivityDot(color: statusColor ?? raftGray400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RaftCssText(
                              statusText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: raftCssText.merge(
                                RaftTypography.mono(
                                  t,
                                  size: 14,
                                  line: 20,
                                  color: raftPanelInk(
                                    t,
                                    .6,
                                    t.colors['foreground-muted']!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline creator / member reference: avatar (creator-link), name
/// (`font-medium`), mono handle.
class RaftCreatorLink extends StatelessWidget {
  const RaftCreatorLink({
    super.key,
    required this.name,
    required this.handle,
    this.human = true,
    this.avatarUrl,
  });
  final String name, handle;
  final bool human;
  final String? avatarUrl;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      children: [
        RaftAvatarSlot(
          name: name,
          agent: !human,
          avatarUrl: avatarUrl,
          slot: RaftAvatarSlotContext.creatorLink,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RaftCssText(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Web v1.21.12 drops `font-medium`: the name is regular weight.
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RaftCssText(
            '@$handle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // `font-mono text-xs text-foreground-hint
            // theme-brutal:text-black/50` (v1.21.12).
            style: RaftPanelText.monoCaption(t).copyWith(
              color: raftPanelInk(t, .5, t.colors['foreground-hint']!),
            ),
          ),
        ),
      ],
    );
  }
}

/// Computer status value: dot + Connected / Offline.
class RaftConnectionValue extends StatelessWidget {
  const RaftConnectionValue({super.key, required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      children: [
        RaftActivityDot(color: online ? t.product.brutalLime : raftGray400),
        const SizedBox(width: 6),
        // v1.21.12 `<span className="flex items-center gap-1.5 font-mono">`.
        RaftCssText(
          raftText(context, online ? 'Connected' : 'Offline'),
          style: RaftPanelText.profileMono(t),
        ),
      ],
    );
  }
}

/// EnvVarsSection read-only chips: `flex flex-wrap gap-2`, chip `inline-block
/// border border-line-muted bg-layer-card px-2 py-0.5 text-xs font-mono
/// theme-brutal:border-2 theme-brutal:border-black theme-brutal:bg-white`.
class RaftEnvVarChips extends StatelessWidget {
  const RaftEnvVarChips({super.key, required this.vars});
  final Map<String, String> vars;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = raftCssText.merge(
      RaftTypography.mono(t, color: t.brutal ? Colors.black : t.strong),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in vars.entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.brutal ? Colors.white : t.colors['layer-card'],
              border: Border.all(
                color: t.brutal ? Colors.black : t.colors['line-muted']!,
                width: t.brutal ? 2 : 1,
              ),
            ),
            child: RaftCssText.rich(
              TextSpan(
                text: '${e.key}=',
                children: [
                  TextSpan(
                    text: '•' * (e.value.length < 8 ? e.value.length : 8),
                    style: TextStyle(color: t.colors['foreground-muted']),
                  ),
                ],
              ),
              style: style,
            ),
          ),
      ],
    );
  }
}

/// KeyValueRow.tsx (Web v1.21.12): label (`mb-1 text-[13px]
/// text-foreground-hint`) above a `text-sm text-foreground-muted` value. The
/// value is a string ([value]) or any node ([child], which inherits the value
/// style the way Web's value cell does; nodes keep their own explicit
/// classes).
class RaftKeyValueRow extends StatelessWidget {
  const RaftKeyValueRow({
    super.key,
    required this.label,
    required String this.value,
    this.mono = false,
    this.breakAll = false,
  }) : child = null;
  const RaftKeyValueRow.child({
    super.key,
    required this.label,
    required Widget this.child,
    this.mono = false,
  }) : value = null,
       breakAll = false;
  final String label;
  final String? value;
  final Widget? child;
  final bool mono, breakAll;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = mono
        ? RaftPanelText.profileMono(t)
        : RaftPanelText.profileValue(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftCssText(label, style: RaftPanelText.profileLabel(t)),
        const SizedBox(height: 4),
        if (child case final node?)
          DefaultTextStyle.merge(style: style, child: node)
        else
          RaftCssText(
            breakAll ? value!.characters.join('\u200b') : value!,
            style: style,
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ activity

/// Text with inline references linkified (`RefText.tsx`): [style] is the base
/// of the surrounding text, the result its spans.
typedef RaftActivityLinkify = List<InlineSpan> Function(
  BuildContext context,
  String text,
  TextStyle style,
);

class RaftActivityLogEntry {
  const RaftActivityLogEntry({
    required this.time,
    required this.dot,
    required this.title,
    this.badge,
    this.inlineDetail,
    this.inlineMono = false,
    this.detail,
    this.compact = false,
    this.expandable = false,
    this.linkify,
    this.detailExtra = 0,
  });
  final String time, title;
  final Color dot;

  /// The inline Subagent badge after the title (`SubagentBadge`).
  final String? badge;

  /// Same-line secondary text (`ml-1.5`): status detail or tool input.
  final String? inlineDetail;
  final bool inlineMono;

  /// Second-line mono text (`text-xs font-mono mt-0.5 whitespace-pre-wrap`).
  final String? detail;

  /// Status rows use `py-1`, the rest `py-1.5`.
  final bool compact;

  /// A long entry (> 200 characters): the title is a button with a chevron that
  /// expands the two-line clamp.
  final bool expandable;

  /// Reference pills in [inlineDetail] / [detail] (status, system and action
  /// rows only).
  final RaftActivityLinkify? linkify;

  /// Height the detail's reference pills add (a 16.41px chip in a 16px mono
  /// line grows that line by 0.41; [RaftCssText] keeps whole 16px lines).
  final double detailExtra;
}

/// AgentDetailPanel Activity tab: diagnostics header (`border-b-2 px-5 py-2`
/// + copy action) and AgentActivityLog rows (`flex items-start gap-2 px-3`).
/// No rows show the Web EmptyState (the log has no loading or error state).
class RaftActivityLogView extends StatefulWidget {
  const RaftActivityLogView({super.key, required this.entries, this.onCopy});
  final List<RaftActivityLogEntry> entries;
  final VoidCallback? onCopy;
  @override
  State<RaftActivityLogView> createState() => _RaftActivityLogViewState();
}

class _RaftActivityLogViewState extends State<RaftActivityLogView> {
  final scroll = ScrollController();

  List<RaftActivityLogEntry> get entries => widget.entries;
  VoidCallback? get onCopy => widget.onCopy;

  /// Web `bottomRef.scrollIntoView()` on mount and whenever `log.length`
  /// changes: the log always ends at its newest row. Rows build lazily, so the
  /// extent can still grow after the first jump: jump again once it settles.
  void _toBottom({int again = 2}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final end = scroll.position.maxScrollExtent;
      if (scroll.offset != end) scroll.jumpTo(end);
      if (again > 0) _toBottom(again: again - 1);
    });
  }

  @override
  void initState() {
    super.initState();
    _toBottom();
  }

  @override
  void didUpdateWidget(RaftActivityLogView old) {
    super.didUpdateWidget(old);
    if (old.entries.length != widget.entries.length) _toBottom();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-panel']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            // `px-5 py-2`; the elegant ghost copy action sits in an inline
            // `<span>` whose line box is 1px taller than the 24px button.
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              // ignore: raft_lints/off_grid_spacing -- measured 1px taller header split over both sides
              vertical: t.brutal ? 8 : 8.5,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: t.brutal ? Colors.black : t.colors['line-muted']!,
                  width: t.brutal ? 2 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RaftSectionEyebrow(
                    raftText(context, 'Activity Diagnostics'),
                  ),
                ),
                // `CopyableCodeAction` of a `CopyableCodeRoot size="sm"`: the
                // outline icon button on Brutal, a ghost 24px one on Elegant.
                if (t.brutal)
                  RaftPanelIconButton(
                    glyph: RaftGlyph.copy,
                    tooltip: raftText(context, 'Copy diagnostic info'),
                    onPressed: onCopy,
                  )
                else
                  RaftRecipeButton(
                    variant: RaftButtonRecipeVariant.ghost,
                    size: RaftButtonRecipeSize.iconXs,
                    glyph: RaftGlyph.copy,
                    glyphSize: 12,
                    tooltip: raftText(context, 'Copy diagnostic info'),
                    foreground: t.colors['foreground-muted'],
                    onPressed: onCopy,
                  ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? RaftProductEmptyState(
                    title: raftText(context, 'No activity yet'),
                    description: raftText(
                      context,
                      'Start the agent to see its activity log.',
                    ),
                    icon: (context, size, color) =>
                        RaftIcon(RaftGlyph.activity, size: size, color: color),
                  )
                : ListView(
                    controller: scroll,
                    padding: raftScrollPadding(
                      context,
                      const EdgeInsets.symmetric(vertical: 8),
                    ),
                    children: [for (final e in entries) _RaftActivityRow(e)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RaftActivityRow extends StatefulWidget {
  const _RaftActivityRow(this.entry);
  final RaftActivityLogEntry entry;
  @override
  State<_RaftActivityRow> createState() => _RaftActivityRowState();
}

class _RaftActivityRowState extends State<_RaftActivityRow> {
  bool expanded = false;

  /// The outline badge's box height (recipe height, else line + padding + border).
  double _badgeHeight(RaftTokens t) {
    final s = RaftBadgeRecipe.resolve(
      theme: raftRecipeTheme(t),
      appearance: RaftBadgeRecipeAppearance.outline,
      variant: RaftBadgeRecipeVariant.default_,
      uppercase: true,
      tokens: RaftRecipeTokens(t),
    ).root;
    return s.height ??
        (s.lineHeight ?? 1) * (s.fontSize ?? 10) + s.padding.vertical + 2;
  }

  List<InlineSpan> _text(
    BuildContext context,
    String text,
    TextStyle style, {
    required bool refs,
  }) {
    final link = widget.entry.linkify;
    if (!refs || link == null) return [TextSpan(text: text, style: style)];
    return [
      for (final span in link(context, text, style))
        if (span is TextSpan && span.style == null)
          TextSpan(text: span.text, style: style, children: span.children)
        else
          span,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final e = widget.entry;
    final strong = t.brutal ? Colors.black : t.strong;
    final primary = raftCssText.merge(
      RaftTypography.heading(
        t,
        size: 14,
        line: 20,
        weight: FontWeight.w500,
        color: strong,
      ),
    );
    final monoMuted = RaftPanelText.monoCaption(t);
    final inline = e.inlineDetail;
    final hasInline = inline != null && inline.isNotEmpty;
    final detailStyle = e.inlineMono
        // The zero-width break points split the run, and each glyph then
        // advances by a whole pixel (7.0 instead of the font's 7.2 at 12px):
        // `letterSpacing` (paid twice, by the glyph and its break point)
        // restores the fractional advance so lines wrap where Blink's do.
        ? monoMuted.copyWith(height: 20 / 12, letterSpacing: 0.05)
        : primary.copyWith(
            fontWeight: FontWeight.w400,
            color: raftPanelInk(t, .6, t.colors['foreground-muted']!),
          );
    final badgeH = e.badge == null ? 0.0 : _badgeHeight(t);
    // The badge centre sits 11.55 (Brutal) / 11.17 (Elegant) below the line top.
    final badgeTop = math.max(0.0, (t.brutal ? 11.55 : 11.17) - badgeH / 2);
    // CSS grows the line box when the middle-aligned badge ends below it;
    // [RaftCssText] keeps whole 20px lines, so the row takes the difference.
    final badgeGrowth = e.badge == null
        ? 0.0
        : math.max(0.0, badgeTop + badgeH - 20);
    final title = e.expandable
        ? RaftHoverRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => expanded = !expanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: RaftCssText(e.title, style: primary)),
                  const SizedBox(width: 4),
                  Transform.rotate(
                    angle: expanded ? 1.5708 : 0,
                    child: RaftIcon(
                      RaftGlyph.chevronRight,
                      size: 12,
                      color: strong,
                    ),
                  ),
                ],
              ),
            ),
          )
        : RaftCssText.rich(
            TextSpan(
              children: [
                TextSpan(text: e.title, style: primary),
                if (e.badge != null) ...[
                  const WidgetSpan(child: SizedBox(width: 6)),
                  WidgetSpan(
                    // `align-middle`: the badge's centre sits at the baseline
                    // plus half the x-height, so its box starts `11.55 - h/2`
                    // below the line top (the row grows by [badgeGrowth]).
                    alignment: PlaceholderAlignment.top,
                    child: SizedBox(
                      height: 20,
                      child: Align(
                        alignment: Alignment.topLeft,
                        widthFactor: 1,
                        child: Transform.translate(
                          // A top-aligned placeholder starts 2px below the
                          // CSS line top in this paragraph (measured).
                          offset: Offset(0, badgeTop - 2),
                          // Blink snaps the badge's edges to whole pixels.
                          child: RaftCssPixelSnap(
                            child: SizedBox(
                              height: badgeH,
                              child: RaftRecipeBadge(
                                e.badge!,
                                appearance: RaftBadgeRecipeAppearance.outline,
                                variant: RaftBadgeRecipeVariant.default_,
                                uppercase: true,
                                mono: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (hasInline) ...[
                  const WidgetSpan(child: SizedBox(width: 6)),
                  if (e.inlineMono)
                    TextSpan(
                      // `break-all` mono input.
                      text: inline.characters.join('​'),
                      style: detailStyle,
                    )
                  else
                    ..._text(context, inline, detailStyle, refs: true),
                ],
              ],
            ),
            style: primary,
          );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: e.compact ? 4 : 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RaftCssText(
              e.time,
              style: raftCssText.merge(
                RaftTypography.mono(
                  t,
                  color: raftPanelInk(
                    t,
                    .4,
                    t.colors['foreground-placeholder']!,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: RaftActivityDot(color: e.dot, small: true),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badgeGrowth > 0)
                  Padding(
                    padding: EdgeInsets.only(bottom: badgeGrowth),
                    child: title,
                  )
                else
                  title,
                // The `<p mt-0.5>` stays (2px) even when its text is empty.
                if (e.detail != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2, bottom: e.detailExtra),
                    child: e.detail!.isEmpty
                        ? const SizedBox.shrink()
                        : RaftCssText.rich(
                            TextSpan(
                              children: _text(
                                context,
                                e.detail!,
                                monoMuted,
                                refs: true,
                              ),
                            ),
                            style: monoMuted,
                            maxLines: e.expandable && !expanded ? 2 : null,
                            overflow: e.expandable && !expanded
                                ? TextOverflow.ellipsis
                                : null,
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- skills

class RaftSkillItem {
  const RaftSkillItem({
    required this.name,
    required this.displayName,
    this.description = '',
    this.sourcePath = '',
    this.userInvocable = false,
  });
  final String name, displayName, description, sourcePath;
  final bool userInvocable;
}

/// Web `AgentSkills embedded`: `SectionHeader` + count, then Global and
/// Workspace sub-sections grouped by source path of `SurfaceListItem` cards.
/// Loading / error(+Retry) replace the section body like Web.
///
/// Owner decision (2026-10-18): the list is collapsed by default and opens on
/// a tap of its header. Agents carry many skills, and expanded they pushed the
/// profile's Actions and every section after them off the first screens.
class RaftSkillsSection extends StatefulWidget {
  const RaftSkillsSection({
    super.key,
    required this.global,
    required this.workspace,
    this.loading = false,
    this.error,
    this.onRetry,
    this.initiallyExpanded = false,
    this.expanded,
    this.onExpandedChanged,
  });
  final List<RaftSkillItem> global, workspace;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  /// Opens the list on its first frame (a caller that remembers the choice).
  final bool initiallyExpanded;

  /// Controlled disclosure; when null the section keeps its own state.
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<RaftSkillsSection> createState() => _RaftSkillsSectionState();
}

class _RaftSkillsSectionState extends State<RaftSkillsSection> {
  late bool open = widget.expanded ?? widget.initiallyExpanded;

  void hold(bool value) {
    if (widget.expanded == null) setState(() => open = value);
    widget.onExpandedChanged?.call(value);
  }

  Widget _group(
    BuildContext context,
    RaftTokens t,
    String label,
    RaftGlyph glyph,
    List<RaftSkillItem> skills,
    String empty,
  ) {
    final groups = <String, List<RaftSkillItem>>{};
    for (final s in skills) {
      (groups[s.sourcePath.isEmpty ? 'unknown' : s.sourcePath] ??= []).add(s);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSectionHeader(
          label: raftText(context, label),
          icon: RaftIcon(glyph, size: 12),
          count: skills.length,
        ),
        const SizedBox(height: 8),
        if (skills.isEmpty)
          RaftCssText(raftText(context, empty), style: RaftPanelText.muted(t))
        else
          RaftGapColumn(
            gap: 16,
            children: [
              for (final g in groups.entries)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RaftCssText(
                      '${g.key} (${g.value.length})',
                      style: RaftPanelText.mono(t),
                    ),
                    const SizedBox(height: 8),
                    RaftGapColumn(
                      children: [for (final s in g.value) _card(t, s)],
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _card(RaftTokens t, RaftSkillItem s) => RaftSurfaceListItem(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: RaftCssText(
                s.displayName,
                style: RaftPanelText.value(t)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (s.userInvocable) ...[
              const SizedBox(width: 8),
              RaftRecipeBadge(
                '/${s.name}',
                variant: RaftBadgeRecipeVariant.success,
              ),
            ],
          ],
        ),
        if (s.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          RaftCssText(
            s.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RaftPanelText.muted(t),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final expanded = widget.expanded ?? open;
    if (widget.loading) {
      return RaftPanelSection(
        children: [
          RaftCssText(
            raftText(context, 'Loading skills…'),
            style: RaftPanelText.muted(t),
          ),
        ],
      );
    }
    if (widget.error != null) {
      // AgentSkills.tsx: centred `gap-3` column, mono muted message and an
      // outline `sm` Retry with the RefreshCw icon.
      return RaftLoadError(widget.error!, onRetry: widget.onRetry);
    }
    final total = widget.global.length + widget.workspace.length;
    // Web renders the header alone (with its 0) when nothing is installed;
    // with nothing to disclose the header stays a plain label.
    if (total == 0) {
      return RaftPanelSection(
        children: [
          RaftSectionHeader(label: raftText(context, 'Skills'), count: total),
        ],
      );
    }
    return RaftPanelSection(
      gap: 16,
      children: [
        RaftCollapsibleSectionHeader(
          label: raftText(context, 'Skills'),
          count: total,
          expanded: expanded,
          onExpandedChanged: hold,
          disclosureKey: const ValueKey('agent-skills-disclosure'),
          gap: 16,
          children: [
            _group(
              context,
              t,
              'Global',
              RaftGlyph.globe,
              widget.global,
              'No global skills installed on this computer',
            ),
            _group(
              context,
              t,
              'Workspace',
              RaftGlyph.folderOpen,
              widget.workspace,
              "No skills in this agent's workspace",
            ),
          ],
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- reminders

class RaftReminderItem {
  const RaftReminderItem({
    required this.title,
    required this.relative,
    required this.dateTime,
    this.recurrence,
  });
  final String title, relative, dateTime;
  final String? recurrence;
}

/// AgentRemindersSection variant="tab": `px-5 py-5`, `space-y-3` of
/// SurfaceListItem cards (title `text-sm font-bold`; meta row `mt-1 flex
/// flex-wrap items-center gap-2 text-xs`).
class RaftReminderListView extends StatelessWidget {
  const RaftReminderListView({
    super.key,
    required this.reminders,
    this.loading = false,
    this.error,
    this.onRetry,
  });
  final List<RaftReminderItem> reminders;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = raftPanelInk(t, .5, t.colors['foreground-muted']!);
    final bold = raftCssText.merge(
      RaftTypography.heading(
        t,
        size: 12,
        line: 16,
        weight: FontWeight.w700,
        color: muted,
      ),
    );
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-panel']!,
      child: ListView(
        padding: raftScrollPadding(context, const EdgeInsets.all(20)),
        children: [
          // Only an empty list waits on a first read; a refresh of rows already
          // shown never inserts a line above them.
          if (loading && reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RaftCssText(raftText(context, 'Loading…'), style: bold),
            ),
          if (error != null)
            // AgentRemindersSection: `<Banner intent="warning" density="sm"
            // className="font-bold">` with the outline Retry below.
            RaftErrorBanner(
              error!,
              small: true,
              bold: true,
              onRetry: onRetry,
              retryLabel: 'Retry',
            )
          else if (reminders.isEmpty && !loading)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  RaftIcon(RaftGlyph.bellRing, size: 28, color: muted),
                  const SizedBox(height: 12),
                  RaftCssText(
                    raftText(context, 'No reminders'),
                    style: RaftPanelText.value(t)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < reminders.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _card(t, reminders[i]),
            ],
        ],
      ),
    );
  }

  Widget _card(RaftTokens t, RaftReminderItem r) {
    final meta60 = raftPanelInk(t, .6, t.colors['foreground-muted']!);
    return RaftSurfaceListItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftCssText(
            r.title,
            style: RaftPanelText.value(t).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftIcon(RaftGlyph.clock3, size: 12, color: meta60),
                  const SizedBox(width: 4),
                  RaftCssText(
                    r.relative,
                    style: raftCssText.merge(
                      RaftTypography.heading(
                        t,
                        size: 12,
                        line: 16,
                        weight: FontWeight.w500,
                        color: meta60,
                      ),
                    ),
                  ),
                ],
              ),
              RaftCssText(r.dateTime, style: RaftPanelText.monoCaption(t)),
              if (r.recurrence != null && r.recurrence!.isNotEmpty)
                // `border border-line-muted theme-brutal:border-black
                // bg-accent-soft theme-brutal:bg-brutal-lavender/30 px-1.5
                // py-0.5 font-mono text-[11px]`.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.brutal
                        ? t.product.brutalLavender.withValues(alpha: .3)
                        : t.colors['accent-soft'],
                    border: Border.all(
                      color: t.brutal ? Colors.black : t.colors['line-muted']!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RaftIcon(RaftGlyph.repeat, size: 11, color: t.strong),
                      const SizedBox(width: 4),
                      RaftCssText(
                        r.recurrence!,
                        style: RaftTypography.mono(
                          t,
                          size: 11,
                          line: 16,
                          color: t.strong,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- workspace

class RaftWorkspaceNode {
  const RaftWorkspaceNode({
    required this.name,
    required this.depth,
    required this.directory,
    this.open = false,
    this.bold = false,
    this.hidden = false,
    this.selected = false,
    this.onTap,
  }) : loading = false,
       hint = false;

  /// A folder's listing in flight (`Spinner xs` + "Loading..."), at the depth
  /// of the folder's children.
  const RaftWorkspaceNode.loading({required this.depth})
    : name = '',
      directory = false,
      open = false,
      bold = false,
      hidden = false,
      selected = false,
      loading = true,
      hint = false,
      onTap = null;

  /// The server cut a listing short (`TruncationHint`): [name] is the text,
  /// [depth] the children's depth (the root hint uses `indent` 8).
  const RaftWorkspaceNode.hint(this.name, {required this.depth})
    : directory = false,
      open = false,
      bold = false,
      hidden = false,
      selected = false,
      loading = false,
      hint = true,
      onTap = null;
  final String name;
  final int depth;

  /// `-1` depth is the root hint (`indent={8}`).
  final bool directory, open, bold, hidden, loading, hint;

  /// The open file's row (`bg-accent-soft`, Brutal `bg-brutal-pink/20` with a
  /// pink right rule).
  final bool selected;
  final VoidCallback? onTap;
}

/// AgentWorkspace.tsx: path bar (`border-b px-3 py-1.5`), tree header
/// (`border-b px-3 py-2`, hidden-files toggle `size-7` + refresh) and the
/// expandable tree (`py-1 pr-2 text-sm`, padding-left depth*16+8 / +22).
class RaftWorkspaceTreeView extends StatelessWidget {
  const RaftWorkspaceTreeView({
    super.key,
    required this.path,
    required this.nodes,
    this.loading = false,
    this.error,
    this.showHidden = false,
    this.onCopyPath,
    this.onToggleHidden,
    this.onRefresh,
    this.preview,
  });

  /// Right pane of the `md:` split layout (an open file); when the panel is
  /// wide and this is null the pane shows "Select a file to view".
  final Widget? preview;
  final String path;
  final List<RaftWorkspaceNode> nodes;
  final bool loading, showHidden;
  final String? error;
  final VoidCallback? onCopyPath, onToggleHidden, onRefresh;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hairline = BorderSide(
      color: raftPanelInk(t, .1, t.colors['line-muted']!),
    );
    final placeholder = raftPanelInk(
      t,
      .4,
      t.colors['foreground-placeholder']!,
    );
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final pathBar = Container(
      height: 37,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border(bottom: hairline)),
      child: Row(
        children: [
          Flexible(
            child: RaftCssText(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RaftPanelText.monoCaption(t),
            ),
          ),
          const SizedBox(width: 8),
          RaftInlineIconButton(
            glyph: RaftGlyph.copy,
            tooltip: raftText(context, 'Copy path'),
            onPressed: onCopyPath,
          ),
        ],
      ),
    );
    final treeHeader = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: hairline)),
      child: Row(
        children: [
          Expanded(child: RaftSectionEyebrow(raftText(context, 'Workspace'))),
          SizedBox.square(
            dimension: 28,
            child: Center(
              child: RaftInlineIconButton(
                glyph: showHidden ? RaftGlyph.eye : RaftGlyph.eyeOff,
                size: 13,
                tooltip: raftText(context, 'Hidden files'),
                onPressed: onToggleHidden,
              ),
            ),
          ),
          const SizedBox(width: 4),
          RaftInlineIconButton(
            glyph: RaftGlyph.refreshCw,
            tooltip: raftText(context, 'Refresh'),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
    // `px-3 py-4 text-center text-sm font-mono` placeholder lines (loading, no
    // files); the tree container is `py-1`.
    Widget message(String text) => SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: RaftCssText(
          raftText(context, text),
          textAlign: TextAlign.center,
          style: RaftTypography.mono(t, size: 14, line: 20, color: placeholder),
        ),
      ),
    );
    final treeList = Expanded(
      child: ListView(
        padding: raftScrollPadding(
          context,
          const EdgeInsets.symmetric(vertical: 4),
        ),
        children: loading && nodes.isEmpty
            ? [message('Loading...')]
            : error != null
            // AgentWorkspace.tsx: `px-3 py-4 text-center` AlertTriangle
            // (warning-strong / brutal-orange), the mono muted message
            // and an outline Retry.
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      RaftIcon(
                        RaftGlyph.triangleAlert,
                        size: 20,
                        color: t.brutal
                            ? t.product.brutalOrange
                            : t.colors['warning-strong'] ?? t.strong,
                      ),
                      const SizedBox(height: 6),
                      RaftCssText(
                        raftText(context, error!),
                        textAlign: TextAlign.center,
                        style: RaftTypography.mono(
                          t,
                          size: 14,
                          line: 20,
                          color: t.brutal
                              ? t.colors['foreground-muted']
                              : t.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RaftRecipeButton(
                        label: raftText(context, 'Retry'),
                        variant: RaftButtonRecipeVariant.outline,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: onRefresh,
                      ),
                    ],
                  ),
                ),
              ]
            : nodes.isEmpty
            ? [message('No files yet')]
            : [for (final n in nodes) _node(context, t, n)],
      ),
    );
    final panel = t.brutal ? Colors.white : t.colors['layer-panel']!;
    if (!wide && preview != null) {
      // The phone shows the open file alone under the path bar (the tree pane
      // is `hidden`); the container is `bg-layer-canvas-muted`.
      return ColoredBox(
        color: t.brutal ? t.colors['color-brutal-cream']! : t.sidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(color: panel, child: pathBar),
            Expanded(child: preview!),
          ],
        ),
      );
    }
    if (!wide) {
      return ColoredBox(
        color: panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pathBar,
            Expanded(
              child: DecoratedBox(
                // The tree pane keeps its `border-r` when it is not `compact`.
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border(
                    right: t.brutal
                        ? const BorderSide(color: Colors.black, width: 2)
                        : BorderSide(color: t.colors['line-muted']!),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [treeHeader, treeList],
                ),
              ),
            ),
          ],
        ),
      );
    }
    // `md:` split: full-width path bar, a 256px tree column (`border-r`) and
    // the file pane on `bg-layer-canvas-muted`.
    return ColoredBox(
      // `bg-layer-canvas-muted` (Brutal paints the cream here).
      color: t.brutal ? t.colors['color-brutal-cream']! : t.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(color: panel, child: pathBar),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 256,
                  decoration: BoxDecoration(
                    color: panel,
                    border: Border(
                      right: t.brutal
                          ? const BorderSide(color: Colors.black, width: 2)
                          : BorderSide(color: t.colors['line-muted']!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [treeHeader, treeList],
                  ),
                ),
                Expanded(
                  child:
                      preview ??
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: .3,
                              child: RaftIcon(
                                RaftGlyph.file,
                                size: 32,
                                color: t.brutal
                                    ? Colors.black.withValues(alpha: .3)
                                    : placeholder,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RaftCssText(
                              raftText(context, 'Select a file to view'),
                              style: RaftTypography.mono(
                                t,
                                size: 14,
                                line: 20,
                                color: t.brutal
                                    ? Colors.black.withValues(alpha: .3)
                                    : placeholder,
                              ),
                            ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _node(BuildContext context, RaftTokens t, RaftWorkspaceNode n) {
    final dim = raftPanelInk(t, .4, t.colors['foreground-placeholder']!);
    if (n.loading || n.hint) {
      // `py-1 text-xs font-mono` placeholder rows at `padding-left` depth*16+22
      // (the root hint: 8).
      final style = RaftTypography.mono(t, size: 12, line: 16, color: dim);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          n.hint && n.depth < 0 ? 8 : n.depth * 16 + 22,
          4,
          n.hint ? 8 : 0,
          4,
        ),
        child: n.loading
            ? Row(
                children: [
                  IconTheme(
                    data: IconThemeData(color: dim),
                    child: RaftSpinner(
                      size:
                          RaftSpinnerRecipe.resolve(
                            theme: raftRecipeTheme(t),
                            size: RaftSpinnerRecipeSize.xs,
                            tokens: RaftRecipeTokens(t),
                          ).root.width ??
                          12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  RaftCssText(raftText(context, 'Loading...'), style: style),
                ],
              )
            : RaftCssText(n.name, style: style),
      );
    }
    final text = raftCssText.merge(
      RaftTypography.heading(
        t,
        size: 14,
        line: 20,
        weight: n.directory
            ? FontWeight.w500
            : n.bold
            ? FontWeight.w700
            : FontWeight.w400,
        // `text-foreground-muted theme-brutal:text-black/55` for `isHidden`.
        color: n.hidden
            ? (t.brutal
                  ? Colors.black.withValues(alpha: .55)
                  : t.colors['foreground-muted'])
            : null,
      ),
    );
    final folder = t.brutal
        ? t.product.brutalOrange
        : t.colors['warning-strong'] ?? t.strong;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: n.onTap,
      child: Container(
        decoration: n.selected
            ? BoxDecoration(
                color: t.brutal
                    ? t.product.brutalPink.withValues(alpha: .2)
                    : t.colors['accent-soft'],
                border: Border(
                  right: BorderSide(
                    color: t.brutal
                        ? t.product.brutalPink
                        : t.colors['line-strong']!,
                    width: t.brutal ? 2 : 1,
                  ),
                ),
              )
            : null,
        padding: EdgeInsets.fromLTRB(
          n.depth * 16 + (n.directory ? 8 : 22),
          4,
          8,
          4,
        ),
        child: Row(
          children: [
            if (n.directory) ...[
              Transform.rotate(
                angle: n.open ? 1.5708 : 0,
                child: RaftIcon(
                  RaftGlyph.chevronRight,
                  size: 14,
                  color: t.strong,
                ),
              ),
              const SizedBox(width: 4),
              RaftIcon(
                n.open ? RaftGlyph.folderOpen : RaftGlyph.folderClosed,
                size: 14,
                color: folder,
              ),
            ] else
              RaftIcon(
                RaftGlyph.fileText,
                size: 14,
                color: raftPanelInk(t, .5, t.colors['foreground-muted']!),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: RaftCssText(
                n.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain file preview with a back row (AgentWorkspace right pane, compact).
class RaftWorkspaceFilePreview extends StatelessWidget {
  const RaftWorkspaceFilePreview({
    super.key,
    required this.path,
    required this.content,
    this.onBack,
    this.embedded = false,
    this.error,
    this.loading = false,
  });
  final String path, content;
  final VoidCallback? onBack;

  /// The read is in flight: the pane shows the centred "Loading..." line
  /// (AgentWorkspace.tsx `loadingFile`), not an empty file.
  final bool loading;

  /// AgentWorkspace.tsx `fileError || fileLoadFailed`: the read failed, so the
  /// pane shows the centred mono placeholder text instead of the content.
  final String? error;

  /// Kept for call sites: the desktop right pane and the phone page share one
  /// layout (the back arrow shows when [onBack] is set).
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (loading) return Center(child: _loadingText(context, t));
    if (error != null) return Center(child: _errorText(context, t));
    // AgentWorkspace.tsx right pane (the phone shows it alone with a back
    // arrow; `md:hidden` / `compact`): header `gap-2 border-b bg-layer-panel
    // px-4 py-2`, `p-4` content.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: t.brutal ? Colors.white : t.colors['layer-panel'],
            border: Border(
              bottom: BorderSide(
                color: raftPanelInk(t, .1, t.colors['line-muted']!),
              ),
            ),
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                RaftInlineIconButton(
                  glyph: RaftGlyph.arrowLeft,
                  size: 16,
                  tooltip: raftText(context, 'Back'),
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: RaftCssText(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.mono(
                    t,
                    size: 14,
                    line: 20,
                    color: t.brutal ? Colors.black : t.strong,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              content,
              style: RaftTypography.mono(
                t,
                size: 14,
                line: 20,
                color: t.brutal ? Colors.black : t.strong,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadingText(BuildContext context, RaftTokens t) => RaftCssText(
    raftText(context, 'Loading...'),
    style: RaftTypography.mono(
      t,
      size: 14,
      line: 20,
      color: raftPanelInk(t, .4, t.colors['foreground-placeholder']!),
    ),
  );

  Widget _errorText(BuildContext context, RaftTokens t) => Padding(
    padding: const EdgeInsets.all(16),
    child: Semantics(
      liveRegion: true,
      child: RaftCssText(
        raftText(context, error!),
        textAlign: TextAlign.center,
        style: RaftTypography.mono(
          t,
          size: 14,
          line: 20,
          color: t.brutal
              ? Colors.black.withValues(alpha: .4)
              : t.colors['foreground-placeholder'],
        ),
      ),
    ),
  );
}

/// A scrolling column of panel groups separated by [gap]
/// (AgentAppAccessTab `px-5 py-4 space-y-6`).
class RaftPanelGroups extends StatelessWidget {
  const RaftPanelGroups({
    super.key,
    required this.groups,
    this.gap = 24,
    this.innerGap = 12,
  });
  final List<List<Widget>> groups;
  final double gap, innerGap;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-panel']!,
      child: ListView(
        padding: raftScrollPadding(
          context,
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        children: [
          for (var g = 0; g < groups.length; g++) ...[
            if (g > 0) SizedBox(height: gap),
            for (var i = 0; i < groups[g].length; i++) ...[
              if (i > 0) SizedBox(height: innerGap),
              groups[g][i],
            ],
          ],
        ],
      ),
    );
  }
}

/// SectionHeader with the `mt-1 text-xs text-foreground-muted` description
/// line under it (AgentAppAccessTab sections).
class RaftDescribedSectionHeader extends StatelessWidget {
  const RaftDescribedSectionHeader({
    super.key,
    required this.label,
    required this.description,
    this.action,
    this.count,
  });
  final String label, description;
  final Widget? action;
  final int? count;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RaftSectionHeader(label: label, action: action, count: count),
      const SizedBox(height: 4),
      RaftCssText(
        description,
        style: RaftPanelText.caption(RaftTokens.of(context)),
      ),
    ],
  );
}

/// An app access / event card (`SurfaceListItem space-y-2`).
class RaftAccessCard extends StatelessWidget {
  const RaftAccessCard({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.chips = const [],
    this.actions = const [],
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<String> chips;
  final List<Widget> actions;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftSurfaceListItem(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RaftCssText(
                      title,
                      style: RaftTypography.heading(t, weight: FontWeight.w700),
                    ),
                    if (subtitle != null)
                      RaftCssText(subtitle!, style: RaftPanelText.caption(t)),
                  ],
                ),
              ),
              ?badge,
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in chips)
                  RaftRecipeBadge(
                    c,
                    appearance: RaftBadgeRecipeAppearance.outline,
                  ),
              ],
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Wrap of small filter/action buttons (`flex flex-wrap gap-1.5`).
class RaftButtonWrap extends StatelessWidget {
  const RaftButtonWrap({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 6, children: children);
}

/// AgentDetailPanel `startError` strip: `border-b bg-warning-soft px-5 py-2`
/// (brutal `border-b-2 border-black bg-brutal-orange/20`) with the message
/// (`text-sm font-bold`, truncated) and a dismiss `X`.
class RaftPanelErrorStrip extends StatelessWidget {
  const RaftPanelErrorStrip(this.message, {super.key, this.onDismiss});
  final String message;
  final VoidCallback? onDismiss;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: t.brutal
              ? t.product.brutalOrange.withValues(alpha: .2)
              : t.colors['warning-soft'],
          border: Border(
            bottom: BorderSide(
              color: t.brutal ? Colors.black : t.colors['line-muted']!,
              width: t.brutal ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: RaftCssText(
                raftText(context, message),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RaftTypography.heading(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w700,
                  color: t.brutal ? Colors.black : t.strong,
                ),
              ),
            ),
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              RaftInlineIconButton(
                glyph: RaftGlyph.x,
                size: 14,
                tooltip: raftText(context, 'Dismiss'),
                onPressed: onDismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Detail-panel error line (`text-xs font-bold`).
class RaftPanelError extends StatelessWidget {
  const RaftPanelError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: RaftCssText(
          message,
          style: RaftPanelText.caption(t).copyWith(
            fontWeight: FontWeight.w700,
            color: t.colors['danger-strong'] ?? t.strong,
          ),
        ),
      ),
    );
  }
}

/// Generic centred loading / message state of a panel body.
class RaftPanelMessage extends StatelessWidget {
  const RaftPanelMessage(this.message, {super.key, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftCssText(message, style: RaftPanelText.mono(RaftTokens.of(context))),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

/// A column with uniform [gap] (Tailwind `space-y-*`).
class RaftGapColumn extends StatelessWidget {
  const RaftGapColumn({super.key, required this.children, this.gap = 8});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );
}

/// EnvVarsSection (read-only): `mt-3` block, eyebrow `mb-1`, chips.
class RaftEnvVarsBlock extends StatelessWidget {
  const RaftEnvVarsBlock({super.key, required this.vars});
  final Map<String, String> vars;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RaftSectionEyebrow(raftText(context, 'Environment Variables')),
      const SizedBox(height: 4),
      RaftEnvVarChips(vars: vars),
    ],
  );
}

/// Description section: eyebrow (+ pencil) `mb-1`, then the text or the
/// italic placeholder.
class RaftDescriptionBlock extends StatelessWidget {
  const RaftDescriptionBlock({
    super.key,
    required this.text,
    this.onEdit,
    this.editKey,
    this.selectable = true,
  });
  final String text;
  final VoidCallback? onEdit;
  final Key? editKey;
  final bool selectable;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftEditableEyebrow(
          raftText(context, 'Description'),
          onEdit: onEdit,
          editKey: editKey,
          editLabel: raftText(context, 'Edit description'),
        ),
        const SizedBox(height: 4),
        text.isEmpty
            ? RaftCssText(
                raftText(context, 'No description'),
                style: RaftPanelText.profilePlaceholder(t),
              )
            : selectable
            ? RaftSelectionArea(
                child: RaftCssText(text, style: RaftPanelText.profileValue(t)),
              )
            : RaftCssText(text, style: RaftPanelText.profileValue(t)),
      ],
    );
  }
}

/// HumanDetailPanel role field: label row (`mb-1 flex items-center gap-2`)
/// with help / edit icons, then the role Badge inline in a body line.
class RaftRoleField extends StatelessWidget {
  const RaftRoleField({
    super.key,
    required this.label,
    required this.badge,
    this.onEdit,
    this.editKey,
    this.editor,
    this.onHelp,
    this.helpKey,
  });
  final String label;
  final RaftRecipeBadge badge;
  final VoidCallback? onEdit;
  final Key? editKey;

  /// The "Role permissions" help button (RolePermissionHelpDialog).
  final VoidCallback? onHelp;
  final Key? helpKey;

  /// The role editor (InlineBadgeEditor + Save / Cancel) shown in place of the
  /// badge while editing; the pencil is hidden then.
  final Widget? editor;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RaftCssText(label, style: RaftPanelText.profileLabel(t)),
            const SizedBox(width: 8),
            RaftInlineIconButton(
              key: helpKey,
              glyph: RaftGlyph.circleHelp,
              tooltip: raftText(context, 'Role permissions'),
              onPressed: onHelp,
            ),
            if (onEdit != null && editor == null) ...[
              const SizedBox(width: 8),
              RaftInlineIconButton(
                key: editKey,
                glyph: RaftGlyph.pencil,
                tooltip: raftText(context, 'Edit role'),
                onPressed: onEdit,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        editor ?? RaftInlineBadge(badge: badge, bodyLine: true),
      ],
    );
  }
}

/// AgentProfileOverflowMenu: outline icon-sm trigger (EllipsisVertical 14)
/// opening a dropdown aligned to the trigger's end, `sideOffset={4}`.
class RaftOverflowMenuButton extends StatefulWidget {
  const RaftOverflowMenuButton({
    super.key,
    required this.entries,
    required this.tooltip,
  });
  final List<RaftMenuEntry> entries;
  final String tooltip;
  @override
  State<RaftOverflowMenuButton> createState() => _RaftOverflowMenuButtonState();
}

class _RaftOverflowMenuButtonState extends State<RaftOverflowMenuButton> {
  final menu = OverlayPortalController();
  final anchor = LayerLink();
  final popupAnchor = GlobalKey();
  final triggerFocus = FocusNode();
  bool keyboardOpened = false;

  void close() {
    if (!menu.isShowing) return;
    setState(menu.hide);
    triggerFocus.requestFocus();
  }

  void toggle({bool keyboard = false}) {
    if (menu.isShowing) {
      close();
    } else {
      keyboardOpened = keyboard;
      setState(menu.show);
    }
  }

  @override
  void dispose() {
    triggerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: menu,
    overlayChildBuilder: raftBackDismissed(
      close,
      (_) => RaftAnchoredPopup(
        anchorKey: popupAnchor,
        alignRight: true,
        movement: Scrollable.maybeOf(context)?.position,
        child: TapRegion(
          groupId: anchor,
          child: FocusScope(
            autofocus: true,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): close,
              },
              child: Focus(
                autofocus: !keyboardOpened,
                child: RaftMenuPanel(
                  onDismiss: close,
                  children: [
                    for (final (i, e) in widget.entries.indexed)
                      RaftMenuItem(
                        autofocus: keyboardOpened && i == 0,
                        label: e.label ?? '',
                        glyph: e.glyph,
                        leading: e.leading,
                        onPressed: () {
                          close();
                          e.onPressed?.call();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    child: TapRegion(
      groupId: anchor,
      enabled: menu.isShowing,
      consumeOutsideTaps: true,
      onTapOutside: (_) => close(),
      child: RaftHoverRegion(
        onEnter: (_) {
          if (menu.isShowing) setState(() {});
        },
        onExit: (_) {
          if (menu.isShowing) setState(() {});
        },
        child: RaftPanelIconButton(
          anchorLink: anchor,
          anchorKey: popupAnchor,
          focusNode: triggerFocus,
          glyph: RaftGlyph.ellipsisVertical,
          tooltip: widget.tooltip,
          onPressed: () => toggle(),
          onKeyboardActivate: () => toggle(keyboard: true),
        ),
      ),
    ),
  );
}

class _ProfileAvatarAction extends StatefulWidget {
  const _ProfileAvatarAction({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final VoidCallback onPressed;
  final Widget child;
  @override
  State<_ProfileAvatarAction> createState() => _ProfileAvatarActionState();
}

class _ProfileAvatarActionState extends State<_ProfileAvatarAction> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => RaftTooltip(
    message: raftText(context, 'Choose Avatar'),
    child: FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: raftText(context, 'Choose Avatar'),
        child: RaftHoverRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Stack(
              children: [
                widget.child,
                if (hovered)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: .4),
                      child: const Center(
                        child: RaftIcon(
                          RaftGlyph.pencil,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Elegant desktop PanelHeader icon tile: 36px `fill-muted` square, `rounded-md`,
/// 18px `foreground-icon` glyph.
class RaftPanelHeaderMutedTile extends StatelessWidget {
  const RaftPanelHeaderMutedTile({super.key, required this.icon});
  final Widget icon;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.colors['fill-muted'],
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconTheme.merge(
        data: IconThemeData(size: 18, color: t.colors['foreground-icon']),
        child: icon,
      ),
    );
  }
}

/// HumanDetailPanel InlineBadgeEditor + Save / Cancel (`space-y-1.5`, buttons
/// `gap-1.5`) and the error line under them.
class RaftInlineRoleEditor extends StatelessWidget {
  const RaftInlineRoleEditor({
    super.key,
    required this.label,
    required this.selectedId,
    required this.options,
    required this.onSelect,
    required this.open,
    required this.onOpenChanged,
    required this.background,
    required this.foreground,
    required this.saveLabel,
    required this.cancelLabel,
    required this.canSave,
    required this.canCancel,
    required this.onSave,
    required this.onCancel,
    this.error,
    this.saveKey,
  });
  final String label, selectedId, saveLabel, cancelLabel;
  final List<RaftInlineBadgeOption> options;
  final ValueChanged<String> onSelect;
  final bool open, canSave, canCancel;
  final ValueChanged<bool> onOpenChanged;
  final Color background, foreground;
  final VoidCallback onSave, onCancel;
  final String? error;
  final Key? saveKey;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The editor badge sits in an `inline-block` line box (1px lower).
        // ds-allow: Web HumanDetailPanel.tsx InlineBadgeEditor inline-block line-box offset (browser baseline, no class)
        const SizedBox(height: 1),
        RaftInlineBadgeEditor(
          label: label,
          selectedId: selectedId,
          options: options,
          onSelect: onSelect,
          open: open,
          onOpenChanged: onOpenChanged,
          background: background,
          foreground: foreground,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            RaftRecipeTextButton(
              key: saveKey,
              label: saveLabel,
              variant: RaftButtonRecipeVariant.accent,
              horizontalPadding: 8,
              onPressed: canSave ? onSave : null,
            ),
            const SizedBox(width: 6),
            RaftRecipeTextButton(
              label: cancelLabel,
              horizontalPadding: 8,
              onPressed: canCancel ? onCancel : null,
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              raftText(context, error!),
              style: RaftPanelText.caption(t).copyWith(
                color: t.product.brutalOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
