import 'package:flutter/widgets.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'indicators.dart';
import 'interaction.dart';
import 'message_embed_frame.dart';
import 'panel_layout.dart';
import 'raft/avatar.dart';
import 'raft/button.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/recipe_runtime.dart' show CssNum;
import 'recipes/app_link_card.g.dart';
import 'recipes/message_card.g.dart';
import 'recipes/message_reference.g.dart';
import 'sized_image.dart';
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
    final t = RaftTokens.of(context);
    final touchDomain = RaftInteraction.of(context).touch ? domain : null;
    return RaftInteractive(
      onPressed: onPressed,
      button: prompt,
      semanticLabel: semanticLabel,
      expandTouchTarget: false,
      builder: (context, state) {
        final recipe = RaftMessageReferenceRecipe.resolve(
          variant: prompt
              ? RaftMessageReferenceRecipeVariant.muted
              : RaftMessageReferenceRecipeVariant.info,
          capped: true,
          tokens: t.recipeTokens,
          states: t.recipeStates(
            hovered: state.hovered,
            focusVisible: state.focusVisible,
            pressed: state.pressed,
            // The generated :has() atom represents any supported leading mark.
            extra: [
              'has:>svg>data-slot=spinner>data-slot=message-reference-icon',
            ],
          ),
        );
        final base = DefaultTextStyle.of(context).style;
        final body = t.typeSlot('body');
        final size = base.fontSize ?? body.fontSize;
        final chipSize = switch (recipe.root['font-size']) {
          CssNum(unit: 'em', :final value) => size * value,
          _ => size,
        };
        final line = (base.height ?? body.height) * size;
        final style = recipe.root
            .text(t.recipeTokens, base: base)
            .copyWith(
              fontSize: chipSize,
              height: (line - RaftScale.space(.5)) / chipSize,
            );
        final suffixStyle = recipe.suffix
            .text(t.recipeTokens, base: base)
            .copyWith(fontFamily: t.monoFont);
        final gap = recipe.root.columnGap ?? RaftScale.spacing;
        final scaler = MediaQuery.textScalerOf(context);
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: scaler.scale(chipSize) * 24),
          child: RaftRecipeBox(
            style: recipe.root,
            tokens: t.recipeTokens,
            applyText: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: t.ui.foregroundMuted),
                  child: icon,
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: gap,
                    children: [
                      Flexible(
                        child: RaftCssText(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                      ),
                      if (touchDomain != null)
                        Flexible(
                          flex: 2,
                          child: RaftCssText(
                            touchDomain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: suffixStyle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Registration image for an app link. An authorization prompt uses the
/// connected-app sticker instead of the generic preview glyph.
class RaftAppLinkLogo extends StatelessWidget {
  const RaftAppLinkLogo({
    super.key,
    required this.name,
    this.logoUrl,
    this.large = false,
    this.chip = false,
  });

  final String name;
  final String? logoUrl;
  final bool large, chip;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    Widget image(double size, Widget fallback) => url == null || url.isEmpty
        ? fallback
        : RaftSizedImage.avatar(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );

    if (large) {
      final words = name.trim().split(RegExp(r'\s+'));
      final letters = words.length > 1
          ? words.map((word) => word.characters.first).take(2).join()
          : words.first.characters.take(2).join();
      const size = RaftAvatarSize.sm;
      return ExcludeSemantics(
        child: RaftStickerAvatar(
          type: RaftAvatarType.human,
          size: size,
          child: image(
            size.extent,
            RaftAvatarInitials(
              letters.isEmpty ? 'A' : letters.toUpperCase(),
              size: size,
            ),
          ),
        ),
      );
    }

    final extent = chip ? 14.0 : 16.0;
    final radius = RaftTokens.of(context)
        .size('radius.avatarInner', fallback: RaftScale.space(.5));
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: extent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: image(extent, RaftIcon(RaftGlyph.appWindow, size: extent)),
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
    this.afterText = false,
  });

  final String title, appName, domain;
  final bool afterText;
  final Widget icon;
  final VoidCallback onOpen;
  final Widget? body, actions;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftMessageCardRecipe.resolve(
      tokens: t.recipeTokens,
      states: t.recipeStates(),
    );
    final source = raftSlotTextStyle(t, recipe.source);
    final sourceName = recipe.sourceName.text(t.recipeTokens, base: source);
    final block = RaftAppLinkCardRecipe.resolve(tokens: t.recipeTokens);
    return Padding(
      padding: EdgeInsets.only(top: afterText ? block.root.margin.top : 0),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: title,
        child: RaftMessageEmbedFrame(
          size: RaftMessageEmbedSize.item,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftRecipeBox(
                style: recipe.source,
                tokens: t.recipeTokens,
                applyText: false,
                child: Row(
                  spacing: recipe.source.columnGap ?? RaftScale.spacing,
                  children: [
                    IconTheme.merge(
                      data: IconThemeData(color: source.color),
                      child: icon,
                    ),
                    Flexible(
                      child: RaftCssText(
                        appName,
                        style: sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    RaftCssText('·', style: source),
                    Flexible(
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: RaftCssText(
                          domain,
                          style: source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: recipe.body.padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: recipe.body.rowGap ?? RaftScale.spacing,
                  children: [
                    RaftTextLink(
                      label: title,
                      maxLines: 2,
                      typeStyle: raftSlotTextStyle(t, recipe.title),
                      variant: RaftTextLinkVariant.strong,
                      onPressed: onOpen,
                    ),
                    ?body,
                  ],
                ),
              ),
              if (actions != null)
                Padding(padding: recipe.actions.padding, child: actions),
            ],
          ),
        ),
      ),
    );
  }
}

/// Presentation of an app's preview authorization. The caller owns the
/// decision, pending requests and any persisted preferences.
class RaftAppLinkAuthorizationCard extends StatelessWidget {
  const RaftAppLinkAuthorizationCard({
    super.key,
    required this.titleTemplate,
    required this.appName,
    required this.detail,
    required this.logo,
    required this.allowLabel,
    required this.declineLabel,
    required this.allowingLabel,
    required this.decliningLabel,
    required this.onAllow,
    required this.onDecline,
    this.allowing = false,
    this.declining = false,
    this.failed = false,
  });

  final String titleTemplate, appName;
  final String detail, allowLabel, declineLabel, allowingLabel, decliningLabel;
  final Widget logo;
  final VoidCallback onAllow, onDecline;
  final bool allowing, declining, failed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final inset = raftMessageEmbedHeaderPadding(context);
    final titleStyle = t.scale(RaftTypeScale.subhead);
    final fragments = titleTemplate.split('{app}');
    final title = TextSpan(
      children: [
        TextSpan(text: fragments.first),
        for (final fragment in fragments.skip(1)) ...[
          TextSpan(
            text: appName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: fragment),
        ],
      ],
    );
    final detailStyle = t.scale(
      RaftTypeScale.footnote,
      color: failed ? t.ui.foreground : t.ui.foregroundMuted,
    );
    final titleLine =
        MediaQuery.textScalerOf(context)
            .scale(titleStyle.fontSize ?? RaftTypeScale.subhead.fontSize) *
        (titleStyle.height ?? 1);
    final gap = RaftScale.space(2);
    final leading = RaftAvatarSize.sm.extent + gap;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        inset.left,
        RaftScale.space(3),
        inset.right,
        RaftScale.space(2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftScale.space(1.5),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: [
              logo,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: ((RaftAvatarSize.sm.extent - titleLine) / 2).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftScale.space(.5),
                    children: [
                      RaftCssText.rich(title, style: titleStyle),
                      if (failed)
                        Semantics(
                          liveRegion: true,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: RaftScale.space(1.5),
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  top: RaftScale.space(.5),
                                ),
                                child: RaftIcon(
                                  RaftGlyph.triangleAlert,
                                  size: 14,
                                  color: t.colors['warning-strong'],
                                ),
                              ),
                              Expanded(
                                child: RaftCssText(detail, style: detailStyle),
                              ),
                            ],
                          ),
                        )
                      else
                        RaftCssText(detail, style: detailStyle),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(start: leading),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                RaftButton(
                  label: allowLabel,
                  uiVariant: RaftButtonVariant.standard,
                  disabled: declining,
                  busy: allowing,
                  loadingLabel: allowingLabel,
                  onPressed: onAllow,
                ),
                RaftButton(
                  label: declineLabel,
                  uiVariant: RaftButtonVariant.ghost,
                  disabled: allowing,
                  busy: declining,
                  loadingLabel: decliningLabel,
                  onPressed: onDecline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RaftAppLinkSkeleton extends StatelessWidget {
  const RaftAppLinkSkeleton({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final inset = raftMessageEmbedHeaderPadding(context);
    return Semantics(
      liveRegion: true,
      label: label,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: inset.left,
          vertical: RaftScale.space(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftScale.space(3),
          children: [
            for (final (width, line) in [
              (20, true),
              (64, true),
              (20, false),
              (60, true),
            ])
              RaftSkeleton(
                variant: line
                    ? RaftSkeletonVariant.line
                    : RaftSkeletonVariant.block,
                width: RaftScale.space(width),
                height: line ? null : RaftScale.space(5),
                fromRecipe: true,
              ),
          ],
        ),
      ),
    );
  }
}
