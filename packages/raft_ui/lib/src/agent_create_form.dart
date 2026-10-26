// Create-agent / runtime-form dialog building blocks, composed from the
// generated raft-ui recipes the same way the Web client composes them:
//
//   DialogCard          packages/web/src/components/ui/DialogCard.tsx (Modal +
//                       Card p-6 + CardHeader mb-4 + CardTitle text-lg bold
//                       + CloseButton)
//   StableField         packages/web/src/components/agent/StableField.tsx
//                       (Field gap + label + control + reserved
//                       one-line message row with optional counter)
//   Input / Textarea    raft-ui `input` / `textarea` recipes
//   Select trigger      raft-ui SelectTrigger = Button(outline, md) merged with
//                       `select` trigger (chrome=field)
//   Banner              raft-ui `banner` recipe
//   MORE disclosure     RuntimeConfigFields.tsx advanced toggle
//
// Values come from the recipes; the few Tailwind classes written directly in
// Web JSX are cited next to the number that resolves them.

import 'form_controls.dart'
    show
        RaftTextInput,
        RaftTextarea,
        RaftLegacyInput,
        RaftField,
        RaftLegacyField;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'system_inset.dart';
import 'banner.dart' show RaftBanner;
import 'select_field.dart';

import 'components.dart';
import 'design_primitives.dart';
import 'dismiss_scope.dart';
import 'form_presentation.dart';
import 'icons.dart';
import 'indicators.dart' show RaftCheckbox, RaftCheckboxRecipeSize;
import 'localization.dart';
import 'recipe_surface.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'recipes/banner.g.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';
import 'recipes/select.g.dart';
import 'theme.dart';

RaftRecipeTheme _theme(RaftTokens t) => RaftRecipeTheme.elegant;
RaftRecipeStates _states(RaftTokens t, [Set<String> flags = const {}]) =>
    RaftRecipeStates({...flags, if (t.dark) RaftRecipeStates.dark});

/// Tailwind spacing scale step (`--spacing: 0.25rem`): `gap-1` = 4px.
const double _tw = 4;

/// Modal.tsx backdrop: `bg-layer-backdrop … theme-brutal:bg-black/60`.
Color raftAgentModalBarrier(RaftTokens t) => t.colors['layer-backdrop']!;

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
    pageBuilder: (context, _, _) => RaftDismissScope(child: builder(context)),
  );
}

/// Web DialogCard: Card (`w-full max-w-md p-6`) with header row
/// (`mb-4 flex items-center justify-between`), title (`text-lg font-bold`)
/// and a CloseButton (ghost icon-sm, brutal: bordered white).
///
/// In a presented form window on a phone ([showRaftForm], below 768) the card
/// is the sheet: the title and close button pin to the top, [children] scroll
/// and [footer] pins to the bottom, above the keyboard.
class RaftAgentDialogCard extends StatefulWidget {
  const RaftAgentDialogCard({
    super.key,
    required this.title,
    required this.children,
    this.onClose,
    this.onBackdrop,
    this.maxWidth = 448, // max-w-md = 28rem
    this.surfaceKey,
    this.bare = false,
    this.plainCard = false,
    this.footer,
    this.footerGap = 4 * _tw,
  });

  /// The submit row of a form. In a dialog it follows [children] after
  /// [footerGap]; in a bottom sheet it pins to the bottom while [children]
  /// scroll.
  final Widget? footer;
  final double footerGap;

  /// The `card-brutal` utility instead of the raft-ui Card (the agent runtime
  /// config modal): `border border-line-muted bg-layer-panel shadow-raft-md`,
  /// square, in Elegant; Brutal paints the same hard card as the recipe.
  final bool plainCard;

  /// Only the card, for a host that already provides the `Modal` frame
  /// (backdrop, `p-4` padding, centring and scrolling): see
  /// [RaftModalBackdrop].
  final bool bare;

  /// Key of the card surface itself (`dialog-content`).
  final Key? surfaceKey;
  final String title;
  final List<Widget> children;
  final VoidCallback? onClose;

