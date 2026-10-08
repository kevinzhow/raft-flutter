import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'localization.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/recipes.g.dart';
import 'recipes/token_binding.dart';
import 'settings_layout.dart';
import 'theme.dart' hide RaftFieldRecipe;

/// Recipe-driven controls the Settings pages compose. Every geometry, colour
/// and type value comes from the generated raft-ui recipes
/// (`buttonVariants`, `input`, `inputGroup`, `field`, `dialog`); callsite
/// class overrides from the Web JSX are passed explicitly and cited.

RaftRecipeStates _states(
  RaftTokens t, {
  bool hovered = false,
  bool pressed = false,
  bool disabled = false,
  bool focused = false,
}) => RaftRecipeStates({
  if (hovered && !disabled) RaftRecipeStates.hover,
  if (pressed && !disabled) RaftRecipeStates.active,
  if (disabled) RaftRecipeStates.disabled,
  if (focused) RaftRecipeStates.focus,
  if (t.dark) RaftRecipeStates.dark,
});

TextStyle _slotText(RaftTokens t, RaftSlotStyle s, {TextStyle? base}) {
  final tokens = RaftRecipeTokens(t);
  final style = s.textStyle(tokens);
  return (base ?? RaftTypography.heading(t, size: 14, line: 20))
      .merge(style)
      .copyWith(
        fontVariations: const [],
        fontFamilyFallback: const [
          'Noto Sans CJK JP',
          'Noto Sans CJK SC',
          'sans-serif',
        ],
      );
}

/// A borderless, padding-free field decoration: the recipe container owns
/// border, fill and padding (the app theme's input decoration must not apply).
InputDecoration _bare({String? hint, TextStyle? hintStyle}) => InputDecoration(
  isCollapsed: true,
  isDense: true,
  filled: false,
  contentPadding: EdgeInsets.zero,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  hintText: hint,
  hintStyle: hintStyle,
);

/// raft-ui `Button` rendered from `RaftButtonRecipe`.
class RaftRecipeButton extends StatefulWidget {
  const RaftRecipeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = RaftButtonRecipeVariant.outline,
    this.size = RaftButtonRecipeSize.md,
    this.glyph,
    this.glyphSize,
    this.expand = false,
    this.disabledOpacity,
  });
  final String label;
  final VoidCallback? onPressed;
  final RaftButtonRecipeVariant variant;
  final RaftButtonRecipeSize size;
  final RaftGlyph? glyph;

  /// Callsite icon size (`<Trash2 size={14} />`); defaults to the recipe's
  /// `& svg:not([class*='size-'])` size.
  final double? glyphSize;

  /// Block layout (a flex-col parent stretches the button).
  final bool expand;

  /// Callsite `disabled:opacity-*` override (ConfirmDialog uses 80 / 30).
  final double? disabledOpacity;
  @override
  State<RaftRecipeButton> createState() => _RaftRecipeButtonState();
}

class _RaftRecipeButtonState extends State<RaftRecipeButton> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    final disabled = widget.onPressed == null;
    final s = RaftButtonRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: widget.variant,
      size: widget.size,
      states: _states(
        t,
        hovered: hovered,
        pressed: pressed,
        disabled: disabled,
      ),
      tokens: tokens,
    ).root;
    final text = _slotText(t, s);
    final svg = s.target("& svg:not([class*='size-'])");
    final opacity = disabled
        ? (widget.disabledOpacity ?? s.opacity ?? 1)
        : (s.opacity ?? 1);
    final row = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.glyph != null) ...[
          RaftIcon(
            widget.glyph!,
            size: widget.glyphSize ?? svg?.width ?? 16,
            color: text.color,
          ),
          if (widget.label.isNotEmpty) SizedBox(width: s.columnGap ?? 6),
        ],
        if (widget.label.isNotEmpty)
          Text(
            raftText(context, widget.label),
            maxLines: 1,
            softWrap: false,
            style: text,
          ),
      ],
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          onTapDown: disabled ? null : (_) => setState(() => pressed = true),
          onTapCancel: () => setState(() => pressed = false),
          onTapUp: (_) => setState(() => pressed = false),
          onTap: widget.onPressed,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: s.translate ?? Offset.zero,
              child: Container(
                width: s.width,
                height: s.height,
                padding: s.padding,
                decoration: s.decoration(tokens),
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FormField.tsx `labelStyle="plain" size="compact"`: raft-ui `Field`
/// (`flex flex-col gap-1`) with a FieldLabel `mb-1 block text-xs`.
class RaftSettingsField extends StatelessWidget {
  const RaftSettingsField({
    super.key,
    required this.label,
    required this.child,
  });
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final f = RaftFieldRecipe.resolve(
      theme: raftRecipeTheme(t),
      tokens: RaftRecipeTokens(t),
    );
    // tailwind-merge: the callsite `text-xs` replaces the recipe `text-sm`
    // and drops `leading-none`, so the label is 12px / 16px.
    final style = _slotText(t, f.label).copyWith(fontSize: 12, height: 16 / 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(raftText(context, label), style: style),
        SizedBox(height: (f.root.rowGap ?? 4) + 4),
        child,
      ],
    );
  }
}

