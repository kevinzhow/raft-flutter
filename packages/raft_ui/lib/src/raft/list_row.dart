// Published raft-ui 0.7.0 `ListRow`: one row of a list. Children are the leading block (an avatar, `RaftListRowIcon`), a
// `RaftListRowBody` (title / description, or a top and a bottom line) and whatever trails (a value, a badge, a
// switch, `RaftListRowChevron`). Rows are `gap-3 px-4 py-3`; the `default` variant is at least 64px and rules off
// at 63px, `plain` rules off at 16px, `entry` has no rule. `selected` fills `info-soft`; `tone` sets the ink.
import 'package:flutter/material.dart';
import 'package:raft_theme/recipes/recipe_utilities.g.dart' as source;

import '../design_primitives.dart';
import '../indicators.dart';
import '../interaction.dart';
import '../icons.dart';
import '../localization.dart';
import '../recipe_surface.dart';
import '../recipes/list_row.g.dart';
import '../recipes/list_row_skeleton.g.dart';
import '../recipes/recipe_runtime.dart';
import '../surface_background_scope.dart';
import '../theme.dart';
import 'ui_tokens.dart';

/// `variant` axis of `listRow`.
enum RaftListRowVariant { standard, plain, entry }

/// `tone` axis: `unread` bolds the title and inks the description, `muted` and `away` fade the row.
enum RaftListRowTone { normal, unread, muted, away, warning, danger }

/// The three inks a row hands to its parts (`--list-row-ink`, `-ink-2`, `-ink-3`).
@immutable
class RaftListRowInk {
  const RaftListRowInk(this.ink, this.ink2, this.ink3);
  final Color ink, ink2, ink3;

  static RaftListRowInk resolve(
    RaftUiColors ui, {
    RaftListRowTone tone = RaftListRowTone.normal,
    bool disabled = false,
  }) {
    if (disabled) {
      return RaftListRowInk(
        ui.foregroundDisabled,
        ui.foregroundDisabled,
        ui.foregroundDisabled,
      );
    }
    return switch (tone) {
      RaftListRowTone.normal ||
      RaftListRowTone.warning ||
      RaftListRowTone.danger => RaftListRowInk(
        ui.foreground,
        ui.foregroundMuted,
        ui.foregroundHint,
      ),
      RaftListRowTone.unread => RaftListRowInk(
        ui.foreground,
        ui.foreground,
        ui.foregroundHint,
      ),
      RaftListRowTone.muted => RaftListRowInk(
        ui.foregroundMuted,
        ui.foregroundMuted,
        ui.foregroundHint,
      ),
      RaftListRowTone.away => RaftListRowInk(
        ui.foregroundHint,
        ui.foregroundHint,
        ui.foregroundHint,
      ),
    };
  }
}

class _ListRowScope extends InheritedWidget {
  const _ListRowScope({
    required this.ink,
    required this.tone,
    required this.contentWidth,
    this.recipe,
    required super.child,
  });
  final RaftListRowInk ink;
  final RaftListRowTone tone;

  /// Width of the row's content box (for `max-w-[45%]`).
  final double contentWidth;
  final RaftListRowRecipeStyle? recipe;

  static _ListRowScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ListRowScope>();

  @override
  bool updateShouldNotify(_ListRowScope old) =>
      ink != old.ink ||
      tone != old.tone ||
      contentWidth != old.contentWidth ||
      recipe != old.recipe;
}

final _sourceIndices = {
  for (var i = 0; i < source.raftRecipeUtilities.length; i++)
    source.raftRecipeUtilities[i].name: i,
};

bool _unbound(CssValue value) => switch (value) {
  CssUnset() => true,
  CssCalc(:final expr) => _unbound(expr),
  CssOp(:final a, :final b) => _unbound(a) || _unbound(b),
  CssFunction(:final args) => args.any(_unbound),
  CssList(:final items) || CssSeq(:final items) => items.any(_unbound),
  _ => false,
};

