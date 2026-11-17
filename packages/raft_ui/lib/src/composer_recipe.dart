import 'token_geometry.dart';

import 'package:flutter/material.dart';

import 'css_recipe_decoration.dart' show RaftRecipeDecoration;
import 'design_primitives.dart';
import 'tap_slop.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/composer_suggestion_list.g.dart';
import 'theme.dart';
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'raft/button.dart';

/// `--control-embedded-inset`; the Raft shell's bottom padding is this minus
/// the border (`pb-[calc(var(--control-embedded-inset)-1px)]`).
const _embeddedInset = 6.0;

/// MessageInput normal/compact host, distinct from the generic RUI Composer.
enum RaftComposerVariant { normal, compact }

/// Mounted MessageInput + Composer slots; values come from the selected pack.
/// The caller owns overlay positioning, loading and whether SafeArea was consumed.
@immutable
class RaftComposerRecipe {
  const RaftComposerRecipe(
    this.tokens, {
    required this.desktop,
    this.variant = RaftComposerVariant.normal,
    this.bottomSafeInset = 0,
    this.devicePixelRatio = 1,
  }) : assert(bottomSafeInset >= 0);

  final RaftTokens tokens;
  final bool desktop;
  final RaftComposerVariant variant;
  final double bottomSafeInset, devicePixelRatio;
  bool get compact => variant == RaftComposerVariant.compact;

  // MessageInput2490; index.css755. The recipe stays pure: RaftComposer passes
  // raftBottomInset (MediaQuery.paddingOf, 0 while the keyboard is up).
  EdgeInsets get hostInset => compact
      ? EdgeInsets.zero
      : EdgeInsets.fromLTRB(
          tokens.size('space.composerHostInline', fallback: 12),
          tokens.size('space.composerHostTop', fallback: 12),
          tokens.size('space.composerHostInline', fallback: 12),
          16 + bottomSafeInset,
        );
  BoxDecoration get hostDecoration => BoxDecoration(
    color: tokens.colors['layer-composer-host'] ?? tokens.panel,
    // `ConversationPanelFooter` hosts the composer with `!border-0` in v1.21.23.
    border: compact || tokens.size('stroke.channelFooter', fallback: 1) <= 0
        ? null
        : Border(
            top: BorderSide(
              color: tokens.colors['line-muted']!,
              width: tokens.size('stroke.channelFooter', fallback: 1),
            ),
          ),
  );
  // The Raft look is the raft-ui 0.95.3 composer (`pb-[embedded-inset-1px]`,
  // `gap-embedded-inset`, `size-8` / `md:pointer-fine:size-(--bar-button-size)`).
  // Pointer-fine is the desktop token variant, never the width alone.
  EdgeInsets get shellInset => EdgeInsets.fromLTRB(
    tokens.size('space.composerShellInline', fallback: 12),
    tokens.size('space.composerShellTop', fallback: 12),
    tokens.size('space.composerShellInline', fallback: 12),
    _embeddedInset - 1,
  );
  double get shellGap => 8;
  double get shellRadius => tokens.size('radius.container', fallback: 8);
  bool get bordered => shellStroke > 0;
  double get shellStroke {
    final width = tokens.size('stroke.composerShell', fallback: 1.5);
    return RaftBorderSnap.emulatedDeviceScaleFactor
        ? width.floorToDouble()
        : (width * devicePixelRatio).floorToDouble() / devicePixelRatio;
  }

  /// The shell paints a [RaftRecipeDecoration]: its focus ring (`0 0 0 2px gap,
  /// 0 0 0 4px ink`) grows the corner radius with each spread (`radius + spread`,
  /// concentric with the border). A plain [BoxDecoration] inflates only the rect
  /// and keeps the radius, which pinches the gap at the corners.
  BoxDecoration shellDecoration({required bool focused}) {
    final decoration = BoxDecoration(
      color: tokens.colors['layer-composer-shell'] ?? tokens.panel,
      borderRadius: BorderRadius.circular(shellRadius),
      border: bordered
          ? Border.all(
              color: tokens.colors['line-composer']!,
              width: shellStroke,
            )
          : null,
      // Named pack layers are CSS top-first; BoxDecoration paints bottom-first.
      boxShadow: [
        for (final layer
            in tokens
                .shadowLayers(
                  focused ? 'shadow.composerFocus' : 'shadow.composerIdle',
                )
                .reversed)
          if (!layer.inset) layer.toBoxShadow(),
      ],
    );
    return RaftRecipeDecoration.from(decoration, cssGeometry: true);
  }

