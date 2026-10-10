// Create-agent / runtime-form dialog building blocks, composed from the
// generated raft-ui recipes the same way the Web client composes them:
//
//   DialogCard          packages/web/src/components/ui/DialogCard.tsx (Modal +
//                       Card p-6 + CardHeader mb-4 + CardTitle text-lg bold
//                       uppercase + CloseButton)
//   StableField         packages/web/src/components/agent/StableField.tsx
//                       (Field gap + uppercase label + control + reserved
//                       one-line message row with optional counter)
//   Input / Textarea    raft-ui `input` / `textarea` recipes
//   Select trigger      raft-ui SelectTrigger = Button(outline, md) merged with
//                       `select` trigger (chrome=field)
//   Banner              raft-ui `banner` recipe
//   MORE disclosure     RuntimeConfigFields.tsx advanced toggle
//
// Values come from the recipes; the few Tailwind classes written directly in
// Web JSX are cited next to the number that resolves them.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'components.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'recipes/banner.g.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';
import 'recipes/field.g.dart' as field_recipe;
import 'recipes/input.g.dart';
import 'recipes/select.g.dart';
import 'recipes/textarea.g.dart';
import 'recipes/textarea_counter.g.dart';
import 'theme.dart';

RaftRecipeTheme _theme(RaftTokens t) =>
    t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;
RaftRecipeStates _states(RaftTokens t, [Set<String> flags = const {}]) =>
    RaftRecipeStates({...flags, if (t.dark) RaftRecipeStates.dark});

/// Tailwind spacing scale step (`--spacing: 0.25rem`): `gap-1` = 4px.
const double _tw = 4;

/// Modal.tsx backdrop: `bg-layer-backdrop … theme-brutal:bg-black/60`.
Color raftAgentModalBarrier(RaftTokens t) => t.brutal
    ? Colors.black.withValues(alpha: .6)
    : t.colors['layer-backdrop']!;

/// Opens [builder] like Web `Modal`: full-window backdrop that does not close
/// on tap (closeOnBackdrop=false), Escape closes, content scrolls inside a
/// `p-4` frame and centres with `m-auto`.
Future<T?> showRaftAgentModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final t = RaftTokens.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: raftAgentModalBarrier(t),
    // dialog overlay recipe: transition-duration 150ms.
    transitionDuration: const Duration(milliseconds: 150),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, _, _) => builder(context),
  );
}

