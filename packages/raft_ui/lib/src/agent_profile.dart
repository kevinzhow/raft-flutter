// Visual building blocks of the Web member/agent detail panels
// (packages/web/src/components/agent/AgentDetailPanel.tsx, AgentActivityLog,
// AgentRemindersSection, AgentWorkspace, AgentAppAccessTab and
// components/member/HumanDetailPanel.tsx). Data loading stays in the app; the
// widgets here take plain view data and callbacks. Values cite the Tailwind
// classes / raft-ui recipes they come from.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'avatar_content.dart';
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart';
import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'recipes/avatar.g.dart';
import 'recipes/badge.g.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/recipe_utilities.g.dart';
import 'recipes/token_binding.dart';
import 'list_items.dart';
import 'recipe_surface.dart' show raftCssText;
import 'theme.dart';
import 'tooltip.dart';

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

/// Panel body text: `body { font-family: var(--font-sans); color:
/// var(--foreground) }` at 16/24.
class RaftPanelTextScope extends StatelessWidget {
  const RaftPanelTextScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DefaultTextStyle(
      style: raftCssText.merge(RaftTypography.body(t, color: t.ink)),
      child: ColoredBox(color: t.colors['layer-panel']!, child: child),
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
  });
  final String label;
  final RaftBadgeRecipeAppearance appearance;
  final RaftBadgeRecipeVariant? variant;
  final bool uppercase;
  final Color? background;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftBadgeRecipe.resolve(
      theme: raftRecipeTheme(t),
      appearance: appearance,
      variant: variant,
      uppercase: uppercase,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).root;
    final decoration = s.decoration(rt);
    return Container(
      height: s.height,
      padding: s.padding,
      decoration: background == null
          ? decoration
          : decoration.copyWith(color: background),
      child: Center(
        widthFactor: 1,
        child: RaftCssText(
          uppercase ? label.toUpperCase() : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: raftCssText.merge(
            RaftTypography.body(t, size: 10, line: 10).merge(s.textStyle(rt)),
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
  final RaftRecipeBadge badge;
  final bool bodyLine;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = RaftBadgeRecipe.resolve(theme: raftRecipeTheme(t)).root;
    return RaftCssInlineBox(
      lineText: bodyLine
          ? raftCssText.merge(RaftTypography.body(t))
          : RaftInfoRow.valueStyle(t),
      childText: RaftTypography.body(
        t,
        size: s.fontSize ?? 10,
        line: (s.lineHeight ?? 1) * (s.fontSize ?? 10),
        weight: FontWeight.w700,
      ),
      height: s.height ?? 20,
      child: Align(alignment: Alignment.centerLeft, child: badge),
    );
  }
}

/// Web AvatarSlot contexts (components/ui/AvatarSlot.tsx RAFT_AVATAR_SPEC).
enum RaftAvatarSlotContext {
  profileTile(64, 2),
  panelHeader(36, 2),
  surfaceList(32, 2),
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
  });
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
    return Container(
      width: sizeOverride ?? slot.size,
      height: sizeOverride ?? slot.size,
      clipBehavior: Clip.antiAlias,
      decoration: s.root
          .decoration(rt)
          .copyWith(
            border: Border.all(
              color: s.root.borderColor?.resolve(rt) ?? Colors.black,
              width: slot.border,
            ),
          ),
      child:
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
          ),
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
      child: MouseRegion(
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
              child: Container(
                height: s.height,
                padding: EdgeInsets.symmetric(
                  horizontal: pad ?? s.padding.left,
                ),
                decoration: s.decoration(rt),
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
  });
  final String label;
  final VoidCallback? onEdit;
  final String? editLabel;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      RaftSectionEyebrow(label),
      if (onEdit != null) ...[
        const SizedBox(width: 8),
        RaftInlineIconButton(
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
  static TextStyle value(RaftTokens t) => RaftInfoRow.valueStyle(t);
  static TextStyle placeholder(RaftTokens t) => value(t).copyWith(
    fontStyle: FontStyle.italic,
    color: raftPanelInk(t, .4, t.colors['foreground-muted']!),
  );
  static TextStyle muted(RaftTokens t) =>
      value(t)
          .copyWith(color: raftPanelInk(t, .5, t.colors['foreground-muted']!));
  static TextStyle mono(RaftTokens t) =>
      value(t).copyWith(fontFamily: t.monoFont);
  static TextStyle monoSemibold(RaftTokens t) =>
      mono(t).copyWith(fontWeight: FontWeight.w600);
  static TextStyle label(RaftTokens t) => raftCssText.merge(
    RaftTypography.body(
      t,
      size: 12,
      line: 16,
      color: raftPanelInk(t, .5, t.colors['foreground-muted']!),
    ),
  );
  static TextStyle caption(RaftTokens t) => raftCssText.merge(
    RaftTypography.body(
      t,
      size: 12,
      line: 16,
      color: t.colors['foreground-muted'],
    ),
  );
  static TextStyle monoCaption(RaftTokens t) => raftCssText.merge(
    RaftTypography.mono(
      t,
      color: raftPanelInk(t, .5, t.colors['foreground-muted']!),
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
  });
  final String name, handle;
  final String? avatarUrl;
  final bool agent, avatarButton;
  final VoidCallback? onEditName, onAvatar;
  final Color? statusColor;
  final String? statusText;
  final double minHeight;
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
        decoration: BoxDecoration(boxShadow: button.boxShadow.toBoxShadows(rt)),
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
                  // `text-lg leading-tight` is a 22.5px line box; Flutter
                  // rounds a paragraph's height to whole pixels, so the
                  // line box is sized explicitly.
                  Row(
                    children: [
                      Flexible(
                        child: RaftCssText(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: raftCssText.merge(
                            RaftTypography.body(
                              t,
                              size: 18,
                              line: 22.5,
                              weight: FontWeight.w700,
                              color: t.colors['foreground-strong']!,
                            ),
                          ),
                        ),
                      ),
                      if (onEditName != null) ...[
                        const SizedBox(width: 8),
                        RaftInlineIconButton(
                          glyph: RaftGlyph.pencil,
                          size: 14,
                          tooltip: raftText(context, 'Edit display name'),
                          onPressed: onEditName,
                        ),
                      ],
                    ],
                  ),
                  RaftCssText(
                    '@$handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText.merge(
                      RaftTypography.mono(
                        t,
                        size: 14,
                        line: 20,
                        color: agent
                            ? t.colors['foreground-muted']
                            : raftPanelInk(
                                t,
                                .5,
                                t.colors['foreground-muted']!,
                              ),
                      ),
                    ),
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
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RaftCssText(
            '@$handle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RaftPanelText.monoCaption(t),
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
        RaftCssText(raftText(context, online ? 'Connected' : 'Offline')),
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

/// KeyValueRow.tsx: label (`mb-1 text-xs`) above a `text-sm` value.
class RaftKeyValueRow extends StatelessWidget {
  const RaftKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.breakAll = false,
  });
  final String label, value;
  final bool mono, breakAll;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftCssText(label, style: RaftPanelText.label(t)),
        const SizedBox(height: 4),
        RaftCssText(
          breakAll ? value.characters.join('​') : value,
          style: mono ? RaftPanelText.mono(t) : RaftPanelText.value(t),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ activity

class RaftActivityLogEntry {
  const RaftActivityLogEntry({
    required this.time,
    required this.dot,
    required this.title,
    this.inlineDetail,
    this.inlineMono = false,
    this.detail,
    this.compact = false,
    this.clamp = false,
  });
  final String time, title;
  final Color dot;

  /// Same-line secondary text (`ml-1.5`): status detail or tool input.
  final String? inlineDetail;
  final bool inlineMono;

  /// Second-line mono text (`text-xs font-mono mt-0.5 whitespace-pre-wrap`).
  final String? detail;

  /// Status rows use `py-1`, the rest `py-1.5`.
  final bool compact;

  /// `line-clamp-2` while a long entry is collapsed.
  final bool clamp;
}

/// AgentDetailPanel Activity tab: diagnostics header (`border-b-2 px-5 py-2`
/// + copy action) and AgentActivityLog rows (`flex items-start gap-2 px-3`).
class RaftActivityLogView extends StatelessWidget {
  const RaftActivityLogView({
    super.key,
    required this.entries,
    this.onCopy,
    this.emptyLabel,
  });
  final List<RaftActivityLogEntry> entries;
  final VoidCallback? onCopy;
  final String? emptyLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-panel']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                RaftPanelIconButton(
                  glyph: RaftGlyph.copy,
                  tooltip: raftText(context, 'Copy diagnostic info'),
                  onPressed: onCopy,
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: RaftCssText(
                      emptyLabel ?? raftText(context, 'No activity yet'),
                      style: RaftPanelText.muted(t),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [for (final e in entries) _row(t, e)],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(RaftTokens t, RaftActivityLogEntry e) {
    final strong = t.brutal ? Colors.black : t.strong;
    final primary = raftCssText.merge(
      RaftTypography.body(
        t,
        size: 14,
        line: 20,
        weight: FontWeight.w500,
        color: strong,
      ),
    );
    final monoMuted = RaftPanelText.monoCaption(t);
    final inline = e.inlineDetail;
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
                RaftCssText.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: e.title, style: primary),
                      if (inline != null && inline.isNotEmpty) ...[
                        const WidgetSpan(child: SizedBox(width: 6)),
                        TextSpan(
                          // `break-all` mono input / wrapping status detail,
                          // both in the `text-sm` 20px line box.
                          text: e.inlineMono
                              ? inline.characters.join('​')
                              : inline,
                          style: e.inlineMono
                              ? monoMuted.copyWith(height: 20 / 12)
                              : primary.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: raftPanelInk(
                                    t,
                                    .6,
                                    t.colors['foreground-muted']!,
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                  style: primary,
                ),
                if (e.detail != null && e.detail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: RaftCssText(
                      e.detail!,
                      style: monoMuted,
                      maxLines: e.clamp ? 2 : null,
                      overflow: e.clamp ? TextOverflow.ellipsis : null,
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
  });
  final List<RaftReminderItem> reminders;
  final bool loading;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = raftPanelInk(t, .5, t.colors['foreground-muted']!);
    final bold = raftCssText.merge(
      RaftTypography.body(
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
        padding: const EdgeInsets.all(20),
        children: [
          // Only an empty list waits on a first read; a refresh of rows already
          // shown never inserts a line above them.
          if (loading && reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RaftCssText(raftText(context, 'Loading…'), style: bold),
            ),
          if (error != null)
            RaftCssText(error!, style: bold)
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
                      RaftTypography.body(
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
    this.onTap,
  });
  final String name;
  final int depth;
  final bool directory, open, bold;
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
  });
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
    return ColoredBox(
      color: t.brutal ? Colors.white : t.colors['layer-panel']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: hairline)),
            child: Row(
              children: [
                Expanded(
                  child: RaftSectionEyebrow(raftText(context, 'Workspace')),
                ),
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
          ),
          Expanded(
            child: loading && nodes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: RaftCssText(
                      raftText(context, 'Loading…'),
                      textAlign: TextAlign.center,
                      style: RaftTypography.mono(
                        t,
                        size: 14,
                        line: 20,
                        color: placeholder,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: error != null
                        ? [RaftCssText(error!, textAlign: TextAlign.center)]
                        : [for (final n in nodes) _node(t, n)],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _node(RaftTokens t, RaftWorkspaceNode n) {
    final text = raftCssText.merge(
      RaftTypography.body(
        t,
        size: 14,
        line: 20,
        weight: n.directory
            ? FontWeight.w500
            : n.bold
            ? FontWeight.w700
            : FontWeight.w400,
      ),
    );
    final folder = t.brutal
        ? t.product.brutalOrange
        : t.colors['warning-strong'] ?? t.strong;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: n.onTap,
      child: Padding(
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
  });
  final String path, content;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftPanelSection(
          topBorder: false,
          vertical: 8,
          children: [
            Row(
              children: [
                RaftInlineIconButton(
                  glyph: RaftGlyph.arrowLeft,
                  size: 14,
                  tooltip: raftText(context, 'Back'),
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RaftCssText(path, style: RaftPanelText.monoCaption(t)),
                ),
              ],
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              content,
              style: RaftTypography.mono(
                t,
                size: 12,
                line: 18,
                color: t.strong,
              ),
            ),
          ),
        ),
      ],
    );
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                      style: RaftTypography.body(t, weight: FontWeight.w700),
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
    this.selectable = true,
  });
  final String text;
  final VoidCallback? onEdit;
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
          editLabel: raftText(context, 'Edit description'),
        ),
        const SizedBox(height: 4),
        text.isEmpty
            ? RaftCssText(
                raftText(context, 'No description'),
                style: RaftPanelText.placeholder(t),
              )
            : selectable
            ? SelectionArea(
                child: RaftCssText(text, style: RaftPanelText.value(t)),
              )
            : RaftCssText(text, style: RaftPanelText.value(t)),
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
  });
  final String label;
  final RaftRecipeBadge badge;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RaftCssText(label, style: RaftPanelText.label(t)),
            const SizedBox(width: 8),
            RaftInlineIconButton(
              glyph: RaftGlyph.circleHelp,
              tooltip: raftText(context, 'Role permissions'),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: 8),
              RaftInlineIconButton(
                glyph: RaftGlyph.pencil,
                tooltip: raftText(context, 'Edit role'),
                onPressed: onEdit,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        RaftInlineBadge(badge: badge, bodyLine: true),
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
    overlayChildBuilder: (_) => CompositedTransformFollower(
      link: anchor,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topRight,
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
      child: RaftPanelIconButton(
        anchorLink: anchor,
        focusNode: triggerFocus,
        glyph: RaftGlyph.ellipsisVertical,
        tooltip: widget.tooltip,
        onPressed: () => toggle(),
        onKeyboardActivate: () => toggle(keyboard: true),
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
        child: MouseRegion(
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
