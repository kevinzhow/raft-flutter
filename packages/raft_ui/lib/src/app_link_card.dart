import 'package:flutter/widgets.dart';

import 'design_primitives.dart';
import 'message_embed_frame.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/app_link_card.g.dart';
import 'settings_applications.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

class RaftAppLinkChip extends StatelessWidget {
  const RaftAppLinkChip({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.prompt = false,
    this.domain,
  });

  final String label, semanticLabel;
  final Widget icon;
  final VoidCallback onPressed;
  final bool prompt;
  final String? domain;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return RaftInteractive(
      onPressed: onPressed,
      button: prompt,
      semanticLabel: semanticLabel,
      expandTouchTarget: false,
      builder: (context, state) => Container(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 48).clamp(64, 280),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: state.hovered || state.focusVisible
              ? tokens.colors['fill-medium']
              : tokens.colors['fill-subtle'],
          borderRadius: BorderRadius.circular(
            tokens.size('radius.chip', fallback: RaftScale.spacing),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: RaftScale.spacing,
          children: [
            icon,
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DefaultTextStyle.of(context).style.copyWith(
                  color: prompt
                      ? tokens.ui.foregroundMuted
                      : tokens.ui.foreground,
                ),
              ),
            ),
            if (domain case final domain?)
              Flexible(
                child: Text(
                  domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.scale(
                    RaftTypeScale.footnote,
                    color: tokens.ui.foregroundMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class RaftAppLinkLogo extends StatelessWidget {
  const RaftAppLinkLogo({
    super.key,
    required this.name,
    this.logoUrl,
    this.large = false,
  });

  final String name;
  final String? logoUrl;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: large ? 27 : 14,
        child: FittedBox(
          child: RaftAppLogo(
            initials: initials,
            logoUrl: logoUrl,
            size: RaftAppLogoSize.sm,
          ),
        ),
      ),
    );
  }
}

class RaftAppLinkCard extends StatelessWidget {
  const RaftAppLinkCard({
    super.key,
    required this.title,
    required this.appName,
    required this.domain,
    required this.icon,
    required this.onOpen,
    this.body,
    this.actions,
  });

  final String title, appName, domain;
  final Widget icon;
  final VoidCallback onOpen;
  final Widget? body, actions;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final recipe = RaftAppLinkCardRecipe.resolve(
      tokens: tokens.recipeTokens,
      states: tokens.recipeStates(),
    );
    final source = tokens.scale(
      RaftTypeScale.footnote,
      color: tokens.ui.foregroundMuted,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title,
      child: RaftRecipeBox(
        style: recipe.root,
        tokens: tokens.recipeTokens,
        child: RaftMessageEmbedFrame(
          size: RaftMessageEmbedSize.item,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  spacing: 4,
                  children: [
                    icon,
                    Flexible(
                      child: Text(
                        appName,
                        style: source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('·', style: source),
                    Flexible(
                      child: Text(
                        domain,
                        style: source,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RaftTextLink(
                    label: title,
                    variant: RaftTextLinkVariant.strong,
                    onPressed: onOpen,
                  ),
                ),
                ?body,
                ?actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
