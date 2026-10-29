import 'package:flutter/widgets.dart';

import 'recipe_surface.dart';
import 'recipes/recipe_runtime.dart';
import 'surface_background_scope.dart';

/// Paint context used only by owners that paint this exact recipe surface.
/// Unknown, translucent or nonuniform fills explicitly block outer scopes.
class RaftRecipeBackgroundScope extends StatelessWidget {
  const RaftRecipeBackgroundScope({
    super.key,
    required this.style,
    required this.tokens,
    required this.child,
    this.inheritUnpainted = false,
  });

  final RaftSlotStyle style;
  final RaftTokenResolver tokens;
  final Widget child;

  /// An intermediate list with no paint may preserve its surface owner's fill.
  /// A translucent, nonuniform or faded list still blocks the declaration.
  final bool inheritUnpainted;

  @override
  Widget build(BuildContext context) {
    final current = style
        .text(tokens, base: DefaultTextStyle.of(context).style)
        .color;
    final fill = style.backgroundColor?.resolve(tokens, currentColor: current);
    bool hasImage(RaftSlotStyle slot) => switch (slot['background-image']) {
      null || CssKeyword(value: 'none') => false,
      _ => true,
    };
    bool hasOverlay(RaftSlotStyle? slot) =>
        slot != null &&
        (hasImage(slot) ||
            (slot.backgroundColor?.resolve(tokens, currentColor: current).a ??
                    0) >
                0);
    final hasInset = style
        .cssShadows(tokens, currentColor: current)
        .any((shadow) => shadow.inset && shadow.color.a > 0);
    final opaque =
        fill != null &&
        fill.a == 1 &&
        (style.opacity ?? 1) == 1 &&
        !hasImage(style) &&
        !hasInset &&
        !hasOverlay(style.before) &&
        !hasOverlay(style.after);
    final unpainted =
        (fill == null || fill.a == 0) &&
        (style.opacity ?? 1) == 1 &&
        !hasImage(style) &&
        !hasInset &&
        !hasOverlay(style.before) &&
        !hasOverlay(style.after);
    return RaftSurfaceBackgroundScope(
      color: opaque
          ? fill
          : inheritUnpainted && unpainted
          ? RaftSurfaceBackgroundScope.of(context)
          : null,
      child: child,
    );
  }
}
