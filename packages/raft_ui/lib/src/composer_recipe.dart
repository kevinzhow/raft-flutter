import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/composer_suggestion_list.g.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

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
  }) : assert(bottomSafeInset >= 0);

  final RaftTokens tokens;
  final bool desktop;
  final RaftComposerVariant variant;
  final double bottomSafeInset;
  bool get compact => variant == RaftComposerVariant.compact;

  // MessageInput2490; index.css755. Do not read MediaQuery padding here:
  // a SafeArea host may already have consumed it.
  EdgeInsets get hostInset => compact
      ? EdgeInsets.zero
      : EdgeInsets.fromLTRB(12, 12, 12, 16 + bottomSafeInset);
  BoxDecoration get hostDecoration => BoxDecoration(
    color: tokens.panel,
    border: compact
        ? null
        : Border(
            top: BorderSide(
              color: tokens.brutal
                  ? Colors.black
                  : tokens.colors['line-muted']!,
              width: tokens.brutal ? 2 : 1,
            ),
          ),
  );
  EdgeInsets get shellInset =>
      tokens.brutal ? const EdgeInsets.all(8) : EdgeInsets.zero;
  double get shellGap => 8;
  double get shellRadius => tokens.brutal ? 0 : 8;
  BoxDecoration shellDecoration({required bool focused}) => BoxDecoration(
    color: tokens.panel,
    borderRadius: BorderRadius.circular(shellRadius),
    // CSS ring sits outside the border box: use a spread shadow, never an
    // interior Flutter Border that changes the editor's content bounds.
    border: tokens.brutal ? Border.all(color: Colors.black, width: 2) : null,
    boxShadow: tokens.brutal
        ? focused
              ? tokens.focusShadows
              : tokens.shadows
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
            BoxShadow(color: tokens.colors['ink-6']!, spreadRadius: 1),
          ],
  );

  // MessageInput product override wins over generic Elegant min-h-16.
  double get editorMinimum => desktop ? 40 : 20;
  double get editorMaximum => 128;
  EdgeInsets get editorInset => tokens.brutal
      ? EdgeInsets.zero
      : const EdgeInsets.fromLTRB(12, 12, 12, 0);
  TextStyle get editorText => RaftTypography.heading(
    tokens,
    size: desktop ? 14 : 16,
    line: 20,
    weight: FontWeight.w400,
  ).copyWith(color: tokens.brutal ? Colors.black : tokens.strong);
  TextStyle get placeholder => editorText.copyWith(
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .35)
        : tokens.colors['foreground-placeholder'],
  );
  EdgeInsets get toolbarInset => tokens.brutal
      ? EdgeInsets.zero
      : const EdgeInsets.fromLTRB(10, 4, 10, 10);
  Offset get toolbarPaintOffset =>
      tokens.brutal ? Offset.zero : const Offset(0, 4);
  double get toolbarGap => tokens.brutal ? 12 : 8;
  double get actionGap => tokens.brutal ? 8 : 6;
  double get metaGap => 12; // Actual task + submit wrapper, MessageInput2970.
  double get actionFace => tokens.brutal ? 26 : 28;
  double get submitFace => 28;
  double get glyphSize => 14;

  // composer-suggestion.recipe.ts / index.mjs13809–13910.
  double get suggestionMaximum => tokens.brutal ? 192 : 204;
  double get suggestionBottomGap => tokens.brutal ? 8 : 4;
  // Brutal `border-2` sits inside the box: content starts inside it.
  EdgeInsets get suggestionInset => EdgeInsets.all(tokens.brutal ? 2 : 4);
  BoxDecoration get suggestionDecoration => BoxDecoration(
    color: tokens.brutal ? Colors.white : tokens.popover,
    border: tokens.brutal ? Border.all(color: Colors.black, width: 2) : null,
    borderRadius: BorderRadius.circular(tokens.brutal ? 0 : 8),
    boxShadow: tokens.brutal
        ? tokens.focusShadows
        : [
            ...tokens.shadows,
            if (!tokens.dark)
              BoxShadow(color: tokens.colors['ink-6']!, spreadRadius: 1),
          ],
  );
  EdgeInsets get suggestionGroupInset => tokens.brutal
      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
      : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  TextStyle get suggestionGroupLabel => RaftTypography.body(
    tokens,
    size: tokens.brutal ? 12 : 11,
    line: tokens.brutal ? 16 : 11,
    weight: tokens.brutal ? FontWeight.w700 : FontWeight.w500,
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .6)
        : tokens.strong.withValues(alpha: .45),
  ).copyWith(letterSpacing: tokens.brutal ? 1.2 : -.055);
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
    size: tokens.brutal ? 14 : 13,
    line: tokens.brutal ? 20 : 19.5,
    weight: tokens.brutal && highlighted ? FontWeight.w700 : FontWeight.w500,
    color: tokens.brutal
        ? Colors.black
        : highlighted || hovered
        ? tokens.ink
        : tokens.muted,
  ).copyWith(letterSpacing: tokens.brutal ? 0 : -.065);

  /// `ComposerSuggestionIcon variant="auxiliary"`: brutal `text-black/40`.
  Color get suggestionAuxiliary => tokens.brutal
      ? RaftPrimitiveColors.black.withValues(alpha: .4)
      : tokens.colors['foreground-placeholder']!;

  /// `ComposerSuggestionMeta variant="code"`: `text-xs font-mono`
  /// (brutal `text-black/40`), bold with the highlighted option.
  TextStyle suggestionCode({bool highlighted = false}) => TextStyle(
    fontFamily: tokens.monoFont,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
    color: tokens.brutal
        ? RaftPrimitiveColors.black.withValues(alpha: .4)
        : tokens.colors['foreground-placeholder'],
  );

  TextStyle get suggestionMeta => suggestionMetaFor();

  /// Meta sets no weight: it inherits the option's `font-medium`, or
  /// `data-[highlighted=true]:font-bold` (brutal).
  TextStyle suggestionMetaFor({bool highlighted = false}) =>
      RaftTypography.body(
        tokens,
        size: 12,
        line: 16,
        weight: tokens.brutal && highlighted
            ? FontWeight.w700
            : FontWeight.w500,
        color: tokens.brutal
            ? Colors.black.withValues(alpha: .5)
            : tokens.colors['foreground-placeholder'],
      );
}

