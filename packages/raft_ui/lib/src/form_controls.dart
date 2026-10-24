// Form primitives painted from raft-ui recipes: Field (label / description /
// error), Input, Textarea + counter, InputGroup (prefixed / slug input), and
// the Web client's legacy `.input-brutal` chrome (packages/web/src/index.css).
import 'text_selection_toolbar.dart';
import 'hover_region.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'localization.dart' show raftText;
import 'recipe_surface.dart';
import 'recipes/field.g.dart' as gen;
import 'recipes/input.g.dart';
import 'recipes/input_group.g.dart';
import 'recipes/label.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/recipe_utilities.g.dart';
import 'recipes/textarea.g.dart';
import 'recipes/textarea_counter.g.dart';
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Web `FormField` (thin adapter over raft-ui `Field`): label (+ required
/// asterisk / optional marker), control, then error or hint.
class RaftField extends StatelessWidget {
  const RaftField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.optional = false,
    this.optionalLabel = '(optional)',
    this.hint,
    this.error,
    this.compact = false,
    this.labelAccessory,
  });

  final String label;
  final Widget child;
  final bool required, optional;
  final String optionalLabel;
  final String? hint, error;

  /// `size="compact"`: `text-xs` label.
  final bool compact;
  final Widget? labelAccessory;

  /// raft-ui 0.7 `field` under the product `FormField`: `flex-col gap-1.5`, a
  /// `leading-none` label (`text-footnote`, `text-caption` when compact) in
  /// semibold muted ink, the asterisk and `(optional)` in hint ink after `ml-1`,
  /// then a `text-caption` description or a semibold `danger-strong` error.
  Widget _buildRaft(BuildContext context, RaftTokens t) {
    final ui = t.ui;
    final step = compact ? RaftTypeScale.caption : RaftTypeScale.footnote;
    // `leading-none` loses to the size step's own line height (measured 18).
    final labelStyle = t.scale(
      step,
      weight: FontWeight.w600,
      color: ui.foregroundMuted,
    );
    final labelText = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: raftText(context, label)),
          if (required) ...[
            const WidgetSpan(child: SizedBox(width: 4)),
            TextSpan(text: '*', style: TextStyle(color: ui.foregroundHint)),
          ],
          if (optional) ...[
            const WidgetSpan(child: SizedBox(width: 4)),
            TextSpan(
              text: raftText(context, optionalLabel),
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: ui.foregroundHint,
              ),
            ),
          ],
        ],
      ),
      style: labelStyle,
    );
    final message = error ?? hint;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        labelAccessory == null
            ? labelText
            : Row(
                children: [
                  Flexible(child: labelText),
                  const SizedBox(width: 4),
                  labelAccessory!,
                ],
              ),
        const SizedBox(height: 6),
        child,
        if (message != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: error != null,
            child: Text(
              raftText(context, message),
              style: error != null
                  ? t.scale(
                      RaftTypeScale.caption,
                      weight: FontWeight.w600,
                      color: ui['danger-strong'],
                    )
                  : t.scale(RaftTypeScale.caption, color: ui.foregroundHint),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option('field.layout', or: 'recipe') == 'raft') {
      return _buildRaft(context, t);
    }
    final rt = t.recipeTokens;
    final states = t.recipeStates(
      extra: [if (error != null) 'group/field:data-invalid'],
    );
    final f = gen.RaftFieldRecipe.resolve(
      theme: t.recipeTheme,
      states: states,
      tokens: rt,
    );
    final l = RaftLabelRecipe.resolve(
      theme: t.recipeTheme,
      states: states,
      tokens: rt,
    );
    final base = DefaultTextStyle.of(context).style;
    var labelStyle = f.label.text(rt, base: base);
    // FormField label classes: `text-sm` / `text-xs` (decision 0002: no
    // uppercase, so no tracking either).
    labelStyle = labelStyle.copyWith(
      fontSize: compact ? 12 : 14,
      height: compact ? 16 / 12 : 20 / 14,
    );
    final sub = l.sub.text(rt, base: labelStyle);
    final asterisk = l.asterisk.text(rt, base: labelStyle);
    final gap = f.root.rowGap ?? 0;
    final labelText = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          if (required) ...[
            const WidgetSpan(child: SizedBox(width: 4)),
            TextSpan(text: '*', style: asterisk),
          ],
          if (optional) ...[
            const WidgetSpan(child: SizedBox(width: 4)),
            TextSpan(text: optionalLabel, style: sub),
          ],
        ],
      ),
      style: labelStyle,
    );
    final message = error ?? hint;
    final messageSlot = error != null ? f.error : f.description;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `mb-1 block` label (+ accessory row `mb-1 flex items-center gap-1`).
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: labelAccessory == null
              ? labelText
              : Row(
                  children: [
                    Flexible(child: labelText),
                    const SizedBox(width: 4),
                    labelAccessory!,
                  ],
                ),
        ),
        SizedBox(height: gap),
        child,
        if (message != null) ...[
          SizedBox(height: gap + 4), // gap + `mt-1`
          Semantics(
            liveRegion: error != null,
            child: Text(message, style: messageSlot.text(rt, base: base)),
          ),
        ],
      ],
    );
  }
}

