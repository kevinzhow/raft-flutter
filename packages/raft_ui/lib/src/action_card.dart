import 'package:flutter/material.dart';
import 'package:raft_theme/recipes/recipe_runtime.dart';

import 'design_primitives.dart' show RaftInteractive, RaftTypography;
import 'error_presentation.dart' show RaftErrorBanner;
import 'dialog_card.dart' show RaftRecipeButton;
import 'recipes/button_variants.g.dart';
import 'recipes/message_action_card.g.dart';
import 'recipes/message_action_card_content.g.dart';
import 'recipes/message_card.g.dart';
import 'panel_layout.dart' show RaftCssText;
import 'agent_subagents.dart' show RaftDescriptionEntry;
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
import 'rich_card_tokens.dart';
import 'text_measure.dart';
import 'text_scaling.dart' show RaftScaled;
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
      final lines = MediaQuery.textScalerOf(
        context,
      ).scale(style.fontSize ?? 14);
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
    states: tokens.recipeStates(),
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
        // The Web separator is inline generated text. Keep the placeholder
        // from introducing break points between the preceding word and date.
        const TextSpan(text: wordJoiner),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x1),
            child: RaftCssText('·', style: style),
          ),
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
    return Container(
      decoration: slots.notice.decoration(tokens.recipeTokens),
      padding: slots.notice.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: slots.notice.columnGap ?? RaftSpace.x2,
        children: [
          RaftIcon(RaftGlyph.info, size: 14, color: style.color),
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

/// A safe presentation of server-owned action metadata. Execution and current
/// permissions belong to the application adapter, never this component.
class RaftActionCard extends StatelessWidget {
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
  });

  /// ActionTitleLine: the title as `flex flex-wrap items-center gap-2` items
  /// (text pieces and bold chunks), instead of the single [title] string.
  final List<String>? titleParts;

  /// ActionDetail rows (`mt-1 text-xs text-foreground-muted`, `space-y-0.5`).
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

  /// ActionTitleLine: `flex flex-wrap items-center gap-2` of the title items
  /// and, when done, the `ml-auto` Done badge (alone on its line when the
  /// items leave no room for it).
  Widget _titleLine(
    BuildContext context,
    List<String> parts,
    Widget? badge,
    ActionSnapshotRecipe recipe,
  ) {
    final style = recipe.title.copyWith(height: 19.25 / 14);
    Widget item(String part) =>
        // `leading-snug` (19.25px) is fractional; a Text would round the line
        // up to 20.
        RaftScaled.lineBox(
          context,
          height: 19.25,
          child: Text(part, style: style),
        );
    Wrap items() => Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final part in parts) item(part)],
    );
    if (badge == null) return items();
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(String text, [TextStyle? textStyle]) =>
            raftTextWidth(TextSpan(text: text, style: textStyle ?? style));
        final used =
            parts.fold<double>(0, (a, p) => a + width(p)) +
            8 * (parts.length - 1);
        final badgeWidth =
            recipe.badgeInset.horizontal +
            2 +
            10 +
            recipe.badgeGap +
            width('DONE', recipe.badge);
        if (used + 8 + badgeWidth <= constraints.maxWidth) {
          return Row(
            spacing: 8,
            children: [
              for (final part in parts) item(part),
              const Spacer(),
              badge,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            items(),
            Align(alignment: Alignment.centerRight, child: badge),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final done = state == 'executed', frozen = state == 'frozen';
    final recipe = ActionSnapshotRecipe(t);
    final badge = Semantics(
      label: raftText(context, 'Done'),
      child: Container(
        key: const ValueKey('action-success-badge'),
        height: recipe.badgeHeight,
        padding: recipe.badgeInset,
        decoration: recipe.badgeDecoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftIcon(RaftGlyph.check, size: 10, color: recipe.badge.color),
            SizedBox(width: recipe.badgeGap),
            Text(raftText(context, 'Done'), style: recipe.badge),
          ],
        ),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(
          top: RaftMessageBodyMargin.collapse(context, recipe.topGap),
        ),
        child: _ActionFrame(
          child: Padding(
            padding: recipe.inset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titleParts == null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(title, style: recipe.title)),
                      if (done) ...[const SizedBox(width: 8), badge],
                    ],
                  )
                else
                  _titleLine(context, titleParts!, done ? badge : null, recipe),
                if (body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DefaultTextStyle(
                      style: recipe.summary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: body,
                      ),
                    ),
                  ),
                for (final d in details)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        style: recipe.summary,
                        children: [
                          TextSpan(text: '${raftText(context, d.label)}: '),
                          TextSpan(text: d.value, style: recipe.detailValue),
                        ],
                      ),
                    ),
                  ),
                if (targetServer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      raftFormat(context, 'Runs on {server}', {
                        'server': targetServer!,
                      }),
                    ),
                  ),
                if (hint != null && hint!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(left: recipe.hintBorder),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: recipe.hintInset),
                        child: Text(hint!, style: recipe.hint),
                      ),
                    ),
                  ),
                if (done && completedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Builder(
                      builder: (context) {
                        final template = raftFormat(
                          context,
                          'Committed by {name}',
                          {'name': '\uFFFC'},
                        );
                        final parts = template.split('\uFFFC');
                        return Text.rich(
                          TextSpan(
                            style: recipe.committed,
                            children: [
                              TextSpan(text: parts.first),
                              TextSpan(
                                text: completedBy!,
                                style: recipe.committedName,
                              ),
                              if (parts.length > 1)
                                TextSpan(text: parts.sublist(1).join('\uFFFC')),
                              if (completedResult != null)
                                TextSpan(
                                  text: ' $completedResult',
                                  style: recipe.committedName,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (done && completedAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: completedAction,
                    ),
                  ),
                if (error != null)
                  // Web `<Banner intent="warning" density="sm" className="mt-1">`.
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: RaftErrorBanner(error!, small: true),
                  ),
                if (!done)
                  Padding(
                    // `mt-2 flex flex-wrap items-center gap-x-3 gap-y-1`
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RaftRecipeButton(
                          variant: RaftButtonRecipeVariant.accent,
                          size: RaftButtonRecipeSize.sm,
                          label: busy
                              ? '…'
                              : frozen
                              ? 'Frozen'
                              : state == 'reconfirm_required'
                              ? 'Reconfirm'
                              : confirmLabel,
                          disabled: frozen || blockedReason != null,
                          onPressed: busy ? null : onConfirm,
                        ),
                        if (blockedReason != null)
                          Text(
                            raftText(context, blockedReason!),
                            style: recipe.summary,
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

/// One ActionDetail row: `<span text-foreground-hint>label</span> <span
/// text-foreground-strong>value</span>`.
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
    final t = RaftTokens.of(context);
    final recipe = ActionSnapshotRecipe(t);
    final labelStyle = recipe.summary.copyWith(
      color: t.colors['foreground-hint'],
    );
    final label = Text(raftText(context, this.label), style: labelStyle);
    if (child != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [label, child!],
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: raftText(context, this.label), style: labelStyle),
          const TextSpan(text: ' '),
          TextSpan(text: value, style: recipe.detailValue),
        ],
      ),
    );
  }
}

/// A bold notice line inside the summary (`font-bold text-brutal-orange`,
/// `text-amber-700`, `text-foreground-strong`).
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
    final recipe = ActionSnapshotRecipe(t);
    final color = switch (tone) {
      RaftActionTone.orange => t.colors['color-brutal-orange'],
      RaftActionTone.amber => const Color(0xFFB45309),
      RaftActionTone.strong => t.strong,
      RaftActionTone.hint => t.colors['foreground-hint'],
    };
    return Text(
      raftText(context, text),
      style: recipe.summary.copyWith(
        fontWeight: tone == RaftActionTone.hint ? null : FontWeight.w700,
        color: color,
      ),
    );
  }
}