/// ComposerIconButton uses Button's interaction machinery but its own surface.
class _ComposerAttachRecipe extends RaftControlRecipe {
  const _ComposerAttachRecipe(RaftTokens tokens)
    : super(tokens, variant: RaftControlVariant.ghost);
  @override
  Color get background => tokens.brutal ? Colors.white : Colors.transparent;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => tokens.brutal
      ? Colors.white
      : hovered || pressed
      ? tokens.colors['fill-strong']!.withValues(alpha: .8)
      : Colors.transparent;
  @override
  Color foregroundFor({bool hovered = false}) => tokens.brutal
      ? Colors.black
      : hovered
      ? tokens.strong
      : tokens.colors['foreground-icon']!;
  @override
  Color get foreground => foregroundFor();
  @override
  BorderSide side({bool hovered = false}) => tokens.brutal
      ? const BorderSide(color: Colors.black, width: 2)
      : BorderSide.none;
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  @override
  EdgeInsets get padding => EdgeInsets.all(tokens.brutal ? 4 : 7);
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
    if (tokens.brutal)
      BoxShadow(
        color: Colors.black,
        offset: pressed
            ? const Offset(1, 1)
            : hovered
            ? const Offset(4, 4)
            : const Offset(2, 2),
      ),
    if (focused) BoxShadow(color: focusRing, spreadRadius: 2),
  ];
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
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool submit, busy;
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
    final size = widget.submit
        ? 28.0
        : t.brutal
        ? 26.0
        : 28.0;
    return Listener(
      onPointerDown: (_) {},
      onPointerUp: (_) => focus.canRequestFocus = true,
      onPointerCancel: (_) => focus.canRequestFocus = true,
      child: RaftControl(
        focusNode: focus,
        focusOnPointer: false,
        visualWidth: size,
        visualHeight: size,
        minimumTargetSize: size,
        padding: widget.submit ? EdgeInsets.zero : null,
        variant: widget.submit
            ? RaftControlVariant.accent
            : RaftControlVariant.ghost,
        recipe: widget.submit ? null : _ComposerAttachRecipe(t),
        busy: widget.busy,
        semanticLabel: raftText(context, widget.tooltip),
        tooltip: raftText(context, widget.tooltip),
        onPressed: widget.onPressed,
        child: widget.busy
            ? const RaftSpinner()
            : RaftIcon(widget.glyph, size: 14),
      ),
    );
  }
}
