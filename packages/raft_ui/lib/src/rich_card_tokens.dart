import 'package:flutter/material.dart';

import 'css_border.dart';

import 'design_primitives.dart';
import 'tokens/tokens.dart';
import 'theme.dart';

/// Exact pinned raft-ui 0.5.52 messageEmbed/messageForwardedBundle and solid
/// success Badge primitives. See dist/index.mjs; colors resolve through the
/// shared semantic palette rather than duplicating sampled PNG literals.
abstract final class RichCardPrimitive {
  static const badgeElegantHeight = 18.0;
  static const badgeElegantInset = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 2,
  );
  static const badgeGapElegant = 6.0;
  static const embedRadius = 8.0, contentRadius = 5.5;
  static const embedInset = 2.0, fineBorder = .5;
  static const headerVerticalInset = 6.0, footerVerticalInset = 6.0;
}

class RichCardSemantic {
  const RichCardSemantic(this.tokens);
  final RaftTokens tokens;
  Color get success => tokens.colors['success']!;
  Color get successText =>
      tokens.colors[tokens.dark ? 'foreground-inverse' : 'success-foreground']!;
  // messageEmbed extends messageBlock's bg-layer-card. Header/footer are
  // transparent over that card; layer-canvas-muted belongs to the sidebar.
  Color get embedCanvas => tokens.card;
  Color get content => tokens.panel;
  Color get prose => tokens.strong;
  Color get divider => RaftPrimitiveColors.black.withValues(alpha: .1);
}

class ForwardedSnapshotRecipe extends RaftMessageEmbedRecipe {
  const ForwardedSnapshotRecipe(super.tokens, {this.devicePixelRatio = 1});

  /// For Blink's whole-device-pixel border widths ([raftCssBorderWidth]).
  final double devicePixelRatio;
  double get fine =>
      raftCssBorderWidth(RichCardPrimitive.fineBorder, devicePixelRatio);
  RichCardSemantic get semantic => RichCardSemantic(tokens);
  @override
  BorderRadius get radius =>
      BorderRadius.circular(RichCardPrimitive.embedRadius);
  @override
  BorderSide get border => BorderSide(
    color: tokens.dark ? Colors.transparent : tokens.colors['line-muted']!,
    width: fine,
  );
  @override
  EdgeInsets get inset => EdgeInsets.all(RichCardPrimitive.embedInset);
  @override
  BoxDecoration get decoration => BoxDecoration(
    color: semantic.embedCanvas,
    borderRadius: radius,
    border: Border.fromBorderSide(border),
  );
  EdgeInsets headerInset(double width) => EdgeInsets.symmetric(
    horizontal: width >= 640 ? 14 : 12,
    vertical: RichCardPrimitive.headerVerticalInset,
  );
  EdgeInsets footerInset(double width) => EdgeInsets.symmetric(
    horizontal: width >= 640 ? 14 : 12,
    vertical: RichCardPrimitive.footerVerticalInset,
  );
  BoxDecoration get headerDecoration => const BoxDecoration();
  BoxDecoration get footerDecoration => const BoxDecoration();
  BoxDecoration get contentDecoration => BoxDecoration(
    color: semantic.content,
    borderRadius: BorderRadius.circular(RichCardPrimitive.contentRadius),
    border: Border.all(
      color: tokens.dark
          ? RaftPrimitiveColors.black.withValues(alpha: .35)
          : tokens.colors['line-muted']!,
      width: fine,
    ),
  );
  @override
  TextStyle get header => super.header.copyWith(
    height: 1,
    fontWeight: FontWeight.w500,
    color: tokens.muted,
  );
  @override
  TextStyle get metadata => RaftTypography.body(
    tokens,
    size: 11,
    line: 20,
  ).copyWith(color: tokens.colors['foreground-placeholder']);
  @override
  // `text-[11px]` default line height (1.5 = 16.5px).
  TextStyle get count => super.count.copyWith(height: 1.5);
  @override
  TextStyle get source => super.source.copyWith(height: 1.5);
  @override
  TextStyle get showMore => super.header.copyWith(
    height: 20 / 11,
    fontWeight: FontWeight.w500,
    color: tokens.colors['foreground-placeholder'],
  );
  @override
  bool get showMoreUnderlined => false;
}

class ActionSnapshotRecipe extends RaftActionCardRecipe {
  const ActionSnapshotRecipe(super.tokens);
  RichCardSemantic get semantic => RichCardSemantic(tokens);
  TextStyle get detailValue => summary.copyWith(color: tokens.strong);
  TextStyle get committed => summary;
  TextStyle get committedName => summary.copyWith(fontWeight: FontWeight.w700);
  TextStyle get badge => RaftTypography.body(
    tokens,
    size: 11,
    line: 12,
    weight: FontWeight.w500,
    color: semantic.successText,
  ).copyWith(letterSpacing: .22);
  BoxDecoration get badgeDecoration => BoxDecoration(
    color: semantic.success,
    border: Border.all(color: Colors.transparent),
    borderRadius: BorderRadius.circular(999),
  );
  double get badgeHeight => RichCardPrimitive.badgeElegantHeight;
  EdgeInsets get badgeInset => RichCardPrimitive.badgeElegantInset;
  double get badgeGap => RichCardPrimitive.badgeGapElegant;
}
