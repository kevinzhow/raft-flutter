// Frozen style data for migrated Material call sites in Elegant / Brutal.
// No Material button is mounted: RaftButton owns every input and semantics.
import 'package:flutter/material.dart';

import '../design_primitives.dart';
import 'button.dart';

enum RaftLegacyButtonKind { text, outlined, icon }

class RaftLegacyMaterialButtonSurface extends StatelessWidget {
  const RaftLegacyMaterialButtonSurface({
    super.key,
    required this.button,
    required this.state,
  });
  final RaftButton button;
  final RaftInteractionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = button.legacyKind!;
    // These unmounted widgets expose the pinned Flutter default style only.
    // Keeping the data source avoids copying Material's fallback constants.
    final defaults = switch (kind) {
      RaftLegacyButtonKind.text => const TextButton(
        onPressed: null,
        child: SizedBox(),
      ).defaultStyleOf(context),
      RaftLegacyButtonKind.outlined => const OutlinedButton(
        onPressed: null,
        child: SizedBox(),
      ).defaultStyleOf(context),
      RaftLegacyButtonKind.icon => const ButtonStyle(),
    };
    final themed = switch (kind) {
      RaftLegacyButtonKind.text => theme.textButtonTheme.style,
      RaftLegacyButtonKind.outlined => theme.outlinedButtonTheme.style,
      RaftLegacyButtonKind.icon => theme.iconButtonTheme.style,
    };
    final style = defaults.merge(themed).merge(button.legacyStyle);
    final states = <WidgetState>{
      if (!state.enabled) WidgetState.disabled,
      if (state.hovered) WidgetState.hovered,
      if (state.pressed) WidgetState.pressed,
      if (state.focusVisible) WidgetState.focused,
    };
    T? value<T>(
      WidgetStateProperty<T?>? Function(ButtonStyle) read, [
      Set<WidgetState>? resolvingStates,
    ]) {
      for (final layer in [button.legacyStyle, themed, defaults]) {
        if (layer == null) continue;
        final resolved = read(layer)?.resolve(resolvingStates ?? states);
        if (resolved != null) return resolved;
      }
      return null;
    }

    final foreground = value((s) => s.foregroundColor);
    // Flutter resolves a call-site/theme foreground before the default icon
    // colour; a default iconColor must not override the frozen theme ink.
    final iconColor =
        button.legacyStyle?.iconColor?.resolve(states) ??
        themed?.iconColor?.resolve(states) ??
        button.legacyStyle?.foregroundColor?.resolve(states) ??
        themed?.foregroundColor?.resolve(states) ??
        defaults.iconColor?.resolve(states) ??
        defaults.foregroundColor?.resolve(states);
    final fill = value((s) => s.backgroundColor) ?? Colors.transparent;
    final padding =
        button.legacyPadding ?? value((s) => s.padding) ?? EdgeInsets.zero;
    var shape = value((s) => s.shape) ?? const RoundedRectangleBorder();
    final side = value((s) => s.side);
    if (side != null) shape = shape.copyWith(side: side);
    final minimum = value((s) => s.minimumSize) ?? Size.zero;
    final maximum = value((s) => s.maximumSize) ?? Size.infinite;
    final fixed = value((s) => s.fixedSize);
    final density = style.visualDensity ?? theme.visualDensity;
    var constraints = density.effectiveConstraints(
      BoxConstraints(
        minWidth: minimum.width,
        minHeight: minimum.height,
        maxWidth: maximum.width,
        maxHeight: maximum.height,
      ),
    );
    if (fixed != null)
      constraints = constraints.tighten(
        width: fixed.width.isFinite ? fixed.width : null,
        height: fixed.height.isFinite ? fixed.height : null,
      );
    if (button.legacyConstraints != null)
      constraints = button.legacyConstraints!;
    final alignment = style.alignment ?? Alignment.center;
    Widget content = button.child ?? const SizedBox();
    if (button.leading != null)
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button.leading!,
          const SizedBox(width: 8),
          Flexible(child: content),
        ],
      );
    content = DefaultTextStyle.merge(
      style: value((s) => s.textStyle)?.copyWith(color: foreground),
      child: IconTheme.merge(
        data: IconThemeData(color: iconColor, size: value((s) => s.iconSize)),
        child: content,
      ),
    );
    final overlays = <WidgetState, Color>{
      for (final highlight in [
        if (state.hovered) WidgetState.hovered,
        if (state.pressed) WidgetState.pressed,
        if (state.focusVisible) WidgetState.focused,
      ])
        highlight:
            value((s) => s.overlayColor, {highlight}) ?? Colors.transparent,
    };
    Widget surface = ConstrainedBox(
      constraints: constraints,
      child: Material(
        type: MaterialType.button,
        color: fill,
        shape: shape,
        elevation: value((s) => s.elevation) ?? 0,
        shadowColor: value((s) => s.shadowColor),
        surfaceTintColor: value((s) => s.surfaceTintColor),
        borderOnForeground: false,
        animationDuration: style.animationDuration ?? kThemeChangeDuration,
        child: _LegacyHighlights(
          shape: shape,
          colors: overlays,
          child: Padding(
            padding: padding,
            child: Align(
              alignment: alignment,
              widthFactor: 1,
              heightFactor: 1,
              child: content,
            ),
          ),
        ),
      ),
    );
    final target = style.tapTargetSize ?? theme.materialTapTargetSize;
    if (target == MaterialTapTargetSize.padded)
      surface = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: kMinInteractiveDimension + density.baseSizeAdjustment.dx,
          minHeight: kMinInteractiveDimension + density.baseSizeAdjustment.dy,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: surface),
      );
    return surface;
  }
}

// Reuse only the frozen Material ink painter, never its input implementation.
// Painting on the Material controller also preserves its edge antialiasing.
class _LegacyHighlights extends StatefulWidget {
  const _LegacyHighlights({
    required this.shape,
    required this.colors,
    required this.child,
  });
  final OutlinedBorder shape;
  final Map<WidgetState, Color> colors;
  final Widget child;
  @override
  State<_LegacyHighlights> createState() => _LegacyHighlightsState();
}

class _LegacyHighlightsState extends State<_LegacyHighlights> {
  final highlights = <WidgetState, InkHighlight>{};
  bool scheduled = false;
  void schedulePaint() {
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted) return;
      syncPaint();
    });
  }

  void syncPaint() {
    final reference = context.findRenderObject();
    if (reference is! RenderBox) return;
    for (final entry in highlights.entries.toList()) {
      final color = widget.colors[entry.key];
      if (color == null) {
        entry.value.deactivate();
      } else {
        entry.value.color = color;
        entry.value.activate();
      }
    }
    for (final entry in widget.colors.entries) {
      if (highlights.containsKey(entry.key)) continue;
      highlights[entry.key] = InkHighlight(
        controller: Material.of(context),
        referenceBox: reference,
        color: entry.value,
        textDirection: Directionality.of(context),
        customBorder: widget.shape,
        // Pinned Flutter InkResponse highlight fade durations.
        fadeDuration: Duration(
          milliseconds: entry.key == WidgetState.pressed ? 200 : 50,
        ),
        onRemoved: () => highlights.remove(entry.key),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    schedulePaint();
  }

  @override
  void didUpdateWidget(_LegacyHighlights old) {
    super.didUpdateWidget(old);
    if (old.shape != widget.shape) {
      for (final feature in highlights.values.toList()) {
        feature.dispose();
      }
      highlights.clear();
    }
    syncPaint();
  }

  @override
  void dispose() {
    for (final feature in highlights.values.toList()) {
      feature.dispose();
    }
    highlights.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
