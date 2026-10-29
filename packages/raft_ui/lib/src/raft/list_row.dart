// Published raft-ui 0.7.0 `ListRow`: one row of a list. Children are the leading block (an avatar, `RaftListRowIcon`), a
// `RaftListRowBody` (title / description, or a top and a bottom line) and whatever trails (a value, a badge, a
// switch, `RaftListRowChevron`). Rows are `gap-3 px-4 py-3`; the `default` variant is at least 64px and rules off
// at 63px, `plain` rules off at 16px, `entry` has no rule. `selected` fills `info-soft`; `tone` sets the ink.
import 'package:flutter/material.dart';
import 'package:raft_theme/recipes/recipe_utilities.g.dart' as source;

import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../recipe_surface.dart';
import '../recipes/list_row.g.dart';
import '../recipes/recipe_runtime.dart';
import '../theme.dart';
import '../tokens/tokens.dart';
import 'css_box.dart';
import 'ui_tokens.dart';

/// `variant` axis of `listRow`.
enum RaftListRowVariant { standard, plain, entry }

/// `tone` axis: `unread` bolds the title and inks the description, `muted` and `away` fade the row.
enum RaftListRowTone { normal, unread, muted, away }

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
      RaftListRowTone.normal => RaftListRowInk(
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

bool _modern(BuildContext context) =>
    RaftTokens.of(context).recipeTokens.recipeSet == RaftRecipeSet.raft;

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
  final FocusNode? focusNode;
  final String? semanticLabel;

  RaftListRow copyWith({bool? topRule}) => RaftListRow(
    key: key,
    variant: variant,
    tone: tone,
    selected: selected,
    interactive: interactive,
    disabled: disabled,
    onPressed: onPressed,
    topRule: topRule ?? this.topRule,
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
      extra: {
        if (selected) 'data-selected',
        if (tone != RaftListRowTone.normal) 'data-tone=${tone.name}',
        if (tone != RaftListRowTone.normal)
          'group/list-row:data-tone=${tone.name}',
        if (topRule) 'ancestor:data-slot=list-row',
      },
    );
    final recipe = RaftListRowRecipe.resolve(
      variant: switch (variant) {
        RaftListRowVariant.standard => RaftListRowRecipeVariant.default_,
        RaftListRowVariant.plain => RaftListRowRecipeVariant.plain,
        RaftListRowVariant.entry => RaftListRowRecipeVariant.entry,
      },
      interactive: interactive,
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: recipe.root.columnGap ?? 0),
                children[i] is RaftListRowBody
                    ? Expanded(child: children[i])
                    : children[i],
              ],
            ],
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
    return Stack(
      children: [
        row,
        Positioned(
          top: before.length('top'),
          left: before.length('left'),
          right: before.length('right'),
          height: before.borderWidth.top,
          child: IgnorePointer(
            child: ColoredBox(
              color: before.borderColorOf('top')!.resolve(tokens),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = RaftTokens.of(context).ui;
    final ink = RaftListRowInk.resolve(ui, tone: tone, disabled: disabled);
    final pressable = interactive && !disabled && onPressed != null;
    Widget body(RaftInteractionState st) {
      if (_modern(context)) return _recipeBody(context, st);
      final wash = pressable && !selected && (st.hovered || st.pressed);
      final fill = selected
          ? ui['info-soft']
          : wash
          ? ui.fillPressed
          : const Color(0x00000000);
      Widget row = LayoutBuilder(
        builder: (context, box) {
          final contentWidth = box.maxWidth.isFinite ? box.maxWidth - 32 : 0.0;
          return _ListRowScope(
            ink: ink,
            tone: tone,
            contentWidth: contentWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  children[i] is RaftListRowBody
                      ? Expanded(child: children[i])
                      : children[i],
                ],
              ],
            ),
          );
        },
      );
      row = ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: variant == RaftListRowVariant.standard ? 64 : 0,
        ),
        child: RaftCssBox(
          fill: fill,
          insetRingWidth: st.focusVisible ? 2 : 0,
          insetRingColor: ui.foreground,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.center,
          child: row,
        ),
      );
      // `entry` rows have no `before:` rule at all.
      if (!topRule || variant == RaftListRowVariant.entry) return row;
      return Stack(
        children: [
          row,
          Positioned(
            top: 0,
            left: ruleStart,
            right: 0,
            height: 1,
            child: IgnorePointer(child: ColoredBox(color: ui.lineHairline)),
          ),
        ],
      );
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
    final slot = _modern(context)
        ? _part(context, (recipe) => recipe.body)
        : null;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: slot?.rowGap ?? 2),
          children[i],
        ],
      ],
    );
    return slot == null
        ? column
        : RaftRecipeBox(
            style: slot,
            tokens: RaftTokens.of(context).recipeTokens,
            child: column,
          );
  }
}