  /// `Modal closeOnBackdrop`: a press on the backdrop (outside the card).
  final VoidCallback? onBackdrop;
  final double maxWidth;

  @override
  State<RaftAgentDialogCard> createState() => _RaftAgentDialogCardState();
}

class _RaftAgentDialogCardState extends State<RaftAgentDialogCard> {
  final _body = GlobalKey(debugLabel: 'agent card body');
  final _footer = GlobalKey(debugLabel: 'agent card footer');

  @override
  Widget build(BuildContext context) {
    final title = widget.title,
        onClose = widget.onClose,
        onBackdrop = widget.onBackdrop,
        maxWidth = widget.maxWidth;
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final footerRow = widget.footer;
    final body = KeyedSubtree(
      key: _body,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.children,
      ),
    );
    final footer = footerRow == null
        ? null
        : KeyedSubtree(key: _footer, child: footerRow);
    final card_ = RaftCardRecipe.resolve(
      theme: _theme(t),
      states: _states(t),
      tokens: tokens,
    );
    final base = card_.root
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
    if (RaftFormFrame.sheetOf(context)) {
      return DefaultTextStyle(
        style: base,
        child: RaftFormSheet(
          title: raftText(context, title),
          onClose: onClose,
          closeButton: onClose == null
              ? const SizedBox.shrink()
              : RaftAgentCloseButton(
                  onPressed: raftGuardedClose(context, onClose),
                ),
          body: body,
          footer: footer,
        ),
      );
    }
    final titleStyle = card_.title
        .textStyle(tokens)
        .copyWith(
          fontSize: 18, // text-lg: 1.125rem / 1.75rem
          height: 28 / 18,
          fontWeight: FontWeight.w700, // font-bold
        );
    final card = Material(
      type: MaterialType.transparency,
      child: _CardSurface(
        key: widget.surfaceKey,
        plain: widget.plainCard,
        style: card_.root.withCssUsedBorderWidths(),
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
                      child: Text(raftText(context, title), style: titleStyle),
                    ),
                  ),
                  if (onClose != null)
                    RaftAgentCloseButton(
                      onPressed: raftGuardedClose(context, onClose),
                    ),
                ],
              ),
              const SizedBox(height: 4 * _tw), // mb-4
              body,
              if (footer != null) ...[
                SizedBox(height: widget.footerGap),
                footer,
              ],
            ],
          ),
        ),
      ),
    );
    if (widget.bare) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: card,
      );
    }
    if (RaftFormFrame.framedOf(context)) {
      // The presented window already centers the card over its scrim.
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: card,
        ),
      );
    }
    // Edge to edge: a dialog taller than the screen scrolls clear of the
    // gesture / nav bar (0 on desktop and under a SafeArea route).
    final inset = raftBottomInset(context);
    final modal = LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        // Modal inner `p-4`
        padding: EdgeInsets.fromLTRB(
          4 * _tw,
          4 * _tw,
          4 * _tw,
          4 * _tw + inset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.maxHeight.isFinite
                ? math.max(0, box.maxHeight - 8 * _tw - inset)
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // A press on the card never reaches the backdrop handler.
                onTap: onBackdrop == null ? null : () {},
                excludeFromSemantics: true,
                child: card,
              ),
            ),
          ),
        ),
      ),
    );
    if (onBackdrop == null) return modal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBackdrop,
      excludeFromSemantics: true,
      child: modal,
    );
  }
}

/// The dialog card surface: the recipe box, or the plain `card-brutal` chrome.
class _CardSurface extends StatelessWidget {
  const _CardSurface({
    super.key,
    required this.plain,
    required this.style,
    required this.child,
  });
  final bool plain;
  final RaftSlotStyle style;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftRecipeBox(
      style: style,
      tokens: RaftRecipeTokens(t),
      applyText: false,
      width: double.infinity,
      padding: const EdgeInsets.all(6 * _tw), // p-6
      // `card-brutal`: no radius, `bg-layer-panel`, `border-line-muted`.
      decorationOverride: plain
          ? (base) => base.copyWith(
              borderRadius: BorderRadius.zero,
              color: t.colors['layer-panel'],
              border: Border.all(color: t.colors['line-muted']!),
            )
          : null,
      child: child,
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
      variant: RaftControlVariant.ghost,
      onPressed: onPressed,
    );
  }
}

