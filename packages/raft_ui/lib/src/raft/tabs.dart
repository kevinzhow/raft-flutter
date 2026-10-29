// Published raft-ui 0.7.0 `Tabs`: a row of tabs with a panel below. The default variant marks the selected tab with the yellow
// sticker (brand fill, ink border, die-cut `sticker-edge` ring); the underline variant is bare text with a 2px
// foreground bar under the selected tab. Tabs are `h-8` (sticker) / `h-11` (underline) with `font-callout font-semibold`,
// hover lays the `fill-pressed` wash over a resting tab, keyboard focus draws the generated focus ring.
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../control_typography.dart';
import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../recipe_surface.dart';
import '../recipes/tabs.g.dart';
import '../text_scaling.dart' show RaftScaled;
import '../theme.dart';
import '../tokens/tokens.dart';
import 'css_box.dart';
import 'ui_tokens.dart';

/// `variant` of `TabsList`: [standard] is the CSS `default` (sticker), [underline] the bare text row.
enum RaftTabsVariant { standard, underline }

/// One tab: a [value], its [label] and an optional leading [glyph] (16px, stroke 2) or custom [icon].
@immutable
class RaftTabItem<T> {
  const RaftTabItem({
    required this.value,
    required this.label,
    this.glyph,
    this.icon,
    this.enabled = true,
    this.tooltip,
    this.itemKey,
  });
  final T value;
  final String label;
  final RaftGlyph? glyph;

  /// Custom artwork painted with the tab's colour and icon size (wins over [glyph]).
  final Widget Function(double size, Color color, double strokeWidth)? icon;
  final bool enabled;
  final String? tooltip;

  /// Key of the tab button (tests, parity interactions).
  final Key? itemKey;
}

/// Resolved colours of a tab in one state.
class RaftTabColors {
  const RaftTabColors({
    required this.fill,
    required this.border,
    required this.foreground,
    this.ringEdge,
    this.underline,
  });
  final Color fill, border, foreground;

  /// `ring-sticker-edge` (the die-cut ring) of the selected sticker.
  final Color? ringEdge;

  /// `inset_0_-2px_0_foreground` of the selected underline tab.
  final Color? underline;

  static RaftTabColors resolve(
    RaftUiColors ui,
    RaftTabsVariant variant, {
    required bool selected,
    required bool disabled,
    required bool hovered,
    required bool pressed,
  }) {
    const clear = Color(0x00000000);
    if (variant == RaftTabsVariant.underline) {
      return RaftTabColors(
        fill: clear,
        border: clear,
        foreground: disabled
            ? ui.foregroundDisabled
            : selected || hovered || pressed
            ? ui.foreground
            : ui.foregroundMuted,
        underline: selected ? ui.foreground : null,
      );
    }
    if (selected) {
      return RaftTabColors(
        fill: disabled
            ? clear
            : pressed
            ? Color.alphaBlend(ui.stickerPressed, ui.brand)
            : ui.brand,
        border: ui.stickerInk,
        foreground: disabled ? ui.foregroundDisabled : ui.stickerInk,
        ringEdge: ui.stickerEdge,
      );
    }
    return RaftTabColors(
      fill: !disabled && (hovered || pressed) ? ui.fillPressed : clear,
      border: clear,
      foreground: disabled ? ui.foregroundDisabled : ui.foregroundMuted,
    );
  }
}

/// One `TabsTab`. Stateless about selection: the owner passes [selected]; [onPressed] null is `data-disabled`.
class RaftTabButton extends StatelessWidget {
  const RaftTabButton({
    super.key,
    required this.label,
    this.glyph,
    this.icon,
    this.selected = false,
    this.onPressed,
    this.variant = RaftTabsVariant.standard,
    this.height,
    this.focusNode,
    this.tooltip,
    this.semanticLabel,
    this.padding,
    this.iconSize = 16,
    this.growsWithText,
  });

  final String label;
  final RaftGlyph? glyph;
  final Widget Function(double size, Color color, double strokeWidth)? icon;
  final bool selected;
  final VoidCallback? onPressed;
  final RaftTabsVariant variant;

  /// Defaults to the recipe height: 32 (sticker) / 44 (underline).
  final double? height;
  final FocusNode? focusNode;
  final String? tooltip;
  final String? semanticLabel;

  /// Horizontal padding override (default 12 sticker / 0 underline).
  final EdgeInsetsGeometry? padding;
  final double iconSize;

  /// [height] is a minimum and the tab grows with its label (enlarged text); null follows the text scale.
  final bool? growsWithText;

