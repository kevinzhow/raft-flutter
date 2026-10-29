// Mounted ChatPanel.tsx → ui/PanelHeader.tsx inside the attached
// ConversationPanelRoot. Identity is always visible for ordinary/private/joint
// channels; DMs use PanelHeader's titleSlot (peer avatar, name, agent status).
// The generated panelHeader recipe supplies dimensions and text.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'avatar_button.dart';
import 'channel_description_links.dart';
import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'indicators.dart';
import 'panel_layout.dart';
import 'public_page_mark.dart';
import 'raft/button.dart';
import 'raft/css_box.dart' show raftControlBorderPx;
import 'recipe_surface.dart';
import 'recipes/panel_header.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'status_bar.dart';
import 'text_measure.dart';
import 'theme.dart';
import 'tooltip.dart';
import 'working_agents.dart';

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
    final base = RaftPanelHeaderRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (hasMeta) 'has:>data-slot=panel-meta',
      }, MediaQuery.sizeOf(context).width),
      tokens: RaftRecipeTokens(t),
    );
    final rt = t.recipeTokens;
    final phone =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    RaftSlotStyle project(RaftSlotStyle slot, Map<String, CssValue> fields) =>
        RaftSlotStyle(
          {...slot.properties, ...fields},
          slot.targets,
          slot.classes,
          rt,
        );
    CssColor color(String role) => CssColor(t.colors[role]!.toARGB32());
    RaftSlotStyle textSlot(
      RaftSlotStyle slot,
      String prefix,
      String font,
      String foreground, {
      double? size,
      String? lineKey,
    }) => project(slot, {
      'font-size': CssNum(size ?? t.size('$prefix.size', fallback: 17), 'px'),
      'line-height': CssNum(
        t.size(lineKey ?? '$prefix.line', fallback: 20),
        'px',
      ),
      'font-weight': CssNum(t.size('$prefix.weight', fallback: 400)),
      'font-family': CssString(t.fontFamily(font)),
      'color': color(foreground),
    });
    final inline =
        hasMeta &&
        !phone &&
        t.option('conversationHeader.metaFlow', or: 'inlineWide') ==
            'inlineWide';
    final gap = t.size(
      phone
          ? 'space.conversationHeaderMetaPhone'
          : 'space.conversationHeaderMeta',
      fallback: 0,
    );
    final iconBorder = raftControlBorderPx(
      context,
      t.size('stroke.conversationHeaderIcon', fallback: 0),
    );
    // A specified zero border has no CSS used-width floor.
    final usedBorder = t.size('stroke.conversationHeaderIcon', fallback: 0) == 0
        ? 0.0
        : iconBorder;
    return RaftPanelHeaderRecipeStyle(
      header: base.header,
      sectionHeader: base.sectionHeader,
      headerIcon: project(base.headerIcon, {
        'width': CssNum(
          t.size('size.conversationHeaderIcon', fallback: 36),
          'px',
        ),
        'height': CssNum(
          t.size('size.conversationHeaderIcon', fallback: 36),
          'px',
        ),
        'border-radius': CssNum(
          t.size('radius.conversationHeaderIcon', fallback: 6),
          'px',
        ),
        'background-color': color('layer-conversation-icon'),
        'color': color('foreground-conversation-icon'),
        for (final edge in ['top', 'right', 'bottom', 'left']) ...{
          'border-$edge-width': CssNum(usedBorder, 'px'),
          'border-$edge-style': const CssKeyword('solid'),
          'border-$edge-color': color('line-conversation-icon'),
        },
      }),
      headerContent: project(base.headerContent, {
        'flex-direction': CssKeyword(inline ? 'row' : 'column'),
        'gap': CssNum(gap, 'px'),
        'row-gap': CssNum(gap, 'px'),
        'column-gap': CssNum(gap, 'px'),
      }),
      heading: base.heading,
      title: textSlot(
        base.title,
        'type.conversationHeaderTitle',
        'font.conversationHeaderTitle',
        'foreground-conversation-title',
      ),
      meta: textSlot(
        base.meta,
        'type.conversationHeaderMeta',
        'font.conversationHeaderMeta',
        'foreground-conversation-meta',
        size: 12,
        lineKey: phone
            ? 'type.conversationHeaderMetaPhone.line'
            : 'type.conversationHeaderMeta.line',
      ),
      status: base.status,
      activity: base.activity,
      actions: project(base.actions, {
        'column-gap': CssNum(
          t.size(
            phone
                ? 'space.conversationHeaderActionsPhone'
                : 'space.conversationHeaderActions',
            fallback: 6,
          ),
          'px',
        ),
      }),
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
    final ghost = t.option('panelAction.surface', or: 'outline') == 'ghost';
    final surface = ghost
        ? t.colors['layer-panel-header']
        : t.colors['layer-canvas-muted'];
    final recipeFill = recipe.header.decoration(rt).color;
    final paintedFill = ghost || recipeFill == null || recipeFill.a == 0
        ? surface
        : recipeFill;
    return RaftStatusBarSource(
      color: paintedFill ?? Colors.transparent,
      child: RaftRecipeBox(
        style: recipe.header,
        height: ghost
            ? RaftLayoutMetrics.shellHeaderHeight(
                t,
                MediaQuery.sizeOf(context).height,
              )
            : null,
        padding: ghost
            ? raftPanelHeaderEdges(
                context,
                hasBack: onBack != null,
                hasActions: actions.isNotEmpty,
              )
            : null,
        tokens: rt,
        decorationOverride: (d) => d.copyWith(
          color: paintedFill,
          border: Border(
            bottom: BorderSide(
              color: t.colors['line-conversation-header']!,
              width: t.size('stroke.conversationHeader', fallback: 1),
            ),
          ),
        ),
        child: Row(
          children: [
            if (onBack != null) ...[
              RaftPanelAction(
                key: backKey,
                glyph: RaftGlyph.arrowLeft,
                tooltip: backLabel,
                onPressed: onBack,
                minHitExtent: RaftMetrics.touchTarget,
              ),
              SizedBox(width: gap),
            ],
            if (identity != null) ...[
              RaftRecipeBox(
                key: const ValueKey('conversation-header-icon'),
                style: recipe.headerIcon,
                tokens: rt,
                decorationOverride: (d) => d.copyWith(
                  boxShadow: [
                    if (t.size(
                          'stroke.conversationHeaderIconRing',
                          fallback: 0,
                        ) >
                        0)
                      BoxShadow(
                        color: t.colors['line-conversation-icon-ring']!,
                        spreadRadius: t.size(
                          'stroke.conversationHeaderIconRing',
                          fallback: 0,
                        ),
                      ),
                  ],
                ),
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
  _ConversationHeaderAction(
    key: const ValueKey('channel-topbar-search'),
    glyph: RaftGlyph.search,
    tooltip: searchLabel,
    onPressed: onSearch,
  ),
  _ConversationHeaderAction(
    key: const ValueKey('channel-overflow-trigger'),
    glyph: RaftGlyph.settings,
    tooltip: settingsLabel,
    onPressed: onSettings,
  ),
];

class _ConversationHeaderAction extends StatelessWidget {
  const _ConversationHeaderAction({
    super.key,
    required this.glyph,
    required this.tooltip,
    this.onPressed,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      RaftTokens.of(context).option('panelAction.surface', or: 'outline') ==
          'ghost'
      ? RaftButton(
          label: '',
          glyph: glyph,
          tooltip: tooltip,
          semanticLabel: tooltip,
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.iconSm,
          onPressed: onPressed,
        )
      : RaftPanelIconButton(
          glyph: glyph,
          tooltip: tooltip,
          onPressed: onPressed,
        );
}

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
    this.searchLabel = 'Search This Channel',
    this.settingsLabel = 'Channel Settings',
    this.archivedLabel,
    this.mutedLabel,
    this.onOpenLink,
    this.publicPage = false,
    this.workingAgents = const [],
  });
  final String name, description, kind, backLabel, searchLabel, settingsLabel;

  /// Agents working in this channel (members only), in the order they
  /// started. The subtitle then starts with up to three faces and
  /// "2 agents working", then " · " and the description.
  final List<RaftWorkingAgent> workingAgents;
  final VoidCallback? onBack, onSearch, onSettings;
  final Key? backKey;

  /// ChatPanel `ActivityMutedBadge`: the viewer muted this channel's activity.
  /// The localized tooltip of the small bell-off after the title (null = not
  /// muted).
  final String? mutedLabel;

  /// ChannelDescription: tapping an http(s) link in the description. Null
  /// leaves the description plain text.
  final ValueChanged<String>? onOpenLink;

  /// Anyone can read this channel on the server's public page (the server is
  /// public and the channel visible to Guests): the # carries a small globe.
  final bool publicPage;

  /// ChatPanel `regularTitleSuffix` for an archived channel: the localized
  /// "Archived" badge after the title (null = not archived).
  final String? archivedLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = RaftRecipeTokens(t);
    // ChannelDescription is `line-clamp-2` inside PanelMeta, whose recipe is
    // `truncate`: one unwrapped line, clipped (no ellipsis) at the box edge.
    final meta = raftCollapseWhitespace(description);
    final working = workingAgents.isNotEmpty;
    final recipe = RaftConversationHeader.recipeOf(
      context,
      hasMeta: meta.isNotEmpty || working,
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
      hasMeta: meta.isNotEmpty || working,
      identity: publicPage && kind == 'channel'
          ? RaftPublicChannelMark(
              color: recipe.headerIcon.color?.resolve(rt) ?? t.strong,
            )
          : RaftIcon(
              glyph,
              size: 14,
              color: recipe.headerIcon.color?.resolve(rt) ?? t.strong,
            ),
      content: RaftPanelHeaderContent(
        style: recipe.headerContent,
        heading: _withArchivedBadge(
          t,
          RaftTooltip(
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
              strutStyle: StrutStyle.fromTextStyle(
                title,
                forceStrutHeight: true,
              ),
            ),
          ),
        ),
        meta: working
            ? LayoutBuilder(
                key: const Key('channel-header-subtitle'),
                builder: (context, box) {
                  final label = raftWorkingAgentsLabel(
                    context,
                    workingAgents.length,
                  );
                  final facesWidth =
                      math.min(workingAgents.length, raftWorkingFaceLimit) *
                          19.0 -
                      (math.min(workingAgents.length, raftWorkingFaceLimit) -
                              1) *
                          5.0;
                  final lineWidth =
                      facesWidth +
                      6 +
                      raftTextWidth(
                        TextSpan(text: label, style: metaStyle),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                        maxLines: 1,
                      );
                  // " · " and the description need their separator plus room
                  // for a few characters; otherwise the working line stands
                  // alone (and ellipsizes if it is wider than the header).
                  const dotWidth = 16.0, minDescription = 24.0;
                  final room = box.maxWidth - lineWidth - dotWidth;
                  final showDescription =
                      meta.isNotEmpty && room >= minDescription;
                  return Row(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: box.maxWidth),
                        child: RaftWorkingLine(
                          agents: workingAgents,
                          style: metaStyle,
                        ),
                      ),
                      if (showDescription) ...[
                        // " · " between the working line and the description.
                        ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('·', style: metaStyle, softWrap: false),
                          ),
                        ),
                        Flexible(
                          child: RaftTruncationTooltip(
                            text: meta,
                            style: metaStyle,
                            child: onOpenLink == null
                                ? RaftCssText(
                                    meta,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: metaStyle,
                                    strutStyle: StrutStyle.fromTextStyle(
                                      metaStyle,
                                      forceStrutHeight: true,
                                    ),
                                  )
                                : _LinkedDescription(
                                    meta,
                                    style: metaStyle,
                                    linkColor: t.colors['foreground-hint']!,
                                    onOpenLink: onOpenLink!,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              )
            : meta.isEmpty
            ? null
            : RaftTruncationTooltip(
                text: meta,
                style: metaStyle,
                child: onOpenLink == null
                    ? RaftCssText(
                        meta,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: metaStyle,
                        strutStyle: StrutStyle.fromTextStyle(
                          metaStyle,
                          forceStrutHeight: true,
                        ),
                      )
                    : _LinkedDescription(
                        meta,
                        style: metaStyle,
                        linkColor: t.colors['foreground-hint']!,
                        onOpenLink: onOpenLink!,
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

  /// ChatPanel `regularTitleSuffix`: the Archived badge and the muted bell in
  /// one `gap-1.5` row after the title.
  Widget _withArchivedBadge(RaftTokens t, Widget title) {
    final label = archivedLabel, muted = mutedLabel;
    if (label == null && muted == null) return title;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: title),
        const SizedBox(width: 8),
        if (label != null) _ArchivedBadge(label),
        if (label != null && muted != null) const SizedBox(width: 6),
        if (muted != null)
          RaftTooltip(
            message: muted,
            child: RaftIcon(
              RaftGlyph.bellOff,
              key: const ValueKey('channel-activity-muted-badge'),
              size: 12,
              color: t.colors['foreground-hint'],
            ),
          ),
      ],
    );
  }
}

/// The header description with its http(s) links tappable
/// ([raftSegmentChannelDescription]); the line stays one clipped line.
class _LinkedDescription extends StatefulWidget {
  const _LinkedDescription(
    this.text, {
    required this.style,
    required this.linkColor,
    required this.onOpenLink,
    this.overflow = TextOverflow.clip,
  });
  final TextOverflow overflow;
  final String text;
  final TextStyle style;
  final Color linkColor;
  final ValueChanged<String> onOpenLink;
  @override
  State<_LinkedDescription> createState() => _LinkedDescriptionState();
}

class _LinkedDescriptionState extends State<_LinkedDescription> {
  final _recognizers = <TapGestureRecognizer>[];

  void _release() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _release();
    final spans = <InlineSpan>[];
    for (final segment in raftSegmentChannelDescription(widget.text)) {
      if (!segment.link) {
        spans.add(TextSpan(text: segment.value));
        continue;
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onOpenLink(segment.value);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: segment.value,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
            decorationThickness: 1.5,
          ),
        ),
      );
    }
    return RaftCssText.rich(
      TextSpan(children: spans),
      key: const ValueKey('channel-description-links'),
      maxLines: 1,
      softWrap: false,
      overflow: widget.overflow,
      style: widget.style,
      strutStyle: StrutStyle.fromTextStyle(
        widget.style,
        forceStrutHeight: true,
      ),
    );
  }
}

/// ChatPanel `regularTitleSuffix` archived badge: `inline-flex items-center
/// rounded-sm border bg-warning/30 px-1.5 py-1 text-[11px] font-bold
/// leading-none`; Brutal `rounded-none border-2 border-black
/// bg-brutal-orange/30`.
class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      key: const ValueKey('channel-archived-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: t.colors['warning']!.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: t.colors['line-muted']!, width: 1),
      ),
      child: Text(
        label,
        style: RaftTypography.mono(
          t,
          size: 11,
          line: 11,
          color: t.strong,
        ).copyWith(fontWeight: FontWeight.w700),
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
    this.onAvatarTap,
    this.avatarButtonKey,
    this.avatarSemanticLabel,
    this.backLabel = 'Back',
    this.searchLabel = 'Search This Channel',
    this.settingsLabel = 'Channel Settings',
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
  final VoidCallback? onBack, onSearch, onSettings, onAvatarTap;
  final Key? backKey, avatarButtonKey;
  final String backLabel, searchLabel, settingsLabel, mutedLabel;
  final String? avatarSemanticLabel;

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
    final headerAvatar = onAvatarTap == null
        ? avatar
        : RaftAvatarButton(
            key: avatarButtonKey ?? const Key('dm-header-avatar-button'),
            semanticLabel: avatarSemanticLabel ?? name,
            onPressed: onAvatarTap,
            child: avatar,
          );
    return RaftConversationHeader(
      onBack: onBack,
      backKey: backKey,
      backLabel: backLabel,
      content: Row(
        children: [
          headerAvatar,
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
        raftTextWidth(
          TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        ),
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