  double get editorMinimum => desktop
      ? tokens.size('size.composerEditorMinimumDesktop', fallback: 24)
      : tokens.size('type.composerInput.line', fallback: 24);
  double get editorMaximum => 128;
  EdgeInsets get editorInset => EdgeInsets.fromLTRB(
    tokens.size('space.composerEditorInline', fallback: 2),
    tokens.size('space.composerEditorTop', fallback: 0),
    tokens.size('space.composerEditorInline', fallback: 2),
    0,
  );
  TextStyle get editorText => RaftTypography.heading(
    tokens,
    size: desktop
        ? tokens.size('type.composerInputDesktop.size', fallback: 14)
        : 16,
    line: tokens.size('type.composerInput.line', fallback: 20),
    weight: FontWeight.w400,
  ).copyWith(color: tokens.strong);
  TextStyle get placeholder =>
      editorText.copyWith(color: tokens.colors['foreground-placeholder']);
  EdgeInsets get toolbarInset => EdgeInsets.fromLTRB(
    tokens.size('space.composerToolbarInline', fallback: 0),
    tokens.size('space.composerToolbarTop', fallback: 0),
    tokens.size('space.composerToolbarInline', fallback: 0),
    tokens.size('space.composerToolbarBottom', fallback: 0),
  );
  Offset get toolbarPaintOffset =>
      Offset(0, tokens.size('space.composerToolbarShiftY', fallback: 0));
  // Toolbar `mx`: (18 - 28) / 2 with a fine pointer, 6 - 12 - 1 otherwise.
  double get firstActionOffset => tokens.desktop ? -5 : -7;

  /// The toolbar's negative margin also pulls Send past the shell's right
  /// padding.
  double get lastActionOffset => !compact ? firstActionOffset : 0;

  /// Shell padding with the toolbar's bleed taken out of both ends.
  EdgeInsets shellPadding(double firstOffset) => shellInset.copyWith(
    left: shellInset.left + firstOffset,
    right: shellInset.right + lastActionOffset,
  );

  /// The editor keeps its own inset: it gives back what [shellPadding] took.
  EdgeInsets editorInsetFor(double firstOffset) => editorInset.copyWith(
    left: editorInset.left - firstOffset,
    right: editorInset.right - lastActionOffset,
  );
  double get toolbarGap => 6;
  double get actionGap => 6;
  double get metaGap => 6;
  double get _barButton => tokens.desktop ? 28 : 32;
  double get actionFace => _barButton;
  double get submitFace => _barButton;
  double get glyphSize => tokens.size('size.composerGlyph', fallback: 18);

  // composer-suggestion.recipe.ts / index.mjs13809–13910.
  double get suggestionMaximum => 240;
  double get suggestionBottomGap => 8;
  EdgeInsets get suggestionInset => EdgeInsets.all(4);
  BoxDecoration get suggestionDecoration => BoxDecoration(
    color: tokens.popover,
    borderRadius: tokens.corner('radius.container', fallback: 10),
    // `ring-1 ring-line-seam shadow-float`; CSS lists the ring first.
    boxShadow: [
      for (final layer in tokens.shadowLayers('shadow.float').reversed)
        if (!layer.inset) layer.toBoxShadow(),
      BoxShadow(color: tokens.colors['line-seam']!, spreadRadius: 1),
    ],
  );
  EdgeInsets get suggestionGroupInset =>
      const EdgeInsets.fromLTRB(10, 8, 10, 4);
  // `text-caption font-bold text-foreground-hint`.
  TextStyle get suggestionGroupLabel => tokens.scale(
    tokens.typeSlot('caption'),
    weight: FontWeight.w700,
    color: tokens.ui.foregroundHint,
  );
  Color suggestionBackground({
    required bool highlighted,
    bool hovered = false,
  }) =>
      RaftComposerSuggestionListRecipe.resolve(
        states: tokens.recipeStates(
          hovered: hovered,
          extra: [if (highlighted) 'data-highlighted=true'],
        ),
        tokens: tokens.recipeTokens,
      ).item.backgroundColor?.resolve(tokens.recipeTokens) ??
      Colors.transparent;
  TextStyle suggestionTitle({
    required bool highlighted,
    bool hovered = false,
  }) =>
      // `text-callout font-medium text-foreground`, whatever the highlight.
      tokens.scale(
        tokens.typeSlot('callout'),
        weight: FontWeight.w500,
        color: tokens.ui.foreground,
      );

  /// `ComposerSuggestionIcon variant="auxiliary"`.
  Color get suggestionAuxiliary => tokens.colors['foreground-placeholder']!;

  /// `ComposerSuggestionMeta variant="code"`: `text-xs font-mono`, bold with
  /// the highlighted option.
  TextStyle suggestionCode({bool highlighted = false}) => tokens.scale(
    tokens.typeSlot('mono-meta'),
    mono: true,
    weight: highlighted ? FontWeight.w700 : FontWeight.w500,
    color: tokens.ui.foregroundHint,
  );

  TextStyle get suggestionMeta => suggestionMetaFor();

  /// Meta sets no weight: it inherits the option's `font-medium`.
  TextStyle suggestionMetaFor({bool highlighted = false}) =>
      tokens.scale(tokens.typeSlot('caption'), color: tokens.ui.foregroundHint);
}