/// StableField: label (+ asterisk) / control / belowControl / reserved message row, the agent forms'
/// [RaftField] with a held-open message row.
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
  Widget build(BuildContext context) => RaftField(
    label: label,
    required: required,
    hint: hint,
    error: error,
    counter: counter,
    labelAccessory: labelAccessory,
    belowControl: belowControl,
    reserveMessage: true,
    legacy: RaftLegacyField.stable,
    child: child,
  );
}

/// raft-ui Input (or Textarea when [multiline]) in the agent forms: the shared [RaftTextInput] /
/// [RaftTextarea] with this form's call shape.
class RaftAgentTextInput extends StatelessWidget {
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
    this.focusNode,
    this.trailing,
    this.onTap,
    this.onKeyEvent,
  });
  final TextEditingController controller;
  final String? placeholder, semanticLabel;
  final bool invalid, readOnly, enabled, obscure, multiline;
  final int rows;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  /// The host's focus node (a combobox input); its owner disposes it.
  final FocusNode? focusNode;

  /// A glyph at the end of the box (a combobox chevron), inside the border.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Keys the input receives before it handles them itself.
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final hint = placeholder == null ? null : raftText(context, placeholder!);
    return multiline
        ? RaftTextarea(
            controller: controller,
            hintText: hint,
            invalid: invalid,
            readOnly: readOnly,
            enabled: enabled,
            rows: rows,
            maxLength: maxLength,
            onChanged: onChanged,
            semanticLabel: semanticLabel,
            focusNode: focusNode,
            legacy: RaftLegacyInput.recipe,
          )
        : RaftTextInput(
            controller: controller,
            hintText: hint,
            invalid: invalid,
            readOnly: readOnly,
            enabled: enabled,
            obscureText: obscure,
            maxLength: maxLength,
            onChanged: onChanged,
            semanticLabel: semanticLabel,
            focusNode: focusNode,
            trailing: trailing,
            onTap: onTap,
            onKeyEvent: onKeyEvent,
            legacy: RaftLegacyInput.recipe,
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
class RaftAgentSelect<T> extends StatelessWidget {
  const RaftAgentSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'Select...',
    this.invalid = false,
    this.semanticLabel,
    this.unmatchedLabel,
  });

  /// Shown for a [value] that no option carries (Base UI renders the raw
  /// value when its `items` do not include it); the placeholder otherwise.
  final String? unmatchedLabel;
  final T? value;
  final List<RaftAgentSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String placeholder;
  final bool invalid;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => RaftSelectField<T>(
    value: value,
    chrome: RaftSelectRecipeChrome.field,
    height: RaftTokens.of(context).size('size.fieldSelect', fallback: 36),
    items: [
      for (final option in options)
        RaftSelectItem<T>(
          value: option.value,
          enabled: option.enabled,
          label: option.label,
        ),
    ],
    onChanged: onChanged == null
        ? null
        : (value) {
            if (value != null) onChanged!(value);
          },
    label: semanticLabel,
    placeholder: placeholder,
    unmatchedLabel: unmatchedLabel,
    invalid: invalid,
  );
}

/// Banner `status` axis.
enum RaftAgentBannerStatus { warning, info, destructive, success }

