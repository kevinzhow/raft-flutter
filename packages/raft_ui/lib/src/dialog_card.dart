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
import 'card.dart' show RaftCard;
import 'form_controls.dart'
    show
        RaftField,
        RaftLegacyField,
        RaftTextInput,
        RaftTextarea,
        RaftLegacyInput;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'form_presentation.dart';
import 'presentation.dart' show RaftSurfaceForm;
import 'system_inset.dart';

import 'package:flutter/rendering.dart';

import 'control_typography.dart';
import 'design_primitives.dart';
import 'dismiss_scope.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';
import 'raft/button.dart' show RaftButton, RaftButtonMetrics;
import 'tokens/tokens.dart' show RaftTypeStyle;
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'status_bar.dart';
import 'text_scaling.dart';
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

RaftRecipeTheme raftRecipeThemeOf(RaftTokens t) => RaftRecipeTheme.elegant;

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
  final BoxDecoration Function(RaftTokens t, bool hovered)? brutalSurface;
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
    legacyBuilder: _paintLegacy,
  );

  Widget _paintLegacy(BuildContext context, RaftInteractionState state) {
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
        if (state.focusVisible || (focusRing && (focusNode?.hasFocus ?? false)))
          RaftRecipeStates.focusVisible,
        if (disabled) RaftRecipeStates.disabled,
      }),
      tokens: tokens,
    ).root;
    var decoration = root.decoration(tokens);

    final base = root.textStyle(tokens);
    final profile = RaftButtonMetrics(
      height: root.height ?? 0,
      paddingX: root.padding.left,
      iconStartPaddingLeft: root.padding.left,
      iconEndPaddingRight: root.padding.right,
      text: RaftTypeStyle(
        base.fontSize ?? 14,
        (base.fontSize ?? 14) * (base.height ?? 1),
      ),
      icon:
          glyphSize ?? root.target("& svg:not([class*='size-'])")?.width ?? 16,
      gap: gap ?? root.columnGap ?? 0,
    ).forComponent(t, metricsKey);
    final color = foreground ?? base.color ?? t.ink;
    final step = textStep;
    final text = RaftControlTypography.of(
      context,
      base.copyWith(
        color: color,
        fontWeight: fontWeight ?? base.fontWeight,
        fontSize:
            step?.$1 ??
            (metricsKey == null ? base.fontSize : profile.text.fontSize),
        height: step == null
            ? (metricsKey == null ? base.height : profile.text.height)
            : step.$2 / step.$1,
        leadingDistribution: TextLeadingDistribution.even,
        decoration: underline ? TextDecoration.underline : null,
      ),
    );
    final wraps = autoHeight || RaftScaled.grows(context);
    final svg = root.target("& svg:not([class*='size-'])");
    final iconSize = metricsKey == null
        ? glyphSize ?? svg?.width ?? 16
        : profile.icon;
    final resolvedGap = metricsKey == null
        ? gap ?? root.columnGap ?? 0
        : profile.gap;
    Widget content =
        child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null && !glyphTrailing)
              RaftIcon(glyph!, size: iconSize, color: color),
            if (glyph != null && label != null && !glyphTrailing)
              SizedBox(width: resolvedGap),
            if (label != null)
              Flexible(
                child: Text(
                  raftText(context, label!),
                  maxLines: wraps ? null : 1,
                  textAlign: wraps ? TextAlign.center : null,
                  overflow: wraps ? TextOverflow.clip : TextOverflow.ellipsis,
                  style: text,
                ),
              ),
            if (glyph != null && label != null && glyphTrailing)
              SizedBox(width: resolvedGap),
            if (glyph != null && glyphTrailing)
              RaftIcon(glyph!, size: iconSize, color: color),
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
    final resolvedPadding =
        padding ??
        (metricsKey == null
            ? root.padding
            : root.padding.copyWith(
                left: profile.paddingX,
                right: profile.paddingX,
              ));
    final boxHeight = metricsKey == null ? root.height : profile.height;
    // Above the default text size the recipe height is a minimum (CSS
    // `min-height`) and the label wraps, so the button grows with its text.
    final grows = boxHeight != null && wraps;
    Widget box = Container(
      height: grows ? null : boxHeight,
      constraints: grows ? BoxConstraints(minHeight: boxHeight) : null,
      width: expand ? double.infinity : root.width,
      padding: boxHeight == null
          ? resolvedPadding
          : grows
          ? EdgeInsets.fromLTRB(
              resolvedPadding.left,
              math.max(resolvedPadding.top, 4),
              resolvedPadding.right,
              math.max(resolvedPadding.bottom, 4),
            )
          : EdgeInsets.only(
              left: resolvedPadding.left,
              right: resolvedPadding.right,
            ),
      decoration: decoration,
      // inline-flex: shrink-wraps its content unless `w-full`.
      child: Center(widthFactor: expand ? null : 1, child: content),
    );
    box = Transform.translate(offset: translate, child: box);
    final opacity = disabled && disabledOpacity != null
        ? disabledOpacity
        : root.opacity;
    if (opacity != null && opacity < 1) {
      box = Opacity(opacity: opacity, child: box);
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
      foreground: t.colors['foreground-muted'],
      brutalSurface: (t, hovered) => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: RaftShadowSet.brutalSm,
      ),
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
      brutalSurface: (t, hovered) => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: RaftShadowSet.brutalSm,
      ),
      child: RaftThreadIcon(size: 14, color: color),
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
          : SingleChildScrollView(child: content);
    }
    final child = widget.child, onBackdrop = widget.onBackdrop;
    final t = RaftTokens.of(context);
    // Web Modal has no blur in Raft; the frozen packs supply their own radius.
    final blur = t.size('blur.modalBackdrop', fallback: 2);
    final scrim = t.colors['layer-backdrop']!;
    // The scrim dims the status bar band over its width too (see
    // `status_bar.dart`: a modal inside the host's scope publishes it).
    return RaftStatusBarSource(
      color: scrim,
      overlay: true,
      child: BackdropFilter(
        enabled: blur > 0,
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: ColoredBox(
          color: scrim,
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
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: inset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, box.maxHeight - inset),
                  ),
                  child: content,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
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
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => RaftDismissScope(
    child: Material(type: MaterialType.transparency, child: builder(context)),
  ),
);

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
class RaftDialogCard extends StatefulWidget {
  const RaftDialogCard({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.maxWidth = 448, // max-w-md = 28rem
    this.titleGlyph,
    this.actions,
    this.footer,
    this.footerGap = 16,
  });
  final String title;