/// The inbound-scope caveat box in the scope list footer: `border
/// border-line-hairline bg-warning-soft p-[7px]` around a [RaftActionNote].
class RaftActionWarningBox extends StatelessWidget {
  const RaftActionWarningBox(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.colors['warning-soft'],
        border: Border.all(color: t.colors['line-hairline']!),
      ),
      child: Padding(
        // `p-1.5` plus the 1px `border` (a DecoratedBox border takes no layout space).
        padding: const EdgeInsets.all(RaftSpace.x1_5 + RaftSpace.hairline),
        child: RaftActionNote(text),
      ),
    );
  }
}

/// `hint` is the regular-weight `text-foreground-hint` line.
enum RaftActionTone { orange, amber, strong, hint }

/// ActionScopeList: one `border border-line-hairline bg-layer-inset p-1.5`
/// block per visible OAuth scope (mono name + copy), `mt-1 space-y-1.5`.
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
    final t = RaftTokens.of(context);
    final recipe = ActionSnapshotRecipe(t);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          for (final s in scopes)
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.colors['layer-inset'],
                border: Border.all(color: t.colors['line-hairline']!),
              ),
              child: Padding(
                // `p-1.5` plus the 1px `border` (a DecoratedBox border takes no layout space).
                padding: const EdgeInsets.all(
                  RaftSpace.x1_5 + RaftSpace.hairline,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftScaled.lineBox(
                      context,
                      height: 11 * 4 / 3,
                      child: Text(
                        s.scope,
                        style: RaftTypography.mono(
                          t,
                          size: 11,
                          line: 11 * 4 / 3,
                          color: t.muted,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(raftText(context, s.copy), style: recipe.summary),
                  ],
                ),
              ),
            ),
          ...footer,
        ],
      ),
    );
  }
}

/// The card's frame. The Raft look is the raft-ui `MessageEmbed` (size `item`:
/// radius 10, one hairline, `layer-card`, 400 wide).
class _ActionFrame extends StatelessWidget {
  const _ActionFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RaftMessageEmbedFrame(size: RaftMessageEmbedSize.item, child: child);
  }
}
