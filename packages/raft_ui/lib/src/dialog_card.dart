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
import 'form_controls.dart' show RaftField, RaftTextInput, RaftTextarea;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'form_presentation.dart';
import 'overlays/dialog.dart' show RaftDialog, showRaftDialog;
import 'dialog_surface.dart';
import 'presentation.dart' show RaftSurfaceForm;
import 'system_inset.dart';

import 'package:flutter/rendering.dart';

import 'dismiss_scope.dart';
import 'icons.dart';
import 'localization.dart';
import 'raft/ui_tokens.dart' show raftChromeBlend;
import 'recipes/button_variants.g.dart';
import 'raft/button.dart' show RaftButton;
import 'tokens/tokens.dart' show RaftDesktopMetrics;
import 'recipes/recipe_runtime.dart';
import 'status_bar.dart';
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

/// raft-ui `Button` painted from `buttonVariants`. [padding], [textStep] and
/// [expand] are the JSX `className` overrides (`px-4 py-2`, `text-sm`,
/// `w-full`).
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
    this.foreground,
    this.gap,
    this.fontWeight,
    this.focusNode,
    this.glyphTrailing = false,
    this.focusRing = false,
    this.disabledOpacity,
    this.underline = false,
    this.autoHeight = false,
    this.squareExtent,
    this.metricsKey,
  });

  /// A product icon button that is smaller than the raft-ui icon size (the
  /// feedback attachment's remove badge): the ported surface keeps its recipe
  /// look at this extent instead of the 32px `icon-xs`.
  final double? squareExtent;

  /// Component-specific size/type values, shared by both surface renderers.
  final String? metricsKey;

  /// Callsite `underline`.
  final bool underline;

  /// Callsite `h-auto min-h-8 whitespace-normal text-center`: the recipe
  /// height is a minimum and a long label wraps.
  final bool autoHeight;

  /// Callsite `disabled:opacity-*` replacing the recipe's disabled opacity.
  final double? disabledOpacity;

  /// Paints the focus-visible ring while focused even after a pointer press
  /// (Blink keeps `:focus-visible` on an element that script focused when a
  /// click lands on it again).
  final bool focusRing;

  /// Focus node of the control (e.g. a modal's primary action that takes
  /// focus when it opens).
  final FocusNode? focusNode;

  /// The glyph follows the label (`{label}<ChevronRight />`).
  final bool glyphTrailing;

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
  final Color? foreground;

  /// `gap-*` override of the recipe gap.
  final double? gap;
  @override
  Widget build(BuildContext context) => RaftButton(
    label: label ?? '',
    child: child,
    glyph: glyph,
    onPressed: onPressed,
    disabled: disabled,
    tone: variant,
    size: size,
    padding: padding,
    textStep: textStep,
    expand: expand,
    semanticLabel: tooltip,
    foreground: foreground,
    gap: gap,
    fontWeight: fontWeight,
    focusNode: focusNode,
    iconInlineStart: false,
    iconInlineEnd: glyphTrailing,
    focusRing: focusRing,
    disabledOpacity: disabledOpacity,
    underline: underline,
    autoHeight: autoHeight,
    physicalHeight: squareExtent,
    visualWidth: squareExtent,
    metricsKey: metricsKey,
  );
}

/// Web v1.24 `CloseButton`: ghost `icon-md` Button (the 32px ×) that, with a
/// mouse on a desktop, is a 28px bar button at radius 6
/// (`md:pointer-fine:size-(--bar-button-size) rounded-(--bar-button-radius)`,
/// `BAR_BUTTON_DESKTOP`).
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
    if (t.desktop) {
      const bar = RaftDesktopMetrics.barButtonSize;
      return RaftButton(
        tone: RaftButtonRecipeVariant.ghost,
        size: RaftButtonRecipeSize.iconMd,
        glyph: RaftGlyph.x,
        semanticLabel: raftText(context, tooltip),
        onPressed: onPressed,
        foreground: t.colors['foreground-muted'],
        physicalHeight: bar,
        visualWidth: bar,
        styleBuilder: (context, state, style) => style.copyWith(
          properties: {
            ...style.properties,
            for (final corner in [
              'top-left',
              'top-right',
              'bottom-left',
              'bottom-right',
            ])
              'border-$corner-radius': const CssNum(
                RaftDesktopMetrics.barButtonRadius,
                'px',
              ),
          },
        ),
      );
    }
    return RaftRecipeButton(
      variant: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.iconMd,
      // `<X size={20} />`, but the recipe's `& svg:not([class*='size-'])`
      // width/height win over Lucide's size attributes.
      glyph: RaftGlyph.x,
      tooltip: raftText(context, tooltip),
      onPressed: onPressed,
      // text-foreground-muted.
      foreground: t.colors['foreground-muted'],
    );
  }
}