/// Text input chrome.
enum RaftInputChrome {
  /// raft-ui `Input` recipe (default).
  recipe,

  /// Web legacy `.input-brutal` class: elegant `border border-line-field
  /// bg-layer-panel px-3 py-2 font-display text-foreground-strong
  /// shadow-raft-xs`, focus `border-line-strong shadow-raft-sm`; brutal
  /// `border-2 border-black bg-white text-black shadow-brutal-sm`, focus
  /// `shadow-brutal`. Invalid adds the Web callsite classes
  /// `!border-brutal-red ring-2 ring-brutal-red/60`.
  legacy,
}

/// Single- or multi-line text input painted from the raft-ui `Input` recipe
/// (or the legacy Web chrome); editing is a collapsed [TextField].
class RaftTextInput extends StatefulWidget {
  const RaftTextInput({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText,
    this.readOnly = false,
    this.enabled = true,
    this.invalid = false,
    this.chrome = RaftInputChrome.recipe,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.semanticLabel,
    this.padding,
    this.style,
  });

  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final bool readOnly, enabled, invalid, obscureText, autofocus;

  /// Callsite overrides layered on the recipe (e.g. `px-2 py-1`,
  /// `text-xs font-mono`).
  final EdgeInsets? padding;
  final TextStyle? style;
  final RaftInputChrome chrome;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged, onSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  @override
  State<RaftTextInput> createState() => _RaftTextInputState();
}

mixin _FieldInteraction<T extends StatefulWidget> on State<T> {
  FocusNode? _owned;
  FocusNode? get externalFocus;
  FocusNode get focus => externalFocus ?? (_owned ??= FocusNode());
  bool hovered = false;

  @override
  void initState() {
    super.initState();
    focus.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    focus.removeListener(_changed);
    _owned?.dispose();
    super.dispose();
  }

  Widget hoverRegion(Widget child) => RaftHoverRegion(
    cursor: SystemMouseCursors.text,
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: child,
  );
}

