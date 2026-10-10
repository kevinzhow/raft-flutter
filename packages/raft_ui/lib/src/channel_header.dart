// Mounted ChatPanel.tsx → ui/PanelHeader.tsx inside the attached
// ConversationPanelRoot. Identity is always visible for ordinary/private/joint
// channels; DMs use PanelHeader's titleSlot (peer avatar, name, agent status).
// The generated panelHeader recipe supplies dimensions and text.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'indicators.dart';
import 'panel_layout.dart';
import 'recipe_surface.dart';
import 'recipes/panel_header.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';
import 'tooltip.dart';

/// Header bar of a mounted conversation panel: Web `PanelHeader` inside the
/// `edge="attached"` ConversationPanelRoot (ChatPanel). The panel root paints
/// the bar's surface (Brutal white, Elegant `layer-canvas-muted`, where the
/// desktop recipe leaves the header transparent) and its bottom rule (Elegant
/// `*:data-panel-frame-header:border-b border-line-muted`; Brutal's
/// `border-b-2 border-black` is the recipe's own).
class RaftConversationHeader extends StatelessWidget {
  const RaftConversationHeader({
    super.key,
    required this.content,
    this.identity,
    this.hasMeta = false,
    this.actions = const [],
    this.onBack,
    this.backKey,
    this.backLabel = 'Back',
  });

  /// Title block (PanelHeaderContent). Its width is the remaining row space.
  final Widget content;

  /// `PanelHeaderIcon` cell content (the 36px identity square), if any.
  final Widget? identity;

  /// Whether [content] carries a PanelMeta line (recipe `has:` state).
  final bool hasMeta;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Key? backKey;
  final String backLabel;

  /// Resolved recipe for [context] (viewport breakpoint, theme, meta state).
  static RaftPanelHeaderRecipeStyle recipeOf(
    BuildContext context, {
    bool hasMeta = false,
  }) {
    final t = RaftTokens.of(context);
    return RaftPanelHeaderRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (hasMeta) 'has:>data-slot=panel-meta',
      }, MediaQuery.sizeOf(context).width),
      tokens: RaftRecipeTokens(t),
    );
  }

  /// Slot text over the panel's body face, keeping the theme's CJK/emoji
  /// fallbacks (CSS font stacks fall back per glyph; Flutter needs the names).
  static TextStyle text(BuildContext context, RaftSlotStyle slot) {
    final t = RaftTokens.of(context);
    final style = slot.text(
      RaftRecipeTokens(t),
      base: RaftTypography.body(t, size: 16, line: 20),
    );
    final numeric = slot['font-variant-numeric'];
    return style.copyWith(
      fontFamilyFallback: [
        ...?style.fontFamilyFallback,
        for (final f in t.fontFallback)
          if (!(style.fontFamilyFallback ?? const []).contains(f)) f,
      ],
      fontFeatures: numeric.toString().contains('tabular-nums')
          ? const [FontFeature.tabularFigures()]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = RaftRecipeTokens(t);
    final recipe = recipeOf(context, hasMeta: hasMeta);
    final gap = recipe.header.columnGap ?? recipe.header.length('gap') ?? 12;
    final actionGap =
        recipe.actions.columnGap ?? recipe.actions.length('gap') ?? 6;
    return RaftRecipeBox(
      style: recipe.header,
      tokens: rt,
      decorationOverride: (d) => d.copyWith(
        color: d.color == null || d.color!.a == 0
            ? (t.brutal ? Colors.white : t.colors['layer-canvas-muted'])
            : d.color,
        border: t.brutal
            ? d.border
            : Border(bottom: BorderSide(color: t.colors['line-muted']!)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            RaftPanelAction(
              key: backKey,
              glyph: RaftGlyph.arrowLeft,
              tooltip: backLabel,
              onPressed: onBack,
            ),
            SizedBox(width: gap),
          ],
          if (identity != null) ...[
            RaftRecipeBox(
              style: recipe.headerIcon,
              tokens: rt,
              alignment: Alignment.center,
              child: identity,
            ),
            SizedBox(width: gap),
          ],
          Expanded(child: content),
          if (actions.isNotEmpty) ...[
            SizedBox(width: gap),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) SizedBox(width: actionGap),
              actions[i],
            ],
          ],
        ],
      ),
    );
  }
}

