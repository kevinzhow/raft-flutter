import 'package:flutter/material.dart';

import 'dashed_rounded_border.dart';
import 'raft/css_box.dart' show raftSnapBorder;
import 'recipe_surface.dart';
import 'recipes/comment.g.dart';
import 'theme.dart';

class RaftCommentCard extends StatelessWidget {
  const RaftCommentCard({
    super.key,
    required this.children,
    this.active = false,
    this.privateDraft = false,
    this.onActivate,
  });

  final List<Widget> children;
  final bool active, privateDraft;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final resolver = tokens.recipeTokens;
    final slot = RaftCommentRecipe.resolve(
      states: tokens.recipeStates(extra: [if (active) 'data-active']),
      tokens: resolver,
    ).card;
    final surface = slot.decoration(resolver);
    final decoration = raftSnapBorder(
      context,
      surface.copyWith(
        boxShadow: [
          for (final shadow in surface.boxShadow ?? const <BoxShadow>[])
            BoxShadow(
              color: shadow.color,
              offset: shadow.offset,
              blurRadius: raftCssBlurRadius(shadow.blurRadius),
              spreadRadius: shadow.spreadRadius,
            ),
        ],
      ),
    );
    final border = decoration.border?.top;
    final radius = slot.borderRadius?.topLeft.x ?? tokens.radius;
    final card = DecoratedBox(
      decoration: privateDraft
          ? decoration.copyWith(border: const Border())
          : decoration,
      child: Padding(
        padding: slot.padding.add(decoration.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: slot.rowGap ?? 0,
          children: children,
        ),
      ),
    );
    if (privateDraft && border != null) {
      return CustomPaint(
        foregroundPainter: RaftDashedRoundedPainter(
          color: border.color,
          width: border.width,
          radius: radius,
        ),
        child: card,
      );
    }
    if (onActivate == null) return card;
    return Semantics(
      selected: active,
      child: Focus(
        skipTraversal: true,
        canRequestFocus: false,
        onFocusChange: (focused) {
          if (focused) onActivate?.call();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onActivate,
          child: card,
        ),
      ),
    );
  }
}
