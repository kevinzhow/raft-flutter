import 'package:flutter/widgets.dart';

import 'package:flutter/material.dart' show Colors;

import 'design_primitives.dart' show RaftInteractive;
import 'dialog_card.dart';
import 'icons.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

/// Source ChatPanel.tsx:1514–1525 at 26f77ef. Place in the timeline Stack.
/// The host owns visibility, unread count, localization and latest loading.
class RaftTimelineBottomButton extends StatelessWidget {
  const RaftTimelineBottomButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 12,
    left: 0,
    right: 0,
    child: Center(
      child: RaftTimelineBottomButtonBody(label: label, onPressed: onPressed),
    ),
  );
}

/// The button itself, without its place in the timeline Stack.
class RaftTimelineBottomButtonBody extends StatelessWidget {
  const RaftTimelineBottomButtonBody({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => RaftRecipeButton(
    label: label,
    glyph: RaftGlyph.arrowDown,
    glyphSize: 12,
    variant: RaftButtonRecipeVariant.outline,
    size: RaftButtonRecipeSize.sm,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    textStep: (12, 16),
    gap: 6,
    onPressed: onPressed,
  );
}

/// Web `ThreadUnreadJumpPill`: one pill for the unread followed threads of a
/// channel whose parent message is off screen, with the shape, weight and
/// height of the "Back to bottom" button (a paper control with the ink
/// control edge). The label jumps; the cross dismisses it until the number of
/// unread threads changes.
class RaftThreadUnreadJumpPill extends StatelessWidget {
  const RaftThreadUnreadJumpPill({
    super.key,
    required this.up,
    required this.label,
    required this.dismissLabel,
    required this.onJump,
    required this.onDismiss,
  });

  /// "Earliest unread thread" at the top (up) or "Next unread thread" at the
  /// bottom (down).
  final bool up;
  final String label, dismissLabel;
  final VoidCallback onJump, onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = t.brutal ? Colors.black : t.colors['foreground-muted']!;
    Widget segment({
      required Widget child,
      required EdgeInsets padding,
      required VoidCallback onPressed,
      required String semanticLabel,
      Key? key,
    }) => RaftInteractive(
      key: key,
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, state) => ColoredBox(
        color: state.hovered || state.pressed
            ? t.colors['fill-muted']!
            : Colors.transparent,
        child: Padding(
          padding: padding,
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
    return RaftRecipeButton(
      key: ValueKey('thread-unread-jump-pill-${up ? 'top' : 'bottom'}'),
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.sm,
      padding: EdgeInsets.zero,
      fontWeight: FontWeight.w700,
      textStep: (12, 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(
            key: const ValueKey('thread-unread-jump'),
            padding: const EdgeInsets.only(left: 12, right: 6),
            onPressed: onJump,
            semanticLabel: label,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RaftIcon(
                  up ? RaftGlyph.arrowUp : RaftGlyph.arrowDown,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          segment(
            key: const ValueKey('thread-unread-dismiss'),
            padding: const EdgeInsets.only(left: 4, right: 10),
            onPressed: onDismiss,
            semanticLabel: dismissLabel,
            child: RaftIcon(RaftGlyph.x, size: 14, color: muted),
          ),
        ],
      ),
    );
  }
}

/// Where the timeline's bottom controls sit (`absolute inset-x-0 bottom-3 flex
/// gap-2`): "Back to bottom" and the "Next unread thread" pill side by side,
/// centred. Place in the timeline Stack.
class RaftTimelineBottomControls extends StatelessWidget {
  const RaftTimelineBottomControls({super.key, this.button, this.pill});
  final Widget? button, pill;

  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 12,
    left: 0,
    right: 0,
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?button,
          if (button != null && pill != null) const SizedBox(width: 8),
          if (pill != null) Flexible(child: pill!),
        ],
      ),
    ),
  );
}

/// The "Earliest unread thread" pill at the top of the timeline
/// (`absolute inset-x-0 top-3 mx-auto`). Place in the timeline Stack.
class RaftTimelineTopPill extends StatelessWidget {
  const RaftTimelineTopPill({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Positioned(top: 12, left: 0, right: 0, child: Center(child: child));
}