/// ChannelOverflowMenu's two topbar triggers (OverflowMenuTrigger:
/// Button icon-sm outline + tooltip): Search this channel, Settings.
List<Widget> raftConversationHeaderActions({
  required String searchLabel,
  required String settingsLabel,
  VoidCallback? onSearch,
  VoidCallback? onSettings,
}) => [
  RaftPanelIconButton(
    key: const ValueKey('channel-topbar-search'),
    glyph: RaftGlyph.search,
    tooltip: searchLabel,
    onPressed: onSearch,
  ),
  RaftPanelIconButton(
    key: const ValueKey('channel-overflow-trigger'),
    glyph: RaftGlyph.settings,
    tooltip: settingsLabel,
    onPressed: onSettings,
  ),
];

/// CSS `white-space: nowrap` collapses every whitespace run (newlines
/// included) into one space; descriptions are stored with authored newlines.
String raftCollapseWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

class RaftChannelHeader extends StatelessWidget {
  const RaftChannelHeader({
    super.key,
    required this.name,
    this.description = '',
    this.kind = 'channel',
    this.onBack,
    this.backKey,
    this.onSearch,
    this.onSettings,
    this.backLabel = 'Back',
    this.searchLabel = 'Search this channel',
    this.settingsLabel = 'Channel settings',
  });
  final String name, description, kind, backLabel, searchLabel, settingsLabel;
  final VoidCallback? onBack, onSearch, onSettings;
  final Key? backKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = RaftRecipeTokens(t);
    // ChannelDescription is `line-clamp-2` inside PanelMeta, whose recipe is
    // `truncate`: one unwrapped line, clipped (no ellipsis) at the box edge.
    final meta = raftCollapseWhitespace(description);
    final recipe = RaftConversationHeader.recipeOf(
      context,
      hasMeta: meta.isNotEmpty,
    );
    final glyph = switch (kind) {
      'private' => RaftGlyph.lock,
      'joint' => RaftGlyph.gitBranch,
      _ => RaftGlyph.hash,
    };
    final title = RaftConversationHeader.text(context, recipe.title);
    final metaStyle = RaftConversationHeader.text(context, recipe.meta);
    return RaftConversationHeader(
      onBack: onBack,
      backKey: backKey,
      backLabel: backLabel,
      hasMeta: meta.isNotEmpty,
      identity: RaftIcon(
        glyph,
        size: 14,
        color: recipe.headerIcon.color?.resolve(rt) ?? t.strong,
      ),
      content: RaftPanelHeaderContent(
        style: recipe.headerContent,
        heading: RaftTooltip(
          message: name,
          onlyWhenTruncated: true,
          excludeFromSemantics: true,
          child: RaftCssText(
            name,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: title,
            // Keep the primary CSS face's line box with CJK fallbacks.
            strutStyle: StrutStyle.fromTextStyle(title, forceStrutHeight: true),
          ),
        ),
        meta: meta.isEmpty
            ? null
            : RaftTruncationTooltip(
                text: meta,
                style: metaStyle,
                child: RaftCssText(
                  meta,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: metaStyle,
                  strutStyle: StrutStyle.fromTextStyle(
                    metaStyle,
                    forceStrutHeight: true,
                  ),
                ),
              ),
      ),
      actions: raftConversationHeaderActions(
        searchLabel: searchLabel,
        settingsLabel: settingsLabel,
        onSearch: onSearch,
        onSettings: onSettings,
      ),
    );
  }
}

/// ChatPanel's DM header (`titleSlot`): the peer's panel-header avatar, the
/// bold display name and, for agents, AgentDMStatus (status dot + activity
/// text), then the same Search / Settings triggers as a channel.
class RaftDmHeader extends StatelessWidget {
  const RaftDmHeader({
    super.key,
    required this.name,
    required this.avatar,
    this.activity,
    this.external = false,
    this.activityText,
    this.muted = false,
    this.onBack,
    this.backKey,
    this.onSearch,
    this.onSettings,
    this.backLabel = 'Back',
    this.searchLabel = 'Search this channel',
    this.settingsLabel = 'Channel settings',
    this.mutedLabel = 'Activity muted',
  });