// The CSS row's custom properties inherit into its separate child elements.
// Reuse the generated cascade to fill only unresolved values; preserve every
// already-resolved value and theme binding on the child's original style.
RaftSlotStyle _inheritRowVariables(RaftSlotStyle slot, RaftSlotStyle root) {
  final variables = {
    for (final entry in root.properties.entries)
      if (entry.key.startsWith('--list-row-')) entry.key: entry.value,
  };
  final projected =
      RaftRecipeEngine(source.raftRecipeUtilities, {
        ...source.raftRecipeEngine.registered,
        ...variables,
      }).resolveSlot(
        [for (final name in slot.classes) _sourceIndices[name]!],
        slot.context!.states,
        slot.tokens,
      );
  Map<String, CssValue> fill(
    Map<String, CssValue> original,
    Map<String, CssValue> inherited,
  ) => {
    for (final entry in original.entries)
      entry.key: _unbound(entry.value)
          ? inherited[entry.key] ?? entry.value
          : entry.value,
  };
  return slot.copyWith(
    properties: fill(slot.properties, projected.properties),
    targets: {
      for (final target in slot.targets.entries)
        target.key: fill(
          target.value,
          projected.targets[target.key] ?? const {},
        ),
    },
  );
}

RaftSlotStyle _part(
  BuildContext context,
  RaftSlotStyle Function(RaftListRowRecipeStyle) select, {
  bool wrap = false,
}) {
  final t = RaftTokens.of(context);
  final scope = _ListRowScope.maybeOf(context);
  final recipe = wrap
      ? RaftListRowRecipe.resolve(
          wrap: true,
          states: scope?.recipe?.root.context?.states ?? t.recipeStates(),
          tokens: t.recipeTokens,
        )
      : scope?.recipe ??
            RaftListRowRecipe.resolve(
              states: t.recipeStates(),
              tokens: t.recipeTokens,
            );
  return _inheritRowVariables(
    select(recipe),
    scope?.recipe?.root ?? recipe.root,
  );
}

TextStyle _partText(BuildContext context, RaftSlotStyle slot) => slot.text(
  RaftTokens.of(context).recipeTokens,
  base: DefaultTextStyle.of(context).style.copyWith(color: _inkOf(context).ink),
);

RaftListRowInk _inkOf(BuildContext context) =>
    _ListRowScope.maybeOf(context)?.ink ??
    RaftListRowInk.resolve(RaftTokens.of(context).ui);

/// `ListRow`. Without [onPressed] the row still looks like a button (it is one in the web kit); [interactive]
/// false is the `div` row that hosts its own control (a switch).
class RaftListRow extends StatelessWidget {
  const RaftListRow({
    super.key,
    required this.children,
    this.variant = RaftListRowVariant.standard,
    this.tone = RaftListRowTone.normal,
    this.selected = false,
    this.interactive = true,
    this.disabled = false,
    this.onPressed,
    this.topRule = false,
    this.attached = false,
    this.afterTarget = false,
    this.focusNode,
    this.semanticLabel,
  });

  final List<Widget> children;
  final RaftListRowVariant variant;
  final RaftListRowTone tone;
  final bool selected;

  /// `interactive={false}`: no hover wash, no button.
  final bool interactive;
  final bool disabled;
  final VoidCallback? onPressed;

  /// The hairline above the row (`[data-slot=list-row]+&` / `li+li>&`): drawn from the rule start to the right
  /// edge. [RaftListRowGroup] and [RaftListRowList] set it on every row after the first.
  final bool topRule;

  /// `attached`: the row belongs to the interactive row above it (an inset
  /// settings panel under its switch). It has no hairline above and, when
  /// `plain`, no top padding.
  final bool attached;

  /// Set by [RaftListRowList]: the row above is interactive and not attached
  /// (`[[data-slot=list-row][data-interactive]:not([data-attached])+&]`), the
  /// only case where a display-only attached row keeps its rule and top pad.
  final bool afterTarget;
  final FocusNode? focusNode;
  final String? semanticLabel;

  RaftListRow copyWith({bool? topRule, bool? afterTarget}) => RaftListRow(
    key: key,
    variant: variant,
    tone: tone,
    selected: selected,
    interactive: interactive,
    disabled: disabled,
    onPressed: onPressed,
    topRule: topRule ?? this.topRule,
    attached: attached,
    afterTarget: afterTarget ?? this.afterTarget,
    focusNode: focusNode,
    semanticLabel: semanticLabel,
    children: children,
  );

  /// `--list-row-rule-start`.
  double get ruleStart => variant == RaftListRowVariant.standard ? 63 : 16;

