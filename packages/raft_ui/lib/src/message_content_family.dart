// WP-DS3 content family, Raft look only (raft-ui 0.95.3 / Web v1.24): the code
// block frame and its keyboard region, the markdown link run, and the pieces
// they share. The frozen looks (Elegant, Brutal) never reach this file.
import 'token_geometry.dart';
import 'package:flutter/material.dart';
import 'package:raft_theme/recipes.dart' show RaftRecipeSet;

import 'icons.dart';
import 'localization.dart';
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'theme.dart';

/// True for the Raft look; the frozen looks keep their own recipes.
bool raftContentLook(RaftTokens t) => t.recipeSet == RaftRecipeSet.raft;

/// `CodeBlock` (raft-ui `code-block.recipe.mjs`): `rounded-container`
/// `border-line-hairline` `bg-layer-code`, `py-2` body.
abstract final class RaftCodeBlockFrame {
  static BoxDecoration decoration(RaftTokens t) => BoxDecoration(
    color: t.colors['layer-code'],
    border: Border.all(color: t.colors['line-hairline']!, width: t.border),
    borderRadius: t.corner('radius.container', fallback: 10),
  );

  /// The text column keeps clear of the copy button: Web `px-3` (12) plus the
  /// 34px action and its 5px inset leave 51 on the right.
  // ignore: raft_lints/off_grid_spacing -- Web measured: 12 + 34 action + 5 inset.
  static const padding = EdgeInsets.fromLTRB(12, 8, 51, 8);

  /// Web body min height: the action (34) between two 5px margins, plus the
  /// frame border.
  static const minHeight = 46.0;

  /// Distance of the copy action from the outer corner.
  static const actionInset = 6.0;

  /// `CopyIconButton`: a ghost `icon-md` holding an 18px glyph.
  static Widget copyButton({
    required bool copied,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => RaftButton(
    label: '',
    uiVariant: RaftButtonVariant.ghost,
    uiSize: RaftButtonSize.iconMd,
    glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
    glyphSize: 18,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// Wraps the horizontal scroller of a code block. Only while the code
/// overflows is it a keyboard Tab stop labelled `Code` (Web `ui.codeBlock.region`:
/// `tabindex=0 role=region aria-label`), with a keyboard-only 2px foreground
/// inset ring; when it fits there is no extra stop.
class RaftCodeScrollRegion extends StatefulWidget {
  const RaftCodeScrollRegion({
    super.key,
    required this.child,
    required this.onOverflowChanged,
  });

  final Widget child;

  /// Called after layout whenever the overflow state flips.
  final ValueChanged<bool> onOverflowChanged;

  @override
  State<RaftCodeScrollRegion> createState() => _RaftCodeScrollRegionState();
}

class _RaftCodeScrollRegionState extends State<RaftCodeScrollRegion> {
  bool overflow = false, focused = false;

  bool onMetrics(ScrollMetricsNotification n) {
    if (n.metrics.axis != Axis.horizontal) return false;
    final next = n.metrics.maxScrollExtent > 0;
    if (next != overflow && mounted) {
      setState(() => overflow = next);
      widget.onOverflowChanged(next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final keyboard =
        focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: onMetrics,
      child: Focus(
        key: const ValueKey('code-block-region'),
        canRequestFocus: overflow,
        skipTraversal: !overflow,
        onFocusChange: (value) => setState(() => focused = value),
        child: Semantics(
          container: overflow,
          focusable: overflow,
          focused: overflow && focused,
          label: overflow ? raftText(context, 'Code') : null,
          child: Stack(
            children: [
              ExcludeSemantics(excluding: overflow, child: widget.child),
              if (overflow && keyboard)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const ValueKey('code-block-ring'),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: t.colors['foreground']!,
                          width: t.border * 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