/// Web DialogCard: Card (`w-full max-w-md p-6`) with header row
/// (`mb-4 flex items-center justify-between`), title (`text-lg font-bold
/// uppercase`) and a CloseButton (ghost icon-sm, brutal: bordered white).
class RaftAgentDialogCard extends StatelessWidget {
  const RaftAgentDialogCard({
    super.key,
    required this.title,
    required this.children,
    this.onClose,
    this.maxWidth = 448, // max-w-md = 28rem
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final card = RaftCardRecipe.resolve(
      theme: _theme(t),
      states: _states(t),
      tokens: tokens,
    );
    final base = card.root
        .text(
          tokens,
          base: TextStyle(
            // Modal portals inherit document.body font-sans, outside main font-display.
            fontFamily: t.bodyFont,
            fontSize: 16,
            height: 1.5,
          ),
        )
        .copyWith(
          decoration: TextDecoration.none,
          // CSS line boxes: half the leading above, half below.
          leadingDistribution: TextLeadingDistribution.even,
        );
    final titleStyle = card.title.textStyle(tokens).copyWith(
      fontSize: 18, // text-lg: 1.125rem / 1.75rem
      height: 28 / 18,
      fontWeight: FontWeight.w700, // font-bold
    );
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(4 * _tw), // Modal inner `p-4`
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.maxHeight.isFinite ? box.maxHeight - 8 * _tw : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Material(
                type: MaterialType.transparency,
                child: RaftRecipeBox(
                  style: card.root.withCssUsedBorderWidths(),
                  tokens: tokens,
                  applyText: false,
                  width: double.infinity,
                  padding: const EdgeInsets.all(6 * _tw), // p-6
                  child: DefaultTextStyle(
                    style: base,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  raftText(context, title).toUpperCase(),
                                  style: titleStyle,
                                ),
                              ),
                            ),
                            if (onClose != null) RaftAgentCloseButton(onPressed: onClose),
                          ],
                        ),
                        const SizedBox(height: 4 * _tw), // mb-4
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web CloseButton: `Button variant=ghost size=icon-sm` with `X size={20}`;
/// brutal adds `border-2 border-black shadow-brutal-sm bg-white text-black`,
/// which is the outline control chrome.
class RaftAgentCloseButton extends StatelessWidget {
  const RaftAgentCloseButton({super.key, this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = RaftButtonRecipe.resolve(
      theme: _theme(t),
      variant: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.iconSm,
      tokens: RaftRecipeTokens(t),
    ).root;
    // `X size={20}` is overridden by the button's `[&_svg:not([class*='size-'])]`
    // size rule (CSS beats the SVG attribute).
    final glyph = size.target("& svg:not([class*='size-'])")?.width ?? 16;
    return RaftIconButton(
      glyph: RaftGlyph.x,
      tooltip: 'Close',
      visualSize: size.width ?? 28,
      // Web hit area is the 28px button itself.
      minimumTargetSize: size.width ?? 28,
      glyphSize: glyph,
      variant: t.brutal ? RaftControlVariant.outline : RaftControlVariant.ghost,
      onPressed: onPressed,
    );
  }
}

/// StableField: label (+ asterisk) / control / belowControl / reserved
/// message row. Children of the Field flex column are separated by the field
/// recipe gap.
class RaftStableField extends StatelessWidget {
  const RaftStableField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
    this.error,
    this.counter,
    this.labelAccessory,
    this.belowControl = const [],
  });
  final String label;
  final Widget child;
  final bool required;
  final String? hint, error, counter;
  final Widget? labelAccessory;
  final List<Widget> belowControl;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final field = field_recipe.RaftFieldRecipe.resolve(
      theme: _theme(t),
      states: _states(t),
      tokens: tokens,
    );
    final gap = field.root.rowGap ?? 0;
    // LABEL_CLS = "text-sm font-bold text-foreground-strong uppercase tracking-wide"
    final labelStyle = field.label
        .textStyle(tokens)
        .copyWith(
          fontWeight: FontWeight.w700,
          // FieldLabel dark:text-foreground-hint outranks the caller's base color.
          color: t.dark
              ? field.label.color?.resolve(tokens) ?? t.strong
              : t.strong,
          letterSpacing: 14 * .025,
        );
    final message = error ?? hint;
    final messageStyle = TextStyle(
      fontSize: 12, // text-xs
      height: 16 / 12,
      fontWeight: error != null ? FontWeight.w700 : null,
      color: error != null
          ? t.colors[t.brutal ? 'color-brutal-red' : 'danger-strong']
          : t.brutal
          ? t.colors['color-black']?.withValues(alpha: .5) ??
                t.strong.withValues(alpha: .5)
          : t.muted,
    );
    final counterRecipe = RaftTextareaCounterRecipe.resolve(
      theme: _theme(t),
      tokens: tokens,
    ).root;
    final labelText = RaftCssText.rich(
      TextSpan(
        text: raftText(context, label).toUpperCase(),
        children: [
          if (required) ...[
            const WidgetSpan(child: SizedBox(width: _tw)), // ml-1
            TextSpan(
              text: '*',
              style: TextStyle(
                color: t.brutal ? t.strong : t.colors['danger-strong'],
              ),
            ),
          ],
        ],
      ),
      style: labelStyle,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelAccessory != null)
          Row(
            children: [
              labelText,
              const SizedBox(width: 2 * _tw), // gap-2
              const Spacer(),
              labelAccessory!,
            ],
          )
        else
          labelText,
        SizedBox(height: gap),
        child,
        for (final below in belowControl) ...[SizedBox(height: gap), below],
        SizedBox(height: gap),
        Semantics(
          liveRegion: error != null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 4 * _tw), // min-h-4
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RaftCssText(
                    message == null ? ' ' : raftText(context, message),
                    style: messageStyle,
                  ),
                ),
                if (counter != null) ...[
                  const SizedBox(width: 2 * _tw), // gap-2
                  Text(
                    counter!,
                    style: messageStyle.copyWith(
                      fontWeight: FontWeight.w400,
                      // `font-mono tabular-nums text-foreground-muted
                      // theme-brutal:text-black/50`
                      fontFamily: counterRecipe.fontFamily ?? t.monoFont,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: t.brutal ? t.strong.withValues(alpha: .5) : t.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// raft-ui Input (or Textarea when [multiline]) rendered from the recipe:
/// the editable text carries no Material decoration.
class RaftAgentTextInput extends StatefulWidget {
  const RaftAgentTextInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.invalid = false,
    this.readOnly = false,
    this.enabled = true,
    this.obscure = false,
    this.multiline = false,
    this.rows = 3,
    this.maxLength,
    this.onChanged,
    this.semanticLabel,
  });
  final TextEditingController controller;
  final String? placeholder, semanticLabel;
  final bool invalid, readOnly, enabled, obscure, multiline;
  final int rows;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  @override
  State<RaftAgentTextInput> createState() => _RaftAgentTextInputState();
}

class _RaftAgentTextInputState extends State<RaftAgentTextInput> {
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
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final states = _states(t, {
      if (widget.invalid) 'data-invalid',
      if (focus.hasFocus) RaftRecipeStates.focus,
      if (focus.hasFocus) RaftRecipeStates.focusVisible,
      if (!widget.enabled) RaftRecipeStates.disabled,
    });
    final root = widget.multiline
        ? RaftTextareaRecipe.resolve(
            theme: _theme(t),
            states: states,
            tokens: tokens,
          ).root
        : RaftInputRecipe.resolve(
            theme: _theme(t),
            states: states,
            tokens: tokens,
          ).root;
    final style = root
        .textStyle(tokens, currentColor: t.ink)
        .copyWith(
          color: root.color?.resolve(tokens) ?? t.ink,
          leadingDistribution: TextLeadingDistribution.even,
        );
    // Tailwind preflight `::placeholder { color: color-mix(currentcolor 50%) }`
    // unless the recipe styles it.
    final placeholderColor =
        root.target('::placeholder')?.color?.resolve(tokens) ??
        style.color!.withValues(alpha: .5);
    final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1);
    final pad = root.padding;
    final border = root.borderWidth;
    final minHeight = widget.multiline
        ? [
            root.minHeight ?? 0,
            widget.rows * lineHeight + pad.vertical + border.vertical,
          ].reduce((a, b) => a > b ? a : b)
        : null;
    final editor = TextField(
      autofillHints: null,
      controller: widget.controller,
      focusNode: focus,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: widget.obscure,
      obscuringCharacter: '•',
      maxLines: widget.multiline ? null : 1,
      expands: widget.multiline,
      maxLength: widget.maxLength,
      textAlignVertical: TextAlignVertical.top,
      style: style,
      cursorColor: style.color,
      cursorWidth: 1,
      onChanged: widget.onChanged,
      // Bare editable text: every frame/border comes from the recipe box.
      decoration: InputDecoration(
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
        counterText: '',
        hintText: widget.placeholder == null
            ? null
            : raftText(context, widget.placeholder!),
        hintStyle: style.copyWith(color: placeholderColor),
      ),
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
    );
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: RaftRecipeBox(
        style: root,
        tokens: tokens,
        height: minHeight,
        applyText: false,
        child: editor,
      ),
    );
  }
}

