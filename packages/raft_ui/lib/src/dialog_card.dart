// Product dialog chrome shared by the channel dialogs: the Web `Modal`
// backdrop (packages/web/src/components/Modal.tsx), `DialogCard`
// (components/ui/DialogCard.tsx), `CloseButton` (components/ui/CloseButton.tsx),
// `FormField` (components/ui/FormField.tsx) and `SectionEyebrow`
// (components/ui/SectionEyebrow.tsx), plus a raft-ui `Button` painted from the
// generated `buttonVariants` recipe with the call-site class overrides those
// dialogs pass (`px-4 py-2 text-sm`, `w-full`, ...).
//
// Values come from the generated recipes (package:raft_ui/recipes.dart) and
// tokens; Tailwind classes written in the Web JSX are resolved in comments.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';
import 'recipes/field.g.dart' as field_recipe;
import 'recipes/label.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/segmented_control.g.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// Tailwind v4 text steps used by the dialogs (`--text-*` and its
/// `--line-height`), in px.
abstract final class RaftTextSteps {
  static const xs = (12.0, 16.0);
  static const sm = (14.0, 20.0);
  static const base = (16.0, 24.0);
  static const lg = (18.0, 28.0);
  static const xl = (20.0, 28.0);
}

/// CSS-like text style: absolute line height with half-leading split evenly.
TextStyle raftCssTextStyle({
  required String family,
  required (double, double) step,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double trackingEm = 0,
}) => TextStyle(
  fontFamily: family,
  fontSize: step.$1,
  height: step.$2 / step.$1,
  fontWeight: weight,
  color: color,
  letterSpacing: trackingEm * step.$1,
  leadingDistribution: TextLeadingDistribution.even,
);

RaftRecipeTheme raftRecipeThemeOf(RaftTokens t) =>
    t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;

/// raft-ui `Button` painted from `buttonVariants`. [padding], [textStep] and
/// [expand] are the JSX `className` overrides (`px-4 py-2`, `text-sm`,
/// `w-full`); [brutalSurface] lets product wrappers (CloseButton) restate
/// their `theme-brutal:` background/border/shadow classes.
class RaftRecipeButton extends StatelessWidget {
  const RaftRecipeButton({
    super.key,
    this.label,
    this.glyph,
    this.glyphSize,
    this.child,
    this.onPressed,
    this.variant = RaftButtonRecipeVariant.default_,
    this.size = RaftButtonRecipeSize.md,
    this.padding,
    this.textStep,
    this.expand = false,
    this.disabled = false,
    this.tooltip,
    this.brutalSurface,
    this.foreground,
    this.gap,
    this.fontWeight,
  });

  /// Callsite `font-bold` etc.
  final FontWeight? fontWeight;
  final String? label;
  final RaftGlyph? glyph;
  final double? glyphSize;
  final Widget? child;
  final VoidCallback? onPressed;
  final RaftButtonRecipeVariant variant;
  final RaftButtonRecipeSize size;
  final EdgeInsets? padding;
  final (double, double)? textStep;
  final bool expand, disabled;
  final String? tooltip;
  final BoxDecoration Function(RaftTokens t, bool hovered)? brutalSurface;
  final Color? foreground;

  /// `gap-*` override of the recipe gap.
  final double? gap;
  @override
  Widget build(BuildContext context) => RaftInteractive(
    onPressed: disabled ? null : onPressed,
    semanticLabel: tooltip,
    builder: (context, state) => _paint(context, state),
  );

