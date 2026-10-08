import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'tokens/tokens.dart';
import 'theme.dart';

/// Exact pinned raft-ui 0.5.27 messageEmbed/messageForwardedBundle and solid
/// success Badge primitives. See dist/index.mjs; colors resolve through the
/// shared semantic palette rather than duplicating sampled PNG literals.
abstract final class RichCardPrimitive {
  static const badgeBrutalHeight = 20.0, badgeElegantHeight = 18.0;
  static const badgeBrutalInset = EdgeInsets.symmetric(horizontal: 6);
  static const badgeElegantInset = EdgeInsets.symmetric(horizontal: 8, vertical: 2);
  static const badgeGapBrutal = 4.0, badgeGapElegant = 6.0;
  static const embedRadius = 8.0, contentRadius = 5.5;
  static const embedInset = 2.0, fineBorder = .5;
  static const headerVerticalInset = 6.0, footerVerticalInset = 6.0;
}

class RichCardSemantic {
  const RichCardSemantic(this.tokens);
  final RaftTokens tokens;
  Color get success => tokens.colors[tokens.brutal ? 'color-brutal-lime' : 'success']!;
  Color get successText => tokens.brutal ? tokens.strong : tokens.colors[tokens.dark ? 'foreground-inverse' : 'success-foreground']!;
  // messageEmbed extends messageBlock's bg-layer-card. Header/footer are
  // transparent over that card; layer-canvas-muted belongs to the sidebar.
  Color get embedCanvas => tokens.brutal ? RaftPrimitiveColors.white : tokens.card;
  Color get content => tokens.brutal ? RaftPrimitiveColors.white : tokens.panel;
  Color get prose => tokens.brutal ? RaftPrimitiveColors.black : tokens.strong;
  Color get divider => RaftPrimitiveColors.black.withValues(alpha: .1);
}

class ForwardedSnapshotRecipe extends RaftMessageEmbedRecipe {
  const ForwardedSnapshotRecipe(super.tokens);
  RichCardSemantic get semantic => RichCardSemantic(tokens);
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : RichCardPrimitive.embedRadius);
  @override
  BorderSide get border => BorderSide(color: tokens.brutal ? RaftPrimitiveColors.black.withValues(alpha: .2) : tokens.dark ? Colors.transparent : tokens.colors['line-muted']!, width: tokens.brutal ? 1 : RichCardPrimitive.fineBorder);
  @override
  EdgeInsets get inset => EdgeInsets.all(tokens.brutal ? 0 : RichCardPrimitive.embedInset);
  @override
  BoxDecoration get decoration => BoxDecoration(color: semantic.embedCanvas, borderRadius: radius, border: Border.fromBorderSide(border));
  EdgeInsets headerInset(double width) => EdgeInsets.symmetric(horizontal: tokens.brutal ? 10 : width >= 640 ? 14 : 12, vertical: RichCardPrimitive.headerVerticalInset);
  EdgeInsets footerInset(double width) => EdgeInsets.symmetric(horizontal: tokens.brutal ? 12 : width >= 640 ? 14 : 12, vertical: RichCardPrimitive.footerVerticalInset);
  BoxDecoration get headerDecoration => tokens.brutal ? BoxDecoration(color: semantic.content, border: Border(bottom: BorderSide(color: semantic.divider))) : const BoxDecoration();
  BoxDecoration get footerDecoration => tokens.brutal ? BoxDecoration(color: semantic.content, border: Border(top: BorderSide(color: semantic.divider))) : const BoxDecoration();
  BoxDecoration get contentDecoration => BoxDecoration(color: semantic.content, borderRadius: tokens.brutal ? null : BorderRadius.circular(RichCardPrimitive.contentRadius), border: tokens.brutal ? null : Border.all(color: tokens.dark ? RaftPrimitiveColors.black.withValues(alpha: .35) : tokens.colors['line-muted']!, width: RichCardPrimitive.fineBorder));
  @override
  TextStyle get header => super.header.copyWith(height: 1, fontWeight: tokens.brutal ? FontWeight.w900 : FontWeight.w500, color: tokens.brutal ? RaftPrimitiveColors.black.withValues(alpha: .7) : tokens.muted);
  @override
  TextStyle get metadata => (tokens.brutal ? RaftTypography.mono(tokens, size: 11, line: 110 / 7) : RaftTypography.body(tokens, size: 11, line: 20)).copyWith(color: tokens.brutal ? RaftPrimitiveColors.black.withValues(alpha: .55) : tokens.colors['foreground-placeholder']);
  @override
  TextStyle get count => super.count.copyWith(height: 20 / 11);
  @override
  TextStyle get source => super.source.copyWith(height: 20 / 11);
  @override
  TextStyle get showMore => super.header.copyWith(height: 20 / 11, fontWeight: tokens.brutal ? FontWeight.w900 : FontWeight.w500, color: tokens.brutal ? RaftPrimitiveColors.black.withValues(alpha: .6) : tokens.colors['foreground-placeholder'], decoration: tokens.brutal ? TextDecoration.underline : TextDecoration.none);
}

class ActionSnapshotRecipe extends RaftActionCardRecipe {
  const ActionSnapshotRecipe(super.tokens);
  RichCardSemantic get semantic => RichCardSemantic(tokens);
  TextStyle get detailValue => summary.copyWith(color: tokens.strong);
  TextStyle get committed => summary;
  TextStyle get committedName => summary.copyWith(fontWeight: FontWeight.w700);
  TextStyle get badge => RaftTypography.body(tokens, size: tokens.brutal ? 10 : 11, line: tokens.brutal ? 10 : 12, weight: tokens.brutal ? FontWeight.w700 : FontWeight.w500, color: semantic.successText).copyWith(letterSpacing: tokens.brutal ? .5 : .22);
  BoxDecoration get badgeDecoration => BoxDecoration(color: semantic.success, border: Border.all(color: tokens.brutal ? tokens.colors['line-strong']! : Colors.transparent), borderRadius: BorderRadius.circular(tokens.brutal ? 0 : 999));
  double get badgeHeight => tokens.brutal ? RichCardPrimitive.badgeBrutalHeight : RichCardPrimitive.badgeElegantHeight;
  EdgeInsets get badgeInset => tokens.brutal ? RichCardPrimitive.badgeBrutalInset : RichCardPrimitive.badgeElegantInset;
  double get badgeGap => tokens.brutal ? RichCardPrimitive.badgeGapBrutal : RichCardPrimitive.badgeGapElegant;
}