/// raft-ui `Input` (`input` recipe) with a callsite text size.
class RaftRecipeInput extends StatefulWidget {
  const RaftRecipeInput({
    super.key,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.mono = false,
    this.padding,
  });
  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool mono;

  /// Callsite padding override (`theme-brutal:p-2` on the account name).
  final EdgeInsets? padding;
  @override
  State<RaftRecipeInput> createState() => _RaftRecipeInputState();
}

class _RaftRecipeInputState extends State<RaftRecipeInput> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    final s = RaftInputRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: _states(t, focused: focus.hasFocus),
      tokens: tokens,
    ).root;
    // Callsite `text-sm`.
    var text = _slotText(t, s).copyWith(fontSize: 14, height: 20 / 14);
    if (widget.mono) {
      text = text.copyWith(fontFamily: t.monoFont);
    }
    return Container(
      decoration: s.decoration(tokens),
      padding: widget.padding ?? s.padding,
      child: TextField(
        controller: widget.controller,
        focusNode: focus,
        style: text,
        cursorColor: text.color ?? t.strong,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: _bare(
          hint: widget.placeholder,
          hintStyle: text.copyWith(color: t.colors['foreground-placeholder']),
        ),
      ),
    );
  }
}

/// SlugInput.tsx / PrefixedInput: raft-ui `InputGroup` with an
/// `InputGroupAddon.Text variant="container"` prefix.
class RaftPrefixedInput extends StatefulWidget {
  const RaftPrefixedInput({
    super.key,
    required this.prefix,
    this.controller,
    this.value,
    this.placeholder,
    this.readOnly = false,
    this.mono = false,
    this.onChanged,
    this.rootColor,
    this.rootBorderColor,
    this.flat = false,
    this.textColor,
  });
  final String prefix;
  final TextEditingController? controller;

  /// Read-only value (ignored when [controller] is given).
  final String? value;
  final String? placeholder;
  final bool readOnly, mono;
  final ValueChanged<String>? onChanged;

  /// Callsite root overrides (`bg-*`, `border-*`, `shadow-none`) and the
  /// input `text-*` colour.
  final Color? rootColor, rootBorderColor, textColor;
  final bool flat;
  @override
  State<RaftPrefixedInput> createState() => _RaftPrefixedInputState();
}