Widget _line(BuildContext context, List<Widget> children) {
  final slot = _modern(context)
      ? _part(context, (recipe) => recipe.line)
      : null;
  final row = Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: slot?.columnGap ?? 8),
        children[i] is RaftListRowTitle || children[i] is RaftListRowDescription
            ? Expanded(child: children[i])
            : children[i],
      ],
    ],
  );
  return slot == null
      ? row
      : RaftRecipeBox(
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
    final t = RaftTokens.of(context);
    if (_modern(context)) {
      return Text(
        raftText(context, text),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: _partText(context, _part(context, (recipe) => recipe.title)),
      );
    }
    final scope = _ListRowScope.maybeOf(context);
    final unread = scope?.tone == RaftListRowTone.unread;
    // Chromium seats a 16/24 Space Grotesk line box about 0.75px higher than Flutter's half-leading does.
    return Transform.translate(
      offset: const Offset(0, -0.75),
      child: Text(
        raftText(context, text),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: t.scale(
          RaftTypeScale.body,
          weight: unread ? FontWeight.w700 : FontWeight.w600,
          color: _inkOf(context).ink,
        ),
      ),
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
    final t = RaftTokens.of(context);
    return Text(
      raftText(context, text),
      maxLines: wrap ? null : 1,
      softWrap: wrap,
      overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
      style: _modern(context)
          ? _partText(
              context,
              _part(context, (recipe) => recipe.description, wrap: wrap),
            )
          : t.scale(
              RaftTypeScale.callout,
              weight: FontWeight.w400,
              color: _inkOf(context).ink2,
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
    final t = RaftTokens.of(context);
    if (_modern(context)) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: _partText(context, _part(context, (recipe) => recipe.meta)),
      );
    }
    // Chromium rounds Space Mono's ascent and descent at 12px, which seats the line box 1px higher.
    return Transform.translate(
      offset: const Offset(0, -1),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: t
            .scale(
              RaftTypeScale.monoMeta,
              mono: true,
              weight: FontWeight.w400,
              color: _inkOf(context).ink3,
            )
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// `ListRowValue`: a setting's current value, 15/20 in ink-3, at most 45% of the row.
class RaftListRowValue extends StatelessWidget {
  const RaftListRowValue(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final scope = _ListRowScope.maybeOf(context);
    final width = scope?.contentWidth ?? 0;
    final slot = _modern(context)
        ? _part(context, (recipe) => recipe.value)
        : null;
    final max = slot?['max-width'];
    final fraction = max is CssNum && max.unit == '%' ? max.value / 100 : null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width > 0
            ? width * (slot == null ? .45 : fraction ?? 1)
            : double.infinity,
      ),
      child: Text(
        raftText(context, text),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: slot == null
            ? t.scale(
                RaftTypeScale.subhead,
                weight: FontWeight.w400,
                color: _inkOf(context).ink3,
              )
            : _partText(context, slot),
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
    if (_modern(context))
      return _recipeIcon(context, glyph, (recipe) => recipe.icon);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 20,
        child: RaftIcon(glyph, size: 20, color: _inkOf(context).ink3),
      ),
    );
  }
}

/// `ListRowChevron`: the ink-3 arrow of a row that opens another page.
class RaftListRowChevron extends StatelessWidget {
  const RaftListRowChevron({super.key});

  @override
  Widget build(BuildContext context) {
    if (_modern(context))
      return _recipeIcon(
        context,
        RaftGlyph.chevronRight,
        (recipe) => recipe.chevron,
      );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 20,
        child: RaftIcon(
          RaftGlyph.chevronRight,
          size: 20,
          color: _inkOf(context).ink3,
        ),
      ),
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
        ? (children[i] as RaftListRow).copyWith(topRule: true)
        : children[i],
];

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
    if (_modern(context)) {
      final t = RaftTokens.of(context);
      final group = RaftListRowRecipe.resolve(
        states: t.recipeStates(),
        tokens: t.recipeTokens,
      ).group;
      return RaftRecipeBox(
        style: group,
        tokens: t.recipeTokens,
        clip: true,
        child: RaftListRowList(children: children),
      );
    }
    final ui = RaftTokens.of(context).ui;
    final border = raftControlBorderPx(context, 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.layerCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ui.lineHairline, width: border),
      ),
      child: Padding(
        padding: EdgeInsets.all(border),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10 - border),
          child: RaftListRowList(children: children),
        ),
      ),
    );
  }
}
