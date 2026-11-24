import 'package:flutter/material.dart';
import 'package:raft_theme/recipes/recipe_runtime.dart';

import 'design_primitives.dart' show RaftInteractive;
import 'error_presentation.dart' show RaftErrorBanner;
import 'recipes/message_action_card.g.dart';
import 'recipes/message_action_card_content.g.dart';
import 'recipes/message_card.g.dart';
import 'panel_layout.dart' show RaftCssText;
import 'agent_subagents.dart' show RaftDescriptionEntry;
import 'raft/button.dart';
import 'raft/status.dart';
import 'raft/ui_tokens.dart';
import 'localization.dart';
import 'space.dart';
import 'theme.dart';
import 'icons.dart';
import 'message_embed_frame.dart';
import 'message_reference_chip.dart';
import 'message_row_recipe.dart' show RaftMessageBodyMargin;
import 'recipe_surface.dart' show RaftRecipeBinding, RaftRecipeBox;
import 'text_measure.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

class RaftSpecActionCard extends StatelessWidget {
  const RaftSpecActionCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.description,
    this.descriptionSpan,
    this.completed = false,
    this.status,
    this.statusVariant = RaftStatusVariant.muted,
    this.expanded = true,
    this.onToggle,
  });

  final String title;
  final Widget body;
  final RaftGlyph? icon;
  final String? description, status;
  final InlineSpan? descriptionSpan;
  final RaftStatusVariant statusVariant;
  final bool expanded, completed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final states = tokens.recipeStates(responsive: true);
    final recipe = RaftMessageActionCardRecipe.resolve(
      states: states,
      tokens: tokens.recipeTokens,
    );
    final card = RaftMessageCardRecipe.resolve(
      states: states,
      tokens: tokens.recipeTokens,
    );
    final glyph = icon;
    final statusText = status;
    final descriptionContent =
        descriptionSpan ??
        (description == null ? null : TextSpan(text: description));
    final titleStyle = raftSlotTextStyle(tokens, card.heading);
    final descriptionStyle = raftSlotTextStyle(
      tokens,
      recipe.headerDescription,
    );
    final statusStyle = raftSlotTextStyle(tokens, recipe.status);
    final tile = recipe.headerIcon.width ?? 27;
    final inset = card.inset.padding;
    final headerPadding = inset.copyWith(
      bottom: expanded ? recipe.header.padding.bottom : inset.bottom,
      right: onToggle == null
          ? null
          : inset.right + recipe.collapseTrigger.margin.right,
    );
    double centerFirstLine(TextStyle style) {
      final lines = MediaQuery.textScalerOf(context)
          .scale(style.fontSize ?? 14);
      return ((tile - lines * (style.height ?? 1)) / 2).clamp(0.0, tile);
    }

    return Padding(
      padding: EdgeInsets.only(top: RaftMessageBodyMargin.collapse(context, 8)),
      child: RaftMessageEmbedFrame(
        size: RaftMessageEmbedSize.item,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: headerPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: recipe.header.columnGap ?? RaftSpace.x2,
                children: [
                  if (glyph != null)
                    Container(
                      width: tile,
                      height: recipe.headerIcon.height ?? tile,
                      decoration: recipe.headerIcon.decoration(
                        tokens.recipeTokens,
                      ),
                      alignment: Alignment.center,
                      child: RaftIcon(
                        glyph,
                        size: 14,
                        color: recipe.headerIcon.color?.resolve(
                          tokens.recipeTokens,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: centerFirstLine(titleStyle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: recipe.headerDescription.margin.top,
                        children: [
                          RaftCssText(
                            title,
                            style: titleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (descriptionContent != null)
                            RaftCssText.rich(
                              TextSpan(
                                children: [
                                  if (completed)
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: RaftSpace.x1_5,
                                        ),
                                        child: RaftIcon(
                                          RaftGlyph.check,
                                          size: 16,
                                          color: tokens.ui.foreground,
                                        ),
                                      ),
                                    ),
                                  descriptionContent,
                                ],
                              ),
                              style: descriptionStyle,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (statusText != null)
                    Padding(
                      padding: EdgeInsets.only(
                        top: centerFirstLine(statusStyle),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: recipe.status.columnGap ?? RaftSpace.x1_5,
                          children: [
                            RaftStatus(variant: statusVariant),
                            Flexible(
                              child: RaftCssText(
                                statusText,
                                style: statusStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (onToggle != null)
                    _SpecActionCardDisclosure(
                      expanded: expanded,
                      onToggle: onToggle!,
                    ),
                ],
              ),
            ),
            if (expanded) Padding(padding: inset.copyWith(top: 0), child: body),
          ],
        ),
      ),
    );
  }
}

class _SpecActionCardDisclosure extends StatelessWidget {
  const _SpecActionCardDisclosure({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final label = raftText(context, 'Show or hide details');
    return Semantics(
      expanded: expanded,
      child: RaftInteractive(
        key: const ValueKey('action-card-toggle-details'),
        onPressed: onToggle,
        semanticLabel: label,
        tooltip: label,
        builder: (context, state) {
          final recipe = RaftMessageActionCardRecipe.resolve(
            states: tokens.recipeStates(
              responsive: true,
              hovered: state.hovered,
              pressed: state.pressed,
              focusVisible: state.focusVisible,
            ),
            tokens: tokens.recipeTokens,
          ).collapseTrigger;
          return RaftRecipeBox(
            style: recipe,
            tokens: tokens.recipeTokens,
            alignment: Alignment.center,
            applyText: false,
            child: RaftIcon(
              expanded ? RaftGlyph.chevronUp : RaftGlyph.chevronDown,
              size: 16,
              color: recipe.color?.resolve(tokens.recipeTokens),
            ),
          );
        },
      ),
    );
  }
}

class RaftSpecActionCardContent {
  RaftSpecActionCardContent(BuildContext context)
    : tokens = RaftTokens.of(context),
      direction = Directionality.of(context),
      scaler = MediaQuery.textScalerOf(context);

  final RaftTokens tokens;
  final TextDirection direction;
  final TextScaler scaler;

  late final slots = RaftMessageActionCardContentRecipe.resolve(
    states: tokens.recipeStates(responsive: true),
    tokens: tokens.recipeTokens,
  );

  TextStyle text(RaftSlotStyle slot) => raftSlotTextStyle(
    tokens,
    slot,
  ).copyWith(fontWeight: slot.fontWeight ?? FontWeight.w400);

  static const _nameStyle = TextStyle(fontWeight: FontWeight.w600);

  TextSpan completionName(String name) => TextSpan(
    text: name,
    style: _nameStyle.copyWith(color: tokens.ui.foreground),
  );

  TextSpan completionTime(String timestamp) {
    const wordJoiner = '\u2060';
    final style = tokens.scale(
      RaftTypeScale.monoMeta,
      color: tokens.ui.foregroundMuted,
      mono: true,
    );
    return TextSpan(
      style: style,
      children: [
        // Flutter advances each character by its tracking. The joiner
        // supplies the leading margin from the Web separator’s ::before.
        const TextSpan(
          text: '$wordJoiner·',
          style: TextStyle(letterSpacing: RaftSpace.x1),
        ),
        TextSpan(text: '$wordJoiner$timestamp'),
      ],
    );
  }

  InlineSpan entityReference(
    BuildContext context,
    String label, {
    RaftReferenceKind? kind,
    VoidCallback? onTap,
  }) {
    if (kind == null && onTap == null) {
      return TextSpan(text: label, style: _nameStyle);
    }
    return raftReferenceSpan(
      context,
      label: label,
      href: '',
      base: text(slots.propertyValue).merge(_nameStyle),
      appearance: kind == null ? null : RaftReferenceAppearance(kind),
      onTap: onTap,
    );
  }

  Widget column(List<Widget> children) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: slots.root.rowGap ?? RaftSpace.x2,
    children: children,
  );

  Widget properties(
    List<RaftDescriptionEntry> entries, {
    bool fitLabels = false,
  }) {
    final labelStyle = text(slots.propertyLabel);
    final valueStyle = text(slots.propertyValue);
    final gap = slots.properties.columnGap ?? RaftSpace.x4;
    final rowGap = slots.properties.rowGap ?? RaftSpace.half;
    Widget label(RaftDescriptionEntry entry) =>
        RaftCssText(entry.term, style: labelStyle);
    Widget value(RaftDescriptionEntry entry) =>
        entry.detailsChild ?? RaftCssText(entry.details, style: valueStyle);
    double width(String value, TextStyle style) => raftTextWidth(
      TextSpan(text: value, style: style),
      textDirection: direction,
      textScaler: scaler,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = slots.propertyLabel.maxWidth ?? 160;
        final labelWidth = entries.fold<double>(fitLabels ? 0 : 88, (
          current,
          entry,
        ) {
          final next = width(entry.term, labelStyle).clamp(0.0, cap);
          return next > current ? next : current;
        });
        final valueWidth = constraints.maxWidth - labelWidth - gap;
        final stacked =
            valueWidth < 160 ||
            entries.any((entry) {
              final natural = width(entry.details, valueStyle);
              if (natural <= constraints.maxWidth + .5)
                return natural > valueWidth + .5;
              return entry.details.split(RegExp(r'\s+')).any((word) {
                final piece = width(word, valueStyle);
                return piece > valueWidth + .5 &&
                    piece <= constraints.maxWidth + .5;
              });
            });
        if (stacked) {
          return column([
            for (final entry in entries)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: rowGap,
                children: [label(entry), value(entry)],
              ),
          ]);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: rowGap,
          children: [
            for (final entry in entries)
              Row(
                spacing: gap,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(width: labelWidth, child: label(entry)),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: slots.propertyValue.minHeight ?? 0,
                      ),
                      child: Padding(
                        padding: slots.propertyValue.padding,
                        child: value(entry),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget hint({String? label, required String body, int? maxLines}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: RaftSpace.x1,
    children: [
      if (label != null) RaftCssText(label, style: text(slots.hintLabel)),
      Container(
        decoration: slots.hint.decoration(tokens.recipeTokens),
        padding: slots.hint.padding,
        child: RaftCssText(
          body,
          style: text(slots.hint),
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget notice(String copy) {
    final style = text(slots.notice);
    final lineHeight = scaler.scale(style.fontSize ?? 12) * (style.height ?? 1);
    final iconTop = ((lineHeight - 14) / 2).clamp(0.0, 14.0);
    return Container(
      decoration: slots.notice.decoration(tokens.recipeTokens),
      padding: slots.notice.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: slots.notice.columnGap ?? RaftSpace.x2,
        children: [
          Padding(
            padding: EdgeInsets.only(top: iconTop),
            child: RaftIcon(RaftGlyph.info, size: 14, color: style.color),
          ),
          Expanded(child: RaftCssText(copy, style: style)),
        ],
      ),
    );
  }

  Widget scopes(
    BuildContext context,
    List<({String scope, String? copy})> entries,
  ) {
    final label = raftFormat(context, 'Permissions ({count})', {
      'count': entries.length,
    });
    final nameStyle = text(slots.scopeName);
    final descriptionStyle = text(slots.scopeDescription);
    final gap = slots.scopeListViewportContent.rowGap ?? RaftSpace.x1_5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        RaftCssText(label, style: text(slots.scopeListLabel)),
        if (entries.every((entry) => entry.copy == null))
          RaftCssText(
            entries.isEmpty
                ? '-'
                : entries.map((entry) => entry.scope).join(', '),
            style: nameStyle,
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: slots.scopeListViewport.maxHeight ?? 136,
            ),
            child: SingleChildScrollView(
              padding: slots.scopeListViewportContent.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: [
                  for (final entry in entries)
                    RaftRecipeBox(
                      style: slots.scope,
                      tokens: tokens.recipeTokens,
                      applyText: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: slots.scopeDescription.margin.top,
                        children: [
                          RaftCssText(entry.scope, style: nameStyle),
                          RaftCssText(
                            raftText(
                              context,
                              entry.copy ??
                                  'Raft has no description for this scope.',
                            ),
                            style: descriptionStyle,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget actions(List<Widget> children) => Padding(
    padding: slots.actions.margin,
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: RaftSpace.x2,
      runSpacing: RaftSpace.x2,
      children: children,
    ),
  );
}

/// A safe presentation of server-owned action metadata, rendered on the
/// canonical v1.24 [RaftSpecActionCard] / [RaftMessageEmbedFrame] frame.
/// Execution and current permissions belong to the application adapter.
class RaftActionCard extends StatefulWidget {
  const RaftActionCard({
    super.key,
    required this.title,
    required this.state,
    this.details = const [],
    this.hint,
    this.targetServer,
    this.completedBy,
    this.confirmLabel = 'Confirm',
    this.blockedReason,
    this.error,
    this.busy = false,
    this.onConfirm,
    this.titleParts,
    this.body = const [],
    this.completedResult,
    this.completedAction,
    this.icon,
    this.headerDescription,
    this.statusLabel,
    this.statusVariant,
    this.warning,
    this.collapsible = false,
    this.defaultExpanded = true,
    this.hideConfirmAction = false,
  });

  /// ActionTitleLine pieces joined into the card's heading when [title] is empty.
  final List<String>? titleParts;

  /// Body rows rendered inside [MessageActionCardContent].
  final List<Widget> body;

  /// ResultLink after "Committed by": the `→ ...` produced resource.
  final String? completedResult;

  /// A follow-up action under the completed line (the installed App's
  /// "Continue setup" button).
  final Widget? completedAction;
  final String title, state, confirmLabel;
  final List<({String label, String value})> details;
  final String? hint, targetServer, completedBy, blockedReason, error;
  final bool busy;
  final VoidCallback? onConfirm;

  /// Optional v1.24 header icon (`CircleHelp` for view-only/unknown cards).
  final RaftGlyph? icon;

  /// Optional header description line (replaces committedBy when provided).
  final String? headerDescription;

  /// Optional explicit status label & tone (defaults from [state]).
  final String? statusLabel;
  final RaftStatusVariant? statusVariant;

  /// Optional standing notice rendered at top of content (`MessageActionCardNotice`).
  final String? warning;

  /// Whether the card exposes a header disclosure toggle (`UnknownActionCard`).
  final bool collapsible;
  final bool defaultExpanded;

  /// View-only cards (`UnknownActionCard`) omit the confirm action row.
  final bool hideConfirmAction;

  @override
  State<RaftActionCard> createState() => _RaftActionCardState();
}

class _RaftActionCardState extends State<RaftActionCard> {
  late bool _expanded = widget.defaultExpanded;

  @override
  void didUpdateWidget(covariant RaftActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.defaultExpanded != oldWidget.defaultExpanded ||
        widget.collapsible != oldWidget.collapsible) {
      _expanded = widget.defaultExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RaftSpecActionCardContent(context);
    final done = widget.state == 'executed';
    final frozen = widget.state == 'frozen';
    final heading = widget.titleParts != null && widget.titleParts!.isNotEmpty
        ? widget.titleParts!.join(' ')
        : widget.title;

    InlineSpan? descriptionSpan;
    if (widget.headerDescription != null &&
        widget.headerDescription!.isNotEmpty) {
      descriptionSpan = TextSpan(text: widget.headerDescription);
    } else if (done && widget.completedBy != null) {
      final template = raftFormat(context, 'Committed by {name}', {
        'name': '\uFFFC',
      });
      final parts = template.split('\uFFFC');
      descriptionSpan = TextSpan(
        children: [
          TextSpan(text: parts.first),
          content.completionName(widget.completedBy!),
          if (parts.length > 1) TextSpan(text: parts.sublist(1).join('\uFFFC')),
          if (widget.completedResult != null)
            content.completionName(' ${widget.completedResult}'),
        ],
      );
    }

    final statusText =
        widget.statusLabel ??
        (done
            ? raftText(context, 'Done')
            : frozen
            ? raftText(context, 'Frozen')
            : null);
    final statusTone =
        widget.statusVariant ??
        (done ? RaftStatusVariant.success : RaftStatusVariant.muted);

    final children = <Widget>[
      if (widget.warning != null && widget.warning!.isNotEmpty)
        content.notice(widget.warning!),
      ...widget.body,
      if (widget.details.isNotEmpty)
        content.properties([
          for (final d in widget.details)
            RaftDescriptionEntry(raftText(context, d.label), d.value),
        ]),
      if (widget.targetServer != null)
        RaftCssText(
          raftFormat(context, 'Runs on {server}', {
            'server': widget.targetServer!,
          }),
          style: content.text(content.slots.propertyValue),
        ),
      if (widget.hint != null && widget.hint!.isNotEmpty)
        content.hint(body: widget.hint!),
      if (done && widget.completedAction != null)
        Align(alignment: Alignment.centerLeft, child: widget.completedAction),
      if (widget.error != null) RaftErrorBanner(widget.error!, small: true),
      if (!done && !widget.hideConfirmAction)
        content.actions([
          if (widget.blockedReason != null)
            RaftCssText(
              raftText(context, widget.blockedReason!),
              style: content.text(content.slots.actionsNote),
            ),
          RaftButton(
            uiVariant: RaftButtonVariant.accent,
            uiSize: RaftButtonSize.sm,
            label: widget.busy
                ? '…'
                : frozen
                ? 'Frozen'
                : widget.state == 'reconfirm_required'
                ? 'Reconfirm'
                : widget.confirmLabel,
            disabled: frozen || widget.blockedReason != null,
            onPressed: widget.busy ? null : widget.onConfirm,
          ),
        ]),
    ];

    final hasBody = children.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: RaftSpecActionCard(
        icon: widget.icon,
        title: heading,
        descriptionSpan: descriptionSpan,
        status: statusText,
        statusVariant: statusTone,
        expanded: widget.collapsible ? _expanded : hasBody,
        onToggle: widget.collapsible
            ? () => setState(() => _expanded = !_expanded)
            : null,
        body: hasBody ? content.column(children) : const SizedBox.shrink(),
      ),
    );
  }
}

/// One ActionDetail row using canonical [RaftMessageActionCardContentRecipe]
/// `propertyLabel` / `propertyValue` typography.
class RaftActionField extends StatelessWidget {
  const RaftActionField({
    super.key,
    required this.label,
    this.value,
    this.child,
  });
  final String label;
  final String? value;

  /// A block value (scope list) below the label instead of an inline [value].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = RaftSpecActionCardContent(context);
    final labelStyle = content.text(content.slots.propertyLabel);
    final valueStyle = content.text(content.slots.propertyValue);
    final labelWidget = RaftCssText(
      raftText(context, label),
      style: labelStyle,
    );
    if (child != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: RaftSpace.x1,
        children: [labelWidget, child!],
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: raftText(context, label), style: labelStyle),
          const TextSpan(text: ' '),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
    );
  }
}

/// A note line inside an action card using semantic v1.24 tokens.
class RaftActionNote extends StatelessWidget {
  const RaftActionNote(
    this.text, {
    super.key,
    this.tone = RaftActionTone.strong,
  });
  final String text;
  final RaftActionTone tone;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final color = switch (tone) {
      RaftActionTone.orange || RaftActionTone.amber => ui['warning-strong'],
      RaftActionTone.strong => ui.foreground,
      RaftActionTone.hint => ui.foregroundHint,
    };
    return RaftCssText(
      raftText(context, text),
      style: t.scale(
        RaftTypeScale.footnote,
        weight: tone == RaftActionTone.hint ? FontWeight.w400 : FontWeight.w600,
        color: color,
      ),
    );
  }
}

/// Standing caveat notice inside an action card, matching Web v1.24
/// `MessageActionCardNotice` (`rounded-control bg-fill-muted px-2.5 py-2`).
class RaftActionWarningBox extends StatelessWidget {
  const RaftActionWarningBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      RaftSpecActionCardContent(context).notice(raftText(context, text));
}

/// `hint` is the regular-weight `text-foreground-hint` line.
enum RaftActionTone { orange, amber, strong, hint }

/// Canonical `MessageActionCardScopeList`: `rounded-control border
/// border-line-hairline bg-layer-card px-2.5 py-2` per visible OAuth scope.
class RaftActionScopeList extends StatelessWidget {
  const RaftActionScopeList({
    super.key,
    required this.scopes,
    this.footer = const [],
  });
  final List<({String scope, String copy})> scopes;

  /// Trailing blocks (`Will send to`, the inbound-scope warning).
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final content = RaftSpecActionCardContent(context);
    final slots = content.slots;
    final nameStyle = content.text(slots.scopeName);
    final descriptionStyle = content.text(slots.scopeDescription);
    final gap = slots.scopeListViewportContent.rowGap ?? RaftSpace.x1_5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        for (final s in scopes)
          RaftRecipeBox(
            style: slots.scope,
            tokens: content.tokens.recipeTokens,
            applyText: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: slots.scopeDescription.margin.top,
              children: [
                RaftCssText(s.scope, style: nameStyle),
                if (s.copy.isNotEmpty)
                  RaftCssText(
                    raftText(context, s.copy),
                    style: descriptionStyle,
                  ),
              ],
            ),
          ),
        ...footer,
      ],
    );
  }
}