  /// The submit row of a form. In a dialog it follows [child] after a 16px
  /// gap, as part of the body; in a bottom sheet ([showRaftForm] below 768)
  /// it pins to the bottom while [child] scrolls.
  final Widget? footer;

  /// The space between [child] and [footer] in a dialog.
  final double footerGap;

  /// The action row (buttons) under [child]. Above the default text size the
  /// card is capped to the viewport and only [child] scrolls, so these stay on
  /// screen; at the default size it simply follows [child].
  final Widget? actions;

  /// A leading `<Icon size={18} />` in the title (`flex min-w-0 items-center
  /// gap-2` + `truncate` title span).
  final RaftGlyph? titleGlyph;
  final VoidCallback onClose;
  final Widget child;
  final double maxWidth;

  @override
  State<RaftDialogCard> createState() => _RaftDialogCardState();
}

class _RaftDialogCardState extends State<RaftDialogCard> {
  final _body = GlobalKey(debugLabel: 'dialog card body');
  final _actions = GlobalKey(debugLabel: 'dialog card actions');
  final _footer = GlobalKey(debugLabel: 'dialog card footer');

  @override
  Widget build(BuildContext context) {
    final title = widget.title,
        onClose = widget.onClose,
        maxWidth = widget.maxWidth,
        titleGlyph = widget.titleGlyph;
    final body = KeyedSubtree(key: _body, child: widget.child);
    final footerRow = widget.footer;
    final footer = footerRow == null
        ? null
        : KeyedSubtree(key: _footer, child: footerRow);
    // A dialog keeps the form's own layout: the submit row ends the body.
    final child = footer == null
        ? body
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              body,
              SizedBox(height: widget.footerGap),
              footer,
            ],
          );
    final actionRow = widget.actions;
    final actions = actionRow == null
        ? null
        : KeyedSubtree(key: _actions, child: actionRow);
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    if (RaftFormFrame.sheetOf(context)) {
      final root = RaftCardRecipe.resolve(
        theme: raftRecipeThemeOf(t),
        states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
        tokens: tokens,
      ).root;
      return DefaultTextStyle(
        style: root.text(tokens, base: DefaultTextStyle.of(context).style),
        child: RaftFormSheet(
          title: raftText(context, title),
          onClose: onClose,
          titleGlyph: titleGlyph,
          body: body,
          footer: footer ?? actions,
        ),
      );
    }
    final titleSlot = RaftCardRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      tokens: tokens,
    ).title;
    final titleStyle = raftCssTextStyle(
      family: titleSlot.fontFamily ?? t.headingFont,
      step: RaftTextSteps.lg,
      weight: FontWeight.w700,
      color: t.ink,
    );
    final grows = RaftScaled.grows(context);
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        // CardHeader `gap-4` between the title and the close button.
        spacing: 16,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: titleGlyph == null
                  ? Text(
                      // CardTitle has no `truncate`: a long title wraps.
                      raftText(context, title),
                      style: titleStyle,
                    )
                  : Row(
                      spacing: 8,
                      children: [
                        RaftIcon(titleGlyph, size: 18, color: t.ink),
                        Expanded(
                          child: Text(
                            raftText(context, title),
                            // The title wraps above the default text size.
                            maxLines: grows ? null : 1,
                            overflow: grows
                                ? TextOverflow.clip
                                : TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          RaftCloseButton(onPressed: raftGuardedClose(context, onClose)),
        ],
      ),
    );
    if (grows) {
      // Text above the default size: the dialog never outgrows the viewport
      // (minus the system insets and the modal's 16px margin); the actions
      // stay put and the body scrolls above them.
      final media = MediaQuery.of(context);
      final cap = math.max(
        0.0,
        media.size.height - 32 - media.padding.vertical,
      );
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: cap),
        child: RaftCard(
          dialog: true,
          maxWidth: maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Without pinned actions the close button stays reachable;
              // with them the header scrolls so a short viewport keeps room
              // for the body.
              if (actions == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: header,
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    actions == null ? 0 : 24,
                    24,
                    actions == null ? 24 : 0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [if (actions != null) header, child],
                  ),
                ),
              ),
              if (actions != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: actions,
                ),
            ],
          ),
        ),
      );
    }
    return RaftCard(
      dialog: true,
      maxWidth: maxWidth,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, child, ?actions],
      ),
    );
  }
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
    labelWeight: labelWeight,
    family: family,
    legacy: RaftLegacyField.product,
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
    this.onSubmitted,
    this.fieldKey,
    this.obscure = false,
    this.readOnly = false,
    this.mono = false,
  });
  final TextEditingController controller;
  final String? placeholder;

  /// Web `readOnly` Input; [mono] is `font-mono text-xs`.
  final bool multiline, autofocus, enabled, obscure, readOnly, mono;
  final RaftGlyph? leadingGlyph;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) {
    final hint = placeholder == null ? null : raftText(context, placeholder!);
    return multiline
        ? RaftTextarea(
            controller: controller,
            hintText: hint,
            fieldKey: fieldKey,
            autofocus: autofocus,
            enabled: enabled,
            readOnly: readOnly,
            mono: mono,
            textStep: mono ? RaftTextSteps.xs : null,
            growsWithScale: true,
            legacy: RaftLegacyInput.dialog,
          )
        : RaftTextInput(
            controller: controller,
            hintText: hint,
            fieldKey: fieldKey,
            autofocus: autofocus,
            enabled: enabled,
            readOnly: readOnly,
            obscureText: obscure,
            leadingGlyph: leadingGlyph,
            onSubmitted: onSubmitted,
            mono: mono,
            textStep: mono ? RaftTextSteps.xs : null,
            legacy: RaftLegacyInput.dialog,
          );
  }
}
