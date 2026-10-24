import 'recipe_surface.dart';
import 'recipes/banner.g.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';

RaftBannerRecipeStyle raftBannerSlots(
  RaftTokens t,
  RaftBannerRecipeStyle source,
  RaftBannerRecipeSize size,
  RaftBannerRecipeStatus status,
) {
  final foreground = t.colors['foreground-banner-body'] ?? t.muted;
  final desc = {
    ...source.description.properties,
    'color': CssColor(foreground.toARGB32(), null, foreground),
  };
  // `banner.style`: the Raft banner (raft-ui 0.7 `banner`) paints every
  // density from the same box (`rounded-container ring-1 ring-inset`) and only
  // changes padding, gap and text size; the recipe look keeps the generated
  // `sm` / `lg` rules.
  final byToken = t.option('banner.style', or: 'recipe') == 'raft';
  if (size != RaftBannerRecipeSize.md && !byToken)
    return RaftBannerRecipeStyle(
      root: source.root,
      title: source.title,
      description: RaftSlotStyle(
        desc,
        source.description.targets,
        source.description.classes,
        t.recipeTokens,
      ),
      action: source.action,
    );
  // raft-ui `banner` sizes: `sm` px-3 py-2 gap-x-2 text-footnote (13/18),
  // `md` px-3.5 py-3, `lg` px-4 py-3.5; only `sm` changes the text.
  final small = size == RaftBannerRecipeSize.sm;
  final bodySize = small ? 13.0 : t.size('type.bannerBody.size', fallback: 13);
  final bodyLine = small ? 18.0 : t.size('type.bannerBody.line', fallback: 16);
  desc['font-size'] = CssNum(bodySize, 'px');
  desc['line-height'] = CssNum(bodyLine, 'px');
  final root = {...source.root.properties};
  final color = t.colors['line-banner'] ?? t.line;
  final border = t.size('stroke.bannerBorder', fallback: 0);
  final ring = t.size('stroke.bannerRing', fallback: 0);
  final fill =
      t.colors[switch (status) {
        RaftBannerRecipeStatus.destructive => 'layer-banner-destructive',
        RaftBannerRecipeStatus.warning => 'layer-banner-warning',
        RaftBannerRecipeStatus.info => 'layer-banner-info',
        RaftBannerRecipeStatus.success => 'layer-banner-success',
        _ => 'fill-muted',
      }]!;
  root['background-color'] = CssColor(fill.toARGB32(), null, fill);
  for (final side in ['top', 'right', 'bottom', 'left']) {
    root['border-$side-width'] = CssNum(border, 'px');
    root['border-$side-style'] = const CssKeyword('solid');
    root['border-$side-color'] = CssColor(color.toARGB32(), null, color);
    root['padding-$side'] = CssNum(
      side == 'left' || side == 'right'
          ? switch (size) {
              RaftBannerRecipeSize.sm when byToken => 12,
              RaftBannerRecipeSize.lg when byToken => 16,
              _ => t.size('space.bannerInline', fallback: 12),
            }
          : switch (size) {
              RaftBannerRecipeSize.sm when byToken => 8,
              RaftBannerRecipeSize.lg when byToken => 14,
              _ => 12,
            },
      'px',
    );
  }
  for (final corner in [
    'top-left',
    'top-right',
    'bottom-left',
    'bottom-right',
  ]) {
    root['border-$corner-radius'] = CssNum(
      t.size('radius.banner', fallback: 4),
      'px',
    );
  }
  root['column-gap'] = CssNum(
    small && byToken ? 8 : t.size('space.bannerGap', fallback: 8),
    'px',
  );
  root['font-size'] = CssNum(bodySize, 'px');
  root['line-height'] = CssNum(small ? 18 : 20, 'px');
  root['letter-spacing'] = CssNum(
    t.size('type.bannerBody.tracking', fallback: 0),
    'px',
  );
  if (ring > 0)
    root['box-shadow'] = CssSeq([
      const CssKeyword('inset'),
      const CssNum(0),
      const CssNum(0),
      const CssNum(0),
      CssNum(ring, 'px'),
      CssColor(color.toARGB32(), null, color),
    ]);
  return RaftBannerRecipeStyle(
    root: RaftSlotStyle(
      root,
      source.root.targets,
      source.root.classes,
      t.recipeTokens,
    ),
    title: source.title,
    description: RaftSlotStyle(
      desc,
      source.description.targets,
      source.description.classes,
      t.recipeTokens,
    ),
    action: source.action,
  );
}
