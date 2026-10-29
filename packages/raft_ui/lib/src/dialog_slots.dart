import 'recipe_surface.dart';

import 'package:flutter/widgets.dart';

import 'recipes/recipe_runtime.dart';
import 'recipes/recipe_router.dart';
import 'tap_slop.dart';
import 'theme.dart';

/// Projects the shared dialog's measured slots onto its existing recipe.
/// The original decorations, semantic colors and text family remain intact.
RaftSlotStyle raftDialogSlot(RaftTokens t, RaftSlotStyle source, String slot) {
  final legacy = usesLegacyRecipes(t.recipeTokens);
  final overrides = t.themeOverrides;
  if (!legacy && overrides == null) return source;
  final properties = {...source.properties};
  void number(String property, String name, double fallback) {
    if (!legacy && !overrides!.geometry.containsKey(name)) return;
    properties[property] = CssNum(t.size(name, fallback: fallback), 'px');
  }

  void inset(String part) {
    final prefix = 'space.dialog$part';
    number('padding-left', '${prefix}Inline', source.padding.left);
    number('padding-right', '${prefix}Inline', source.padding.right);
    number('padding-top', '${prefix}Top', source.padding.top);
    number('padding-bottom', '${prefix}Bottom', source.padding.bottom);
  }

  switch (slot) {
    case 'content':
      final fill = overrides?.colors['layer-dialog'];
      if (!legacy && fill != null) {
        properties['background-color'] = CssColor(fill.toARGB32(), null, fill);
      }
      number('padding-left', 'space.dialogContentInline', source.padding.left);
      number(
        'padding-right',
        'space.dialogContentInline',
        source.padding.right,
      );
      number('padding-top', 'space.dialogContentBlock', source.padding.top);
      number(
        'padding-bottom',
        'space.dialogContentBlock',
        source.padding.bottom,
      );
      final line = t.colors['line-dialog'] ?? t.line;
      for (final side in ['top', 'right', 'bottom', 'left']) {
        number('border-$side-width', 'stroke.dialog', source.borderWidth.top);
        if (legacy || overrides!.geometry.containsKey('stroke.dialog')) {
          properties['border-$side-style'] = const CssKeyword('solid');
        }
        if (legacy || overrides!.colors.containsKey('line-dialog')) {
          properties['border-$side-color'] = CssColor(
            line.toARGB32(),
            null,
            line,
          );
        }
      }
      final ring = t.size('stroke.dialogRing', fallback: 0);
      if (legacy && ring > 0) {
        final shadow = source['box-shadow'];
        properties['box-shadow'] = CssList([
          CssSeq([
            const CssNum(0),
            const CssNum(0),
            const CssNum(0),
            CssNum(ring, 'px'),
            CssColor(line.toARGB32(), null, line),
          ]),
          if (shadow is CssList)
            ...shadow.items
          else if (shadow != null)
            shadow,
        ]);
      }
      if (!legacy &&
          (overrides!.geometry.containsKey('stroke.dialogRing') ||
              overrides.colors.containsKey('line-dialog'))) {
        // Replace the source ring in place; floating shadow layers keep their
        // source order, and reapplying a content binding remains idempotent.
        final shadows = source['box-shadow'];
        final layers = shadows is CssList
            ? shadows.items
            : [if (shadows != null) shadows];
        bool isRing(CssValue value) {
          final layers = RaftSlotStyle(
            {'box-shadow': value},
            const {},
            const [],
          ).boxShadow;
          return layers.length == 1 &&
              layers.single is RaftLiteralShadow &&
              (layers.single as RaftLiteralShadow).offset == Offset.zero &&
              (layers.single as RaftLiteralShadow).blur == 0 &&
              (layers.single as RaftLiteralShadow).spread > 0;
        }

        final replacement = CssSeq([
          const CssNum(0),
          const CssNum(0),
          const CssNum(0),
          CssNum(ring, 'px'),
          CssColor(line.toARGB32(), null, line),
        ]);
        var found = false;
        final bound = <CssValue>[];
        for (final layer in layers) {
          if (isRing(layer)) {
            if (!found && ring > 0) bound.add(replacement);
            found = true;
          } else {
            bound.add(layer);
          }
        }
        if (!found && ring > 0) bound.insert(0, replacement);
        properties['box-shadow'] = CssList(bound);
      }
      number('row-gap', 'space.dialogPartGap', source.rowGap ?? 0);
      for (final corner in [
        'top-left',
        'top-right',
        'bottom-left',
        'bottom-right',
      ]) {
        number('border-$corner-radius', 'radius.dialog', 8);
      }
    case 'header':
      inset('Header');
      number('column-gap', 'space.dialogHeaderGap', source.columnGap ?? 12);
    case 'body':
      inset('Body');
    case 'footer':
      inset('Footer');
      number('column-gap', 'space.dialogFooterGap', source.columnGap ?? 12);
      number('row-gap', 'space.dialogFooterGap', source.rowGap ?? 12);
    case 'title':
      final style = source.textStyle(t.recipeTokens);
      number('font-size', 'type.dialogTitle.size', style.fontSize ?? 16);
      number(
        'line-height',
        'type.dialogTitle.line',
        (style.fontSize ?? 16) * (style.height ?? 1.5),
      );
  }
  return RaftSlotStyle(
    properties,
    source.targets,
    source.classes,
    t.recipeTokens,
  );
}

/// CSS DialogClose has negative block/end margins. Its paint and full touch
/// target extend past the smaller flex slot; the host routes those touches.
class RaftDialogCloseOutset extends StatelessWidget {
  const RaftDialogCloseOutset({
    super.key,
    required this.child,
    this.verticalOutset,
    this.endOutset,
  });
  final Widget child;
  final double? verticalOutset;
  final double? endOutset;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final extent = t.size('size.dialogClose', fallback: 28);
    final outset = endOutset ?? t.size('space.dialogCloseOutset', fallback: 0);
    final vertical = verticalOutset ?? outset;
    if (outset == 0) return SizedBox.square(dimension: extent, child: child);
    return RaftTapSlopAnchor(
      minSize: const Size.square(48),
      child: SizedBox(
        width: extent - outset,
        height: extent - vertical * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: -vertical,
              width: extent,
              height: extent,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