class _RaftPrefixedInputState extends State<RaftPrefixedInput> {
  final focus = FocusNode();
  late final TextEditingController own = TextEditingController(
    text: widget.value ?? '',
  );
  TextEditingController get controller => widget.controller ?? own;
  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant RaftPrefixedInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && widget.value != oldWidget.value) {
      own.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    focus.dispose();
    own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    final g = RaftInputGroupRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: RaftInputGroupRecipeVariant.container,
      states: RaftRecipeStates({
        if (focus.hasFocus) 'has:data-slot=input-group-control+focus',
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: tokens,
    );
    final root = g.root.decoration(tokens);
    final border = root.border as Border?;
    final decoration = root.copyWith(
      color: widget.rootColor ?? root.color,
      border: widget.rootBorderColor == null || border == null
          ? border
          : Border.all(color: widget.rootBorderColor!, width: border.top.width),
      boxShadow: widget.flat ? const [] : root.boxShadow,
    );
    final addonDecoration = g.text.decoration(tokens);
    final addonBorder = addonDecoration.border as Border?;
    final prefixStyle = _slotText(t, g.text);
    var text = _slotText(
      t,
      g.control,
    ).copyWith(color: widget.textColor ?? t.strong);
    if (widget.mono) text = text.copyWith(fontFamily: t.monoFont);
    return Container(
      decoration: decoration,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: g.text.padding,
              alignment: Alignment.center,
              decoration: addonDecoration.copyWith(
                border: widget.rootBorderColor == null || addonBorder == null
                    ? addonBorder
                    : Border(
                        right: addonBorder.right.copyWith(
                          color: widget.rootBorderColor,
                        ),
                      ),
              ),
              child: Text(widget.prefix, style: prefixStyle),
            ),
            Expanded(
              child: Padding(
                padding: g.control.padding,
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  readOnly: widget.readOnly,
                  enableInteractiveSelection: !widget.readOnly,
                  showCursor: !widget.readOnly,
                  onChanged: widget.onChanged,
                  style: text,
                  cursorColor: t.strong,
                  decoration: _bare(
                    hint: widget.placeholder,
                    hintStyle: text.copyWith(
                      color: t.colors['foreground-placeholder'],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ConfirmDialog.tsx on raft-ui `Dialog` (`dialog` recipe, `max-w-sm`).
class RaftConfirmDialog extends StatelessWidget {
  const RaftConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmVariant = RaftButtonRecipeVariant.danger,
    this.confirmEnabled,
    this.confirmKey,
    this.maxWidth = 384,
  });
  final String title;

  /// Plain copy rendered in `text-sm leading-relaxed text-foreground-muted`.
  final String? message;

  /// Rich message (the caller's own layout inside the same text style).
  final Widget? content;
  final String confirmLabel, cancelLabel;
  final RaftButtonRecipeVariant confirmVariant;

  /// `confirmDisabled` inverse; null keeps the confirm action enabled.
  final ValueListenable<bool>? confirmEnabled;
  final Key? confirmKey;
  final double maxWidth;

  static Future<bool?> show(BuildContext context, RaftConfirmDialog dialog) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: RaftTokens.of(context).colors['layer-backdrop'],
        builder: (_) => dialog,
      );

  /// `text-sm leading-relaxed text-foreground-muted` (font-normal body).
  static TextStyle messageStyle(RaftTokens t) =>
      RaftTypography.body(t, size: 14, line: 14 * 1.625, color: t.muted);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    final size = MediaQuery.sizeOf(context);
    final d = RaftDialogRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates(
        {if (t.dark) RaftRecipeStates.dark},
        size.width,
        size.height,
      ),
      tokens: tokens,
    );
    final gap = d.content.rowGap ?? 16;
    final titleStyle = _slotText(t, d.title);
    final body = DefaultTextStyle.merge(
      style: messageStyle(t),
      child: content ?? Text(raftText(context, message ?? '')),
    );
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: (size.width - 32).clamp(0, maxWidth).toDouble(),
          constraints: BoxConstraints(maxHeight: size.height - 32),
          padding: d.content.padding,
          decoration: d.content.decoration(tokens),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      raftText(context, title).toUpperCase(),
                      style: titleStyle,
                    ),
                  ),
                  SizedBox(width: d.header.columnGap ?? 12),
                  RaftRecipeButton(
                    key: const Key('confirm-dialog-close'),
                    label: '',
                    glyph: RaftGlyph.x,
                    // DialogClose: brutal `outline` / `icon-md`, X `size-5`.
                    variant: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.iconMd,
                    glyphSize: 20,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              SizedBox(height: gap),
              Flexible(
                child: SingleChildScrollView(
                  padding: d.body.padding,
                  child: body,
                ),
              ),
              SizedBox(height: gap),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: d.footer.columnGap ?? 12,
                runSpacing: d.footer.rowGap ?? 12,
                children: [
                  RaftRecipeButton(
                    label: cancelLabel,
                    size: RaftButtonRecipeSize.sm,
                    disabledOpacity: .3,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        confirmEnabled ?? const AlwaysStoppedAnimation(true),
                    builder: (context, enabled, _) => RaftRecipeButton(
                      key: confirmKey,
                      label: confirmLabel,
                      variant: confirmVariant,
                      size: RaftButtonRecipeSize.sm,
                      disabledOpacity: .8,
                      onPressed: enabled
                          ? () => Navigator.of(context).pop(true)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SettingsPanel.tsx DangerActionCard / AccountSignOutSection card: title,
/// `mt-0.5 text-xs` description and an action. [stacked] is the
/// DangerActionCard `flex-col gap-3` below `sm`, where the button stretches.
class RaftSettingsActionCard extends StatelessWidget {
  const RaftSettingsActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.action,
    this.stacked = false,
  });
  final String title, description;
  final Widget action;
  final bool stacked;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          raftText(context, title),
          style: RaftTypography.body(
            t,
            size: 14,
            line: 20,
            weight: FontWeight.w700,
            color: t.brutal ? Colors.black : t.strong,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          raftText(context, description),
          style: RaftTypography.body(
            t,
            size: 12,
            line: 16,
            color: t.brutal ? Colors.black.withValues(alpha: .6) : t.muted,
          ),
        ),
      ],
    );
    final wide = MediaQuery.sizeOf(context).width >= 640;
    return RaftSettingsCard(
      child: stacked && !wide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 12), action],
            )
          : Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 16),
                action,
              ],
            ),
    );
  }
}

