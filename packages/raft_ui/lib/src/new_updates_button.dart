import 'package:flutter/widgets.dart';

import 'dialog_card.dart';
import 'icons.dart';
import 'recipes/button_variants.g.dart';

/// Source ThreadsInbox.tsx (`thread.newUpdates` pill): an outline `sm` Button
/// `sticky top-0 left-1/2 -translate-x-1/2 z-10 flex items-center gap-1.5
/// px-3 py-1.5 text-xs font-bold` with `ArrowUp size={14}`, pinned to the top
/// of the scroll container while the reader is scrolled away from the top.
/// Place in a Stack over the list. The host owns visibility, the count,
/// localization and the scroll to the top.
class RaftNewUpdatesButton extends StatelessWidget {
  const RaftNewUpdatesButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: Center(
      child: RaftRecipeButton(
        label: label,
        glyph: RaftGlyph.arrowUp,
        glyphSize: 14,
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
