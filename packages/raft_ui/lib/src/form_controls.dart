// Form primitives painted from raft-ui recipes: Field (label / description /
// error), Input, Textarea + counter, InputGroup (prefixed / slug input), and
// the Web client's legacy `.input-brutal` chrome (packages/web/src/index.css).
import 'dart:math' as math;

import 'text_selection_toolbar.dart';
import 'hover_region.dart';
import 'tap_slop.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'localization.dart' show raftText;
import 'recipe_surface.dart';
import 'recipes/field.g.dart' as gen;
import 'recipes/input.g.dart';
import 'recipes/input_group.g.dart';
import 'recipes/kbd.g.dart';
import 'recipes/label.g.dart';
import 'kbd.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/recipe_router.dart' show resolveAuthoredClasses;
import 'recipes/textarea.g.dart';
import 'recipes/textarea_counter.g.dart';
import 'recipes/token_binding.dart';
import 'auth_page.dart'
    show RaftAuthHandleGroup, raftAuthGroupedInputDecoration;
import 'label.dart';
import 'raft/button.dart' show RaftButton, RaftButtonVariant, RaftButtonSize;
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart';
import 'design_primitives.dart'
    show RaftFieldSurface, RaftTypography, RaftIconButton, RaftControlVariant;
import 'panel_layout.dart' show raftRecipeTheme, RaftCssText;
import 'dialog_card.dart'
    show raftRecipeThemeOf, raftCssTextStyle, RaftTextSteps;

import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'text_scaling.dart' show RaftScaled;

part 'form_controls_frozen.dart';

/// How the frozen Elegant and Brutal looks paint a field; see `form_controls_frozen.dart`.
enum RaftLegacyField {
  /// The shared form field (label, control, hint).
  form,

  /// A dialog's product `FormField`.
  product,

  /// The settings forms' compact field.
  settings,

  /// The agent forms' `StableField`.
  stable,

  /// The sign-in pages' field.
  auth,
}