  Widget _paint(BuildContext context, RaftInteractionState state) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final root = RaftButtonRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      variant: variant,
      size: size,
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (state.hovered && state.enabled) RaftRecipeStates.hover,
        if (state.pressed && state.enabled) RaftRecipeStates.active,
        if (state.focusVisible) RaftRecipeStates.focusVisible,
        if (disabled) RaftRecipeStates.disabled,
      }),
      tokens: tokens,
    ).root;
    var decoration = root.decoration(tokens);
    if (t.brutal && brutalSurface != null) {
      decoration = brutalSurface!(t, state.hovered && state.enabled);
    }
    final base = root.textStyle(tokens);
    final color = foreground ?? base.color ?? t.ink;
    final step = textStep;
    final text = base.copyWith(
      color: color,
      fontWeight: fontWeight ?? base.fontWeight,
      fontSize: step?.$1 ?? base.fontSize,
      height: step == null ? base.height : step.$2 / step.$1,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final svg = root.target("& svg:not([class*='size-'])");
    final iconSize = glyphSize ?? svg?.width ?? 16;
    final resolvedGap = gap ?? root.columnGap ?? 0;
    Widget content =
        child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) RaftIcon(glyph!, size: iconSize, color: color),
            if (glyph != null && label != null) SizedBox(width: resolvedGap),
            if (label != null)
              Flexible(
                child: Text(
                  raftText(context, label!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text,
                ),
              ),
          ],
        );
    content = DefaultTextStyle.merge(
      style: text,
      child: IconTheme.merge(
        data: IconThemeData(color: color, size: iconSize),
        child: content,
      ),
    );
    final translate = root.translate ?? Offset.zero;
    // With a fixed CSS height the flex item is centred in the content box;
    // symmetric vertical padding (even when it overflows, e.g. `h-7 py-2`)
    // therefore only matters horizontally.
    final resolvedPadding = padding ?? root.padding;
    Widget box = Container(
      height: root.height,
      width: expand ? double.infinity : root.width,
      padding: root.height == null
          ? resolvedPadding
          : EdgeInsets.only(
              left: resolvedPadding.left,
              right: resolvedPadding.right,
            ),
      decoration: decoration,
      // inline-flex: shrink-wraps its content unless `w-full`.
      child: Center(widthFactor: expand ? null : 1, child: content),
    );
    box = Transform.translate(offset: translate, child: box);
    if (root.opacity != null && root.opacity! < 1) {
      box = Opacity(opacity: root.opacity!, child: box);
    }
    return box;
  }
}

/// Web `CloseButton`: ghost `icon-sm` Button with
/// `theme-brutal:border-2 theme-brutal:border-black theme-brutal:shadow-brutal-sm
/// theme-brutal:bg-white theme-brutal:text-black` and an `X`.
class RaftCloseButton extends StatelessWidget {
  const RaftCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Close',
  });
  final VoidCallback? onPressed;
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftRecipeButton(
      variant: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.iconSm,
      // `<X size={20} />`, but the recipe's `& svg:not([class*='size-'])`
      // width/height win over Lucide's size attributes.
      glyph: RaftGlyph.x,
      tooltip: raftText(context, tooltip),
      onPressed: onPressed,
      // text-foreground-muted (elegant) / theme-brutal:text-black.
      foreground: t.brutal ? Colors.black : t.colors['foreground-muted'],
      brutalSurface: (t, hovered) => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: RaftShadowSet.brutalSm,
      ),
    );
  }
}

/// `--shadow-brutal-sm: 2px 2px 0px #141111` (Web index.css @theme).
abstract final class RaftShadowSet {
  static const brutalSm = [
    BoxShadow(color: Color(0xff141111), offset: Offset(2, 2)),
  ];
}

/// Web `Modal`: `fixed inset-0 overflow-y-auto bg-layer-backdrop
/// backdrop-blur-[2px] theme-brutal:bg-black/60`, then `flex min-h-full p-4`
/// and a `m-auto flex w-full justify-center` column holding [child].
class RaftModalBackdrop extends StatelessWidget {
  const RaftModalBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // backdrop-blur-[2px]: CSS blur radius is the Gaussian standard deviation.
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: ColoredBox(
        color: t.brutal
            ? Colors.black.withValues(alpha: .6)
            : t.colors['layer-backdrop']!,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [builder] the way the Web mounts `Modal`: a full-window layer whose
/// backdrop is painted by [RaftModalBackdrop] (not a Material barrier).
Future<T?> showRaftModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) =>
      Material(type: MaterialType.transparency, child: builder(context)),
);

/// raft-ui `Card` root (`card.recipe.ts` slot `root`) with [padding].
class RaftRecipeCard extends StatelessWidget {
  const RaftRecipeCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.maxWidth,
  });
  final Widget child;
  final EdgeInsets padding;
  final double? maxWidth;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final root = RaftCardRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: tokens,
    ).root;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: RaftRecipeBox(
        style: root.withCssUsedBorderWidths(),
        tokens: tokens,
        width: double.infinity,
        padding: padding,
        applyText: false,
        child: DefaultTextStyle.merge(
          style: root.textStyle(tokens),
          child: child,
        ),
      ),
    );
  }
}