/// CSS outer `box-shadow`s are clipped to outside the border box, so a
/// translucent background (e.g. the invalid input tint) never shows the
/// shadow through it. Flutter's BoxShadow fills underneath; this paints the
/// non-inset shadows of [decoration] with the box itself cut out.
class RaftCssOuterShadow extends StatelessWidget {
  const RaftCssOuterShadow({
    super.key,
    required this.decoration,
    required this.child,
  });
  final BoxDecoration decoration;
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CssOuterShadowPainter(
      decoration.boxShadow ?? const [],
      decoration.borderRadius?.resolve(Directionality.maybeOf(context)),
    ),
    child: child,
  );
}

class _CssOuterShadowPainter extends CustomPainter {
  _CssOuterShadowPainter(this.shadows, this.radius);
  final List<BoxShadow> shadows;
  final BorderRadius? radius;
  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final box = (radius ?? BorderRadius.zero).toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(1e4))
        ..addRRect(box),
    );
    for (final s in shadows) {
      final shape = box.shift(s.offset).inflate(s.spreadRadius);
      canvas.drawRRect(shape, s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CssOuterShadowPainter old) =>
      old.shadows != shadows || old.radius != radius;
}

/// One option of [RaftAgentSelect].
class RaftAgentSelectOption<T> {
  const RaftAgentSelectOption(this.value, this.label, {this.enabled = true});
  final T value;
  final String label;
  final bool enabled;
}