/// raft-ui Banner (status + optional title, description with an inline
/// action): the agent dialogs' call shape over [RaftBanner].
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
  Widget build(BuildContext context) => RaftBanner(
    status: switch (status) {
      RaftAgentBannerStatus.warning => RaftBannerRecipeStatus.warning,
      RaftAgentBannerStatus.info => RaftBannerRecipeStatus.info,
      RaftAgentBannerStatus.destructive => RaftBannerRecipeStatus.destructive,
      RaftAgentBannerStatus.success => RaftBannerRecipeStatus.success,
    },
    live: false,
    title: title,
    description: description,
    // The frozen looks never put a gap under these titles.
    titleGap: RaftTokens.of(context).recipeSet == RaftRecipeSet.raft ? null : 0,
    linkAction: (label: action, onPressed: onAction),
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    actionForeground: actionForeground,
  );
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
    final color =
        widget.actionForeground ??
        t.colors['foreground-button-link'] ??
        link.color?.resolve(tokens);
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
                decoration:
                    t.option('button.linkDecoration', or: 'none') == 'underline'
                    ? TextDecoration.underline
                    : TextDecoration.none,
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

/// CreateAgentDialog `autoJoinChannelName` line: `rounded-container
/// bg-info-soft px-3 py-2 text-footnote font-semibold text-foreground`, a plain
/// persistent context line (not a Banner) that stays until submit. [text] is
/// already localized.
class RaftAgentContextLine extends StatelessWidget {
  const RaftAgentContextLine(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 3 * _tw,
        vertical: 2 * _tw,
      ),
      decoration: BoxDecoration(
        color: t.colors['info-soft'],
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13, // text-footnote
          height: 18 / 13,
          fontWeight: FontWeight.w600,
          color: t.colors['foreground'],
        ),
      ),
    );
  }
}

/// CreateAgentDialog `prefilledNameNote`: `text-caption text-foreground-hint`
/// paragraph under the name field. [text] is already localized.
class RaftAgentHintNote extends StatelessWidget {
  const RaftAgentHintNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 12, // text-caption
        height: 16 / 12,
        color: t.colors['foreground-hint'] ?? t.muted,
      ),
    );
  }
}

/// RuntimeConfigFields "More" toggle: `flex items-center gap-1 text-sm
/// font-bold text-foreground-muted` with a 16px
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
                    raftText(context, label),
                    style: TextStyle(
                      fontSize: 14, // text-sm
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
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
    this.size = RaftButtonRecipeSize.lg,
    this.accent = true,
  });
  final String label;

  /// `size="md"` for the runtime config editor, `lg` for the create dialogs.
  final RaftButtonRecipeSize size;

  /// The primary action uses the `accent` variant (false: `primary`).
  final bool accent;

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
          ? (accent
                ? RaftButtonRecipeVariant.accent
                : RaftButtonRecipeVariant.primary)
          : (RaftTokens.of(context)
                        .option('dialog.cancelSurface', or: 'outline') ==
                    'ghost'
                ? RaftButtonRecipeVariant.ghost
                : RaftButtonRecipeVariant.outline),
      size: size,
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