/// Web `DialogCard`: `Card w-full max-w-md p-6`; header `mb-4 flex
/// items-center justify-between border-b-0 p-0` with a `CardTitle`
/// `text-lg font-bold uppercase` and a [RaftCloseButton] (`X` 20).
class RaftDialogCard extends StatelessWidget {
  const RaftDialogCard({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.maxWidth = 448, // max-w-md = 28rem
  });
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final titleSlot = RaftCardRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      tokens: tokens,
    ).title;
    return RaftRecipeCard(
      maxWidth: maxWidth,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      raftText(context, title).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: raftCssTextStyle(
                        family: titleSlot.fontFamily ?? t.headingFont,
                        step: RaftTextSteps.lg,
                        weight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
                RaftCloseButton(onPressed: onClose),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Web `FormField` over raft-ui `Field`/`FieldLabel`/`LabelAsterisk`/
/// `LabelOptional`: label `mb-1 block text-sm` (+ `uppercase tracking-wide`
/// for [uppercase]), then [child], then an optional hint/error line.
class RaftProductFormField extends StatelessWidget {
  const RaftProductFormField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.optional = false,
    this.uppercase = true,
    this.labelWeight,
    this.hint,
    this.error,
  });
  final String label;
  final Widget child;
  final bool required, optional, uppercase;
  final FontWeight? labelWeight;
  final String? hint, error;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final field = field_recipe.RaftFieldRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: tokens,
    );
    final labelRecipe = RaftLabelRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      tokens: tokens,
    );
    final labelBase = field.label.textStyle(tokens);
    final labelStyle = raftCssTextStyle(
      family: t.headingFont,
      step: RaftTextSteps.sm,
      weight: labelWeight ?? labelBase.fontWeight ?? FontWeight.w700,
      color: labelBase.color,
      trackingEm: uppercase ? .025 : 0,
    );
    final text = raftText(context, label);
    final sub = labelRecipe.sub.textStyle(tokens);
    // Field root `flex flex-col gap-1` (recipe row-gap) + the label's `mb-1`.
    final gap = field.root.rowGap ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 4 + gap),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: uppercase ? text.toUpperCase() : text),
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: labelRecipe.asterisk.color?.resolve(tokens),
                    ),
                  ),
                if (optional)
                  TextSpan(
                    // LabelOptional keeps the source case (`normal-case`).
                    text: ' ${raftText(context, '(optional)')}',
                    style: TextStyle(
                      color: sub.color,
                      fontWeight: sub.fontWeight,
                      letterSpacing: (sub.letterSpacing ?? 0),
                    ),
                  ),
              ],
            ),
            style: labelStyle,
          ),
        ),
        child,
        if (error != null || hint != null)
          Padding(
            padding: EdgeInsets.only(top: 4 + gap),
            child: Text(
              error ?? hint!,
              style: (error != null ? field.error : field.description)
                  .textStyle(tokens)
                  .copyWith(leadingDistribution: TextLeadingDistribution.even),
            ),
          ),
      ],
    );
  }
}

/// Web `SectionEyebrow`: `text-xs font-bold uppercase text-foreground-muted
/// tracking-widest` plus the call-site [padding]/[background]/[color].
class RaftDialogSectionEyebrow extends StatelessWidget {
  const RaftDialogSectionEyebrow(
    this.text, {
    super.key,
    this.uppercase = true,
    this.padding = EdgeInsets.zero,
    this.background,
    this.color,
  });
  final String text;
  final bool uppercase;
  final EdgeInsets padding;
  final Color? background, color;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(context, text);
    return Container(
      width: double.infinity,
      padding: padding,
      color: background,
      child: Text(
        uppercase ? label.toUpperCase() : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: raftCssTextStyle(
          family: t.headingFont,
          step: RaftTextSteps.xs,
          weight: FontWeight.w700,
          color: color ?? t.colors['foreground-muted'],
          trackingEm: .1,
        ),
      ),
    );
  }
}

/// raft-ui `SegmentedControl` + `SegmentedControlItem` (+ leading Lucide icon
/// and `SegmentedControlLabel`) painted from the generated
/// `segmentedControl` recipe: `root` lays items out with its gap, `item`
/// carries border/padding/type and its `data-checked`/`hover` states.
class RaftRecipeSegmentedControl<T> extends StatelessWidget {
  const RaftRecipeSegmentedControl({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
  });
  final T value;
  final List<(T, RaftGlyph?, String)> items;
  final ValueChanged<T>? onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final root = RaftSegmentedControlRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      tokens: RaftRecipeTokens(t),
    ).root;
    return Semantics(
      label: label,
      container: true,
      child: Wrap(
        spacing: root.columnGap ?? 0,
        runSpacing: root.rowGap ?? 0,
        children: [
          for (final (v, glyph, text) in items)
            _RecipeSegment(
              checked: v == value,
              glyph: glyph,
              label: raftText(context, text),
              onTap: onChanged == null ? null : () => onChanged!(v),
            ),
        ],
      ),
    );
  }
}