/// Web `FormField` over raft-ui `Field` / `FieldLabel` / `FieldDescription` / `FieldError`: the label (with the
/// required `*` or `(optional)` marker), the control, then the error or the hint, in the `field` recipe's
/// `gap-1.5` column. [compact] is `size="sm"`.
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
    this.labelAction,
    this.counter,
    this.reserveMessage = false,
    this.belowControl = const [],
    this.legacy = RaftLegacyField.form,
    this.labelWeight,
    this.family,
    this.helperHint = false,
    this.helperRecipe = false,
    this.surface = true,
  });

  final String label;
  final Widget child;
  final bool required, optional;
  final String optionalLabel;
  final String? hint, error;

  /// `size="compact"`: the `sm` label step.
  final bool compact;

  /// A small control beside the label (`flex items-center gap-1`) and a secondary action pushed to its far end.
  final Widget? labelAccessory, labelAction;

  /// Persistent end-aligned text on the message row (a character counter), and whether that row keeps its height
  /// when empty (`StableField`: nothing below moves when a hint or an error appears).
  final String? counter;
  final bool reserveMessage;

  /// Nodes after the control, inside the field (status lines, inline retry actions).
  final List<Widget> belowControl;

  /// How the frozen looks paint this field and the knobs only they read (the Raft look draws the `field`
  /// recipe for every one of them).
  final RaftLegacyField legacy;
  final FontWeight? labelWeight;
  final String? family;
  final bool helperHint, helperRecipe, surface;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.recipeSet != RaftRecipeSet.raft) {
      return switch (legacy) {
        RaftLegacyField.form => buildFrozenForm(context),
        RaftLegacyField.product => buildFrozenProduct(context),
        RaftLegacyField.settings => buildFrozenSettings(context),
        RaftLegacyField.stable => buildFrozenStable(context),
        RaftLegacyField.auth => buildFrozenAuth(context),
      };
    }
    final rt = t.recipeTokens;
    final states = t.recipeStates(
      extra: [if (error != null) 'group/field:data-invalid'],
    );
    final size = compact
        ? gen.RaftFieldRecipeSize.sm
        : gen.RaftFieldRecipeSize.md;
    final f = gen.RaftFieldRecipe.resolve(
      theme: t.recipeTheme,
      size: size,
      states: states,
      tokens: rt,
    );
    final l = RaftLabelRecipe.resolve(
      theme: t.recipeTheme,
      size: compact ? RaftLabelRecipeSize.sm : RaftLabelRecipeSize.md,
      states: states,
      tokens: rt,
    );
    final base = DefaultTextStyle.of(context).style;
    final labelStyle = f.label.text(rt, base: base);
    final labelText = Text.rich(
      style: labelStyle,
      raftLabelSpan(
        context,
        text: label,
        style: labelStyle,
        recipe: l,
        tokens: rt,
        required: required,
        optional: optional,
        optionalLabel: optionalLabel,
      ),
    );
    final message = error ?? hint;
    final messageText = message == null
        ? null
        : Text(
            raftText(context, message),
            style: (error != null ? f.error : f.description).text(
              rt,
              base: base,
            ),
          );
    final counterText = counter == null
        ? null
        : Text(
            counter!,
            style: RaftTextareaCounterRecipe.resolve(
              theme: t.recipeTheme,
              states: states,
              tokens: rt,
            ).root.text(rt, base: base),
          );
    Widget? messageRow;
    if (reserveMessage || counterText != null) {
      messageRow = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _tw * 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  messageText ??
                  ExcludeSemantics(
                    child: Text(' ', style: f.description.text(rt, base: base)),
                  ),
            ),
            if (counterText != null) ...[
              const SizedBox(width: _tw * 2),
              counterText,
            ],
          ],
        ),
      );
    } else {
      messageRow = messageText;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: f.root.rowGap ?? 0,
      children: [
        if (labelAccessory == null && labelAction == null)
          labelText
        else if (reserveMessage && labelAccessory != null)
          // StableField: the accessory sits at the end of the label row without making the row taller than its
          // label (the pack's `space.fieldLabelAccessoryOutset` is how far it pokes out above and below).
          Row(
            spacing: _tw * 2,
            children: [
              Expanded(child: labelText),
              SizedBox(
                height:
                    (_tw * 8 -
                            2 *
                                t.size(
                                  'space.fieldLabelAccessoryOutset',
                                  fallback: 0,
                                ))
                        .clamp(0, double.infinity),
                child: OverflowBox(
                  fit: OverflowBoxFit.deferToChild,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: labelAccessory!,
                ),
              ),
            ],
          )
        else
          Row(
            spacing: _tw,
            children: [
              Flexible(child: labelText),
              ?labelAccessory,
              if (labelAction != null) ...[const Spacer(), labelAction!],
            ],
          ),
        child,
        ...belowControl,
        if (messageRow != null)
          Semantics(liveRegion: error != null, child: messageRow),
      ],
    );
  }
}

/// Tailwind spacing scale step (`--spacing: 0.25rem`): `gap-1` = 4px.
const double _tw = 4;

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

/// How the frozen Elegant and Brutal looks paint an input (the Raft look ignores it: every input is the `input`
/// recipe there). One value per call-shape the pre-theme build drew differently; see `form_controls_frozen.dart`.
enum RaftLegacyInput {
  /// A form field (login, settings rows): the Raft tokens in a hand-built box.
  field,

  /// A dialog input: the theme's input decoration inside the shared field frame.
  dialog,

  /// Agent forms, the forward search and combobox inputs: the `input` recipe in a recipe box.
  recipe,

  /// Settings forms: the `input` recipe as a plain container with the callsite `text-sm`.
  settings,

  /// Settings forms without the callsite `text-sm`: the recipe's own text.
  settingsPlain,