/// Web `<Card variant="option" render={<label />}>` holding a Checkbox leading
/// slot, a `CardTitle` and an optional `CardDescription`
/// (RuntimeConfigFields Fast mode / Load local Pi extensions).
class RaftAgentOptionCard extends StatelessWidget {
  const RaftAgentOptionCard({
    super.key,
    required this.checked,
    required this.title,
    required this.onChanged,
    this.description,
  });
  final bool checked;
  final String title;
  final String? description;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final card = RaftCardRecipe.resolve(
      theme: _theme(t),
      variant: RaftCardRecipeVariant.option,
      states: _states(t),
      tokens: tokens,
    );
    final gap = card.header.columnGap ?? 12;
    final rowGap = card.header.rowGap ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      child: RaftRecipeBox(
        style: card.root.withCssUsedBorderWidths(),
        tokens: tokens,
        applyText: false,
        width: double.infinity,
        padding: card.header.padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RaftCheckbox(
              value: checked,
              size: RaftCheckboxRecipeSize.md,
              onChanged: onChanged,
              semanticLabel: raftText(context, title),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RaftCssText(
                    raftText(context, title),
                    style: card.title
                        .textStyle(tokens)
                        .copyWith(
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                  ),
                  if (description != null) ...[
                    SizedBox(height: rowGap),
                    RaftCssText(
                      raftText(context, description!),
                      style: card.description
                          .textStyle(tokens)
                          .copyWith(
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web `KeyValueInputRow` list + `KeyValueAddButton`: name input, `=`, value
/// input and a danger icon button per row, then a ghost "Add Variable" button.
class RaftAgentKeyValueRows extends StatefulWidget {
  const RaftAgentKeyValueRows({
    super.key,
    required this.entries,
    required this.onChanged,
    this.enabled = true,
    this.hint,
  });

  /// `mb-2 -mt-1 text-xs text-foreground-muted` line above the rows.
  final String? hint;

  /// The rows when mounted; later edits are reported through [onChanged] and
  /// owned by this widget's text controllers.
  final List<MapEntry<String, String>> entries;
  final ValueChanged<List<MapEntry<String, String>>> onChanged;
  final bool enabled;
  @override
  State<RaftAgentKeyValueRows> createState() => _RaftAgentKeyValueRowsState();
}

class _RaftAgentKeyValueRowsState extends State<RaftAgentKeyValueRows> {
  final keys = <TextEditingController>[], values = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    for (final e in widget.entries) {
      keys.add(TextEditingController(text: e.key));
      values.add(TextEditingController(text: e.value));
    }
  }

  @override
  void dispose() {
    for (final c in [...keys, ...values]) {
      c.dispose();
    }
    super.dispose();
  }

  void report() => widget.onChanged([
    for (var i = 0; i < keys.length; i++)
      MapEntry(keys[i].text, values[i].text),
  ]);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2 * _tw, // space-y-2
      children: [
        for (var i = 0; i < keys.length; i++)
          Row(
            key: ValueKey('env-row-${keys[i].hashCode}'),
            spacing: 2 * _tw, // gap-2
            children: [
              Expanded(
                flex: 1,
                child: RaftAgentTextInput(
                  key: ValueKey('env-key-$i'),
                  controller: keys[i],
                  semanticLabel: tr('Environment variable name'),
                  placeholder: tr('KEY'),
                  enabled: widget.enabled,
                  onChanged: (_) => report(),
                ),
              ),
              RaftCssText(
                '=',
                style: TextStyle(color: t.colors['foreground-muted']),
              ),
              Expanded(
                flex: 2,
                child: RaftAgentTextInput(
                  key: ValueKey('env-value-$i'),
                  controller: values[i],
                  semanticLabel: raftFormat(context, 'Value for {name}', {
                    'name': keys[i].text.isEmpty
                        ? tr('environment variable')
                        : keys[i].text,
                  }),
                  placeholder: tr('value'),
                  enabled: widget.enabled,
                  onChanged: (_) => report(),
                ),
              ),
              RaftIconButton(
                key: ValueKey('env-remove-$i'),
                glyph: RaftGlyph.trash2,
                tooltip: tr('Remove Environment Variable'),
                visualSize: 24,
                minimumTargetSize: 24,
                glyphSize: 14,
                variant: RaftControlVariant.danger,
                onPressed: widget.enabled
                    ? () {
                        setState(() {
                          keys.removeAt(i).dispose();
                          values.removeAt(i).dispose();
                        });
                        report();
                      }
                    : null,
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: RaftButton(
            key: const ValueKey('env-add'),
            label: tr('Add Variable'),
            glyph: RaftGlyph.plus,
            tone: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.sm,
            onPressed: widget.enabled
                ? () {
                    setState(() {
                      keys.add(TextEditingController());
                      values.add(TextEditingController());
                    });
                    report();
                  }
                : null,
          ),
        ),
      ],
    );
    if (widget.hint == null) return rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2 * _tw),
          child: RaftCssText(
            raftText(context, widget.hint!),
            style: TextStyle(fontSize: 12, height: 16 / 12, color: t.muted),
          ),
        ),
        rows,
      ],
    );
  }
}