/// raft-ui Select with `chrome="field"`: trigger = Button(outline, md) merged
/// with the select trigger slot; options open in the raft menu panel.
class RaftAgentSelect<T> extends StatefulWidget {
  const RaftAgentSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'Select...',
    this.invalid = false,
    this.semanticLabel,
  });
  final T? value;
  final List<RaftAgentSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String placeholder;
  final bool invalid;
  final String? semanticLabel;
  @override
  State<RaftAgentSelect<T>> createState() => _RaftAgentSelectState<T>();
}

class _RaftAgentSelectState<T> extends State<RaftAgentSelect<T>> {
  final portal = OverlayPortalController();
  final link = LayerLink();
  double width = 0;

  void close() {
    if (portal.isShowing) setState(portal.hide);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final open = portal.isShowing;
    final enabled = widget.onChanged != null;
    final flags = {
      if (widget.invalid) 'data-invalid',
      if (open) 'data-popup-open',
      if (!enabled) RaftRecipeStates.disabled,
    };
    final button = RaftButtonRecipe.resolve(
      theme: _theme(t),
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.md,
      states: _states(t, flags),
      tokens: tokens,
    ).root;
    final select = RaftSelectRecipe.resolve(
      theme: _theme(t),
      chrome: RaftSelectRecipeChrome.field,
      states: _states(t, flags),
      tokens: tokens,
    );
    // tailwind-merge: the select trigger classes win over the button's.
    final trigger = RaftSlotStyle(
      {...button.properties, ...select.trigger.properties},
      {...button.targets, ...select.trigger.targets},
      const [],
      tokens,
    );
    final selected = widget.options
        .where((o) => o.value == widget.value)
        .firstOrNull;
    final style = trigger.textStyle(tokens);
    final icon = select.icon;
    Widget body = RaftRecipeBox(
      style: trigger,
      tokens: tokens,
      applyTransform: false,
      child: Row(
        children: [
          Expanded(
            child: RaftCssText(
              selected?.label ?? raftText(context, widget.placeholder),
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 1.5 * _tw), // select-trigger-content gap-1.5
          Opacity(
            opacity: icon.opacity ?? 1,
            child: RaftIcon(
              RaftGlyph.chevronDown,
              size: icon.target('& > svg')?.width ?? 14,
              strokeWidth: 1.5,
              color: style.color,
            ),
          ),
        ],
      ),
    );
    final translate = trigger.translate;
    if (translate != null) {
      body = Transform.translate(offset: translate, child: body);
    }
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      value: selected?.label,
      child: CompositedTransformTarget(
        link: link,
        child: OverlayPortal(
          controller: portal,
          overlayChildBuilder: (context) => Positioned.fill(
            child: TapRegion(
              onTapOutside: (_) => close(),
              child: Stack(
                children: [
                  CompositedTransformFollower(
                    link: link,
                    targetAnchor: Alignment.bottomLeft,
                    offset: const Offset(0, _tw),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: RaftMenuPanel(
                        width: width,
                        onDismiss: close,
                        children: [
                          for (final o in widget.options)
                            RaftMenuItem(
                              label: o.label,
                              selected: o.value == widget.value,
                              onPressed: o.enabled
                                  ? () {
                                      close();
                                      widget.onChanged?.call(o.value);
                                    }
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              width = box.maxWidth.isFinite ? box.maxWidth : 192;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled && widget.options.isNotEmpty
                    ? () => setState(portal.toggle)
                    : null,
                child: body,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Banner `status` axis.
enum RaftAgentBannerStatus { warning, info, destructive, success }

/// raft-ui Banner (status + optional title, description spans).
class RaftAgentBanner extends StatelessWidget {
  const RaftAgentBanner({
    super.key,
    required this.status,
    required this.description,
    this.title,
    this.action,
    this.onAction,
    this.backgroundColor,
    this.foregroundColor,
    this.actionForeground,
  });
  final RaftAgentBannerStatus status;

  /// Explicit product caller classes (for example the capacity warning’s
  /// dark:bg-warning-soft and dark:!text-warning-strong). Null keeps the recipe.
  final Color? backgroundColor, foregroundColor, actionForeground;
  final String? title, action;
  final String description;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final b = RaftBannerRecipe.resolve(
      theme: _theme(t),
      status: switch (status) {
        RaftAgentBannerStatus.warning => RaftBannerRecipeStatus.warning,
        RaftAgentBannerStatus.info => RaftBannerRecipeStatus.info,
        RaftAgentBannerStatus.destructive => RaftBannerRecipeStatus.destructive,
        RaftAgentBannerStatus.success => RaftBannerRecipeStatus.success,
      },
      states: _states(t, {
        'group/banner:data-status=${status.name}',
        if (title != null)
          'has:>data-slot=banner-description+has:>data-slot=banner-title',
      }),
      tokens: tokens,
    );
    final descriptionText = b.description.text(
      tokens,
      base: b.root.text(tokens),
    );
    final descriptionColor = foregroundColor ?? descriptionText.color;
    return Semantics(
      container: true,
      child: RaftRecipeBox(
        style: b.root,
        tokens: tokens,
        decorationOverride: backgroundColor == null
            ? null
            : (d) => d.copyWith(color: backgroundColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: b.title.margin,
                child: Text(
                  raftText(context, title!),
                  style: b.title
                      .text(tokens, base: b.root.text(tokens))
                      .copyWith(color: foregroundColor),
                ),
              ),
            RaftAgentInlineText(
              description,
              action: action,
              onAction: onAction,
              style: descriptionText.copyWith(color: descriptionColor),
              actionForeground:
                  actionForeground ??
                  b.description
                      .target('& button')
                      ?.color
                      ?.resolve(tokens, currentColor: descriptionColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sentence ending in an inline action — `Button variant="link"
/// size="inline"` (`h-auto p-0 align-baseline leading-[inherit]`, bold,
/// foreground): a word in the line that happens to be clickable.
class RaftAgentInlineText extends StatefulWidget {
  const RaftAgentInlineText(
    this.text, {
    super.key,
    this.action,
    this.onAction,
    this.style,
    this.actionForeground,
  });
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final TextStyle? style;
  final Color? actionForeground;
  @override
  State<RaftAgentInlineText> createState() => _RaftAgentInlineTextState();
}

class _RaftAgentInlineTextState extends State<RaftAgentInlineText> {
  final tap = TapGestureRecognizer();
  @override
  void dispose() {
    tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final link = RaftButtonRecipe.resolve(
      theme: _theme(t),
      variant: RaftButtonRecipeVariant.link,
      size: RaftButtonRecipeSize.inline,
      states: _states(t, {
        if (widget.onAction == null) RaftRecipeStates.disabled,
      }),
      tokens: tokens,
    ).root;
    tap.onTap = widget.onAction;
    final color = widget.actionForeground ?? link.color?.resolve(tokens);
    return RaftCssText.rich(
      TextSpan(
        text: raftText(context, widget.text),
        children: [
          if (widget.action != null) ...[
            const TextSpan(text: ' '),
            TextSpan(
              text: raftText(context, widget.action!),
              recognizer: widget.onAction == null ? null : tap,
              mouseCursor: widget.onAction == null
                  ? null
                  : SystemMouseCursors.click,
              style: TextStyle(
                fontWeight: link.fontWeight,
                color: color?.withValues(alpha: color.a * (link.opacity ?? 1)),
              ),
            ),
          ],
        ],
      ),
      style: widget.style,
    );
  }
}

/// Model-source status line: `mt-2 border-l-2 border-line-muted pl-2 text-xs
/// text-foreground-muted` with an inline Retry action.
class RaftAgentSourceStatus extends StatelessWidget {
  const RaftAgentSourceStatus({
    super.key,
    required this.message,
    this.retryLabel,
    this.onRetry,
  });
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftAgentInlineText(
      message,
      action: retryLabel,
      onAction: onRetry,
      style: TextStyle(fontSize: 12, height: 16 / 12, color: t.muted),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2 * _tw), // mt-2
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: t.colors['line-muted']!, width: 2),
          ),
        ),
        padding: const EdgeInsets.only(left: 2 * _tw), // pl-2
        child: text,
      ),
    );
  }
}

/// `mt-1.5 text-xs text-foreground-muted` helper paragraph below a control.
class RaftAgentFieldNote extends StatelessWidget {
  const RaftAgentFieldNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 1.5 * _tw),
      child: Text(
        raftText(context, text),
        style: TextStyle(fontSize: 12, height: 16 / 12, color: t.muted),
      ),
    );
  }
}

/// RuntimeConfigFields "More" toggle: `flex items-center gap-1 text-sm
/// font-bold uppercase tracking-wide text-foreground-muted` with a 16px
/// chevron; open content sits `mt-3 space-y-3` below.
class RaftAgentMoreDisclosure extends StatelessWidget {
  const RaftAgentMoreDisclosure({
    super.key,
    required this.open,
    required this.onToggle,
    required this.children,
    this.label = 'More',
  });
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            expanded: open,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftIcon(
                    open ? RaftGlyph.chevronDown : RaftGlyph.chevronRight,
                    size: 16,
                    color: t.muted,
                  ),
                  const SizedBox(width: _tw), // gap-1
                  Text(
                    raftText(context, label).toUpperCase(),
                    style: TextStyle(
                      fontSize: 14, // text-sm
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 14 * .025, // tracking-wide
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open)
          for (final child in children) ...[
            const SizedBox(height: 3 * _tw), // mt-3 / space-y-3
            child,
          ],
      ],
    );
  }
}

/// Footer: `flex justify-end gap-3` with outline + accent `size="lg"` buttons.
class RaftAgentDialogFooter extends StatelessWidget {
  const RaftAgentDialogFooter({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
  });
  final List<Widget> children;
  final MainAxisAlignment alignment;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: alignment == MainAxisAlignment.end
        ? WrapAlignment.end
        : WrapAlignment.start,
    spacing: 3 * _tw, // gap-3
    runSpacing: 3 * _tw,
    children: children,
  );
}

/// Height of a `size="lg"` button from the button recipe.
double raftAgentLgButtonHeight(BuildContext context) {
  final t = RaftTokens.of(context);
  return RaftButtonRecipe.resolve(
        theme: _theme(t),
        variant: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.lg,
        tokens: RaftRecipeTokens(t),
      ).root.height ??
      40;
}

/// Footer action button (`size="lg"`): outline for Cancel, accent for the
/// primary action. Uses the shared raft control.
class RaftAgentDialogButton extends StatelessWidget {
  const RaftAgentDialogButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = false,
    this.busy = false,
    this.expand = false,
    this.foreground,
  });
  final String label;

  /// Explicit caller color; null keeps the shared button default.
  final Color? foreground;
  final VoidCallback? onPressed;
  final bool primary, busy, expand;
  @override
  Widget build(BuildContext context) {
    // `<Button size="lg">`: the recipe-exact shared button (touch target is
    // an overlay, not layout).
    return RaftButton(
      label: label,
      foreground: foreground,
      busy: busy,
      tone: primary
          ? RaftButtonRecipeVariant.accent
          : RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.lg,
      expand: expand,
      onPressed: onPressed,
    );
  }
}

/// Reads a field's column gap so callers can stack fields with the Web form
/// rhythm (`space-y-1`).
const double raftAgentFormGap = _tw; // form `space-y-1`

/// `gap-2` between inline choice chips.
const double raftAgentChipGap = 2 * _tw;

/// `mt-4` between a notice and its footer (needs-computer card).
const double raftAgentSectionGap = 4 * _tw;
