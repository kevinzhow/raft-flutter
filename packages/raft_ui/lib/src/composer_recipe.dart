import 'package:flutter/material.dart';

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

/// MessageInput normal/compact host, distinct from the generic RUI Composer.
enum RaftComposerVariant { normal, compact }

/// Mounted MessageInput + RUI Composer slots, pinned at 26f77ef / RUI 0.5.27.
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
    color: tokens.panel,
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
  EdgeInsets get shellInset => EdgeInsets.fromLTRB(
    tokens.size('space.composerShellInline', fallback: 12),
    tokens.size('space.composerShellTop', fallback: 12),
    tokens.size('space.composerShellInline', fallback: 12),
    tokens.size('space.composerShellBottom', fallback: 8),
  );
  double get shellGap => 8;
  double get shellRadius => tokens.size('radius.container', fallback: 8);
  bool get bordered => tokens.option('control.edge', or: 'ring') == 'inkBorder';
  double get shellStroke {
    final width = tokens.size('stroke.control', fallback: 1.5);
    return RaftBorderSnap.emulatedDeviceScaleFactor
        ? width.floorToDouble()
        : (width * devicePixelRatio).floorToDouble() / devicePixelRatio;
  }

  BoxDecoration shellDecoration({required bool focused}) => BoxDecoration(
    color: tokens.panel,
    borderRadius: BorderRadius.circular(shellRadius),
    border: bordered
        ? Border.all(color: tokens.colors['line-composer']!, width: shellStroke)
        : null,
    boxShadow: bordered
        ? tokens.option('press.effect', or: 'overlay') == 'offsetShadow'
              ? focused
                    ? tokens.focusShadows
                    : tokens.shadows
              : focused
              ? tokens.focusShadows
              : const []
        : tokens.dark
        ? [
            if (focused)
              BoxShadow(
                color: tokens.colors['accent-400']!.withValues(alpha: .7),
                spreadRadius: .5,
              ),
          ]
        : [
            ...tokens.shadows,
            BoxShadow(color: tokens.colors['line-composer']!, spreadRadius: 1),
          ],
  );

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
  double get firstActionOffset =>
      tokens.size('space.composerFirstActionOffset', fallback: -5);
  double get toolbarGap => 8;
  double get actionGap => tokens.size('space.composerActionGap', fallback: 8);
  double get metaGap => tokens.size('space.composerMetaGap', fallback: 8);
  double get actionFace => tokens.size('size.composerAction', fallback: 32);
  double get submitFace => tokens.size('size.composerSubmit', fallback: 32);
  double get glyphSize => tokens.size('size.composerGlyph', fallback: 18);

  // composer-suggestion.recipe.ts / index.mjs13809–13910.
  double get suggestionMaximum => 204;
  double get suggestionBottomGap => 4;
  // Brutal `border-2` sits inside the box: content starts inside it.
  EdgeInsets get suggestionInset => EdgeInsets.all(4);
  BoxDecoration get suggestionDecoration => BoxDecoration(
    color: tokens.popover,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      ...tokens.shadows,
      if (!tokens.dark)
        BoxShadow(color: tokens.colors['ink-6']!, spreadRadius: 1),
    ],
  );
  EdgeInsets get suggestionGroupInset =>
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  TextStyle get suggestionGroupLabel => RaftTypography.body(
    tokens,
    size: 11,
    line: 11,
    weight: FontWeight.w500,
    color: tokens.strong.withValues(alpha: .45),
  ).copyWith(letterSpacing: -.055);
  Color suggestionBackground({
    required bool highlighted,
    bool hovered = false,
  }) =>
      RaftComposerSuggestionListRecipe.resolve(
        theme: tokens.recipeTheme,
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
  }) => RaftTypography.body(
    tokens,
    size: 13,
    line: 19.5,
    weight: FontWeight.w500,
    color: highlighted || hovered ? tokens.ink : tokens.muted,
  ).copyWith(letterSpacing: -.065);

  /// `ComposerSuggestionIcon variant="auxiliary"`: brutal `text-black/40`.
  Color get suggestionAuxiliary => tokens.colors['foreground-placeholder']!;

  /// `ComposerSuggestionMeta variant="code"`: `text-xs font-mono`
  /// (brutal `text-black/40`), bold with the highlighted option.
  TextStyle suggestionCode({bool highlighted = false}) => TextStyle(
    fontFamily: tokens.monoFont,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
    color: tokens.colors['foreground-placeholder'],
  );

  TextStyle get suggestionMeta => suggestionMetaFor();

  /// Meta sets no weight: it inherits the option's `font-medium`, or
  /// `data-[highlighted=true]:font-bold` (brutal).
  TextStyle suggestionMetaFor({bool highlighted = false}) =>
      RaftTypography.body(
        tokens,
        size: 12,
        line: 16,
        weight: FontWeight.w500,
        color: tokens.colors['foreground-placeholder'],
      );
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
      hovered ? tokens.strong : tokens.colors['foreground-icon']!;
  @override
  Color get foreground => foregroundFor();
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  BorderRadius get radius => BorderRadius.circular(6);
  @override
  // ds-allow: Web raft-ui/composer.recipe.ts iconButton `p-[7px]` (elegant), `p-1` (brutal)
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
    // Web uses 32px; legacy buttons keep their 26/28px face. Android's
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
  BorderRadius get radius =>
      BorderRadius.circular(tokens.size('radius.control', fallback: 8));
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