  static double heightOf(RaftTabsVariant variant) =>
      variant == RaftTabsVariant.underline ? 44 : 32;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final text = raftText(context, label);
    final underline = variant == RaftTabsVariant.underline;
    final borderWidth = underline ? 0.0 : raftControlBorderPx(context, 1.5);
    final grows = growsWithText ?? RaftScaled.grows(context);
    return RaftInteractive(
      onPressed: onPressed,
      focusNode: focusNode,
      tooltip: tooltip,
      selected: selected,
      semanticRole: SemanticsRole.tab,
      semanticLabel: semanticLabel ?? text,
      builder: (context, st) {
        if (t.isRaftLook) return _recipeSurface(context, st);
        final disabled = onPressed == null;
        final colors = RaftTabColors.resolve(
          ui,
          variant,
          selected: selected,
          disabled: disabled,
          hovered: st.hovered,
          pressed: st.pressed,
        );
        final fg = colors.foreground;
        final weight = selected && !underline
            ? FontWeight.w700
            : FontWeight.w600;
        final style = RaftControlTypography.of(
          context,
          t.scale(RaftTypeScale.callout, weight: weight, color: fg),
        );
        Widget? leading;
        if (icon != null) {
          leading = icon!(iconSize, fg, 2);
        } else if (glyph != null) {
          leading = RaftIcon(glyph!, size: iconSize, color: fg);
        }
        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?leading,
            if (leading != null && text.isNotEmpty) const SizedBox(width: 6),
            if (text.isNotEmpty)
              Text(text, maxLines: 1, softWrap: false, style: style),
          ],
        );
        final rings = <RaftRing>[
          if (colors.ringEdge != null) RaftRing(1.5, colors.ringEdge!),
          if (st.focusVisible)
            for (final layer in ui.focusRing.layers)
              RaftRing(layer.spread, layer.color),
        ];
        final boxHeight = height ?? heightOf(variant);
        Widget box = RaftCssBox(
          // Measured per look rather than taken from the 0.7.1 class:
          //   Raft     official `rounded-control`          = 8
          //   Elegant  a57b9dab tab `rounded-md` (0.375rem) = 6
          //   Brutal   a57b9dab tab, no rounding           = 0
          // `radius.control` carries exactly 8 / 6 / 0, so it fits all three.
          // `radius.chip` also holds 6 for Raft but 4 for Elegant, which would
          // miss the measurement.
          // The underline variant is `rounded-none` in the official source: a
          // shape decision rather than a theme value, so it stays 0 everywhere.
          radius: underline ? 0 : t.size('radius.control', fallback: 8),
          fill: colors.fill,
          borderWidth: borderWidth,
          borderColor: colors.border,
          rings: rings,
          height: grows ? null : boxHeight,
          padding:
              padding ??
              (underline
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 12)),
          alignment: Alignment.center,
          child: content,
        );
        if (grows) {
          box = ConstrainedBox(
            constraints: BoxConstraints(minHeight: boxHeight),
            child: box,
          );
        }
        if (colors.underline != null) {
          box = Stack(
            children: [
              box,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: IgnorePointer(
                  child: ColoredBox(color: colors.underline!),
                ),
              ),
            ],
          );
        }
        return box;
      },
    );
  }

  Widget _recipeSurface(BuildContext context, RaftInteractionState state) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final recipe = RaftTabsRecipe.resolve(
      theme: t.recipeTheme,
      variant: variant == RaftTabsVariant.underline
          ? RaftTabsRecipeVariant.underline
          : RaftTabsRecipeVariant.default_,
      states: t.recipeStates(
        hovered: state.hovered,
        pressed: state.pressed,
        focusVisible: state.focusVisible,
        extra: [
          if (selected) 'data-active',
          if (!state.enabled) 'data-disabled',
        ],
      ),
      tokens: tokens,
    );
    final tab = recipe.tab;
    final textStyle = RaftControlTypography.of(
      context,
      recipe.label
          .text(tokens, base: tab.text(tokens))
          .copyWith(fontFamilyFallback: t.fontFallback, locale: t.textLocale),
    );
    final ink = textStyle.color ?? t.ink;
    final svg = tab.target("& svg:not([class*='size-'])");
    final text = raftText(context, label);
    final leading = icon != null
        ? icon!(iconSize, ink, 2)
        : glyph == null
        ? null
        : RaftIcon(glyph!, size: iconSize, color: ink);
    return RaftRecipeBox(
      style: tab,
      tokens: tokens,
      height: height,
      padding: padding?.resolve(Directionality.of(context)),
      alignment: Alignment.center,
      growWithText: growsWithText ?? RaftScaled.grows(context),
      overflowCenter: true,
      applyText: false,
      decorationOverride: (decoration) => raftSnapBorder(context, decoration),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: tab.columnGap ?? 0,
        children: [
          if (leading != null)
            IconTheme.merge(
              data: IconThemeData(size: svg?.width, color: ink),
              child: leading,
            ),
          if (text.isNotEmpty)
            Text(text, maxLines: 1, softWrap: false, style: textStyle),
        ],
      ),
    );
  }
}