  /// The theme's Material input decoration as it is, with the callsite [RaftTextInput.style] and a glyph as the
  /// decoration's prefix icon (inside an enclosing field frame where the page draws one).
  themed,
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
    this.fieldKey,
    this.leadingGlyph,
    this.trailing,
    this.onTap,
    this.onKeyEvent,
    this.height,
    this.textStep,
    this.mono = false,
    this.numeric = false,
    this.upperCase = false,
    this.legacy = RaftLegacyInput.field,
  });

  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final bool readOnly, enabled, invalid, obscureText, autofocus;

  /// Key of the inner [TextField] (tests and focus lookups).
  final Key? fieldKey;

  /// A glyph at the start of the box: the Web's `pl-9` input with an absolutely placed
  /// `left-3` icon (`size-3.5`, muted).
  final RaftGlyph? leadingGlyph;

  /// A widget at the end of the box, inside the border (a combobox chevron).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Keys the input receives before it handles them itself.
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  /// Callsite `h-*` on the input: a fixed box height that grows with large text (null: the recipe's `h-11`).
  final double? height;

  /// Callsite type step on the input (`text-sm`, a [RaftTextSteps] value).
  final (double, double)? textStep;

  /// `font-mono`; [numeric] is `inputMode="numeric"` (digits only); [upperCase] capitalises typed text.
  final bool mono, numeric, upperCase;

  /// How the frozen Elegant and Brutal looks paint this input.
  final RaftLegacyInput legacy;

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
    void caretToEnd() {
      if (!controller.selection.isValid) {
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
      }
    }

    if (widget.controller == null) {
      caretToEnd();
    } else {
      // A caller's controller may have listeners that rebuild: not while this widget is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) caretToEnd();
      });
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  /// The Raft look: raft-ui `Input` painted from the generated `input` recipe
  /// (`h-11 px-3 py-0`, `rounded-control border-[1.5px] border-line-strong
  /// bg-layer-card`, `focus:shadow-focus`, `data-invalid`, `disabled`).
  /// The callsite classes (`px-2 py-1`, `h-10`, `text-sm`, `font-mono`, `pl-9`) are the widget's
  /// [RaftTextInput.padding], [RaftTextInput.height], [RaftTextInput.textStep], [RaftTextInput.mono],
  /// [RaftTextInput.leadingGlyph].
  Widget _buildRecipe(BuildContext context, RaftTokens t) {
    final glyph = widget.leadingGlyph;
    // A field with a leading icon is the Web's `InputGroup` with an icon addon.
    if (glyph != null) {
      return RaftInputGroup(
        leading: RaftInputGroupAddon.icon(glyph),
        controller: controller,
        hintText: widget.hintText,
        readOnly: widget.readOnly,
        enabled: widget.enabled,
        invalid: widget.invalid,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        focusNode: focus,
        inputFormatters: widget.inputFormatters,
        semanticLabel: widget.semanticLabel,
        autofocus: widget.autofocus,
        maxLength: widget.maxLength,
        mono: widget.mono,
        fieldKey: widget.fieldKey,
      );
    }
    final rt = t.recipeTokens;
    final focused = focus.hasFocus;
    final s = RaftInputRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(
        hovered: hovered,
        disabled: !widget.enabled,
        extra: [
          if (focused) RaftRecipeStates.focus,
          // Editable text inputs match :focus-visible even after pointer focus.
          if (focused) RaftRecipeStates.focusVisible,
          if (widget.invalid) 'data-invalid',
        ],
      ),
      tokens: rt,
    ).root;
    var textStyle = s.text(rt, base: DefaultTextStyle.of(context).style);
    final step = widget.textStep;
    if (step != null) {
      textStyle = textStyle.copyWith(
        fontSize: step.$1,
        height: step.$2 / step.$1,
      );
    }
    if (widget.mono) textStyle = textStyle.copyWith(fontFamily: t.monoFont);
    textStyle = textStyle.merge(widget.style);
    final placeholder =
        s.target('::placeholder')?.color?.resolve(rt) ??
        t.semantic.foregroundPlaceholder;
    Widget field = _editable(textStyle, placeholder);
    if (widget.onKeyEvent != null) {
      field = Focus(
        canRequestFocus: false,
        onKeyEvent: widget.onKeyEvent,
        child: field,
      );
    }
    final trailing = widget.trailing;
    if (trailing != null) {
      field = Row(
        children: [
          Expanded(child: field),
          const SizedBox(width: _tw * 2),
          trailing,
        ],
      );
    }
    final box = RaftRecipeBox(
      // A callsite padding lets the height follow the content (`h-11` is not applied there).
      style: widget.padding == null
          ? s
          : s.copyWith(properties: {...s.properties}..remove('height')),
      tokens: rt,
      applyText: false,
      growWithText: true,
      applyOpacity: false,
      height: widget.height,
      padding: widget.padding,
      decorationOverride: (d) => raftSnapBorder(context, d),
      // An `<input>` centres its line in a box taller than the line; with no height of its own the box follows it.
      child: Align(
        alignment: Alignment.centerLeft,
        heightFactor: 1,
        child: SizedBox(width: double.infinity, child: field),
      ),
    );
    return Semantics(
      label: widget.semanticLabel,
      child: hoverRegion(
        RaftTapSlopGuard(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.enabled
                ? () {
                    focus.requestFocus();
                    widget.onTap?.call();
                  }
                : null,
            child: box,
          ),
        ),
      ),
    );
  }

  Widget _editable(TextStyle textStyle, Color placeholder) => TextField(
    contextMenuBuilder: RaftTextSelectionToolbar.editableText,
    key: widget.fieldKey,
    controller: controller,
    focusNode: focus,
    readOnly: widget.readOnly,
    enabled: widget.enabled,
    obscureText: widget.obscureText,
    enableSuggestions: !widget.obscureText,
    autocorrect: !widget.obscureText,
    keyboardType:
        widget.keyboardType ?? (widget.numeric ? TextInputType.number : null),
    textInputAction: widget.textInputAction,
    textCapitalization: widget.upperCase
        ? TextCapitalization.characters
        : TextCapitalization.none,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    onTap: widget.onTap,
    autofocus: widget.autofocus,
    autofillHints: widget.autofillHints,
    inputFormatters: [
      if (widget.numeric) FilteringTextInputFormatter.digitsOnly,
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

  /// The Web's legacy `.input-brutal` chrome (explicit `chrome: legacy`; every look).
  Widget _buildLegacyChrome(BuildContext context, RaftTokens t) {
    final rt = t.recipeTokens;
    final focused = focus.hasFocus;
    final base = DefaultTextStyle.of(context).style;
    late final RaftSlotStyle s;
    final BoxDecoration legacyDecoration;
    late final TextStyle textStyle;
    late final Color placeholder;
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    {
      // Source index.css .input-brutal includes the complete shadow-raft-xs
      // (or focus shadow-raft-sm), including Elegant dark inset layers.
      // The product's hard Brutal shadow and explicit invalid ring remain
      // caller overrides; no global recipe or renderer changes are required.
      s = resolveAuthoredClasses(
        [
          'border',
          focused ? 'border-line-strong' : 'border-line-field',
          'bg-layer-panel',
          focused ? 'shadow-raft-sm' : 'shadow-raft-xs',
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
    final field = _editable(textStyle, placeholder);
    final box = RaftRecipeBox(
      style: s,
      tokens: rt,
      padding: widget.padding ?? padding,
      applyText: false,
      decorationOverride: (_) => legacyDecoration,
      // An `<input>` centres its line in a box taller than the line (a fixed
      // `h-8` with no vertical padding); a TextField only fills its own line
      // and would sit at the top. With a loose height this is the field itself.
      child: RaftCssOverflowY(child: field),
    );
    return Semantics(label: widget.semanticLabel, child: hoverRegion(box));
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (widget.chrome == RaftInputChrome.recipe) {
      if (t.recipeSet == RaftRecipeSet.raft) return _buildRecipe(context, t);
      return switch (widget.legacy) {
        RaftLegacyInput.field => buildFrozenField(context, t),
        RaftLegacyInput.dialog => buildFrozenDialog(context, t),
        RaftLegacyInput.recipe => buildFrozenRecipe(context, t),
        RaftLegacyInput.settings ||
        RaftLegacyInput.settingsPlain => buildFrozenSettings(context, t),
        RaftLegacyInput.themed => buildFrozenThemed(context, t),
      };
    }
    return _buildLegacyChrome(context, t);
  }
}

/// raft-ui `Textarea` (+ optional `TextareaCounter` is a separate widget).
/// Height is `max(min-h-24, rows × line-height + padding + border)`; [minHeight] makes it an auto-growing
/// field (`field-sizing-content`) with that `min-h-*` instead.
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
    this.autofocus = false,
    this.mono = false,
    this.textStep,
    this.lineHeight,
    this.minHeight,
    this.growsWithScale = false,
    this.legacy = RaftLegacyInput.field,
  });

  /// Callsite type classes merged over the recipe text (`font-mono
  /// text-xs`); the row height follows the merged line height.
  final TextStyle? textStyle;

  /// Key of the inner [TextField].
  final Key? fieldKey;
  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final int rows;
  final bool readOnly, enabled, invalid, autofocus, mono;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  /// Callsite type step (`text-sm`, a [RaftTextSteps] value) and `leading-*` (a line-height multiplier).
  final (double, double)? textStep;
  final double? lineHeight;

  /// Callsite `min-h-*`: the box grows with its text from this height instead of holding [rows].
  final double? minHeight;

  /// Above the default text size the rows are a minimum and the box grows with its text, instead of holding a
  /// bounded height (a dialog's description field).
  final bool growsWithScale;

  /// How the frozen Elegant and Brutal looks paint this textarea.
  final RaftLegacyInput legacy;

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
    final raft = t.recipeSet == RaftRecipeSet.raft;
    if (!raft) {
      switch (widget.legacy) {
        case RaftLegacyInput.field:
          break;
        case RaftLegacyInput.dialog:
          return buildFrozenDialog(context, t);
        case RaftLegacyInput.recipe:
          return buildFrozenRecipe(context, t);
        case RaftLegacyInput.settings:
        case RaftLegacyInput.settingsPlain:
          return buildFrozenSettings(context, t);
        case RaftLegacyInput.themed:
          break;
      }
    }
    final rt = t.recipeTokens;
    var s = RaftTextareaRecipe.resolve(
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
    // Above the default text size the rows are a minimum (`min-h-*`): the box grows with the text it holds.
    final scaled = widget.growsWithScale && RaftScaled.grows(context);
    final grows = widget.minHeight != null || scaled;
    if (widget.minHeight != null) {
      s = s.copyWith(
        properties: {
          ...s.properties,
          'min-height': CssNum(widget.minHeight!, 'px'),
        },
      );
    }
    var style = s.text(rt, base: DefaultTextStyle.of(context).style);
    final step = widget.textStep;
    if (step != null) {
      style = style.copyWith(fontSize: step.$1, height: step.$2 / step.$1);
    }
    if (widget.lineHeight != null) {
      style = style.copyWith(height: widget.lineHeight);
    }
    if (widget.mono) style = style.copyWith(fontFamily: t.monoFont);
    style = style.merge(widget.textStyle);
    final line =
        (style.height ?? 1.5) *
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14);
    final chrome = s.padding.vertical + s.borderWidth.vertical;
    final height = grows
        ? null
        : [
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
          decorationOverride: raft ? (d) => raftSnapBorder(context, d) : null,
          child: TextField(
            contextMenuBuilder: RaftTextSelectionToolbar.editableText,
            key: widget.fieldKey,
            autofillHints: null,
            controller: controller,
            focusNode: focus,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            minLines: widget.minHeight != null
                ? 1
                : (scaled ? widget.rows : null),
            maxLines: null,
            expands: !grows,
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

/// An `InputGroupAddon` of a [RaftInputGroup]: a text (`InputGroupAddon.Text`), an icon, or a control the
/// group hosts without padding (the section emoji button).
class RaftInputGroupAddon {
  const RaftInputGroupAddon.text(String this.text) : glyph = null, child = null;
  const RaftInputGroupAddon.icon(RaftGlyph this.glyph)
    : text = null,
      child = null;
  const RaftInputGroupAddon.custom(Widget this.child)
    : text = null,
      glyph = null;
  final String? text;
  final RaftGlyph? glyph;
  final Widget? child;
}

/// How the frozen Elegant and Brutal looks paint an input group; see `form_controls_frozen.dart`.
enum RaftLegacyGroup {
  /// A prefixed input (`SlugInput`, the section name field).
  prefixed,

  /// The settings forms' prefixed input.
  settings,

  /// The message search field.
  search,

  /// The sign-in pages' username group: an `@` block and a borderless Material field in a hand-built frame.
  handle,
}

/// raft-ui `InputGroup`: one bordered box holding an optional leading addon, the control and an optional trailing
/// addon, `InputGroupAddon` / `InputGroupAddon.Text` / `InputGroupInput` of the Web. [clearLabel] and [onClear]
/// add the inline-end clear button while the field holds text, [kbd] the key hint after it.
class RaftInputGroup extends StatefulWidget {
  const RaftInputGroup({
    super.key,
    this.leading,
    this.trailing,
    this.variant = RaftInputGroupRecipeVariant.default_,
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
    this.autofocus = false,
    this.maxLength,
    this.controlWeight,
    this.mono = false,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.flat = false,
    this.clearLabel,
    this.onClear,
    this.kbd,
    this.legacy = RaftLegacyGroup.prefixed,
    this.fieldKey,
  });

  final RaftInputGroupAddon? leading, trailing;

  /// `variant="container"` addons are a muted block with a hairline seam (`SlugInput`); the default ones sit on
  /// the group's own fill.
  final RaftInputGroupRecipeVariant variant;
  final TextEditingController? controller;
  final String? initialValue, hintText, semanticLabel;
  final bool readOnly, enabled, invalid, autofocus;
  final ValueChanged<String>? onChanged, onSubmitted;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  /// The control's `font-bold` / `font-medium` class over the recipe weight; [mono] is `font-mono`.
  final FontWeight? controlWeight;
  final bool mono;

  /// Callsite `text-*`, `bg-*`, `border-*` and `shadow-none` classes on the group.
  final Color? textColor, backgroundColor, borderColor;
  final bool flat;

  /// The inline-end clear button (shown while there is text) and the `Kbd` hint after it.
  final String? clearLabel, kbd;
  final VoidCallback? onClear;

  /// How the frozen Elegant and Brutal looks paint this group.
  final RaftLegacyGroup legacy;

  /// Key of the inner [TextField] (tests and focus lookups).
  final Key? fieldKey;

  @override
  State<RaftInputGroup> createState() => _RaftInputGroupState();
}

class _RaftInputGroupState extends State<RaftInputGroup>
    with _FieldInteraction<RaftInputGroup> {
  @override
  FocusNode? get externalFocus => widget.focusNode;
  TextEditingController? _ownedController;
  TextEditingController get controller =>
      widget.controller ??
      (_ownedController ??= TextEditingController(text: widget.initialValue));

  void _textChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.onClear != null) controller.addListener(_textChanged);
  }

  @override
  void didUpdateWidget(covariant RaftInputGroup old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _ownedController)?.removeListener(_textChanged);
      if (widget.onClear != null) controller.addListener(_textChanged);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_textChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  /// The Raft look: raft-ui `inputGroup` from the generated recipe (`h-11 overflow-hidden rounded-control
  /// border-[1.5px] border-line-strong bg-layer-card`, `focus-within:shadow-focus`), its `addon` / `text` /
  /// `control` slots, the default and `container` variants.
  Widget _buildRecipe(BuildContext context, RaftTokens t) {
    final rt = t.recipeTokens;
    final focused = focus.hasFocus;
    final disabled = !widget.enabled;
    RaftInputGroupRecipeStyle resolve(RaftInputGroupRecipeAlign align) =>
        RaftInputGroupRecipe.resolve(
          theme: t.recipeTheme,
          align: align,
          variant: widget.variant,
          states: t.recipeStates(
            hovered: hovered,
            disabled: disabled,
            extra: [
              if (focused) RaftRecipeStates.focusWithin,
              if (widget.invalid)
                'has:data-slot=input-group-control+data-invalid',
              if (disabled) 'has:data-slot=input-group-control+disabled',
            ],
          ),
          tokens: rt,
        );
    final start = resolve(RaftInputGroupRecipeAlign.inlineStart);
    final end = resolve(RaftInputGroupRecipeAlign.inlineEnd);
    final container = widget.variant == RaftInputGroupRecipeVariant.container;
    // `[--ig-addon-fg]` / `[--ig-text-fg]` turn `foreground-disabled` on a disabled group.
    final addonInk = disabled ? t.colors['foreground-disabled'] : null;
    Widget box(RaftSlotStyle slot, Widget child, {EdgeInsets? padding}) =>
        RaftRecipeBox(
          style: slot,
          tokens: rt,
          alignment: Alignment.center,
          padding: padding,
          decorationOverride: (d) => raftSnapBorder(context, d),
          child: child,
        );
    Widget addon(RaftInputGroupAddon a, RaftInputGroupRecipeStyle g) {
      final child = a.child;
      if (child != null) return box(g.addon, child, padding: EdgeInsets.zero);
      final text = a.text;
      if (text != null) {
        final style = g.text.text(rt, base: DefaultTextStyle.of(context).style);
        return ExcludeSemantics(
          child: box(
            g.text,
            Text(text, style: style.copyWith(color: addonInk)),
          ),
        );
      }
      final svg = g.addon.target("& > svg:not([class*='size-'])");
      return ExcludeSemantics(
        child: box(
          g.addon,
          RaftIcon(
            a.glyph!,
            size: svg?.width ?? 18,
            color: addonInk ?? g.addon.color?.resolve(rt),
          ),
        ),
      );
    }

    final actions = <Widget>[
      if (widget.onClear != null && controller.text.isNotEmpty)
        _clearButton(t, rt),
      if (widget.kbd != null) RaftKbd(widget.kbd!),
    ];
    final trailing = widget.trailing;
    final control = start.control;
    final defaultStart = widget.leading != null && !container;
    final defaultEnd = (trailing != null || actions.isNotEmpty) && !container;
    var padding = control.padding;
    if (defaultStart) padding = padding.copyWith(left: 0);
    if (defaultEnd) padding = padding.copyWith(right: 0);
    var style = control
        .text(rt, base: DefaultTextStyle.of(context).style)
        .copyWith(
          fontWeight: widget.controlWeight,
          fontFamily: widget.mono ? t.monoFont : null,
        );
    if (widget.textColor != null)
      style = style.copyWith(color: widget.textColor);
    final placeholder =
        control.target('::placeholder')?.color?.resolve(rt) ??
        t.semantic.foregroundPlaceholder;
    final field = TextField(
      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
      autofillHints: null,
      key: widget.fieldKey,
      autofocus: widget.autofocus,
      controller: controller,
      focusNode: focus,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      enableInteractiveSelection: !widget.readOnly,
      showCursor: !widget.readOnly,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      inputFormatters: [
        ...?widget.inputFormatters,
        if (widget.maxLength != null)
          LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      style: style,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      cursorColor: style.color,
      decoration: _bare(
        hintText: widget.hintText,
        hintStyle: style.copyWith(color: placeholder),
      ),
    );
    final box0 = RaftRecipeBox(
      style: start.root,
      tokens: rt,
      width: double.infinity,
      clip: true,
      decorationOverride: (d) {
        d = raftSnapBorder(context, d);
        final border = d.border;
        return d.copyWith(
          color: widget.backgroundColor ?? d.color,
          // A caller's border override is the read-only group's frame: `border-line-hairline` in raft-ui 0.7.0.
          border: widget.borderColor == null || border is! Border
              ? border
              : Border.all(color: t.ui.lineHairline, width: border.top.width),
          boxShadow: widget.flat ? const [] : d.boxShadow,
        );
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.leading != null) addon(widget.leading!, start),
            Expanded(
              child: Padding(
                padding: padding,
                child: Align(alignment: Alignment.centerLeft, child: field),
              ),
            ),
            if (trailing != null || actions.isNotEmpty)
              box(
                end.addon,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: end.addon.columnGap ?? 0,
                  children: [?trailing?.child, ...actions],
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(label: widget.semanticLabel, child: hoverRegion(box0));
  }

  /// `Button variant="ghost" size="icon-sm"` with the X: the recipe's square and its `svg` size.
  Widget _clearButton(RaftTokens t, RaftTokenResolver rt) {
    return RaftButton(
      label: '',
      glyph: RaftGlyph.x,
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.iconSm,
      tooltip: widget.clearLabel,
      semanticLabel: widget.clearLabel,
      onPressed: widget.onClear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.recipeSet == RaftRecipeSet.raft) return _buildRecipe(context, t);
    return switch (widget.legacy) {
      RaftLegacyGroup.prefixed => buildFrozenPrefixed(context, t),
      RaftLegacyGroup.settings => buildFrozenSettings(context, t),
      RaftLegacyGroup.search => buildFrozenSearch(context, t),
      RaftLegacyGroup.handle => buildFrozenHandle(context, t),
    };
  }
}

/// `PrefixedInput` of the Web: an [RaftInputGroup] with a leading text addon (`InputGroupAddon.Text
/// variant="container"`), an icon addon or a hosted control.
class RaftPrefixedInput extends StatelessWidget {
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

  /// `InputGroupAddon` holding an icon (`<Search size={14} />`) instead of the text [prefix].
  final RaftGlyph? leadingIcon;

  /// The control's `font-bold` / `font-medium` class over the recipe weight.
  final FontWeight? controlWeight;

  /// `InputGroupAddon className="p-0"` holding a control (the section emoji button) instead of the text [prefix].
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
  Widget build(BuildContext context) => RaftInputGroup(
    leading: leading != null
        ? RaftInputGroupAddon.custom(leading!)
        : leadingIcon != null
        ? RaftInputGroupAddon.icon(leadingIcon!)
        : RaftInputGroupAddon.text(prefix),
    variant: variant,
    controller: controller,
    initialValue: initialValue,
    hintText: hintText,
    readOnly: readOnly,
    enabled: enabled,
    invalid: invalid,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    focusNode: focusNode,
    inputFormatters: inputFormatters,
    semanticLabel: semanticLabel,
    autofocus: autofocus,
    maxLength: maxLength,
    controlWeight: controlWeight,
    legacy: RaftLegacyGroup.prefixed,
  );
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

/// The editable text of an input that sits inside chrome another component draws (a finder box, a combobox's
/// input group, a popover's search row, the emoji picker's header): a text field with no border, fill or padding
/// of its own, the Raft text selection toolbar and none of the theme's input decoration.
class RaftBareInput extends StatelessWidget {
  const RaftBareInput({
    super.key,
    required this.style,
    required this.hintStyle,
    this.fieldKey,
    this.controller,
    this.focusNode,
    this.hintText,
    this.cursorColor,
    this.autofocus = false,
    this.enabled = true,
    this.textAlignVertical,
    this.onChanged,
    this.onSubmitted,
    this.onTapOutside,
  });

  final Key? fieldKey;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextStyle style, hintStyle;
  final Color? cursorColor;
  final bool autofocus, enabled;
  final TextAlignVertical? textAlignVertical;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onTapOutside;

  @override
  Widget build(BuildContext context) => TextField(
    contextMenuBuilder: RaftTextSelectionToolbar.editableText,
    autofillHints: null,
    key: fieldKey,
    controller: controller,
    focusNode: focusNode,
    autofocus: autofocus,
    enabled: enabled,
    textAlignVertical: textAlignVertical,
    style: style,
    cursorColor: cursorColor,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    onTapOutside: onTapOutside == null ? null : (_) => onTapOutside!(),
    decoration: _bare(hintText: hintText, hintStyle: hintStyle),
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