  final String name;

  /// AvatarSlot context="panel-header" (36px, already sized).
  final Widget avatar;

  /// Agent DMs: dot tone and its status text; null for human DMs.
  final RaftActivityTone? activity;
  final bool external;
  final String? activityText;
  final bool muted;
  final VoidCallback? onBack, onSearch, onSettings;
  final Key? backKey;
  final String backLabel, searchLabel, settingsLabel, mutedLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final nameStyle = RaftTypography.body(
      t,
      size: 16,
      line: 20,
      weight: FontWeight.w700,
      color: t.colors['foreground-strong'],
    ).copyWith(leadingDistribution: TextLeadingDistribution.even);
    final statusStyle = RaftTypography.mono(
      t,
      size: 14,
      line: 20,
      color: t.colors['foreground-muted'],
    ).copyWith(leadingDistribution: TextLeadingDistribution.even);
    final status = activityText;
    return RaftConversationHeader(
      onBack: onBack,
      backKey: backKey,
      backLabel: backLabel,
      content: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: _RaftCssShrinkRow(
              gap: 8,
              texts: [
                (name, nameStyle),
                if (activity != null && status != null) (status, statusStyle),
              ],
              fixedAfterFirst: [
                if (activity != null)
                  RaftStatusDot(activity: activity, external: external),
              ],
              trailing: [
                if (muted)
                  RaftTooltip(
                    message: mutedLabel,
                    child: RaftIcon(
                      RaftGlyph.bellOff,
                      size: 12,
                      color: t.colors['foreground-muted'],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: raftConversationHeaderActions(
        searchLabel: searchLabel,
        settingsLabel: settingsLabel,
        onSearch: onSearch,
        onSettings: onSettings,
      ),
    );
  }
}

/// A CSS flex row of `min-w-0 truncate` texts separated by `shrink-0`
/// items: when the row overflows, every text shrinks in proportion to its
/// content width (flex-shrink 1 × basis), each ellipsized in its own box.
class _RaftCssShrinkRow extends StatelessWidget {
  const _RaftCssShrinkRow({
    required this.gap,
    required this.texts,
    this.fixedAfterFirst = const [],
    this.trailing = const [],
  });
  final double gap;
  final List<(String, TextStyle)> texts;
  final List<Widget> fixedAfterFirst, trailing;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final widths = [
      for (final (text, style) in texts)
        (TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout()).width,
    ];
    // Fixed items: the dot (10px) and trailing icons (12px).
    const dot = 10.0, icon = 12.0;
    final fixed =
        fixedAfterFirst.length * dot +
        trailing.length * icon +
        gap * (texts.length + fixedAfterFirst.length + trailing.length - 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widths.fold<double>(0, (a, b) => a + b);
        final available = math.max(0.0, constraints.maxWidth - fixed);
        final scale = total <= available || total == 0
            ? 1.0
            : available / total;
        Widget text(int i) {
          final (value, style) = texts[i];
          // Unshrunk texts keep their own (unrounded) intrinsic width.
          return SizedBox(
            width: scale == 1 ? null : widths[i] * scale,
            child: RaftTooltip(
              message: value,
              onlyWhenTruncated: true,
              excludeFromSemantics: true,
              child: Text(
                value,
                style: style,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }

        final children = <Widget>[
          text(0),
          for (final w in fixedAfterFirst) w,
          for (var i = 1; i < texts.length; i++) text(i),
          ...trailing,
        ];
        return ClipRect(
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                children[i],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Shows [text] as a tooltip only while [child] (one clipped, unwrapped line
/// of [text] in [style]) is cut off; a tooltip never repeats fully visible
/// text. (Ellipsized text uses `RaftTooltip.onlyWhenTruncated`; a clipped
/// paragraph reports no exceeded line, so this measures instead.)
class RaftTruncationTooltip extends StatelessWidget {
  const RaftTruncationTooltip({
    super.key,
    required this.text,
    required this.style,
    required this.child,
  });
  final String text;
  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedWidth) return child;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final truncated = painter.width > constraints.maxWidth + .5;
      painter.dispose();
      return truncated
          ? RaftTooltip(message: text, excludeFromSemantics: true, child: child)
          : child;
    },
  );
}