/// ComposerIconButton uses Button's interaction machinery but its own surface.
class _ComposerAttachRecipe extends RaftControlRecipe {
  const _ComposerAttachRecipe(RaftTokens tokens)
    : super(tokens, variant: RaftControlVariant.ghost);
  @override
  Color get background => Colors.transparent;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => hovered || pressed
      ? tokens.colors['fill-strong']!.withValues(alpha: .8)
      : Colors.transparent;
  @override
  Color foregroundFor({bool hovered = false}) =>
      hovered ? tokens.strong : tokens.colors['foreground-muted']!;
  @override
  Color get foreground => foregroundFor();
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  BorderRadius get radius => BorderRadius.circular(6);
  @override
  // ds-allow: Web raft-ui/composer.recipe.ts iconButton `p-[7px]`
  EdgeInsets get padding => EdgeInsets.all(7);
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [if (focused) BoxShadow(color: focusRing, spreadRadius: 2)];
}

/// Pointer activation preserves editor focus; keyboard traversal remains enabled.
/// A picker may deliberately blur the editor in its app-owned callback.
class RaftComposerAction extends StatefulWidget {
  const RaftComposerAction({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.submit = false,
    this.busy = false,
    this.spinner = false,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool submit, busy;

  /// Spinner glyph on an otherwise plain (disabled) action, Web `Send` while
  /// files are checked or uploaded.
  final bool spinner;
  @override
  State<RaftComposerAction> createState() => _RaftComposerActionState();
}

class _RaftComposerActionState extends State<RaftComposerAction> {
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftComposerRecipe(t, desktop: false);
    final size = widget.submit ? recipe.submitFace : recipe.actionFace;
    // Web uses 32px. Android's
    // 48dp guideline is met by routing nearby touches to them instead
    // (RaftTapSlopHost in the composer). Desktop keeps the exact box.
    final touch = RaftDensityScope.of(context) == RaftDensity.touch;
    return Listener(
      onPointerDown: (_) {},
      onPointerUp: (_) => focus.canRequestFocus = true,
      onPointerCancel: (_) => focus.canRequestFocus = true,
      child: RaftTapSlopAnchor(
        minSize: touch ? const Size.square(RaftMetrics.touchTarget) : Size.zero,
        child: RaftControl(
          focusNode: focus,
          focusOnPointer: false,
          visualWidth: size,
          visualHeight: size,
          minimumTargetSize: size,
          padding: EdgeInsets.zero,
          variant: widget.submit
              ? RaftControlVariant.accent
              : RaftControlVariant.ghost,
          recipe: widget.submit
              ? t.option('sticker.ring', or: 'none') == 'dieCut'
                    ? _ComposerSubmitRecipe(
                        t,
                        disabled: widget.onPressed == null || widget.busy,
                        stroke: raftControlBorderPx(
                          context,
                          t.size('stroke.control', fallback: 1.5),
                        ),
                      )
                    : null
              : _ComposerAttachRecipe(t),
          busy: widget.busy,
          semanticLabel: raftText(context, widget.tooltip),
          tooltip: raftText(context, widget.tooltip),
          onPressed: widget.onPressed,
          child: widget.busy || widget.spinner
              ? const RaftSpinner()
              : RaftIcon(widget.glyph, size: recipe.glyphSize),
        ),
      ),
    );
  }
}

// Shared native Button colors, with the composer's pointer-focus policy kept
// by RaftControl. A disabled Send is fully opaque and uses the disabled fill.
class _ComposerSubmitRecipe extends RaftControlRecipe {
  const _ComposerSubmitRecipe(
    super.tokens, {
    required this.disabled,
    required this.stroke,
  }) : super(variant: RaftControlVariant.accent);
  final bool disabled;
  final double stroke;
  RaftButtonColors colors({bool overlay = false}) => RaftButtonColors.resolve(
    tokens.ui,
    RaftButtonVariant.accent,
    disabled: disabled,
    overlay: overlay,
    iconSize: true,
  );
  @override
  bool get transformsOnInteraction => false;
  @override
  double get disabledOpacity => 1;
  @override
  Color get background => colors().fill;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => colors(overlay: hovered || pressed).fill;
  @override
  Color get foreground => colors().foreground;
  @override
  Color foregroundFor({bool hovered = false}) => foreground;
  @override
  BorderSide side({bool hovered = false}) =>
      BorderSide(color: colors().border, width: stroke);
  @override
  BorderRadius get radius => tokens.corner('radius.control', fallback: 8);
  @override
  EdgeInsets get padding => EdgeInsets.zero;
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [
    if (colors().ringEdge case final edge?)
      BoxShadow(color: edge, spreadRadius: stroke),
    if (focused) ...tokens.focusShadows,
  ];
}