class _RaftTextInputState extends State<RaftTextInput>
    with _FieldInteraction<RaftTextInput> {
  @override
  FocusNode? get externalFocus => widget.focusNode;
  TextEditingController? _ownedController;
  TextEditingController get controller =>
      widget.controller ??
      (_ownedController ??= TextEditingController(text: widget.initialValue));

  @override
  void initState() {
    super.initState();
    // Programmatic focus (autofocus) places the caret at the end without the
    // touch selection handles, like a focused Web input.
    if (!controller.selection.isValid) {
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  /// raft-ui 0.7.1 `Input` (`inputRecipe`): `h-11 px-3 py-0 text-field rounded-control border-[1.5px] border-line-strong
  /// bg-layer-card`, `data-invalid:border-danger-strong`, `focus:shadow-focus` and the disabled `fill-muted` /
  /// `line-hairline` / `foreground-disabled` colours. [RaftTextInput.padding] / [RaftTextInput.style] are the
  /// callsite overrides (a `padding` lets the height follow the content, as `h-11` is not applied there).
  Widget _buildRaft(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final focused = focus.hasFocus;
    final disabled = !widget.enabled;
    final disabledInk = raftChromeBlend(ui.foregroundDisabled, ui.fillMuted);
    final textStyle = t
        .scale(
          RaftTypeScale.body,
          color: disabled ? disabledInk : ui.foreground,
        )
        .merge(widget.style);
    final placeholder = disabled ? disabledInk : ui.foregroundHint;
    final field = TextField(
      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
      controller: controller,
      focusNode: focus,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      autofillHints: widget.autofillHints,
      inputFormatters: [
        ...?widget.inputFormatters,
        if (widget.maxLength != null)
          LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      style: textStyle,
      strutStyle: StrutStyle.fromTextStyle(textStyle, forceStrutHeight: true),
      cursorColor: textStyle.color,
      decoration: _bare(
        hintText: widget.hintText,
        hintStyle: textStyle.copyWith(color: placeholder),
      ),
    );
    final box = RaftCssBox(
      radius: 8,
      fill: disabled ? ui.fillMuted : ui.layerCard,
      borderWidth: raftControlBorderPx(context, 1.5),
      borderColor: disabled
          ? raftChromeBlend(ui.lineHairline, ui.fillMuted)
          : widget.invalid
          ? ui['danger-strong']
          : ui.lineStrong,
      rings: [
        if (focused && !disabled)
          for (final layer in ui.focusRing.layers)
            RaftRing(layer.spread, layer.color),
      ],
      height: widget.padding == null ? 44 : null,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12),
      // An `<input>` centres its line in a box taller than the line; a TextField only fills its own line.
      alignment: Alignment.centerLeft,
      child: SizedBox(width: double.infinity, child: field),
    );
    return Semantics(label: widget.semanticLabel, child: hoverRegion(box));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chrome == RaftInputChrome.recipe) return _buildRaft(context);
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final focused = focus.hasFocus;
    final base = DefaultTextStyle.of(context).style;
    late final RaftSlotStyle s;
    final BoxDecoration? legacyDecoration;
    late final TextStyle textStyle;
    late final Color placeholder;
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (widget.chrome == RaftInputChrome.recipe) {
      legacyDecoration = null;
      s = RaftInputRecipe.resolve(
        theme: t.recipeTheme,
        states: t.recipeStates(
          hovered: hovered,
          disabled: !widget.enabled,
          extra: [
            if (focused) RaftRecipeStates.focus,
            // Editable text inputs match :focus-visible even after pointer
            // focus; Source's autofocus Input also exposes its focus ring.
            if (focused) RaftRecipeStates.focusVisible,
            if (widget.invalid) 'data-invalid',
          ],
        ),
        tokens: rt,
      ).root;
      textStyle = s.text(rt, base: base).merge(widget.style);
      placeholder =
          s.target('::placeholder')?.color?.resolve(rt) ??
          t.semantic.foregroundPlaceholder;
    } else {
      // Source index.css .input-brutal includes the complete shadow-raft-xs
      // (or focus shadow-raft-sm), including Elegant dark inset layers.
      // The product's hard Brutal shadow and explicit invalid ring remain
      // caller overrides; no global recipe or renderer changes are required.
      s = raftRecipeEngine.resolveSlot(
        [
          for (final name in [
            'border',
            focused ? 'border-line-strong' : 'border-line-field',
            'bg-layer-panel',
            focused ? 'shadow-raft-sm' : 'shadow-raft-xs',
          ])
            raftRecipeUtilities.indexWhere((u) => u.name == name),
        ],
        t.recipeStates(),
        rt,
      );
      final red = t.product.brutalRed;
      textStyle = raftCssText
          .merge(base)
          .copyWith(
            fontFamily: t.headingFont,
            color: t.semantic.foregroundStrong,
          )
          .merge(widget.style);
      placeholder = t.semantic.foregroundPlaceholder;
      final shadow = (focused ? t.themeShadows.sm : t.themeShadows.xs);
      legacyDecoration = BoxDecoration(
        color: t.semantic.layerPanel,
        border: Border.all(
          width: 1,
          color: widget.invalid
              ? red
              : focused
              ? t.semantic.lineStrong
              : t.semantic.lineField,
        ),
        boxShadow: [
          for (final l in shadow.layers.reversed)
            if (!l.inset)
              BoxShadow(
                color: l.color,
                offset: l.offset,
                blurRadius: raftCssBlurRadius(l.blur),
                spreadRadius: l.spread,
              ),
          if (widget.invalid)
            BoxShadow(color: red.withValues(alpha: .6), spreadRadius: 2),
        ],
      );
    }
    final field = TextField(
      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
      controller: controller,
      focusNode: focus,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      autofillHints: widget.autofillHints,
      inputFormatters: [
        ...?widget.inputFormatters,
        if (widget.maxLength != null)
          LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      style: textStyle,
      strutStyle: StrutStyle.fromTextStyle(textStyle, forceStrutHeight: true),
      cursorColor: textStyle.color,
      decoration: _bare(
        hintText: widget.hintText,
        hintStyle: textStyle.copyWith(color: placeholder),
      ),
    );
    final box = RaftRecipeBox(
      style: s,
      tokens: rt,
      padding:
          widget.padding ??
          (widget.chrome == RaftInputChrome.legacy ? padding : null),
      applyText: widget.chrome == RaftInputChrome.recipe,
      decorationOverride: legacyDecoration == null
          ? null
          : (_) => legacyDecoration!,
      // An `<input>` centres its line in a box taller than the line (a fixed
      // `h-8` with no vertical padding); a TextField only fills its own line
      // and would sit at the top. With a loose height this is the field itself.
      child: RaftCssOverflowY(child: field),
    );
    return Semantics(label: widget.semanticLabel, child: hoverRegion(box));
  }
}

/// raft-ui `Textarea` (+ optional `TextareaCounter` is a separate widget).
/// Height is `max(min-h-24, rows × line-height + padding + border)`.
class RaftTextarea extends StatefulWidget {
  const RaftTextarea({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText,
    this.rows = 2,
    this.readOnly = false,
    this.enabled = true,
    this.invalid = false,
    this.onChanged,
    this.focusNode,
    this.maxLength,
    this.semanticLabel,
    this.textStyle,
    this.fieldKey,
  });

  /// Callsite type classes merged over the recipe text (`font-mono
  /// text-xs`); the row height follows the merged line height.
  final TextStyle? textStyle;

  /// Key of the inner [TextField].
  final Key? fieldKey;
  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final int rows;
  final bool readOnly, enabled, invalid;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  /// Enforced limit (`maxLength`); the counter is [RaftTextareaCounter].
  final int? maxLength;

  @override
  State<RaftTextarea> createState() => _RaftTextareaState();
}

class _RaftTextareaState extends State<RaftTextarea>
    with _FieldInteraction<RaftTextarea> {
  @override
  FocusNode? get externalFocus => widget.focusNode;
  TextEditingController? _ownedController;
  TextEditingController get controller =>
      widget.controller ??
      (_ownedController ??= TextEditingController(text: widget.initialValue));

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final s = RaftTextareaRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(
        hovered: hovered,
        disabled: !widget.enabled,
        extra: [
          if (focus.hasFocus) RaftRecipeStates.focus,
          if (widget.invalid) 'data-invalid',
        ],
      ),
      tokens: rt,
    ).root;
    final style = s
        .text(rt, base: DefaultTextStyle.of(context).style)
        .merge(widget.textStyle);
    final line =
        (style.height ?? 1.5) *
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14);
    final chrome = s.padding.vertical + s.borderWidth.vertical;
    final height = [
      s.minHeight ?? 0,
      widget.rows * line + chrome,
    ].reduce((a, b) => a > b ? a : b);
    return Semantics(
      label: widget.semanticLabel,
      child: hoverRegion(
        RaftRecipeBox(
          style: s,
          tokens: rt,
          height: height,
          // This expanding input owns its scaled row height. Keeping that
          // bound avoids an infinite editor in a scrolling form at large text.
          applyText: false,
          child: TextField(
            contextMenuBuilder: RaftTextSelectionToolbar.editableText,
            key: widget.fieldKey,
            autofillHints: null,
            controller: controller,
            focusNode: focus,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            inputFormatters: [
              if (widget.maxLength != null && !widget.readOnly)
                LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            style: style,
            strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
            cursorColor: style.color,
            decoration: _bare(
              hintText: widget.hintText,
              hintStyle: style.copyWith(
                // Tailwind preflight `::placeholder`: currentColor at 50%.
                color:
                    s.target('::placeholder')?.color?.resolve(rt) ??
                    t.semantic.foregroundPlaceholder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// raft-ui `TextareaCounter`: `length/limit`, danger once over the limit.
class RaftTextareaCounter extends StatelessWidget {
  const RaftTextareaCounter({
    super.key,
    required this.length,
    required this.limit,
    this.fieldInvalid = false,
  });

  final int length, limit;

  /// Inside an invalid Field (`group/field:data-invalid`).
  final bool fieldInvalid;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final s = RaftTextareaCounterRecipe.resolve(
      theme: t.recipeTheme,
      overLimit: length > limit,
      states: t.recipeStates(
        extra: [if (fieldInvalid) 'group/field:data-invalid'],
      ),
      tokens: rt,
    ).root;
    return Text(
      '$length/$limit',
      style: s
          .text(rt, base: DefaultTextStyle.of(context).style)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// raft-ui `InputGroup` with a leading text addon (`InputGroupAddon.Text`,
/// variant `container`) and an `InputGroupInput` — Web `PrefixedInput`.
class RaftPrefixedInput extends StatefulWidget {
  const RaftPrefixedInput({
    super.key,
    required this.prefix,
    this.controller,
    this.initialValue,
    this.hintText,
    this.readOnly = false,
    this.enabled = true,
    this.invalid = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.inputFormatters,
    this.semanticLabel,
    this.leading,
    this.leadingIcon,
    this.controlWeight,
    this.autofocus = false,
    this.variant = RaftInputGroupRecipeVariant.container,
    this.maxLength,
  });

  /// `InputGroupAddon` holding a 14px icon (`<Search size={14} />`) with the
  /// recipe's addon padding and colour, instead of the text [prefix].
  final RaftGlyph? leadingIcon;

  /// The control's `font-bold` / `font-medium` class over the recipe weight.
  final FontWeight? controlWeight;

  /// `InputGroupAddon className="p-0"` holding a control (the section emoji
  /// button) instead of the text [prefix].
  final Widget? leading;
  final RaftInputGroupRecipeVariant variant;
  final int? maxLength;
  final String prefix;
  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final bool readOnly, enabled, invalid;

  /// InputGroupInput `autoFocus`: the control takes focus when mounted.
  final bool autofocus;
  final ValueChanged<String>? onChanged, onSubmitted;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<RaftPrefixedInput> createState() => _RaftPrefixedInputState();
}

class _RaftPrefixedInputState extends State<RaftPrefixedInput>
    with _FieldInteraction<RaftPrefixedInput> {
  @override
  FocusNode? get externalFocus => widget.focusNode;
  TextEditingController? _ownedController;
  TextEditingController get controller =>
      widget.controller ??
      (_ownedController ??= TextEditingController(text: widget.initialValue));

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  /// raft-ui 0.7 `inputGroup` (`h-11 overflow-hidden rounded-control
  /// border-[1.5px] border-line-strong bg-layer-card`, `focus-within:shadow-focus`)
  /// with a `container` addon (`fill-muted`, `border-r border-line-hairline`,
  /// `px-3`, `font-mono text-mono-code` hint ink) and the field type step.
  Widget _buildRaft(BuildContext context, RaftTokens t) {
    final ui = t.ui;
    final focused = focus.hasFocus;
    final disabled = !widget.enabled;
    final radius = t.size('radius.control', fallback: 8);
    final border = raftControlBorderPx(context, 1.5);
    final rule = raftControlBorderPx(context, 1);
    final borderColor = disabled
        ? ui.lineHairline
        : widget.invalid
        ? ui['danger-strong']
        : ui.lineStrong;
    final addonInk = disabled ? ui.foregroundDisabled : ui.foregroundHint;
    final addonStyle = t.scale(
      RaftTypeScale.monoCode,
      mono: true,
      color: addonInk,
    );
    final field = t.fieldStyle.copyWith(
      fontWeight: widget.controlWeight,
      color: disabled ? ui.foregroundDisabled : ui.foreground,
    );
    final Widget addon = widget.leading != null
        ? widget.leading!
        : widget.leadingIcon != null
        ? ExcludeSemantics(
            child: RaftIcon(widget.leadingIcon!, size: 14, color: addonInk),
          )
        : ExcludeSemantics(child: Text(widget.prefix, style: addonStyle));
    return Semantics(
      label: widget.semanticLabel,
      child: hoverRegion(
        Container(
          height: 44,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: disabled ? ui.fillMuted : ui.layerCard,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: border),
            boxShadow: focused && !disabled ? t.focusShadows : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: widget.leading != null
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ui.fillMuted,
                  border: Border(
                    right: BorderSide(color: ui.lineHairline, width: rule),
                  ),
                ),
                child: addon,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.leadingIcon == null ? 12 : 0,
                    right: 12,
                  ),
                  child: Center(
                    child: TextField(
                    contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                    autofillHints: null,
                    autofocus: widget.autofocus,
                    controller: controller,
                    focusNode: focus,
                    readOnly: widget.readOnly,
                    enabled: widget.enabled,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    inputFormatters: widget.inputFormatters,
                    maxLength: widget.maxLength,
                    buildCounter: widget.maxLength == null
                        ? null
                        : (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                    style: field,
                    strutStyle: StrutStyle.fromTextStyle(
                      field,
                      forceStrutHeight: true,
                    ),
                    cursorColor: field.color,
                    decoration: _bare(
                      hintText: widget.hintText,
                      hintStyle: field.copyWith(
                        color: disabled
                            ? ui.foregroundDisabled
                            : ui.foregroundHint,
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option('inputGroup.style', or: 'recipe') == 'raft') {
      return _buildRaft(context, t);
    }
    final rt = t.recipeTokens;
    final focused = focus.hasFocus;
    final g = RaftInputGroupRecipe.resolve(
      theme: t.recipeTheme,
      variant: widget.variant,
      states: t.recipeStates(
        hovered: hovered,
        extra: [
          if (focused) 'has:data-slot=input-group-control+focus',
          // An editable text input always matches :focus-visible.
          if (focused) 'has:data-slot=input-group-control+focus-visible',
          if (focused)
            'group/input-group:has:data-slot=input-group-control+focus',
          if (!widget.enabled) 'has:data-slot=input-group-control+disabled',
          if (!widget.enabled)
            'group/input-group:has:data-slot=input-group-control+disabled',
          if (widget.invalid) 'has:data-slot=input-group-control+data-invalid',
        ],
      ),
      tokens: rt,
    );
    final base = DefaultTextStyle.of(context).style;
    final control = g.control
        .text(rt, base: base)
        .copyWith(fontWeight: widget.controlWeight);
    return Semantics(
      label: widget.semanticLabel,
      child: hoverRegion(
        RaftRecipeBox(
          style: g.root,
          tokens: rt,
          width: double.infinity,
          clip: true,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.leading != null)
                  RaftRecipeBox(
                    style: g.addon,
                    tokens: rt,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    child: widget.leading!,
                  )
                else if (widget.leadingIcon != null)
                  ExcludeSemantics(
                    child: RaftRecipeBox(
                      style: g.addon,
                      tokens: rt,
                      alignment: Alignment.center,
                      child: RaftIcon(widget.leadingIcon!, size: 14),
                    ),
                  )
                else
                  ExcludeSemantics(
                    child: RaftRecipeBox(
                      style: g.text,
                      tokens: rt,
                      alignment: Alignment.center,
                      child: Text(widget.prefix),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    // `& ~ [data-slot=input-group-control]` after an icon
                    // addon: `padding-left: 0`.
                    padding: widget.leadingIcon == null
                        ? g.control.padding
                        : g.control.padding.copyWith(left: 0),
                    child: TextField(
                      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                      autofillHints: null,
                      autofocus: widget.autofocus,
                      controller: controller,
                      focusNode: focus,
                      readOnly: widget.readOnly,
                      enabled: widget.enabled,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      inputFormatters: widget.inputFormatters,
                      maxLength: widget.maxLength,
                      buildCounter: widget.maxLength == null
                          ? null
                          : (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                      style: control,
                      strutStyle: StrutStyle.fromTextStyle(
                        control,
                        forceStrutHeight: true,
                      ),
                      cursorColor: control.color,
                      decoration: _bare(
                        hintText: widget.hintText,
                        hintStyle: control.copyWith(
                          // InputGroupInput `placeholder:text-foreground-placeholder`
                          // (brutal black/40) when the recipe names none.
                          color:
                              g.control
                                  .target('::placeholder')
                                  ?.color
                                  ?.resolve(rt) ??
                              t.semantic.foregroundPlaceholder,
                        ),
                      ),
                    ),
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

/// Web `SlugInput`: [RaftPrefixedInput] with the `/` prefix.
class RaftSlugInput extends StatelessWidget {
  const RaftSlugInput({
    super.key,
    this.controller,
    this.initialValue,
    this.readOnly = false,
    this.enabled = true,
    this.invalid = false,
    this.onChanged,
    this.onSubmitted,
    this.hintText,
    this.semanticLabel,
  });
  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final bool readOnly, enabled, invalid;
  final ValueChanged<String>? onChanged, onSubmitted;

  @override
  Widget build(BuildContext context) => RaftPrefixedInput(
    prefix: '/',
    controller: controller,
    initialValue: initialValue,
    hintText: hintText,
    readOnly: readOnly,
    enabled: enabled,
    invalid: invalid,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    semanticLabel: semanticLabel,
  );
}

/// A decoration that paints nothing: the recipe box owns the chrome, so no
/// theme border, fill or content padding may leak in.
InputDecoration _bare({String? hintText, TextStyle? hintStyle}) =>
    InputDecoration(
      isCollapsed: true,
      isDense: true,
      filled: false,
      contentPadding: EdgeInsets.zero,
      hintText: hintText,
      hintStyle: hintStyle,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );
