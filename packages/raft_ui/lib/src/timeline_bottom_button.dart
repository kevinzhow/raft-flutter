import 'package:flutter/widgets.dart';

import 'dialog_card.dart';
import 'icons.dart';
import 'recipes/button_variants.g.dart';

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
      child: RaftRecipeButton(
        label: label,
        glyph: RaftGlyph.arrowDown,
        glyphSize: 12,
        variant: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.sm,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStep: (12, 16),
        gap: 6,
        onPressed: onPressed,
      ),
    ),
  );
}