/// `TabsList`: the row of tabs, keyboard navigation (arrows, Home, End move focus and select), and a horizontal
/// scroll when the tabs do not fit (`overflow-x-auto`, scrollbar hidden).
class RaftTabsList<T> extends StatefulWidget {
  const RaftTabsList({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.variant = RaftTabsVariant.standard,
    this.scrollController,
    this.label,
  });
  final List<RaftTabItem<T>> tabs;
  final T value;
  final ValueChanged<T>? onChanged;
  final RaftTabsVariant variant;
  final ScrollController? scrollController;
  final String? label;

  @override
  State<RaftTabsList<T>> createState() => _RaftTabsListState<T>();
}

class _RaftTabsListState<T> extends State<RaftTabsList<T>> {
  final nodes = <T, FocusNode>{};

  @override
  void dispose() {
    for (final node in nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode node(T value) => nodes.putIfAbsent(value, FocusNode.new);

  @override
  void didUpdateWidget(RaftTabsList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final id in nodes.keys.toList()) {
      if (!widget.tabs.any((tab) => tab.value == id)) {
        nodes.remove(id)!.dispose();
      }
    }
  }

  KeyEventResult navigation(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || widget.onChanged == null) {
      return KeyEventResult.ignored;
    }
    final enabled = widget.tabs.where((tab) => tab.enabled).toList();
    if (enabled.isEmpty) return KeyEventResult.ignored;
    final current = enabled.indexWhere(
      (tab) => nodes[tab.value]?.hasFocus ?? false,
    );
    final key = event.logicalKey;
    int next;
    if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = enabled.length - 1;
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      var delta = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
      if (Directionality.of(context) == TextDirection.rtl) delta = -delta;
      final from = current < 0
          ? enabled.indexWhere((tab) => tab.value == widget.value)
          : current;
      next = (from + delta) % enabled.length;
    } else {
      return KeyEventResult.ignored;
    }
    node(enabled[next].value).requestFocus();
    widget.onChanged!(enabled[next].value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final underline = widget.variant == RaftTabsVariant.underline;
    final tokens = RaftTokens.of(context);
    final list = tokens.isRaftLook
        ? RaftTabsRecipe.resolve(
            theme: tokens.recipeTheme,
            variant: underline
                ? RaftTabsRecipeVariant.underline
                : RaftTabsRecipeVariant.default_,
            tokens: tokens.recipeTokens,
          ).list
        : null;
    final gap = list?.columnGap ?? (underline ? 20.0 : 2.0);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.tabs.length; i++) ...[
          // `gap-0.5` (sticker) / `gap-5` (underline).
          if (i > 0) SizedBox(width: gap),
          _tab(widget.tabs[i]),
        ],
      ],
    );
    return Focus(
      canRequestFocus: false,
      onKeyEvent: navigation,
      child: ClipRect(
        child: SingleChildScrollView(
          controller: widget.scrollController,
          scrollDirection: Axis.horizontal,
          primary: false,
          child: Semantics(
            role: SemanticsRole.tabBar,
            label: widget.label,
            explicitChildNodes: true,
            child: row,
          ),
        ),
      ),
    );
  }

  Widget _tab(RaftTabItem<T> tab) => RaftTabButton(
    key: tab.itemKey,
    label: tab.label,
    glyph: tab.glyph,
    icon: tab.icon,
    tooltip: tab.tooltip,
    variant: widget.variant,
    selected: tab.value == widget.value,
    focusNode: node(tab.value),
    onPressed: widget.onChanged == null || !tab.enabled
        ? null
        : () => widget.onChanged!(tab.value),
  );
}

/// `Tabs`: the list plus the selected panel, `gap-3` is inert (the root is not a flex box). [panels] maps a tab value to its content
/// (`TabsPanel`); without panels this is just the list.
class RaftTabs<T> extends StatelessWidget {
  const RaftTabs({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.variant = RaftTabsVariant.standard,
    this.panels = const {},
    this.gap = 0,
    this.scrollController,
  });
  final List<RaftTabItem<T>> tabs;
  final T value;
  final ValueChanged<T>? onChanged;
  final RaftTabsVariant variant;
  final Map<T, Widget> panels;
  final double gap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final panel = panels[value];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftTabsList<T>(
          tabs: tabs,
          value: value,
          onChanged: onChanged,
          variant: variant,
          scrollController: scrollController,
        ),
        if (panel != null) ...[
          SizedBox(height: gap),
          SizedBox(width: double.infinity, child: panel),
        ],
      ],
    );
  }
}

/// `TabsPanel` as the docs use it (`p-3 text-xs text-foreground-muted`).
class RaftTabsPanelText extends StatelessWidget {
  const RaftTabsPanelText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        raftText(context, text),
        style: t.scale(
          RaftTypeScale.caption,
          weight: FontWeight.w400,
          color: t.ui.foregroundMuted,
        ),
      ),
    );
  }
}
