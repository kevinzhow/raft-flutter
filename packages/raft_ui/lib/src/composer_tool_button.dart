import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'raft/button.dart';
import 'icons.dart';
import 'localization.dart';
import 'theme.dart';

/// Surface of the composer's small icon buttons (transparent, ghost hover; the
/// attach buttons' frame in Brutal). [on] marks a toggled button, [framed] keeps
/// the Brutal attach-button frame (border and hard shadow) while idle, and
/// [prominent] reads one step stronger than the muted icon colour (used by the
/// expand button in the dark theme).
class RaftComposerToolRecipe extends RaftControlRecipe {
  const RaftComposerToolRecipe(
    RaftTokens tokens, {
    this.on = false,
    this.framed = false,
    this.prominent = false,
  }) : super(tokens, variant: RaftControlVariant.ghost);
  final bool on, framed, prominent;

  @override
  Color get background => Colors.transparent;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => on
      ? (tokens.colors['fill-strong']!)
      : hovered || pressed
      ? tokens.colors['fill-strong']!.withValues(alpha: .8)
      : Colors.transparent;
  @override
  Color foregroundFor({bool hovered = false}) =>
      (hovered || on || (prominent && tokens.dark))
      ? tokens.strong
      : tokens.colors['foreground-icon']!;
  @override
  Color get foreground => foregroundFor();
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  BorderRadius get radius => BorderRadius.circular(6);
  @override
  // ds-allow: Web raft-ui/composer.recipe.ts iconButton `p-[7px]` (elegant), `p-1` (brutal)
  EdgeInsets get padding => EdgeInsets.all(7);
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => [if (focused) BoxShadow(color: focusRing, spreadRadius: 2)];
}

/// A square icon button that leaves the editor focused on pointer press.
class RaftComposerToolButton extends StatelessWidget {
  const RaftComposerToolButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.on = false,
    this.framed = false,
    this.prominent = false,
    this.face = RaftMetrics.buttonSm,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool on, framed, prominent;
  final double face;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(context, tooltip);
    final legacy = RaftControl(
      focusOnPointer: false,
      visualWidth: face,
      visualHeight: face,
      minimumTargetSize: face,
      variant: RaftControlVariant.ghost,
      recipe: RaftComposerToolRecipe(
        t,
        on: on,
        framed: framed,
        prominent: prominent,
      ),
      semanticLabel: label,
      tooltip: label,
      onPressed: onPressed,
      child: RaftIcon(glyph, size: RaftMetrics.iconSm),
    );
    return RaftButton(
      glyph: glyph,
      uiVariant: on ? RaftButtonVariant.outline : RaftButtonVariant.ghost,
      uiSize: face <= 24
          ? RaftButtonSize.iconXs
          : face <= 32
          ? RaftButtonSize.iconMd
          : RaftButtonSize.iconLg,
      onPressed: onPressed,
      focusOnPointer: false,
      toggled: on,
      semanticLabel: label,
      tooltip: label,
      legacyBuilder: legacy.legacySurface,
    );
  }
}