/// The quiet icon action beside [RaftCloseButton] in a panel bar that opens the
/// message's thread (Web `PanelAction` with the raft-ui `ThreadIcon`).
class RaftThreadViewButton extends StatelessWidget {
  const RaftThreadViewButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'View in thread',
  });
  final VoidCallback? onPressed;
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = t.colors['foreground-muted']!;
    return RaftRecipeButton(
      variant: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.iconSm,
      tooltip: raftText(context, tooltip),
      onPressed: onPressed,
      foreground: color,
      child: RaftThreadIcon(size: 14, color: color),
    );
  }
}

/// Web `Modal`: `fixed inset-0 overflow-y-auto bg-layer-backdrop
/// backdrop-blur-[2px]`, then `flex min-h-full p-4`
/// and a `m-auto flex w-full justify-center` column holding [child].
///
/// Inside a presented form window ([showRaftForm]) the route draws the scrim,
/// the centering and the sheet, so the backdrop only passes [child] through
/// (scrolling when it is taller than the window); [child] keeps its state when
/// the window crosses the sheet / dialog breakpoint.
class RaftModalBackdrop extends StatefulWidget {
  const RaftModalBackdrop({super.key, required this.child, this.onBackdrop});
  final Widget child;

  /// `closeOnBackdrop`: a press on the backdrop itself (not on [child]).
  final VoidCallback? onBackdrop;

  @override
  State<RaftModalBackdrop> createState() => _RaftModalBackdropState();
}

class _RaftModalBackdropState extends State<RaftModalBackdrop> {
  final _slot = GlobalKey(debugLabel: 'modal backdrop child');

  @override
  Widget build(BuildContext context) {
    final form = RaftFormFrame.maybeOf(context);
    if (form != null) {
      final content = KeyedSubtree(key: _slot, child: widget.child);
      return form == RaftSurfaceForm.sheet
          ? content
          : LayoutBuilder(
              builder: (context, box) => box.hasBoundedHeight
                  ? SingleChildScrollView(child: content)
                  : content,
            );
    }
    final child = widget.child, onBackdrop = widget.onBackdrop;
    final t = RaftTokens.of(context);
    final blur = t.size('blur.modalBackdrop', fallback: 2);
    final scrim = RaftDialogNested.of(context)
        ? t.colors['layer-backdrop-nested']!
        : t.colors['layer-backdrop']!;
    // The scrim dims the status bar band over its width too (see
    // `status_bar.dart`: a modal inside the host's scope publishes it).
    return RaftStatusBarSource(
      color: scrim,
      overlay: true,
      child: BackdropFilter(
        enabled: blur > 0,
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: RaftDialogBackdrop(
          // The scrim fills the window; the card keeps to one side of a hinge.
          child: _FoldAvoiding(
            child: LayoutBuilder(
              builder: (context, box) {
                Widget content = _PixelCenter(child: child);
                if (onBackdrop != null) {
                  // Presses inside [child] never reach the backdrop handler.
                  content = GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBackdrop,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _PixelCenter(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          excludeFromSemantics: true,
                          child: child,
                        ),
                      ),
                    ),
                  );
                } else {
                  content = Padding(
                    padding: const EdgeInsets.all(16),
                    child: content,
                  );
                }
                // Edge to edge: the layer spans the window, so a dialog taller
                // than the screen must scroll clear of the gesture / nav bar.
                // The centring area shrinks by the same amount (0 on desktop).
                final inset = raftBottomInset(context);
                // Web's Dialog caps the popup at `100dvh - 2rem` and scrolls
                // inside the card: a card gets this cap, so the window itself
                // only scrolls for content that is not a card.
                final cap = box.hasBoundedHeight
                    ? math.max(0.0, box.maxHeight - inset - 32)
                    : null;
                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: inset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: box.hasBoundedHeight
                          ? math.max(0, box.maxHeight - inset)
                          : 0,
                    ),
                    child: RaftModalCardCap(maxHeight: cap, child: content),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The height a card may take inside [RaftModalBackdrop] (`100dvh - 2rem`),
/// above which the card scrolls its own content.
class RaftModalCardCap extends InheritedWidget {
  const RaftModalCardCap({
    super.key,
    required this.maxHeight,
    required super.child,
  });
  final double? maxHeight;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftModalCardCap>()?.maxHeight;

  @override
  bool updateShouldNotify(RaftModalCardCap oldWidget) =>
      maxHeight != oldWidget.maxHeight;
}

/// Keeps the card off a fold or hinge while the scrim still spans the window.
class _FoldAvoiding extends StatelessWidget {
  const _FoldAvoiding({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DisplayFeatureSubScreen(child: child);
}

/// `m-auto` centring as Chromium paints it: layout keeps the half-pixel
/// (a 463px dialog in 800px sits at y = 168.5, which is also its screenshot
/// origin) while painting rounds the half up (169), so edges and text land on
/// whole pixels like Blink's snapped boxes.
class _PixelCenter extends SingleChildRenderObjectWidget {
  const _PixelCenter({required Widget child}) : super(child: child);
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPixelCenter();
}

class _RenderPixelCenter extends RenderShiftedBox {
  _RenderPixelCenter() : super(null);
  Offset _snap = Offset.zero;
  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : child.size.width,
        constraints.hasBoundedHeight
            ? constraints.maxHeight
            : child.size.height,
      ),
    );
    final at = Offset(
      (size.width - child.size.width) / 2,
      (size.height - child.size.height) / 2,
    );
    (child.parentData! as BoxParentData).offset = at;
    // Half a pixel (only) rounds up.
    double up(double v) => v - v.floorToDouble() == .5 ? .5 : 0;
    _snap = Offset(up(at.dx), up(at.dy));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final at = (child.parentData! as BoxParentData).offset;
    context.paintChild(child, offset + at + _snap);
  }
}

/// Opens [builder] the way the Web mounts `Modal`: a full-window layer whose
/// backdrop is painted by [RaftModalBackdrop] (not a Material barrier). Like
/// Web (`closeOnEscape` defaults to true) Escape closes it ([RaftDismissScope]);
/// a scrim tap does not (`closeOnBackdrop` is opt-in).
Future<T?> showRaftModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showRaftDialog<T>(context: context, modal: true, builder: builder);

/// The route [showRaftModal] pushes, for hosts that open and close a modal
/// from state (no barrier; [builder] paints its own backdrop, no transition).
RawDialogRoute<T> raftModalRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) => RawDialogRoute<T>(
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  transitionDuration: Duration.zero,
  settings: settings,
  pageBuilder: (context, _, _) => RaftDismissScope(
    child: Material(type: MaterialType.transparency, child: builder(context)),
  ),
);

/// Web `DialogCard`: `Card w-full max-w-md p-6`; header `mb-4 flex
/// items-center justify-between border-b-0 p-0` with a `CardTitle`
/// `text-lg font-bold` (sentence case) and a [RaftCloseButton] (`X` 20).
///
/// In a presented form window on a phone ([showRaftForm], below 768) the card
/// is the sheet: the title and close button pin to the top, [child] scrolls
/// and [actions] pin to the bottom, above the keyboard.
class RaftDialogCard extends StatelessWidget {
  const RaftDialogCard({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.maxWidth = 448,
    this.titleGlyph,
    this.actions,
    this.footer,
    this.footerGap = 16,
    this.description,
  });
  final String title;
  final VoidCallback onClose;
  final Widget child;
  final double maxWidth, footerGap;

  /// DialogCard `description` under the title (Raft look).
  final String? description;
  final RaftGlyph? titleGlyph;
  final Widget? actions, footer;
  @override
  Widget build(BuildContext context) => RaftDialog.card(
    title: title,
    onClose: onClose,
    maxWidth: maxWidth,
    titleGlyph: titleGlyph,
    actions: actions,
    footer: footer,
    footerGap: footerGap,
    description: description,
    child: child,
  );
}

/// Web `FormField` over raft-ui `Field`/`FieldLabel`/`LabelAsterisk`/`LabelOptional` in the dialogs:
/// the shared [RaftField] with this call shape.
class RaftProductFormField extends StatelessWidget {
  const RaftProductFormField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.optional = false,
    this.labelWeight,
    this.hint,
    this.error,
    this.family,
  });
  final String label;
  final Widget child;
  final bool required, optional;
  final FontWeight? labelWeight;
  final String? hint, error;

  /// Label / hint face when the host is not under `font-display` (a portal).
  final String? family;
  @override
  Widget build(BuildContext context) => RaftField(
    label: label,
    required: required,
    optional: optional,
    hint: hint,
    error: error,
    child: child,
  );
}

/// Web `SectionEyebrow`: `text-xs font-bold text-foreground-muted` (sentence
/// case, decision 0002) plus the call-site [padding]/[background]/[color].
class RaftDialogSectionEyebrow extends StatelessWidget {
  const RaftDialogSectionEyebrow(
    this.text, {
    super.key,
    this.padding = EdgeInsets.zero,
    this.background,
    this.color,
  });
  final String text;
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
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: raftCssTextStyle(
          family: t.headingFont,
          step: RaftTextSteps.xs,
          weight: FontWeight.w700,
          color: color ?? t.colors['foreground-muted'],
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
    this.onChanged,
    this.onSubmitted,
    this.fieldKey,
    this.semanticLabel,
    this.obscure = false,
    this.readOnly = false,
    this.mono = false,
    this.focusRingFollowsInputModality = false,
  });
  final TextEditingController controller;
  final String? placeholder, semanticLabel;

  /// Web `readOnly` Input; [mono] is `font-mono text-xs`.
  final bool multiline, autofocus, enabled, obscure, readOnly, mono;

  /// Use keyboard-modality focus paint on the single-line recipe input.
  final bool focusRingFollowsInputModality;
  final RaftGlyph? leadingGlyph;
  final ValueChanged<String>? onChanged, onSubmitted;
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) {
    final hint = placeholder == null ? null : raftText(context, placeholder!);
    final label = semanticLabel == null
        ? null
        : raftText(context, semanticLabel!);
    final tokens = RaftTokens.of(context);
    final selection = tokens.colors['selection'];
    final input = multiline
        ? RaftTextarea(
            controller: controller,
            hintText: hint,
            semanticLabel: label,
            fieldKey: fieldKey,
            autofocus: autofocus,
            enabled: enabled,
            readOnly: readOnly,
            onChanged: onChanged,
            mono: mono,
            textStep: mono ? RaftTextSteps.xs : null,
            growsWithScale: true,
          )
        : RaftTextInput(
            controller: controller,
            hintText: hint,
            semanticLabel: label,
            fieldKey: fieldKey,
            autofocus: autofocus,
            enabled: enabled,
            readOnly: readOnly,
            obscureText: obscure,
            leadingGlyph: leadingGlyph,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            mono: mono,
            focusRingFollowsInputModality: focusRingFollowsInputModality,
            textStep: mono ? RaftTextSteps.xs : null,
          );
    return TextSelectionTheme(
      data: TextSelectionTheme.of(context).copyWith(
        selectionColor: selection != null && !multiline && tokens.card.a == 1
            ? raftChromeBlend(selection, tokens.card)
            : selection,
      ),
      child: input,
    );
  }
}
