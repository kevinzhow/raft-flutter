import 'package:flutter/widgets.dart';

import 'recipes/recipe_runtime.dart';
import 'text_scaling.dart' show RaftScaled;

/// [style] with its pinned CSS `height` turned into a `min-height` once the
/// text is larger than the default, so a text-bearing recipe box (a button, a
/// chip) grows with its label instead of overflowing it. At the default text
/// size [style] is returned untouched (pixel parity).
///
/// For boxes built with `RaftRecipeBox(applyText: false)`, which keep their
/// recipe height at every text size.
RaftSlotStyle raftGrowingHeight(BuildContext context, RaftSlotStyle style) {
  final h = style.height;
  if (h == null || !RaftScaled.grows(context)) return style;
  return RaftSlotStyle(
    {
      for (final e in style.properties.entries)
        if (e.key != 'height') e.key: e.value,
      'min-height': CssNum(h, 'px'),
    },
    style.targets,
    style.classes,
    style.tokens,
  );
}

/// A box of [height] at the default text size that is a minimum height (and
/// grows with its child) once the text is larger.
class RaftMinHeightBox extends StatelessWidget {
  const RaftMinHeightBox({super.key, required this.height, this.child});
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) => RaftScaled.grows(context)
      ? ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: child,
        )
      : SizedBox(height: height, child: child);
}
