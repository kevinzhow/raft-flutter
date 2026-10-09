import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';

import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/banner.g.dart';
import 'theme.dart';

export 'recipes/banner.g.dart'
    show RaftBannerRecipeStatus, RaftBannerRecipeSize;

/// Product ui/Banner.tsx composition: BannerDescription keeps its own font
/// weight even when the caller makes the root bold. Geometry and colors come
/// from the generated public Banner recipe, including the real density axis.
class RaftBanner extends StatelessWidget {
  const RaftBanner({
    super.key,
    required this.description,
    this.title,
    this.status = RaftBannerRecipeStatus.warning,
    this.size = RaftBannerRecipeSize.md,
  });
  final String description;
  final String? title;
  final RaftBannerRecipeStatus status;
  final RaftBannerRecipeSize size;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final recipe = RaftBannerRecipe.resolve(
      theme: t.recipeTheme,
      status: status,
      size: size,
      states: t.recipeStates(
        extra: {
          'group/banner:data-size=${size.css}',
          'group/banner:data-status=${status.css}',
          if (title != null)
            'has:>data-slot=banner-description+has:>data-slot=banner-title',
        },
      ),
      tokens: tokens,
    );
    final base = recipe.root.text(
      tokens,
      base: DefaultTextStyle.of(context).style,
    );
    return Semantics(
      role: SemanticsRole.alert,
      child: RaftRecipeBox(
        style: recipe.root,
        tokens: tokens,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: recipe.title.margin,
                child: Text(
                  raftText(context, title!),
                  style: recipe.title.text(tokens, base: base),
                ),
              ),
            Text(
              raftText(context, description),
              style: recipe.description.text(tokens, base: base),
            ),
          ],
        ),
      ),
    );
  }
}