class _RecipeSegment extends StatefulWidget {
  const _RecipeSegment({
    required this.checked,
    required this.glyph,
    required this.label,
    required this.onTap,
  });
  final bool checked;
  final RaftGlyph? glyph;
  final String label;
  final VoidCallback? onTap;
  @override
  State<_RecipeSegment> createState() => _RecipeSegmentState();
}

class _RecipeSegmentState extends State<_RecipeSegment> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final item = RaftSegmentedControlRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      disabled: widget.onTap == null,
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (hovered && widget.onTap != null) RaftRecipeStates.hover,
        widget.checked ? 'data-checked' : 'data-unchecked',
      }),
      tokens: tokens,
    ).item;
    // Inherited `font-display` (main.font-display) supplies the family.
    final text = item
        .textStyle(tokens)
        .copyWith(
          fontFamily: item.fontFamily ?? t.headingFont,
          leadingDistribution: TextLeadingDistribution.even,
        );
    final color = text.color ?? t.ink;
    final svg = item.target("& svg:not([class*='size-'])");
    final stroke = item.target('& svg');
    return Semantics(
      button: true,
      selected: widget.checked,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Opacity(
            opacity: item.opacity ?? 1,
            child: Container(
              padding: item.padding,
              decoration: item.decoration(tokens),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.glyph != null) ...[
                    RaftIcon(
                      widget.glyph!,
                      size: svg?.width ?? 14,
                      color: color,
                      strokeWidth:
                          (stroke?['stroke-width'] as CssNum?)?.value
                              .toDouble() ??
                          2,
                    ),
                    SizedBox(width: item.columnGap ?? 0),
                  ],
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// raft-ui `Input` (single line) or `Textarea rows={2}` (multiline:
/// textarea recipe `min-height: 96px`, scrolling inside that box).
class RaftDialogTextInput extends StatelessWidget {
  const RaftDialogTextInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.multiline = false,
    this.autofocus = false,
    this.enabled = true,
    this.leadingGlyph,
    this.onSubmitted,
    this.fieldKey,
  });
  final TextEditingController controller;
  final String? placeholder;
  final bool multiline, autofocus, enabled;
  final RaftGlyph? leadingGlyph;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final base = Theme.of(context).inputDecorationTheme.contentPadding;
    final resolved = base?.resolve(Directionality.of(context));
    Widget field = TextField(
      autofillHints: null,
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      style: t.fieldStyle,
      minLines: multiline ? null : 1,
      maxLines: multiline ? null : 1,
      expands: multiline,
      textAlignVertical: multiline ? TextAlignVertical.top : null,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: placeholder == null ? null : raftText(context, placeholder!),
        // `pl-9` replaces the input's left padding when a glyph leads.
        contentPadding: leadingGlyph == null || resolved == null
            ? null
            : resolved.copyWith(left: resolved.left - 12 + 36),
      ),
    );
    if (multiline) field = SizedBox(height: 96, child: field);
    if (leadingGlyph != null) {
      field = Stack(
        alignment: Alignment.centerLeft,
        children: [
          field,
          Positioned(
            left: 12 + t.border, // left-3 inside the border box
            child: IgnorePointer(
              child: RaftIcon(
                leadingGlyph!,
                size: 14,
                color: t.colors['foreground-muted'],
              ),
            ),
          ),
        ],
      );
    }
    return RaftFieldSurface(child: field);
  }
}

/// Web `Banner intent="warning" className="font-bold"`.
class RaftWarningBanner extends StatelessWidget {
  const RaftWarningBanner(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.colors['warning-soft'],
          border: Border.all(
            color: t.brutal ? t.colors['line-strong']! : t.colors['warning']!,
            width: t.border,
          ),
        ),
        child: Text(
          message,
          style: raftCssTextStyle(
            family: t.headingFont,
            step: RaftTextSteps.sm,
            weight: FontWeight.w700,
            color: t.strong,
          ),
        ),
      ),
    );
  }
}
