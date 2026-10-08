// Form primitives painted from raft-ui recipes: Field (label / description /
// error), Input, Textarea + counter, InputGroup (prefixed / slug input), and
// the Web client's legacy `.input-brutal` chrome (packages/web/src/index.css).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'recipe_surface.dart';
import 'recipes/field.g.dart' as gen;
import 'recipes/input.g.dart';
import 'recipes/input_group.g.dart';
import 'recipes/label.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/textarea.g.dart';
import 'recipes/textarea_counter.g.dart';
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
    this.uppercase = true,
    this.compact = false,
    this.labelAccessory,
  });

  final String label;
  final Widget child;
  final bool required, optional;
  final String optionalLabel;
  final String? hint, error;

  /// `labelStyle="uppercase"` (default) vs `"plain"`.
  final bool uppercase;

  /// `size="compact"`: `text-xs` label.
  final bool compact;
  final Widget? labelAccessory;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
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
    // FormField label classes: `text-sm` / `text-xs` + `uppercase
    // tracking-wide` (0.025em).
    labelStyle = labelStyle.copyWith(
      fontSize: compact ? 12 : 14,
      height: compact ? 16 / 12 : 20 / 14,
      letterSpacing: uppercase ? (compact ? 12 : 14) * .025 : null,
    );
    final sub = l.sub.text(rt, base: labelStyle);
    final asterisk = l.asterisk.text(rt, base: labelStyle);
    final gap = f.root.rowGap ?? 0;
    final labelText = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: uppercase ? label.toUpperCase() : label),
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
  });

  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final bool readOnly, enabled, invalid, obscureText, autofocus;
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

  Widget hoverRegion(Widget child) => MouseRegion(
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
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final focused = focus.hasFocus;
    final base = DefaultTextStyle.of(context).style;
    late final RaftSlotStyle? s;
    late final BoxDecoration decoration;
    late final TextStyle textStyle;
    late final Color placeholder;
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (widget.chrome == RaftInputChrome.recipe) {
      s = RaftInputRecipe.resolve(
        theme: t.recipeTheme,
        states: t.recipeStates(
          hovered: hovered,
          disabled: !widget.enabled,
          extra: [
            if (focused) RaftRecipeStates.focus,
            if (widget.invalid) 'data-invalid',
          ],
        ),
        tokens: rt,
      ).root;
      textStyle = s.text(rt, base: base);
      placeholder =
          s.target('::placeholder')?.color?.resolve(rt) ??
          t.semantic.foregroundPlaceholder;
    } else {
      s = null;
      final red = t.product.brutalRed;
      textStyle = raftCssText
          .merge(base)
          .copyWith(
            fontFamily: t.headingFont,
            color: t.brutal
                ? RaftPrimitiveColors.black
                : t.semantic.foregroundStrong,
          );
      placeholder = t.semantic.foregroundPlaceholder;
      final shadow = t.brutal
          ? (focused
                ? RaftProductShadows.shadowBrutal
                : RaftProductShadows.shadowBrutalSm)
          : (focused ? t.themeShadows.sm : t.themeShadows.xs);
      decoration = BoxDecoration(
        color: t.brutal ? RaftPrimitiveColors.white : t.semantic.layerPanel,
        border: Border.all(
          width: t.brutal ? 2 : 1,
          color: widget.invalid
              ? red
              : t.brutal
              ? RaftPrimitiveColors.black
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
    final box = s != null
        ? RaftRecipeBox(style: s, tokens: rt, child: field)
        : Container(padding: padding, decoration: decoration, child: field);
    return Semantics(
      label: widget.semanticLabel,
      child: hoverRegion(box),
    );
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
  });

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
    final style = s.text(rt, base: DefaultTextStyle.of(context).style);
    final line = (style.height ?? 1.5) * (style.fontSize ?? 14);
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
          child: TextField(
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
                color: s.target('::placeholder')?.color?.resolve(rt),
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
    this.focusNode,
    this.inputFormatters,
    this.semanticLabel,
  });

  final String prefix;
  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final bool readOnly, enabled, invalid;
  final ValueChanged<String>? onChanged;
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

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final focused = focus.hasFocus;
    final g = RaftInputGroupRecipe.resolve(
      theme: t.recipeTheme,
      variant: RaftInputGroupRecipeVariant.container,
      states: t.recipeStates(
        hovered: hovered,
        extra: [
          if (focused) 'has:data-slot=input-group-control+focus',
          if (focused) 'group/input-group:has:data-slot=input-group-control+focus',
          if (!widget.enabled) 'has:data-slot=input-group-control+disabled',
          if (!widget.enabled)
            'group/input-group:has:data-slot=input-group-control+disabled',
          if (widget.invalid) 'has:data-slot=input-group-control+data-invalid',
        ],
      ),
      tokens: rt,
    );
    final base = DefaultTextStyle.of(context).style;
    final control = g.control.text(rt, base: base);
    return Semantics(
      label: widget.semanticLabel,
      child: hoverRegion(
        RaftRecipeBox(
          style: g.root,
          tokens: rt,
          width: double.infinity,
          clip: !t.brutal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    padding: g.control.padding,
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      readOnly: widget.readOnly,
                      enabled: widget.enabled,
                      onChanged: widget.onChanged,
                      inputFormatters: widget.inputFormatters,
                      style: control,
                      strutStyle: StrutStyle.fromTextStyle(
                        control,
                        forceStrutHeight: true,
                      ),
                      cursorColor: control.color,
                      decoration: _bare(
                        hintText: widget.hintText,
                        hintStyle: control.copyWith(
                          color: g.control
                              .target('::placeholder')
                              ?.color
                              ?.resolve(rt),
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
    this.hintText,
  });
  final TextEditingController? controller;
  final String? initialValue, hintText;
  final bool readOnly, enabled, invalid;
  final ValueChanged<String>? onChanged;

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