  Widget _recipeBody(BuildContext context, RaftInteractionState interaction) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final states = t.recipeStates(
      hovered: interaction.hovered,
      pressed: interaction.pressed,
      focusVisible: interaction.focusVisible,
      disabled: disabled,
      responsive: true,
      pointerCoarse: RaftInteraction.of(context).touch,
      extra: {
        if (selected) 'data-selected',
        if (tone != RaftListRowTone.normal) 'data-tone=${tone.name}',
        if (tone != RaftListRowTone.normal)
          'group/list-row:data-tone=${tone.name}',
        if (topRule && !attached) 'ancestor:data-slot=list-row',
        if (topRule && attached && afterTarget)
          'ancestor:data-slot=list-row+data-interactive+not:data-attached',
      },
    );
    final recipe = RaftListRowRecipe.resolve(
      variant: switch (variant) {
        RaftListRowVariant.standard => RaftListRowRecipeVariant.default_,
        RaftListRowVariant.plain => RaftListRowRecipeVariant.plain,
        RaftListRowVariant.entry => RaftListRowRecipeVariant.entry,
      },
      interactive: interactive,
      attached: attached,
      states: states,
      tokens: tokens,
    );
    Color ink(String property) =>
        RaftColorRef.fromCss(recipe.root[property])!.resolve(tokens);
    final inherited = RaftListRowInk(
      ink('--list-row-ink'),
      ink('--list-row-ink-2'),
      ink('--list-row-ink-3'),
    );
    final rowSurface = RaftSurfaceBackgroundScope.of(context);
    final selectedFill = selected
        ? recipe.root.before?.backgroundColor?.resolve(
            tokens,
            currentColor: inherited.ink,
          )
        : null;
    final childSurface =
        selected &&
            selectedFill != null &&
            rowSurface != null &&
            rowSurface.a == 1
        ? (selectedFill.a < 1
              ? raftChromeBlend(selectedFill, rowSurface)
              : selectedFill)
        : null;
    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: recipe.root.columnGap ?? 0),
          children[i] is RaftListRowBody
              ? Expanded(child: children[i])
              : children[i],
        ],
      ],
    );
    final row = LayoutBuilder(
      builder: (context, constraints) => RaftRecipeBox(
        style: recipe.root,
        tokens: tokens,
        width: double.infinity,
        child: _ListRowScope(
          ink: inherited,
          tone: tone,
          recipe: recipe,
          contentWidth: constraints.maxWidth.isFinite
              ? constraints.maxWidth -
                    recipe.root.padding.horizontal -
                    recipe.root.borderWidth.horizontal
              : 0,
          child: childSurface == null
              ? rowContent
              : RaftSurfaceBackgroundScope(
                  color: childSurface,
                  child: rowContent,
                ),
        ),
      ),
    );
    final before = recipe.root.before;
    if (!topRule ||
        before == null ||
        before['display'] is! CssKeyword ||
        (before['display'] as CssKeyword).value == 'none') {
      return row;
    }
    final ruleColor = before.borderColorOf('top')!.resolve(tokens);
    final effectiveRuleColor =
        ruleColor.a < 1 && rowSurface != null && rowSurface.a == 1
        ? raftChromeBlend(ruleColor, rowSurface)
        : ruleColor;
    return Stack(
      children: [
        row,
        Positioned(
          top: before.length('top'),
          left: before.length('left'),
          right: before.length('right'),
          height: before.borderWidth.top,
          child: IgnorePointer(child: ColoredBox(color: effectiveRuleColor)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body(RaftInteractionState st) {
      return _recipeBody(context, st);
    }

    if (!interactive) {
      return Semantics(
        container: true,
        selected: selected,
        label: semanticLabel,
        child: body(const RaftInteractionState()),
      );
    }
    return RaftInteractive(
      onPressed: disabled ? null : onPressed,
      focusNode: focusNode,
      selected: selected,
      semanticLabel: semanticLabel,
      builder: (context, st) => body(st),
    );
  }
}

/// `ListRowBody`: the text column (`flex-1 min-w-0 flex-col gap-0.5`). A direct child of [RaftListRow].
class RaftListRowBody extends StatelessWidget {
  const RaftListRowBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final slot = _part(context, (recipe) => recipe.body);
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: slot.rowGap ?? 2),
          children[i],
        ],
      ],
    );
    return RaftRecipeBox(
      style: slot,
      tokens: RaftTokens.of(context).recipeTokens,
      child: column,
    );
  }
}

Widget _line(BuildContext context, List<Widget> children) {
  // A `truncate` meta is capped at the line (non-flex Row children are unbounded).
  final slot = _part(context, (recipe) => recipe.line);
  final gap = slot.columnGap ?? 8;
  Widget cell(Widget child, double? lineWidth) => switch (child) {
    RaftListRowTitle() ||
    RaftListRowSubtitle() ||
    RaftListRowDescription() => Expanded(child: child),
    _SkeletonText(expands: true) => Expanded(child: child),
    // `min-w-0 truncate`: the title gives way first, then the time is cut.
    RaftListRowMeta() when lineWidth != null => ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (lineWidth - gap * (children.length - 1)).clamp(
          0,
          double.infinity,
        ),
      ),
      child: child,
    ),
    _ => child,
  };
  Widget build(double? lineWidth) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        cell(children[i], lineWidth),
      ],
    ],
  );
  final row = LayoutBuilder(
    builder: (context, c) => build(c.maxWidth.isFinite ? c.maxWidth : null),
  );
  return RaftRecipeBox(
    style: slot,
    tokens: RaftTokens.of(context).recipeTokens,
    child: row,
  );
}

/// `ListRowTop`: the title, then the time.
class RaftListRowTop extends StatelessWidget {
  const RaftListRowTop({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => _line(context, children);
}

/// `ListRowBottom`: the preview, then at most one badge.
class RaftListRowBottom extends StatelessWidget {
  const RaftListRowBottom({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => _line(context, children);
}

/// `ListRowTitle`: 16/24 semibold on one line (bold on an unread row).
class RaftListRowTitle extends StatelessWidget {
  const RaftListRowTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      raftText(context, text),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: _partText(context, _part(context, (recipe) => recipe.title)),
    );
  }
}

/// `ListRowSubtitle`: data about the row's subject under the title (an agent's
/// description, a role, a byline): footnote 400 in the row ink, one line.
class RaftListRowSubtitle extends StatelessWidget {
  const RaftListRowSubtitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = _partText(
      context,
      _part(context, (recipe) => recipe.subtitle),
    );
    return Text(
      raftText(context, text),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// `ListRowDescription`: 14/20 in ink-2; [wrap] lets it take several lines.
class RaftListRowDescription extends StatelessWidget {
  const RaftListRowDescription(this.text, {super.key, this.wrap = false});
  final String text;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      raftText(context, text),
      maxLines: wrap ? null : 1,
      softWrap: wrap,
      overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
      style: _partText(
        context,
        _part(context, (recipe) => recipe.description, wrap: wrap),
      ),
    );
  }
}

/// `ListRowMeta`: machine-written facts in Space Mono 12, ink-3 (the time, a gray count).
class RaftListRowMeta extends StatelessWidget {
  const RaftListRowMeta(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: _partText(context, _part(context, (recipe) => recipe.meta)),
    );
  }
}

/// `ListRowValue`: a setting's current value, 15/20 in ink-3, at most 45% of the row.
class RaftListRowValue extends StatelessWidget {
  const RaftListRowValue(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scope = _ListRowScope.maybeOf(context);
    final width = scope?.contentWidth ?? 0;
    final slot = _part(context, (recipe) => recipe.value);
    final max = slot['max-width'];
    final fraction = max is CssNum && max.unit == '%' ? max.value / 100 : null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width > 0 ? width * (fraction ?? 1) : double.infinity,
      ),
      child: Text(
        raftText(context, text),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: _partText(context, slot),
      ),
    );
  }
}

/// `ListRowIcon`: a 20px leading icon in ink-3.
class RaftListRowIcon extends StatelessWidget {
  const RaftListRowIcon(this.glyph, {super.key});
  final RaftGlyph glyph;

  @override
  Widget build(BuildContext context) {
    return _recipeIcon(context, glyph, (recipe) => recipe.icon);
  }
}

/// `ListRowChevron`: the ink-3 arrow of a row that opens another page.
class RaftListRowChevron extends StatelessWidget {
  const RaftListRowChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return _recipeIcon(
      context,
      RaftGlyph.chevronRight,
      (recipe) => recipe.chevron,
    );
  }
}

Widget _recipeIcon(
  BuildContext context,
  RaftGlyph glyph,
  RaftSlotStyle Function(RaftListRowRecipeStyle) select,
) {
  final tokens = RaftTokens.of(context).recipeTokens;
  final slot = _part(context, select);
  final svg = slot.target('& > svg')!;
  return ExcludeSemantics(
    child: RaftRecipeBox(
      style: slot,
      tokens: tokens,
      child: SizedBox(
        width: svg.width,
        height: svg.height,
        child: RaftIcon(
          glyph,
          size: svg.width!,
          color: slot.foreground(tokens, inherited: _inkOf(context).ink3),
        ),
      ),
    ),
  );
}

List<Widget> _withRules(List<Widget> children) => [
  for (var i = 0; i < children.length; i++)
    children[i] is RaftListRow && i > 0 && children[i - 1] is RaftListRow
        ? (children[i] as RaftListRow).copyWith(
            topRule: true,
            afterTarget: _isTarget(children[i - 1] as RaftListRow),
          )
        : children[i],
];

/// `[data-slot=list-row][data-interactive]:not([data-attached])`.
bool _isTarget(RaftListRow row) => row.interactive && !row.attached;

/// A plain stack of rows (a `div` of `ListRow`s): the rule above every row after the first.
class RaftListRowList extends StatelessWidget {
  const RaftListRowList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _withRules(children),
  );
}

/// `ListRowGroup`: rows wrapped in a card (`layer-card`, 1px `line-hairline`, `rounded-container`).
class RaftListRowGroup extends StatelessWidget {
  const RaftListRowGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final group = RaftListRowRecipe.resolve(
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).group;
    return RaftRecipeBox(
      declareSurface: true,
      style: group,
      tokens: t.recipeTokens,
      clip: true,
      child: RaftListRowList(children: children),
    );
  }
}

/// `ListRowSkeleton`: a display-only [RaftListRow] of the same [variant] with a
/// bar in its title, its time and its description, so it is the loaded row's
/// height and its rule sits in the same place. Bars take `45 / 35 / 55%`
/// (title) and `75 / 60 / 70%` (description) by the row's [index] in its list
/// (`nth-[3n+2]`, `nth-[3n]`). Hidden from assistive technology.
class RaftListRowSkeleton extends StatelessWidget {
  const RaftListRowSkeleton({
    super.key,
    this.variant = RaftListRowVariant.standard,
    this.index = 0,
    this.leading,
    this.description,
  });

  final RaftListRowVariant variant;

  /// Position in the list; picks the bar widths.
  final int index;

  /// A leading block: the 35px avatar (`default`) or 20px icon. Defaults to
  /// on for the `default` variant, as in raft-ui.
  final bool? leading;

  /// The description bar. Defaults to on for the `default` variant.
  final bool? description;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftListRowSkeletonRecipe.resolve(
      states: t.recipeStates(
        extra: [
          if (index % 3 == 1) 'nth-child(3n+2)',
          if (index % 3 == 2) 'nth-child(3n)',
        ],
      ),
      tokens: t.recipeTokens,
    );
    double percent(String property) {
      final v = recipe.row[property];
      return v is CssNum ? v.value / 100 : 1;
    }

    final standard = variant == RaftListRowVariant.standard;
    final lead = standard ? recipe.avatar : recipe.icon;
    return ExcludeSemantics(
      child: RaftListRow(
        variant: variant,
        interactive: false,
        children: [
          if (leading ?? standard)
            RaftSkeleton(
              key: const ValueKey('list-row-skeleton-leading'),
              fromRecipe: true,
              width: lead.width,
              height: lead.height,
            ),
          RaftListRowBody(
            children: [
              RaftListRowTop(
                children: [
                  _SkeletonText(
                    slot: (r) => r.title,
                    fraction: percent('--list-row-skeleton-title'),
                    barKey: const ValueKey('list-row-skeleton-title'),
                  ),
                  if (standard)
                    _SkeletonText(
                      slot: (r) => r.meta,
                      width: recipe.metaBar.width,
                      barKey: const ValueKey('list-row-skeleton-meta'),
                    ),
                ],
              ),
              if (description ?? standard)
                RaftListRowBottom(
                  children: [
                    _SkeletonText(
                      slot: (r) => r.description,
                      fraction: percent('--list-row-skeleton-description'),
                      barKey: const ValueKey('list-row-skeleton-description'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One text line of a skeleton: the part's own line box, holding a bar
/// `inline-block h-[0.75em] max-w-full align-middle` of a fraction of the box
/// or a fixed width.
class _SkeletonText extends StatelessWidget {
  const _SkeletonText({
    required this.slot,
    required this.barKey,
    this.fraction,
    this.width,
  });
  final RaftSlotStyle Function(RaftListRowRecipeStyle) slot;
  final Key barKey;
  final double? fraction, width;

  bool get expands => width == null;

  @override
  Widget build(BuildContext context) {
    final style = _partText(context, _part(context, slot));
    final em = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 16);
    Widget text(double? boxWidth) => Text.rich(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: RaftSkeleton(
          key: barKey,
          variant: RaftSkeletonVariant.line,
          fromRecipe: true,
          width: width ?? (boxWidth ?? 0) * (fraction ?? 1),
          height: em * .75,
        ),
      ),
      maxLines: 1,
      style: style,
    );
    if (!expands) return text(null);
    return LayoutBuilder(builder: (context, c) => text(c.maxWidth));
  }
}