/// raft-ui `Badge` rendered from `RaftBadgeRecipe`.
class RaftRecipeBadge extends StatelessWidget {
  const RaftRecipeBadge({
    super.key,
    required this.label,
    this.variant,
    this.appearance,
    this.uppercase = false,
    this.glyph,
  });
  final String label;
  final RaftBadgeRecipeVariant? variant;
  final RaftBadgeRecipeAppearance? appearance;
  final bool uppercase;

  /// Leading icon (callsite size, e.g. `<Shield size={10} />`).
  final RaftGlyph? glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    final s = RaftBadgeRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: variant,
      appearance: appearance,
      uppercase: uppercase,
      states: RaftRecipeStates({
        if (glyph != null) 'has:svg',
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: tokens,
    ).root;
    final text = _slotText(
      t,
      s,
      base: RaftTypography.body(t, size: 10, line: 10),
    );
    final value = raftText(context, label);
    return Container(
      height: s.height,
      padding: s.padding,
      decoration: s.decoration(tokens),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            RaftIcon(glyph!, size: 10, color: text.color),
            SizedBox(width: s.columnGap ?? 4),
          ],
          Text(
            uppercase ? value.toUpperCase() : value,
            maxLines: 1,
            softWrap: false,
            style: text,
          ),
        ],
      ),
    );
  }
}

/// ProfileSection read-only name: `w-full border border-line-muted
/// bg-layer-inset p-2 text-sm font-mono text-foreground-muted
/// theme-brutal:border-2 theme-brutal:border-black/30 theme-brutal:bg-gray-50
/// theme-brutal:text-black/60`.
class RaftSettingsReadonlyValue extends StatelessWidget {
  const RaftSettingsReadonlyValue({super.key, required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: text.insetFill,
        border: Border.all(color: text.softEdge, width: t.brutal ? 2 : 1),
      ),
      child: Text(value, style: text.mono.copyWith(color: text.muted)),
    );
  }
}

/// AvatarSlot `profile-tile` for a server: `!size-16 !border-2`, `text-2xl
/// font-display font-bold theme-brutal:bg-soft-signal theme-brutal:text-black`.
class RaftServerProfileTile extends StatelessWidget {
  const RaftServerProfileTile({super.key, required this.initial});
  final String initial;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.brutal
            ? t.colors['color-soft-signal']
            : t.colors['fill-muted'],
        border: Border.all(color: RaftSettingsText(t).edge, width: 2),
      ),
      child: Text(
        initial,
        style: RaftTypography.heading(
          t,
          size: 24,
          line: 32,
          weight: FontWeight.w700,
        ).copyWith(color: RaftSettingsText(t).strong),
      ),
    );
  }
}
